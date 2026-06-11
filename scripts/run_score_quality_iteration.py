"""Run an inspectable score-quality iteration against one imported score page.

This harness is intentionally outside the API server. It reuses the same engine
adapters as production processing, writes each candidate into its own folder, and
selects the closest valid rendered PDF by the existing visual-diff heuristic.
"""

from __future__ import annotations

# ruff: noqa: E402
import argparse
import json
import shutil
import sys
from dataclasses import asdict, is_dataclass
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

import pypdfium2 as pdfium
from PIL import Image, ImageDraw, ImageFont
from server.routers.review import _run_verified_local_llm_score_edits
from server.services.local_llm import LocalLlmProvider
from server.services.processing_engines import (
    LegatoMusicXmlEngine,
    MuseScoreRenderEngine,
    ProcessingEngineError,
)
from server.services.score_visual_diff import ScoreVisualDiffError, compare_score_pdfs


def main() -> int:
    args = _parse_args()
    output_dir = args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    settings = {
        "musescore_cli_path": str(args.musescore_cli) if args.musescore_cli else None,
        "production_mode": True,
        "legato_cli_path": str(args.legato_cli) if args.legato_cli else None,
        "legato_model_path": args.legato_model,
        "omr_strategy": "legato_experimental",
        "local_llm_provider": "lmstudio" if args.run_local_llm else None,
        "local_llm_base_url": args.lmstudio_base_url,
        "local_llm_model": args.lmstudio_model,
    }
    candidate_data = {
        "title": args.title,
        "composer": args.composer,
        "instrumentation": args.instrument,
        "instrument": args.instrument,
    }

    candidates: list[dict[str, Any]] = []
    if args.baseline_musicxml and args.baseline_rendered:
        candidates.append(
            _record_existing_candidate(
                label="baseline",
                original_pdf=args.original_pdf,
                musicxml_path=args.baseline_musicxml,
                rendered_pdf=args.baseline_rendered,
                output_dir=output_dir / "baseline",
            )
        )

    if args.legato_cli and args.legato_model:
        candidates.append(
            _run_legato_candidate(
                original_pdf=args.original_pdf,
                output_dir=output_dir / "legato",
                title=args.title,
                composer=args.composer,
                instrument=args.instrument,
                settings=settings,
            )
        )

    llm_candidates: list[dict[str, Any]] = []
    if args.run_local_llm:
        for candidate in list(candidates):
            if candidate.get("status") != "valid":
                continue
            llm_candidates.append(
                _run_local_llm_candidate(
                    original_pdf=args.original_pdf,
                    candidate=candidate,
                    output_dir=output_dir / f"{candidate['id']}-llm",
                    settings=settings,
                    candidate_data=candidate_data,
                    parent_notes=args.parent_notes,
                )
            )
    candidates.extend(llm_candidates)

    selected = _select_best_candidate(candidates)
    summary = {
        "original_pdf": str(args.original_pdf),
        "selected_candidate_id": selected.get("id") if selected else "original_pdf_fallback",
        "selected_label": selected.get("label") if selected else "Original PDF fallback",
        "selected_similarity": selected.get("visual_similarity") if selected else 1.0,
        "candidates": candidates,
    }
    summary_path = output_dir / "score-quality-iteration.json"
    summary_path.write_text(json.dumps(_clean(summary), indent=2), encoding="utf-8")

    comparison_path = output_dir / "score-quality-iteration-three-up.png"
    _write_comparison(
        original_pdf=args.original_pdf,
        baseline_pdf=args.baseline_rendered,
        selected_pdf=Path(selected["rendered_pdf"]) if selected else args.original_pdf,
        comparison_path=comparison_path,
    )

    print(
        json.dumps(
            {
                "summary": str(summary_path),
                "comparison": str(comparison_path),
                "selected_candidate_id": summary["selected_candidate_id"],
                "selected_similarity": summary["selected_similarity"],
                "candidate_count": len(candidates),
            },
            indent=2,
        )
    )
    return 0


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--original-pdf", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--title", default="Untitled score")
    parser.add_argument("--composer", default=None)
    parser.add_argument("--instrument", default="Cello")
    parser.add_argument("--musescore-cli", type=Path, required=True)
    parser.add_argument("--baseline-musicxml", type=Path)
    parser.add_argument("--baseline-rendered", type=Path)
    parser.add_argument("--legato-cli", type=Path)
    parser.add_argument("--legato-model")
    parser.add_argument("--run-local-llm", action="store_true")
    parser.add_argument("--lmstudio-base-url", default="http://127.0.0.1:1235/v1")
    parser.add_argument("--lmstudio-model", default=None)
    parser.add_argument(
        "--parent-notes",
        default=(
            "Focus on notation accuracy and preserve the original PDF as fallback "
            "if a correction is uncertain."
        ),
    )
    return parser.parse_args()


def _record_existing_candidate(
    *,
    label: str,
    original_pdf: Path,
    musicxml_path: Path,
    rendered_pdf: Path,
    output_dir: Path,
) -> dict[str, Any]:
    output_dir.mkdir(parents=True, exist_ok=True)
    copied_musicxml = output_dir / musicxml_path.name
    copied_rendered = output_dir / rendered_pdf.name
    shutil.copy2(musicxml_path, copied_musicxml)
    shutil.copy2(rendered_pdf, copied_rendered)
    return _candidate_result(
        candidate_id=label,
        label="Baseline OMR candidate",
        engine_name="baseline",
        musicxml_path=copied_musicxml,
        rendered_pdf=copied_rendered,
        original_pdf=original_pdf,
    )


def _run_legato_candidate(
    *,
    original_pdf: Path,
    output_dir: Path,
    title: str,
    composer: str | None,
    instrument: str,
    settings: dict[str, Any],
) -> dict[str, Any]:
    output_dir.mkdir(parents=True, exist_ok=True)
    musicxml_path = output_dir / "candidate-legato.musicxml"
    rendered_pdf = output_dir / "candidate-legato.pdf"
    try:
        musicxml = LegatoMusicXmlEngine().generate(
            raw_pdf_path=original_pdf,
            output_path=musicxml_path,
            title=title,
            composer=composer,
            primary_instrument=instrument,
            processing_settings=settings,
        )
        render = MuseScoreRenderEngine().render(
            canonical_path=musicxml.file_path,
            raw_pdf_path=original_pdf,
            output_pdf_path=rendered_pdf,
            processing_settings=settings,
        )
    except ProcessingEngineError as exc:
        return {
            "id": "legato",
            "label": "LEGATO experimental",
            "engine_name": "legato",
            "status": "failed",
            "error": str(exc),
            "diagnostics": getattr(exc, "diagnostics", {}),
        }
    result = _candidate_result(
        candidate_id="legato",
        label="LEGATO experimental",
        engine_name=musicxml.engine_name,
        musicxml_path=musicxml.file_path,
        rendered_pdf=render.file_path,
        original_pdf=original_pdf,
    )
    result["warnings"] = [*musicxml.warnings, *render.warnings]
    result["metadata"] = musicxml.metadata
    return result


def _run_local_llm_candidate(
    *,
    original_pdf: Path,
    candidate: dict[str, Any],
    output_dir: Path,
    settings: dict[str, Any],
    candidate_data: dict[str, Any],
    parent_notes: str,
) -> dict[str, Any]:
    output_dir.mkdir(parents=True, exist_ok=True)
    provider = LocalLlmProvider(settings)
    try:
        llm_result = provider.review_score(
            raw_pdf_path=original_pdf,
            rendered_pdf_path=Path(candidate["rendered_pdf"]),
            canonical_musicxml_path=Path(candidate["musicxml_path"]),
            candidate_data={**candidate_data, "engine_name": candidate.get("engine_name")},
            parent_notes=parent_notes,
        )
        loop = _run_verified_local_llm_score_edits(
            provider=provider,
            settings_payload=settings,
            raw_path=original_pdf,
            rendered_path=Path(candidate["rendered_pdf"]),
            canonical_path=Path(candidate["musicxml_path"]),
            candidate_data=candidate_data,
            parent_notes=parent_notes,
            llm_result=llm_result,
            workspace=output_dir / "verified-edits",
        )
    except Exception as exc:  # noqa: BLE001 - harness should record all failures
        return {
            "id": f"{candidate['id']}-llm",
            "label": f"{candidate['label']} + LLM",
            "engine_name": "local_llm",
            "status": "failed",
            "error": str(exc),
        }

    if not loop["accepted_tool_results"]:
        return {
            "id": f"{candidate['id']}-llm",
            "label": f"{candidate['label']} + LLM",
            "engine_name": "local_llm",
            "status": "rejected",
            "error": "No verified notation edits were safe enough to publish.",
            "measure_reviews": loop["measure_reviews"],
        }

    return _candidate_result(
        candidate_id=f"{candidate['id']}-llm",
        label=f"{candidate['label']} + LLM",
        engine_name="local_llm",
        musicxml_path=Path(loop["canonical_path"]),
        rendered_pdf=Path(loop["rendered_path"]),
        original_pdf=original_pdf,
        extra={"measure_reviews": loop["measure_reviews"]},
    )


def _candidate_result(
    *,
    candidate_id: str,
    label: str,
    engine_name: str,
    musicxml_path: Path,
    rendered_pdf: Path,
    original_pdf: Path,
    extra: dict[str, Any] | None = None,
) -> dict[str, Any]:
    try:
        visual_diff = compare_score_pdfs(
            before_pdf_path=rendered_pdf,
            after_pdf_path=rendered_pdf,
            original_pdf_path=original_pdf,
        )
        similarity = _visual_similarity(visual_diff)
    except ScoreVisualDiffError as exc:
        return {
            "id": candidate_id,
            "label": label,
            "engine_name": engine_name,
            "status": "failed",
            "error": str(exc),
            "musicxml_path": str(musicxml_path),
            "rendered_pdf": str(rendered_pdf),
        }

    return {
        "id": candidate_id,
        "label": label,
        "engine_name": engine_name,
        "status": "valid",
        "musicxml_path": str(musicxml_path),
        "rendered_pdf": str(rendered_pdf),
        "visual_similarity": similarity,
        "visual_diff": visual_diff,
        **(extra or {}),
    }


def _select_best_candidate(candidates: list[dict[str, Any]]) -> dict[str, Any] | None:
    valid = [
        candidate
        for candidate in candidates
        if candidate.get("status") == "valid"
        and isinstance(candidate.get("visual_similarity"), (int, float))
    ]
    if not valid:
        return None
    return max(valid, key=lambda candidate: float(candidate["visual_similarity"]))


def _visual_similarity(visual_diff: dict[str, Any]) -> float | None:
    alignment = visual_diff.get("original_alignment")
    if not isinstance(alignment, list) or not alignment:
        return None
    ratios = [
        float(item.get("changed_pixel_ratio"))
        for item in alignment
        if isinstance(item, dict) and item.get("changed_pixel_ratio") is not None
    ]
    if not ratios:
        return None
    return max(0.0, min(1.0, 1.0 - max(ratios)))


def _write_comparison(
    *,
    original_pdf: Path,
    baseline_pdf: Path | None,
    selected_pdf: Path,
    comparison_path: Path,
) -> None:
    images = [(_render_first_page(original_pdf), "Original PDF")]
    if baseline_pdf is not None and baseline_pdf.exists():
        images.append((_render_first_page(baseline_pdf), "Baseline render"))
    images.append((_render_first_page(selected_pdf), "Selected output"))
    pad = 24
    label_h = 44
    width = sum(image.width for image, _ in images) + pad * (len(images) + 1)
    height = max(image.height for image, _ in images) + label_h + pad * 2
    canvas = Image.new("RGB", (width, height), "white")
    draw = ImageDraw.Draw(canvas)
    try:
        font = ImageFont.truetype("arial.ttf", 20)
    except OSError:
        font = ImageFont.load_default()
    x = pad
    for image, label in images:
        draw.text((x, pad // 2), label, fill="black", font=font)
        canvas.paste(image, (x, label_h + pad))
        x += image.width + pad
    canvas.save(comparison_path)


def _render_first_page(path: Path) -> Image.Image:
    document = pdfium.PdfDocument(str(path))
    try:
        page = document[0]
        try:
            bitmap = page.render(scale=1.6)
            image = bitmap.to_pil().convert("RGB")
            image.thumbnail((760, 1000))
            return image
        finally:
            close = getattr(page, "close", None)
            if callable(close):
                close()
    finally:
        close = getattr(document, "close", None)
        if callable(close):
            close()


def _clean(value: Any) -> Any:
    if is_dataclass(value):
        return _clean(asdict(value))
    if isinstance(value, Path):
        return str(value)
    if isinstance(value, dict):
        return {str(key): _clean(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_clean(item) for item in value]
    return value


if __name__ == "__main__":
    raise SystemExit(main())

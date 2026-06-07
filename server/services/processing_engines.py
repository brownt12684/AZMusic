"""Processing engine adapters for MusicXML generation and PDF rendering."""

from __future__ import annotations

import copy
import shutil
import subprocess
import sys
import tempfile
import zipfile
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any
from xml.etree import ElementTree

from server.services.processing_settings import executable_status, homr_status

OMR_SPACING_NORMALIZATION_PROFILE = "balanced_omr"
DEFAULT_MUSESCORE_STYLE_PATH = (
    Path(__file__).resolve().parents[1] / "assets" / "musescore" / "azmusic-default.mss"
)


class ProcessingEngineError(RuntimeError):
    """Raised when a configured processing engine cannot produce an artifact."""

    def __init__(self, message: str, *, diagnostics: dict[str, Any] | None = None) -> None:
        super().__init__(message)
        self.diagnostics = diagnostics or {}


@dataclass(slots=True)
class MusicXmlResult:
    file_path: Path
    engine_name: str
    engine_version: str | None
    provenance: str
    confidence: float
    warnings: list[str] = field(default_factory=list)
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(slots=True)
class RenderResult:
    file_path: Path
    renderer_name: str
    renderer_version: str | None
    provenance: str
    warnings: list[str] = field(default_factory=list)
    validation_status: str = "valid"
    validation_error: str | None = None
    file_size_bytes: int | None = None
    page_count: int | None = None
    diagnostics: dict[str, Any] = field(default_factory=dict)


class MusicXmlEngine:
    def generate(
        self,
        *,
        raw_pdf_path: Path,
        output_path: Path,
        title: str,
        composer: str | None,
        primary_instrument: str | None = None,
        contained_piece_titles: list[str] | None = None,
        multi_piece_page: bool = False,
        processing_settings: dict[str, Any],
    ) -> MusicXmlResult:
        audiveris_path = processing_settings.get("audiveris_cli_path")
        homr_path = processing_settings.get("homr_cli_path")
        omr_strategy = str(processing_settings.get("omr_strategy") or "audiveris_default")
        allow_stub = processing_settings.get("allow_stub_musicxml", True)
        production_mode = bool(processing_settings.get("production_mode"))

        if omr_strategy == "homr_experimental":
            if homr_path:
                result = HomrMusicXmlEngine().generate(
                    raw_pdf_path=raw_pdf_path,
                    output_path=output_path,
                    title=title,
                    composer=composer,
                    primary_instrument=primary_instrument,
                    contained_piece_titles=contained_piece_titles,
                    multi_piece_page=multi_piece_page,
                    processing_settings=processing_settings,
                )
                return _normalize_result_metadata(
                    result,
                    output_path=output_path,
                    title=title,
                    composer=composer,
                    primary_instrument=primary_instrument,
                    contained_piece_titles=contained_piece_titles,
                    multi_piece_page=multi_piece_page,
                )
            raise ProcessingEngineError(
                "HOMR experimental OMR was selected, but HOMR is not configured."
            )

        if audiveris_path:
            result = AudiverisMusicXmlEngine().generate(
                raw_pdf_path=raw_pdf_path,
                output_path=output_path,
                title=title,
                composer=composer,
                primary_instrument=primary_instrument,
                contained_piece_titles=contained_piece_titles,
                multi_piece_page=multi_piece_page,
                processing_settings=processing_settings,
            )
            return _normalize_result_metadata(
                result,
                output_path=output_path,
                title=title,
                composer=composer,
                primary_instrument=primary_instrument,
                contained_piece_titles=contained_piece_titles,
                multi_piece_page=multi_piece_page,
            )

        if omr_strategy in {"omr_bakeoff", "experimental_engine_bakeoff"} and homr_path:
            result = HomrMusicXmlEngine().generate(
                raw_pdf_path=raw_pdf_path,
                output_path=output_path,
                title=title,
                composer=composer,
                primary_instrument=primary_instrument,
                contained_piece_titles=contained_piece_titles,
                multi_piece_page=multi_piece_page,
                processing_settings=processing_settings,
            )
            return _normalize_result_metadata(
                result,
                output_path=output_path,
                title=title,
                composer=composer,
                primary_instrument=primary_instrument,
                contained_piece_titles=contained_piece_titles,
                multi_piece_page=multi_piece_page,
            )

        if production_mode:
            raise ProcessingEngineError(
                "Production processing requires Audiveris; stub MusicXML is disabled."
            )

        if allow_stub:
            result = StubMusicXmlEngine().generate(
                raw_pdf_path=raw_pdf_path,
                output_path=output_path,
                title=title,
                composer=composer,
                primary_instrument=primary_instrument,
                contained_piece_titles=contained_piece_titles,
                multi_piece_page=multi_piece_page,
                processing_settings=processing_settings,
            )
            return _normalize_result_metadata(
                result,
                output_path=output_path,
                title=title,
                composer=composer,
                primary_instrument=primary_instrument,
                contained_piece_titles=contained_piece_titles,
                multi_piece_page=multi_piece_page,
            )

        raise ProcessingEngineError(
            "Audiveris is not configured and stub MusicXML generation is disabled."
        )

    def generate_multi_piece_segments(
        self,
        *,
        raw_pdf_paths: list[Path],
        output_path: Path,
        title: str,
        composer: str | None,
        primary_instrument: str | None = None,
        contained_piece_titles: list[str] | None = None,
        processing_settings: dict[str, Any],
    ) -> MusicXmlResult:
        """Run OMR per shared-page crop, then merge the crops sequentially.

        A single multi-page crop PDF causes Audiveris to interpret each crop as a
        simultaneous part/staff in some books. Processing each crop as its own score
        keeps the songs sequential and prevents dropped systems in the MuseScore review.
        """

        piece_titles = _clean_piece_titles(contained_piece_titles)
        if len(raw_pdf_paths) < 2 or len(piece_titles) < 2:
            return self.generate(
                raw_pdf_path=raw_pdf_paths[0],
                output_path=output_path,
                title=title,
                composer=composer,
                primary_instrument=primary_instrument,
                contained_piece_titles=contained_piece_titles,
                multi_piece_page=True,
                processing_settings=processing_settings,
            )

        segment_results: list[MusicXmlResult] = []
        warnings: list[str] = [
            "Multiple pieces share one source page; each crop was processed separately "
            "and merged sequentially to avoid Audiveris treating songs as simultaneous parts."
        ]
        for index, raw_pdf_path in enumerate(raw_pdf_paths):
            segment_title = (
                piece_titles[index] if index < len(piece_titles) else f"Piece {index + 1}"
            )
            segment_output_path = output_path.with_name(
                f"{output_path.stem}_segment_{index + 1}.musicxml"
            )
            segment_result = self.generate(
                raw_pdf_path=raw_pdf_path,
                output_path=segment_output_path,
                title=segment_title,
                composer=composer,
                primary_instrument=primary_instrument,
                contained_piece_titles=None,
                multi_piece_page=False,
                processing_settings=processing_settings,
            )
            segment_results.append(segment_result)
            warnings.extend(segment_result.warnings)

        alternative_attempts, alternative_warnings = _merged_segment_omr_attempts(
            segment_results,
            output_path=output_path,
            catalog_title=title,
            composer=composer,
            primary_instrument=primary_instrument,
            piece_titles=piece_titles,
        )
        warnings.extend(alternative_warnings)

        merge_warnings, spacing_metadata = _merge_multi_piece_musicxml_segments(
            [result.file_path for result in segment_results],
            output_path=output_path,
            catalog_title=title,
            composer=composer,
            primary_instrument=primary_instrument,
            piece_titles=piece_titles,
        )
        warnings.extend(merge_warnings)
        metadata = _validate_musicxml(output_path)
        metadata["title"] = title
        metadata["contained_piece_titles"] = piece_titles
        metadata["multi_piece_segment_count"] = len(segment_results)
        if alternative_attempts:
            metadata["omr_attempts"] = alternative_attempts
        metadata.update(
            _combine_spacing_normalization_metadata(
                *(result.metadata for result in segment_results),
                spacing_metadata,
            )
        )
        if primary_instrument:
            metadata["primary_instrument"] = primary_instrument
        engine_names = sorted({result.engine_name for result in segment_results})
        engine_versions = sorted(
            {result.engine_version for result in segment_results if result.engine_version}
        )
        confidences = [result.confidence for result in segment_results]
        return MusicXmlResult(
            file_path=output_path,
            engine_name="+".join(engine_names) + "_segment_merge",
            engine_version=", ".join(engine_versions) if engine_versions else None,
            provenance="audiveris_omr_segment_merge"
            if "audiveris" in engine_names
            else "multi_piece_segment_merge",
            confidence=min(confidences) if confidences else 0.72,
            warnings=sorted(set(warnings)),
            metadata=metadata,
        )


class StubMusicXmlEngine:
    def generate(
        self,
        *,
        raw_pdf_path: Path,
        output_path: Path,
        title: str,
        composer: str | None,
        primary_instrument: str | None = None,
        contained_piece_titles: list[str] | None = None,
        multi_piece_page: bool = False,
        processing_settings: dict[str, Any],
    ) -> MusicXmlResult:
        piece_titles = _clean_piece_titles(contained_piece_titles)
        measure_count = 1
        if multi_piece_page and len(piece_titles) > 1:
            measure_count = len(piece_titles) * 2
        output_path.write_text(
            _build_stub_musicxml(
                title=title,
                composer=composer,
                primary_instrument=primary_instrument or "Violin",
                measure_count=measure_count,
            ),
            encoding="utf-8",
        )
        metadata = _validate_musicxml(output_path)
        return MusicXmlResult(
            file_path=output_path,
            engine_name="stub",
            engine_version="deterministic-v1",
            provenance="fixture_stub_musicxml",
            confidence=0.64,
            warnings=["Audiveris is not configured; generated deterministic stub MusicXML."],
            metadata=metadata,
        )


class AudiverisMusicXmlEngine:
    def generate(
        self,
        *,
        raw_pdf_path: Path,
        output_path: Path,
        title: str,
        composer: str | None,
        primary_instrument: str | None = None,
        contained_piece_titles: list[str] | None = None,
        multi_piece_page: bool = False,
        processing_settings: dict[str, Any],
    ) -> MusicXmlResult:
        cli_path = processing_settings.get("audiveris_cli_path")
        if not cli_path:
            raise ProcessingEngineError("Audiveris CLI path is not configured.")

        status = executable_status(
            name="Audiveris",
            configured_path=cli_path,
            fallback_names=("audiveris",),
        )
        if not status.discovered_path:
            raise ProcessingEngineError("Configured Audiveris executable was not found.")

        strategy = str(processing_settings.get("omr_strategy") or "audiveris_default")
        attempts: list[dict[str, Any]] = []
        best_candidate: tuple[Path, dict[str, Any], float] | None = None

        with tempfile.TemporaryDirectory(prefix="azmusic_audiveris_") as temp_dir:
            temp_path = Path(temp_dir)
            for profile in _audiveris_profiles_for(strategy):
                output_dir = output_path.parent / "audiveris-output" / profile["name"]
                output_dir.mkdir(parents=True, exist_ok=True)
                input_path = _audiveris_input_for_profile(
                    raw_pdf_path,
                    temp_path=temp_path,
                    profile=profile,
                )
                command = _command_prefix(status.discovered_path) + [
                    "-batch",
                    "-transcribe",
                    "-export",
                    "-output",
                    str(output_dir),
                ]
                if profile.get("force"):
                    command.append("-force")
                if profile.get("save"):
                    command.append("-save")
                command.append(str(input_path))
                result = subprocess.run(
                    command,
                    check=False,
                    capture_output=True,
                    text=True,
                    encoding="utf-8",
                    errors="replace",
                    timeout=300,
                )
                attempt = {
                    "engine": "audiveris",
                    "profile": profile["name"],
                    "input_mode": profile.get("input_mode", "source"),
                    "input_path": str(input_path),
                    "output_dir": str(output_dir),
                    "command": command,
                    "exit_code": result.returncode,
                    "stdout_excerpt": (result.stdout or "")[-1000:],
                    "stderr_excerpt": (result.stderr or "")[-1000:],
                }
                attempts.append(attempt)
                if result.returncode != 0:
                    attempt["error"] = _summarize_process_failure(
                        "Audiveris",
                        result.stderr or result.stdout,
                        exit_code=result.returncode,
                    )
                    continue

                candidate_path = _find_musicxml_output(output_dir)
                if candidate_path is None:
                    attempt["error"] = "Audiveris completed without producing MusicXML."
                    continue
                metadata = _validate_musicxml(candidate_path)
                quality_score = _musicxml_quality_score(metadata, candidate_path)
                attempt["candidate_path"] = str(candidate_path)
                attempt["metadata"] = metadata
                attempt["quality_score"] = quality_score
                if best_candidate is None or quality_score > best_candidate[2]:
                    best_candidate = (candidate_path, metadata, quality_score)

            if strategy in {"omr_bakeoff", "experimental_engine_bakeoff"}:
                homr_attempt = _run_homr_bakeoff_attempt(
                    raw_pdf_path=raw_pdf_path,
                    output_path=output_path.with_name(f"{output_path.stem}_homr.musicxml"),
                    title=title,
                    composer=composer,
                    primary_instrument=primary_instrument,
                    contained_piece_titles=contained_piece_titles,
                    multi_piece_page=multi_piece_page,
                    processing_settings=processing_settings,
                )
                attempts.append(homr_attempt)
                if homr_attempt.get("candidate_path"):
                    homr_path = Path(str(homr_attempt["candidate_path"]))
                    try:
                        homr_metadata = _validate_musicxml(homr_path)
                        homr_score = float(homr_attempt.get("quality_score") or 0.0)
                        if best_candidate is None or homr_score > best_candidate[2]:
                            best_candidate = (homr_path, homr_metadata, homr_score)
                    except Exception as exc:
                        homr_attempt["error"] = f"HOMR candidate validation failed: {exc}"
                attempts.extend(_alternative_omr_engine_placeholders(raw_pdf_path))

        if best_candidate is None:
            failures = [
                attempt.get("error")
                for attempt in attempts
                if isinstance(attempt.get("error"), str) and attempt.get("error")
            ]
            detail = failures[0] if failures else "Audiveris completed without producing MusicXML."
            raise ProcessingEngineError(detail, diagnostics={"omr_attempts": attempts})

        candidate_path, _candidate_metadata, quality_score = best_candidate

        final_path = output_path
        if candidate_path.suffix.lower() == ".mxl":
            final_path = output_path.with_suffix(".mxl")
        if candidate_path != final_path:
            shutil.copy2(candidate_path, final_path)

        metadata = _validate_musicxml(final_path)
        metadata["omr_strategy"] = strategy
        metadata["omr_quality_score"] = quality_score
        metadata["omr_attempts"] = _sanitize_omr_attempts(attempts)
        return MusicXmlResult(
            file_path=final_path,
            engine_name="audiveris",
            engine_version=status.version,
            provenance="audiveris_omr",
            confidence=0.82,
            warnings=_warnings_from_omr_attempts(attempts),
            metadata=metadata,
        )


class HomrMusicXmlEngine:
    def generate(
        self,
        *,
        raw_pdf_path: Path,
        output_path: Path,
        title: str,
        composer: str | None,
        primary_instrument: str | None = None,
        contained_piece_titles: list[str] | None = None,
        multi_piece_page: bool = False,
        processing_settings: dict[str, Any],
    ) -> MusicXmlResult:
        status = homr_status(processing_settings)
        if not status.discovered_path:
            raise ProcessingEngineError("HOMR CLI path is not configured or discoverable.")

        output_dir = output_path.parent / "homr-output" / output_path.stem
        output_dir.mkdir(parents=True, exist_ok=True)
        image_path, input_warnings = _homr_input_image(raw_pdf_path, output_dir=output_dir)
        command = _command_prefix(status.discovered_path) + [str(image_path)]
        result = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=600,
            cwd=str(output_dir),
        )
        diagnostics = {
            "engine": "homr",
            "input_path": str(image_path),
            "output_dir": str(output_dir),
            "command": command,
            "exit_code": result.returncode,
            "stdout_excerpt": (result.stdout or "")[-1000:],
            "stderr_excerpt": (result.stderr or "")[-1000:],
        }
        if result.returncode != 0:
            raise ProcessingEngineError(
                _summarize_process_failure(
                    "HOMR",
                    result.stderr or result.stdout,
                    exit_code=result.returncode,
                ),
                diagnostics={"omr_attempts": [diagnostics]},
            )

        candidate_path = _find_musicxml_output(output_dir)
        if candidate_path is None:
            raise ProcessingEngineError(
                "HOMR completed without producing MusicXML.",
                diagnostics={"omr_attempts": [diagnostics]},
            )
        if candidate_path != output_path:
            shutil.copy2(candidate_path, output_path)

        metadata = _validate_musicxml(output_path)
        metadata["omr_strategy"] = str(
            processing_settings.get("omr_strategy") or "homr_experimental"
        )
        metadata["omr_quality_score"] = _musicxml_quality_score(metadata, output_path)
        metadata["omr_attempts"] = _sanitize_omr_attempts(
            [
                {
                    **diagnostics,
                    "candidate_path": str(output_path),
                    "quality_score": metadata["omr_quality_score"],
                }
            ]
        )
        warnings = list(input_warnings)
        if multi_piece_page and contained_piece_titles:
            warnings.append(
                "HOMR processed a shared-page segment; verify each contained title "
                "before approval."
            )
        return MusicXmlResult(
            file_path=output_path,
            engine_name="homr",
            engine_version=status.version,
            provenance="homr_omr",
            confidence=0.72,
            warnings=warnings,
            metadata=metadata,
        )


class MuseScoreRenderEngine:
    def render(
        self,
        *,
        canonical_path: Path,
        raw_pdf_path: Path,
        output_pdf_path: Path,
        processing_settings: dict[str, Any],
    ) -> RenderResult:
        cli_path = processing_settings.get("musescore_cli_path")
        if not cli_path:
            if processing_settings.get("production_mode"):
                raise ProcessingEngineError("Production processing requires MuseScore rendering.")
            shutil.copy2(raw_pdf_path, output_pdf_path)
            return RenderResult(
                file_path=output_pdf_path,
                renderer_name="raw_pdf_fallback",
                renderer_version=None,
                provenance="raw_pdf_copy",
                warnings=["MuseScore is not configured; copied the raw PDF for parent review."],
                **validate_rendered_pdf(output_pdf_path, strict=False),
            )

        status = executable_status(
            name="MuseScore Studio",
            configured_path=cli_path,
            fallback_names=("musescore", "mscore", "MuseScore4"),
        )
        if not status.discovered_path:
            raise ProcessingEngineError("Configured MuseScore Studio executable was not found.")

        _validate_musicxml(canonical_path)

        timeout_seconds = 300
        command = _command_prefix(status.discovered_path)
        warnings: list[str] = []
        style_path, style_source, style_warning = _resolve_musescore_style_path(
            processing_settings
        )
        configured_style_path = processing_settings.get("musescore_style_path")
        if style_path:
            command += ["-S", str(style_path)]
        if style_warning:
            warnings.append(style_warning)
        command += [
            "-f",
            str(canonical_path),
            "-o",
            str(output_pdf_path),
        ]
        try:
            result = subprocess.run(
                command,
                check=False,
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=timeout_seconds,
            )
        except subprocess.TimeoutExpired as exc:
            diagnostics = _process_diagnostics(
                command=command,
                output_path=output_pdf_path,
                timeout_seconds=timeout_seconds,
                timed_out=True,
                stdout=exc.stdout,
                stderr=exc.stderr,
            )
            raise ProcessingEngineError(
                f"MuseScore Studio timed out after {timeout_seconds} seconds.",
                diagnostics=diagnostics,
            ) from exc

        diagnostics = _process_diagnostics(
            command=command,
            output_path=output_pdf_path,
            timeout_seconds=timeout_seconds,
            exit_code=result.returncode,
            stdout=result.stdout,
            stderr=result.stderr,
        )
        diagnostics["style_source"] = style_source
        if configured_style_path or style_path:
            diagnostics["style_path"] = str(style_path or configured_style_path)
            diagnostics["style_applied"] = style_path is not None
        if result.returncode != 0 or not output_pdf_path.exists():
            raise ProcessingEngineError(
                _summarize_process_failure(
                    "MuseScore Studio",
                    result.stderr or result.stdout,
                    exit_code=result.returncode,
                ),
                diagnostics=diagnostics,
            )
        validation = validate_rendered_pdf(output_pdf_path, strict=True)
        diagnostics["validation_status"] = validation["validation_status"]
        diagnostics["validation_error"] = validation["validation_error"]
        if validation["validation_status"] != "valid":
            raise ProcessingEngineError(
                f"MuseScore did not produce a usable review PDF: {validation['validation_error']}",
                diagnostics=diagnostics,
            )

        return RenderResult(
            file_path=output_pdf_path,
            renderer_name="musescore",
            renderer_version=status.version,
            provenance="musescore_render",
            warnings=warnings,
            diagnostics=diagnostics,
            **validation,
        )


def _resolve_musescore_style_path(
    processing_settings: dict[str, Any],
) -> tuple[Path | None, str, str | None]:
    raw_value = processing_settings.get("musescore_style_path")
    if isinstance(raw_value, str) and raw_value.strip():
        style_path = Path(raw_value.strip())
        if style_path.exists() and style_path.is_file():
            return style_path, "custom", None
        return (
            None,
            "custom_missing",
            f"MuseScore style file was configured but not found: {raw_value}",
        )
    if DEFAULT_MUSESCORE_STYLE_PATH.exists() and DEFAULT_MUSESCORE_STYLE_PATH.is_file():
        return DEFAULT_MUSESCORE_STYLE_PATH, "azmusic_default", None
    return None, "none", None


def _audiveris_profiles_for(strategy: str) -> list[dict[str, Any]]:
    if strategy in {"audiveris_quality_sweep", "experimental_engine_bakeoff"}:
        return [
            {"name": "default", "input_mode": "source"},
            {"name": "force_save", "input_mode": "source", "force": True, "save": True},
            {
                "name": "highres_page_3x",
                "input_mode": "rendered_page",
                "render_scale": 3,
                "force": True,
                "save": True,
            },
        ]
    return [{"name": "default", "input_mode": "source"}]


def _alternative_omr_engine_placeholders(raw_pdf_path: Path) -> list[dict[str, Any]]:
    return [
        {
            "engine": "omrchecker",
            "profile": "metadata_only_skip",
            "input_path": str(raw_pdf_path),
            "skipped": True,
            "error": (
                "OMRChecker targets bubble-sheet mark recognition and does not "
                "produce MusicXML for sheet music."
            ),
        },
        {
            "engine": "openomr",
            "profile": "musicxml_export_unavailable",
            "input_path": str(raw_pdf_path),
            "skipped": True,
            "error": (
                "OpenOMR is tracked as an exploratory music OMR candidate, but no "
                "installed MusicXML export adapter is configured."
            ),
        },
    ]


def _run_homr_bakeoff_attempt(
    *,
    raw_pdf_path: Path,
    output_path: Path,
    title: str,
    composer: str | None,
    primary_instrument: str | None,
    contained_piece_titles: list[str] | None,
    multi_piece_page: bool,
    processing_settings: dict[str, Any],
) -> dict[str, Any]:
    if not processing_settings.get("homr_cli_path"):
        return {
            "engine": "homr",
            "profile": "experimental",
            "input_path": str(raw_pdf_path),
            "skipped": True,
            "error": "HOMR CLI is not configured.",
        }
    try:
        result = HomrMusicXmlEngine().generate(
            raw_pdf_path=raw_pdf_path,
            output_path=output_path,
            title=title,
            composer=composer,
            primary_instrument=primary_instrument,
            contained_piece_titles=contained_piece_titles,
            multi_piece_page=multi_piece_page,
            processing_settings=processing_settings,
        )
        return {
            "engine": "homr",
            "profile": "experimental",
            "input_path": str(raw_pdf_path),
            "candidate_path": str(result.file_path),
            "metadata": result.metadata,
            "quality_score": result.metadata.get("omr_quality_score", 0.0),
            "warnings": result.warnings,
        }
    except ProcessingEngineError as exc:
        attempt = {
            "engine": "homr",
            "profile": "experimental",
            "input_path": str(raw_pdf_path),
            "error": str(exc),
        }
        diagnostics_attempts = exc.diagnostics.get("omr_attempts") if exc.diagnostics else None
        if isinstance(diagnostics_attempts, list) and diagnostics_attempts:
            attempt["diagnostics"] = diagnostics_attempts[0]
        return attempt


def _audiveris_input_for_profile(
    raw_pdf_path: Path,
    *,
    temp_path: Path,
    profile: dict[str, Any],
) -> Path:
    if profile.get("input_mode") != "rendered_page" or raw_pdf_path.suffix.lower() != ".pdf":
        return raw_pdf_path
    try:
        import pypdfium2 as pdfium
    except ImportError:
        return raw_pdf_path

    document = pdfium.PdfDocument(str(raw_pdf_path))
    try:
        if len(document) != 1:
            return raw_pdf_path
        page = document[0]
        try:
            bitmap = page.render(scale=int(profile.get("render_scale") or 3))
            image = bitmap.to_pil()
            rendered_path = temp_path / f"{raw_pdf_path.stem}_{profile['name']}.png"
            image.save(rendered_path)
            return rendered_path
        finally:
            page.close()
    finally:
        document.close()


def _homr_input_image(raw_path: Path, *, output_dir: Path) -> tuple[Path, list[str]]:
    warnings: list[str] = []
    suffix = raw_path.suffix.lower()
    if suffix in {".png", ".jpg", ".jpeg", ".webp", ".tif", ".tiff"}:
        destination = output_dir / raw_path.name
        if raw_path != destination:
            shutil.copy2(raw_path, destination)
        return destination, warnings
    if suffix != ".pdf":
        raise ProcessingEngineError(f"HOMR does not support {suffix or 'this file type'} input.")

    try:
        import pypdfium2 as pdfium
    except ImportError as exc:
        raise ProcessingEngineError("pypdfium2 is required to render PDF input for HOMR.") from exc

    document = pdfium.PdfDocument(str(raw_path))
    try:
        if len(document) > 1:
            warnings.append(
                "HOMR currently processes the first rendered page of a PDF attempt; "
                "book/multi-page imports should be split before HOMR."
            )
        page = document[0]
        try:
            bitmap = page.render(scale=3)
            image = bitmap.to_pil()
            image_path = output_dir / f"{raw_path.stem}_homr.png"
            image.save(image_path)
            return image_path, warnings
        finally:
            page.close()
    finally:
        document.close()


def _musicxml_quality_score(metadata: dict[str, Any], candidate_path: Path) -> float:
    measure_count = metadata.get("measure_count")
    part_count = metadata.get("part_count")
    score = 0.0
    if isinstance(measure_count, int):
        score += measure_count * 10
    if isinstance(part_count, int):
        score += max(0, 5 - abs(part_count - 1))
    try:
        score += min(candidate_path.stat().st_size / 10000, 10)
    except OSError:
        pass
    return score


def _warnings_from_omr_attempts(attempts: list[dict[str, Any]]) -> list[str]:
    if len(attempts) <= 1:
        return []
    failed_count = sum(1 for attempt in attempts if attempt.get("error"))
    return [
        f"Audiveris quality sweep tried {len(attempts)} profiles; {failed_count} failed."
    ]


def _sanitize_omr_attempts(attempts: Any) -> list[dict[str, Any]]:
    if not isinstance(attempts, list):
        return []
    return [
        _json_safe_metadata_value(attempt)
        for attempt in attempts
        if isinstance(attempt, dict)
    ]


def _json_safe_metadata_value(value: Any, seen: set[int] | None = None) -> Any:
    if value is None or isinstance(value, (str, int, float, bool)):
        return value
    if isinstance(value, Path):
        return str(value)

    seen = seen or set()
    value_id = id(value)
    if value_id in seen:
        return "<circular>"

    if isinstance(value, dict):
        seen.add(value_id)
        try:
            return {
                str(key): _json_safe_metadata_value(item, seen)
                for key, item in value.items()
                if key != "metadata"
            }
        finally:
            seen.remove(value_id)

    if isinstance(value, (list, tuple, set)):
        seen.add(value_id)
        try:
            return [_json_safe_metadata_value(item, seen) for item in value]
        finally:
            seen.remove(value_id)

    return str(value)


def _command_prefix(executable_path: str) -> list[str]:
    path = Path(executable_path)
    if path.suffix.lower() == ".py":
        return [sys.executable, str(path)]
    return [str(path)]


def validate_rendered_pdf(path: Path, *, strict: bool = True) -> dict[str, Any]:
    """Return validation metadata for a rendered review PDF."""
    if not path.exists():
        return _render_validation("missing", "Rendered PDF was not created.")

    try:
        file_size = path.stat().st_size
    except OSError as exc:
        return _render_validation("missing", f"Rendered PDF could not be inspected: {exc}")

    if file_size == 0:
        return _render_validation(
            "empty",
            "Rendered PDF is empty.",
            file_size_bytes=file_size,
        )
    if strict and file_size < 128:
        return _render_validation(
            "empty",
            f"Rendered PDF is too small to be a usable score ({file_size} bytes).",
            file_size_bytes=file_size,
        )

    try:
        from pypdf import PdfReader

        reader = PdfReader(str(path))
        page_count = len(reader.pages)
    except Exception as exc:  # pragma: no cover - pypdf error types vary by file
        if not strict:
            return _render_validation(
                "valid",
                None,
                file_size_bytes=file_size,
                page_count=None,
            )
        return _render_validation(
            "invalid_pdf",
            f"Rendered PDF could not be opened: {exc}",
            file_size_bytes=file_size,
        )

    if page_count < 1:
        return _render_validation(
            "invalid_pdf",
            "Rendered PDF has no pages.",
            file_size_bytes=file_size,
            page_count=page_count,
        )

    return _render_validation(
        "valid",
        None,
        file_size_bytes=file_size,
        page_count=page_count,
    )


def _render_validation(
    status: str,
    error: str | None,
    *,
    file_size_bytes: int | None = None,
    page_count: int | None = None,
) -> dict[str, Any]:
    return {
        "validation_status": status,
        "validation_error": error,
        "file_size_bytes": file_size_bytes,
        "page_count": page_count,
    }


def _find_musicxml_output(output_dir: Path) -> Path | None:
    candidates = [
        path
        for path in output_dir.rglob("*")
        if path.suffix.lower() in {".musicxml", ".xml", ".mxl"}
    ]
    if not candidates:
        return None
    return max(candidates, key=lambda path: path.stat().st_mtime)


def _validate_musicxml(path: Path) -> dict[str, Any]:
    try:
        root = _load_musicxml_root(path)
    except (ElementTree.ParseError, zipfile.BadZipFile, KeyError) as exc:
        raise ProcessingEngineError(f"Generated MusicXML is not valid XML: {exc}") from exc

    root_name = root.tag.rsplit("}", maxsplit=1)[-1]
    if root_name not in {"score-partwise", "score-timewise"}:
        raise ProcessingEngineError(
            f"Generated MusicXML root must be score-partwise or score-timewise, got {root_name}."
        )
    return _extract_musicxml_metadata(root)


def _normalize_result_metadata(
    result: MusicXmlResult,
    *,
    output_path: Path,
    title: str,
    composer: str | None,
    primary_instrument: str | None,
    contained_piece_titles: list[str] | None = None,
    multi_piece_page: bool = False,
) -> MusicXmlResult:
    should_normalize_spacing = result.provenance.startswith("audiveris_omr")
    normalized_path, spacing_metadata = _normalize_musicxml_metadata_with_spacing(
        result.file_path,
        output_path=output_path,
        title=title,
        composer=composer,
        primary_instrument=primary_instrument,
        contained_piece_titles=contained_piece_titles,
        multi_piece_page=multi_piece_page,
        normalize_omr_spacing=should_normalize_spacing,
    )
    metadata = _validate_musicxml(normalized_path)
    for key in (
        "omr_strategy",
        "omr_quality_score",
        "omr_attempts",
        "omr_candidate_engine",
        "omr_candidate_profile",
    ):
        if key not in result.metadata:
            continue
        if key == "omr_attempts":
            metadata[key] = _sanitize_omr_attempts(result.metadata[key])
        else:
            metadata[key] = _json_safe_metadata_value(result.metadata[key])
    metadata.update(_combine_spacing_normalization_metadata(result.metadata, spacing_metadata))
    warnings = list(result.warnings)
    original_instrument = result.metadata.get("primary_instrument")
    if (
        primary_instrument
        and isinstance(original_instrument, str)
        and original_instrument.strip()
        and original_instrument.strip().lower() != primary_instrument.strip().lower()
    ):
        if original_instrument.strip().lower() == "voice":
            warnings.append(
                "A generic OMR part label was suppressed; catalog/book instrument "
                "metadata was kept."
            )
        else:
            warnings.append(
                f"MusicXML part instrument '{original_instrument}' was overridden with "
                f"'{primary_instrument}' from catalog/book metadata."
            )
            metadata["omr_primary_instrument"] = original_instrument
    original_part_count = result.metadata.get("part_count")
    if primary_instrument and isinstance(original_part_count, int) and original_part_count > 1:
        warnings.append(
            f"OMR detected {original_part_count} parts for a {primary_instrument} "
            "piece. Verify the candidate did not split one staff into multiple parts."
        )
        metadata["omr_part_count"] = original_part_count
    if primary_instrument:
        metadata["primary_instrument"] = primary_instrument
        metadata["parts"] = [primary_instrument]
        metadata["part_count"] = 1
    return MusicXmlResult(
        file_path=normalized_path,
        engine_name=result.engine_name,
        engine_version=result.engine_version,
        provenance=result.provenance,
        confidence=result.confidence,
        warnings=warnings,
        metadata=metadata,
    )


def _normalize_musicxml_metadata(
    file_path: Path,
    *,
    output_path: Path,
    title: str,
    composer: str | None,
    primary_instrument: str | None,
    contained_piece_titles: list[str] | None = None,
    multi_piece_page: bool = False,
) -> Path:
    normalized_path, _ = _normalize_musicxml_metadata_with_spacing(
        file_path,
        output_path=output_path,
        title=title,
        composer=composer,
        primary_instrument=primary_instrument,
        contained_piece_titles=contained_piece_titles,
        multi_piece_page=multi_piece_page,
        normalize_omr_spacing=False,
    )
    return normalized_path


def _normalize_musicxml_metadata_with_spacing(
    file_path: Path,
    *,
    output_path: Path,
    title: str,
    composer: str | None,
    primary_instrument: str | None,
    contained_piece_titles: list[str] | None = None,
    multi_piece_page: bool = False,
    normalize_omr_spacing: bool = False,
) -> tuple[Path, dict[str, Any]]:
    root = _load_musicxml_root(file_path)
    piece_titles = _clean_piece_titles(contained_piece_titles)
    display_title = piece_titles[0] if multi_piece_page and len(piece_titles) > 1 else title
    _set_musicxml_title(root, catalog_title=title, display_title=display_title)
    _set_musicxml_composer(root, composer)
    _set_musicxml_primary_instrument(root, primary_instrument)
    _set_multi_piece_title_directions(root, piece_titles, multi_piece_page)
    spacing_metadata = (
        _normalize_omr_spacing(root, profile=OMR_SPACING_NORMALIZATION_PROFILE)
        if normalize_omr_spacing
        else {}
    )

    normalized_path = file_path if file_path.suffix.lower() != ".mxl" else output_path
    ElementTree.ElementTree(root).write(
        normalized_path,
        encoding="utf-8",
        xml_declaration=True,
    )
    return normalized_path, spacing_metadata


def _merge_multi_piece_musicxml_segments(
    segment_paths: list[Path],
    *,
    output_path: Path,
    catalog_title: str,
    composer: str | None,
    primary_instrument: str | None,
    piece_titles: list[str],
) -> tuple[list[str], dict[str, Any]]:
    if not segment_paths:
        raise ProcessingEngineError("No MusicXML segments were available to merge.")

    warnings: list[str] = []
    base_root = _load_musicxml_root(segment_paths[0])
    base_parts = _children(base_root, "part")
    if not base_parts:
        raise ProcessingEngineError("The first MusicXML segment contains no parts.")

    for segment_index, segment_path in enumerate(segment_paths[1:], start=1):
        segment_root = _load_musicxml_root(segment_path)
        segment_parts = _children(segment_root, "part")
        if len(segment_parts) != len(base_parts):
            warnings.append(
                "A shared-page crop produced a different part count during OMR; "
                "measures were merged by available part order and require review."
            )
        for part_index, base_part in enumerate(base_parts):
            if not segment_parts:
                continue
            segment_part = segment_parts[min(part_index, len(segment_parts) - 1)]
            copied_measures = [
                copy.deepcopy(measure) for measure in _children(segment_part, "measure")
            ]
            if not copied_measures:
                continue
            next_number = _next_measure_number(base_part)
            for copied_index, measure in enumerate(copied_measures):
                measure.attrib["number"] = str(
                    copied_index + 1 if segment_index > 0 else next_number + copied_index
                )
                if copied_index == 0:
                    _ensure_new_system_at_piece_boundary(measure)
                    if part_index == 0 and segment_index < len(piece_titles):
                        _remove_piece_title_direction(measure, piece_titles[segment_index])
                        measure.insert(
                            _measure_direction_insert_index(measure),
                            _piece_title_direction(piece_titles[segment_index]),
                        )
                base_part.append(measure)

    _set_musicxml_title(
        base_root,
        catalog_title=catalog_title,
        display_title=piece_titles[0] if piece_titles else catalog_title,
    )
    _set_musicxml_composer(base_root, composer)
    _set_musicxml_primary_instrument(base_root, primary_instrument)
    _apply_multi_piece_portrait_layout(base_root)
    spacing_metadata = _normalize_omr_spacing(
        base_root,
        profile=OMR_SPACING_NORMALIZATION_PROFILE,
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    ElementTree.ElementTree(base_root).write(
        output_path,
        encoding="utf-8",
        xml_declaration=True,
    )
    return warnings, spacing_metadata


def _normalize_omr_spacing(
    root: ElementTree.Element,
    *,
    profile: str,
) -> dict[str, Any]:
    changes = {
        "measure_width_attributes_removed": 0,
        "note_default_x_attributes_removed": 0,
        "system_layout_elements_removed": 0,
        "staff_layout_elements_removed": 0,
    }

    for measure in _iter_named(root, "measure"):
        if "width" in measure.attrib:
            measure.attrib.pop("width", None)
            changes["measure_width_attributes_removed"] += 1

    for element_name in ("note", "rest"):
        for element in _iter_named(root, element_name):
            if "default-x" in element.attrib:
                element.attrib.pop("default-x", None)
                changes["note_default_x_attributes_removed"] += 1

    for print_element in _iter_named(root, "print"):
        for child in list(print_element):
            child_name = _local_name(child.tag)
            if child_name == "system-layout":
                print_element.remove(child)
                changes["system_layout_elements_removed"] += 1
            elif child_name == "staff-layout":
                print_element.remove(child)
                changes["staff_layout_elements_removed"] += 1

    return {
        "spacing_normalization_applied": True,
        "spacing_normalization_profile": profile,
        "spacing_normalization_changes": changes,
    }


def _combine_spacing_normalization_metadata(
    *sources: dict[str, Any] | None,
) -> dict[str, Any]:
    changes = {
        "measure_width_attributes_removed": 0,
        "note_default_x_attributes_removed": 0,
        "system_layout_elements_removed": 0,
        "staff_layout_elements_removed": 0,
    }
    applied = False
    profile: str | None = None

    for source in sources:
        if not source or not source.get("spacing_normalization_applied"):
            continue
        applied = True
        source_profile = source.get("spacing_normalization_profile")
        if isinstance(source_profile, str) and source_profile.strip():
            profile = source_profile.strip()
        source_changes = source.get("spacing_normalization_changes")
        if not isinstance(source_changes, dict):
            continue
        for key, value in source_changes.items():
            if isinstance(value, bool) or not isinstance(value, (int, float)):
                continue
            changes[str(key)] = changes.get(str(key), 0) + int(value)

    if not applied:
        return {}
    return {
        "spacing_normalization_applied": True,
        "spacing_normalization_profile": profile or OMR_SPACING_NORMALIZATION_PROFILE,
        "spacing_normalization_changes": changes,
    }


def _next_measure_number(part: ElementTree.Element) -> int:
    numbers: list[int] = []
    for measure in _children(part, "measure"):
        raw_number = measure.attrib.get("number", "")
        if raw_number.isdigit():
            numbers.append(int(raw_number))
    return (max(numbers) if numbers else len(_children(part, "measure"))) + 1


def _remove_piece_title_direction(measure: ElementTree.Element, title: str) -> None:
    for child in list(measure):
        if _local_name(child.tag) != "direction":
            continue
        if any(
            _local_name(descendant.tag) == "words" and _text_or_none(descendant.text) == title
            for descendant in child.iter()
        ):
            measure.remove(child)


def _apply_multi_piece_portrait_layout(root: ElementTree.Element) -> None:
    defaults = _first_child(root, "defaults")
    if defaults is None:
        defaults = ElementTree.Element("defaults")
        insert_index = 0
        for index, child in enumerate(list(root)):
            if _local_name(child.tag) in {"work", "movement-title", "identification"}:
                insert_index = index + 1
        root.insert(insert_index, defaults)

    scaling = _first_child(defaults, "scaling")
    if scaling is None:
        scaling = ElementTree.SubElement(defaults, "scaling")
    _ensure_child_text(scaling, "millimeters", "7.4507")
    _ensure_child_text(scaling, "tenths", "40")

    page_layout = _first_child(defaults, "page-layout")
    if page_layout is None:
        page_layout = ElementTree.SubElement(defaults, "page-layout")
    _ensure_child_text(page_layout, "page-height", "1500")
    _ensure_child_text(page_layout, "page-width", "1159")
    page_margins = _first_child(page_layout, "page-margins")
    if page_margins is None:
        page_margins = ElementTree.SubElement(page_layout, "page-margins", {"type": "both"})
    for margin_name in ("left-margin", "right-margin", "top-margin", "bottom-margin"):
        _ensure_child_text(page_margins, margin_name, "55")

    for system_layout in _iter_named(root, "system-layout"):
        system_distance = _first_child(system_layout, "system-distance")
        if system_distance is not None:
            system_distance.text = "90"
        top_system_distance = _first_child(system_layout, "top-system-distance")
        if top_system_distance is not None:
            top_system_distance.text = "120"
    for staff_layout in _iter_named(root, "staff-layout"):
        staff_distance = _first_child(staff_layout, "staff-distance")
        if staff_distance is not None:
            staff_distance.text = "70"


def _ensure_child_text(
    element: ElementTree.Element,
    child_name: str,
    text: str,
) -> ElementTree.Element:
    child = _first_child(element, child_name)
    if child is None:
        child = ElementTree.SubElement(element, child_name)
    child.text = text
    return child


def _set_musicxml_title(
    root: ElementTree.Element,
    *,
    catalog_title: str,
    display_title: str,
) -> None:
    work = _first_child(root, "work")
    if work is None:
        work = ElementTree.Element("work")
        root.insert(0, work)
    work_title = _first_child(work, "work-title")
    if work_title is None:
        work_title = ElementTree.SubElement(work, "work-title")
    work_title.text = catalog_title

    movement_title = _first_child(root, "movement-title")
    if movement_title is None:
        insert_index = 1 if _first_child(root, "work") is not None else 0
        movement_title = ElementTree.Element("movement-title")
        root.insert(insert_index, movement_title)
    movement_title.text = display_title


def _set_musicxml_composer(root: ElementTree.Element, composer: str | None) -> None:
    if not composer:
        return
    identification = _first_child(root, "identification")
    if identification is None:
        identification = ElementTree.Element("identification")
        root.insert(1, identification)
    composer_creator = None
    for creator in _children(identification, "creator"):
        if creator.attrib.get("type", "").lower() == "composer":
            composer_creator = creator
            break
    if composer_creator is None:
        composer_creator = ElementTree.SubElement(identification, "creator")
        composer_creator.attrib["type"] = "composer"
    composer_creator.text = composer


def _set_musicxml_primary_instrument(
    root: ElementTree.Element,
    primary_instrument: str | None,
) -> None:
    part_list = _first_child(root, "part-list")
    if part_list is None:
        return
    score_parts = _children(part_list, "score-part")
    if not score_parts:
        return
    single_part = len(score_parts) == 1
    for index, score_part in enumerate(score_parts):
        _remove_voice_score_instrument_names(score_part)
        if primary_instrument or single_part or _score_part_mentions_voice(score_part):
            _suppress_score_part_visual_label(score_part)
        elif primary_instrument and index == 0:
            part_name = _first_child(score_part, "part-name")
            if part_name is None:
                part_name = ElementTree.SubElement(score_part, "part-name")
            part_name.text = primary_instrument

        if primary_instrument:
            score_instrument = _ensure_score_instrument(score_part)
            instrument_name = _first_child(score_instrument, "instrument-name")
            if instrument_name is None:
                instrument_name = ElementTree.SubElement(score_instrument, "instrument-name")
            instrument_name.text = primary_instrument
        else:
            _remove_voice_score_instrument_names(score_part)


def _score_part_mentions_voice(score_part: ElementTree.Element) -> bool:
    for name in ("part-name", "part-abbreviation"):
        value = _first_child_text(score_part, name)
        if value and value.strip().lower() == "voice":
            return True
    for score_instrument in _children(score_part, "score-instrument"):
        value = _first_child_text(score_instrument, "instrument-name")
        if value and value.strip().lower() == "voice":
            return True
    return False


def _remove_voice_score_instrument_names(score_part: ElementTree.Element) -> None:
    for score_instrument in _children(score_part, "score-instrument"):
        instrument_name = _first_child(score_instrument, "instrument-name")
        if (
            instrument_name is not None
            and _text_or_none(instrument_name.text)
            and _text_or_none(instrument_name.text).lower() == "voice"
        ):
            instrument_name.text = ""


def _suppress_score_part_visual_label(score_part: ElementTree.Element) -> None:
    part_name = _first_child(score_part, "part-name")
    if part_name is None:
        part_name = ElementTree.Element("part-name")
        score_part.insert(0, part_name)
    part_name.text = " "
    part_name.attrib["print-object"] = "no"

    part_abbreviation = _first_child(score_part, "part-abbreviation")
    if part_abbreviation is not None:
        part_abbreviation.text = " "
        part_abbreviation.attrib["print-object"] = "no"

    for child in list(score_part):
        if _local_name(child.tag) in {
            "part-name-display",
            "part-abbreviation-display",
        }:
            score_part.remove(child)


def _ensure_score_instrument(score_part: ElementTree.Element) -> ElementTree.Element:
    score_instrument = _first_child(score_part, "score-instrument")
    if score_instrument is not None:
        return score_instrument

    part_id = score_part.attrib.get("id") or "P1"
    score_instrument = ElementTree.Element(
        "score-instrument",
        {"id": f"{part_id}-I1"},
    )
    insert_index = len(score_part)
    for index, child in enumerate(score_part):
        if _local_name(child.tag) in {"midi-device", "midi-instrument"}:
            insert_index = index
            break
    score_part.insert(insert_index, score_instrument)
    return score_instrument


def _set_multi_piece_title_directions(
    root: ElementTree.Element,
    piece_titles: list[str],
    multi_piece_page: bool,
) -> None:
    if not multi_piece_page or len(piece_titles) < 2:
        return
    parts = _iter_named(root, "part")
    if not parts:
        return
    measures = _children(parts[0], "measure")
    if not measures:
        return

    for title_index, title in enumerate(piece_titles[1:], start=1):
        measure_index = round(title_index * len(measures) / len(piece_titles))
        measure_index = min(max(measure_index, 0), len(measures) - 1)
        measure = measures[measure_index]
        _ensure_new_system_at_piece_boundary(measure)
        if _measure_has_direction_words(measure, title):
            continue
        direction = _piece_title_direction(title)
        insert_index = _measure_direction_insert_index(measure)
        measure.insert(insert_index, direction)


def _ensure_new_system_at_piece_boundary(measure: ElementTree.Element) -> None:
    print_element = _first_child(measure, "print")
    if print_element is None:
        print_element = ElementTree.Element("print")
        measure.insert(0, print_element)
    print_element.attrib["new-system"] = "yes"
    print_element.attrib.setdefault("new-page", "no")


def _measure_direction_insert_index(measure: ElementTree.Element) -> int:
    for index, child in enumerate(measure):
        if _local_name(child.tag) in {"print", "attributes"}:
            return index + 1
    return 0


def _measure_has_direction_words(measure: ElementTree.Element, title: str) -> bool:
    normalized_title = _text_or_none(title)
    if not normalized_title:
        return True
    for words in _iter_named(measure, "words"):
        if _text_or_none(words.text) == normalized_title:
            return True
    return False


def _piece_title_direction(title: str) -> ElementTree.Element:
    direction = ElementTree.Element("direction", {"placement": "above"})
    direction_type = ElementTree.SubElement(direction, "direction-type")
    words = ElementTree.SubElement(
        direction_type,
        "words",
        {
            "default-x": "500",
            "font-weight": "bold",
            "font-size": "16",
            "halign": "center",
            "justify": "center",
            "valign": "top",
        },
    )
    words.text = title
    return direction


def _load_musicxml_root(path: Path) -> ElementTree.Element:
    if path.suffix.lower() != ".mxl":
        return ElementTree.parse(path).getroot()

    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        rootfile_name = _mxl_rootfile_name(archive, names)
        return ElementTree.fromstring(archive.read(rootfile_name))


def _mxl_rootfile_name(archive: zipfile.ZipFile, names: list[str]) -> str:
    if "META-INF/container.xml" in names:
        container_root = ElementTree.fromstring(archive.read("META-INF/container.xml"))
        for rootfile in _iter_named(container_root, "rootfile"):
            full_path = rootfile.attrib.get("full-path")
            if full_path:
                return full_path

    for name in names:
        lower_name = name.lower()
        if lower_name.endswith(".xml") and not lower_name.startswith("meta-inf/"):
            return name
    raise KeyError("MXL archive did not contain a MusicXML root file")


def _merged_segment_omr_attempts(
    segment_results: list[MusicXmlResult],
    *,
    output_path: Path,
    catalog_title: str,
    composer: str | None,
    primary_instrument: str | None,
    piece_titles: list[str],
) -> tuple[list[dict[str, Any]], list[str]]:
    if len(segment_results) < 2:
        return [], []

    homr_paths = _segment_attempt_paths(segment_results, engine_name="homr")
    if not homr_paths:
        return [], []
    if len(homr_paths) != len(segment_results):
        return [], [
            "HOMR comparison candidate was not created because HOMR did not produce "
            "MusicXML for every shared-page crop."
        ]

    merged_path = output_path.with_name(f"{output_path.stem}_homr_segment_merge.musicxml")
    merge_warnings, _spacing_metadata = _merge_multi_piece_musicxml_segments(
        homr_paths,
        output_path=merged_path,
        catalog_title=catalog_title,
        composer=composer,
        primary_instrument=primary_instrument,
        piece_titles=piece_titles,
    )
    metadata = _validate_musicxml(merged_path)
    quality_score = _musicxml_quality_score(metadata, merged_path)
    return [
        {
            "engine": "homr",
            "profile": "experimental_segment_merge",
            "candidate_path": str(merged_path),
            "quality_score": quality_score,
            "provenance": "homr_omr_segment_merge",
            "warnings": merge_warnings
            + [
                "HOMR segment outputs were merged for OMR candidate comparison."
            ],
        }
    ], []


def _segment_attempt_paths(
    segment_results: list[MusicXmlResult],
    *,
    engine_name: str,
) -> list[Path]:
    engine_key = engine_name.strip().lower()
    paths: list[Path] = []
    for result in segment_results:
        attempts = result.metadata.get("omr_attempts")
        if not isinstance(attempts, list):
            continue
        attempt_path = _first_successful_attempt_path(attempts, engine_key=engine_key)
        if attempt_path is not None:
            paths.append(attempt_path)
    return paths


def _first_successful_attempt_path(
    attempts: list[Any],
    *,
    engine_key: str,
) -> Path | None:
    for attempt in attempts:
        if not isinstance(attempt, dict):
            continue
        if attempt.get("skipped") or attempt.get("error"):
            continue
        engine = _text_or_none(attempt.get("engine"))
        if engine is None or engine.lower() != engine_key:
            continue
        candidate_path = _text_or_none(attempt.get("candidate_path"))
        if candidate_path is None:
            continue
        path = Path(candidate_path)
        if path.exists() and path.is_file():
            return path
    return None


def _extract_musicxml_metadata(root: ElementTree.Element) -> dict[str, Any]:
    metadata: dict[str, Any] = {
        "musicxml_version": root.attrib.get("version"),
    }

    title = _first_text_in_named_parent(root, "work", "work-title")
    movement_title = _first_text_named(root, "movement-title")
    if not title:
        title = movement_title
    if title:
        metadata["title"] = title
    if movement_title:
        metadata["movement_title"] = movement_title

    creators = _extract_creators(root)
    if creators:
        metadata["creators"] = creators
        composer = _first_creator_of_type(creators, "composer") or creators[0]["name"]
        metadata["composer"] = composer

    parts = _extract_parts(root)
    if parts:
        metadata["parts"] = parts
        metadata["primary_instrument"] = parts[0]
        metadata["part_count"] = len(parts)

    measure_count = _measure_count(root)
    if measure_count is not None:
        metadata["measure_count"] = measure_count

    key_signatures = _extract_key_signatures(root)
    if key_signatures:
        metadata["key_signature"] = key_signatures[0]
        metadata["key_signatures"] = key_signatures

    time_signatures = _extract_time_signatures(root)
    if time_signatures:
        metadata["time_signature"] = time_signatures[0]
        metadata["time_signatures"] = time_signatures

    tempos = _extract_tempos(root)
    if tempos:
        metadata["tempo"] = tempos[0]
        metadata["tempos"] = tempos

    software = _compact_unique(
        _text_or_none(element.text) for element in _iter_named(root, "software")
    )
    if software:
        metadata["software"] = software

    return {key: value for key, value in metadata.items() if value not in (None, "", [])}


def _extract_creators(root: ElementTree.Element) -> list[dict[str, str]]:
    creators: list[dict[str, str]] = []
    seen: set[tuple[str, str]] = set()
    for creator in _iter_named(root, "creator"):
        name = _text_or_none(creator.text)
        if not name:
            continue
        creator_type = creator.attrib.get("type", "creator")
        key = (creator_type, name)
        if key in seen:
            continue
        seen.add(key)
        creators.append({"type": creator_type, "name": name})
    return creators


def _first_creator_of_type(creators: list[dict[str, str]], creator_type: str) -> str | None:
    for creator in creators:
        if creator["type"].lower() == creator_type:
            return creator["name"]
    return None


def _extract_parts(root: ElementTree.Element) -> list[str]:
    parts = []
    for score_part in _iter_named(root, "score-part"):
        if _hidden_musicxml_label(score_part, "part-name"):
            continue
        part_name = _first_child_text(score_part, "part-name")
        if part_name:
            parts.append(part_name)
    return _compact_unique(parts)


def _hidden_musicxml_label(element: ElementTree.Element, name: str) -> bool:
    child = _first_child(element, name)
    if child is None:
        return False
    return child.attrib.get("print-object", "").lower() == "no"


def _measure_count(root: ElementTree.Element) -> int | None:
    counts = [
        len(_children(part, "measure"))
        for part in _iter_named(root, "part")
        if _children(part, "measure")
    ]
    if not counts:
        return None
    return max(counts)


def _extract_key_signatures(root: ElementTree.Element) -> list[str]:
    signatures: list[str] = []
    for key_element in _iter_named(root, "key"):
        fifths_text = _first_child_text(key_element, "fifths")
        if fifths_text is None:
            continue
        try:
            fifths = int(fifths_text)
        except ValueError:
            continue
        mode = (_first_child_text(key_element, "mode") or "major").lower()
        signatures.append(_key_signature_name(fifths, mode))
    return _compact_unique(signatures)


def _extract_time_signatures(root: ElementTree.Element) -> list[str]:
    signatures: list[str] = []
    for time_element in _iter_named(root, "time"):
        beats = _first_child_text(time_element, "beats")
        beat_type = _first_child_text(time_element, "beat-type")
        if beats and beat_type:
            signatures.append(f"{beats}/{beat_type}")
    return _compact_unique(signatures)


def _extract_tempos(root: ElementTree.Element) -> list[str]:
    tempos: list[str] = []
    for sound_element in _iter_named(root, "sound"):
        tempo = _normalize_tempo(sound_element.attrib.get("tempo"))
        if tempo:
            tempos.append(tempo)
    for per_minute in _iter_named(root, "per-minute"):
        tempo = _normalize_tempo(per_minute.text)
        if tempo:
            tempos.append(tempo)
    return _compact_unique(tempos)


def _key_signature_name(fifths: int, mode: str) -> str:
    major_keys = {
        -7: "Cb major",
        -6: "Gb major",
        -5: "Db major",
        -4: "Ab major",
        -3: "Eb major",
        -2: "Bb major",
        -1: "F major",
        0: "C major",
        1: "G major",
        2: "D major",
        3: "A major",
        4: "E major",
        5: "B major",
        6: "F# major",
        7: "C# major",
    }
    minor_keys = {
        -7: "Ab minor",
        -6: "Eb minor",
        -5: "Bb minor",
        -4: "F minor",
        -3: "C minor",
        -2: "G minor",
        -1: "D minor",
        0: "A minor",
        1: "E minor",
        2: "B minor",
        3: "F# minor",
        4: "C# minor",
        5: "G# minor",
        6: "D# minor",
        7: "A# minor",
    }
    if mode == "minor":
        return minor_keys.get(fifths, f"{fifths} fifths minor")
    return major_keys.get(fifths, f"{fifths} fifths major")


def _normalize_tempo(value: str | None) -> str | None:
    if value is None:
        return None
    raw_value = value.strip()
    if not raw_value:
        return None
    try:
        numeric_value = float(raw_value)
    except ValueError:
        return raw_value
    if numeric_value.is_integer():
        return str(int(numeric_value))
    return str(numeric_value)


def _first_text_in_named_parent(
    root: ElementTree.Element,
    parent_name: str,
    child_name: str,
) -> str | None:
    for parent in _iter_named(root, parent_name):
        value = _first_child_text(parent, child_name)
        if value:
            return value
    return None


def _first_text_named(root: ElementTree.Element, name: str) -> str | None:
    for element in _iter_named(root, name):
        value = _text_or_none(element.text)
        if value:
            return value
    return None


def _first_child_text(element: ElementTree.Element, name: str) -> str | None:
    child = _first_child(element, name)
    if child is None:
        return None
    return _text_or_none(child.text)


def _first_child(element: ElementTree.Element, name: str) -> ElementTree.Element | None:
    for child in element:
        if _local_name(child.tag) == name:
            return child
    return None


def _children(element: ElementTree.Element, name: str) -> list[ElementTree.Element]:
    return [child for child in element if _local_name(child.tag) == name]


def _iter_named(root: ElementTree.Element, name: str) -> list[ElementTree.Element]:
    return [element for element in root.iter() if _local_name(element.tag) == name]


def _local_name(tag: str) -> str:
    return tag.rsplit("}", maxsplit=1)[-1]


def _text_or_none(value: str | None) -> str | None:
    if value is None:
        return None
    stripped = " ".join(value.split())
    return stripped or None


def _compact_unique(values) -> list[str]:
    compacted: list[str] = []
    seen: set[str] = set()
    for value in values:
        if not value or value in seen:
            continue
        seen.add(value)
        compacted.append(value)
    return compacted


def _clean_piece_titles(values: list[str] | None) -> list[str]:
    if not values:
        return []
    return _compact_unique(_text_or_none(value) for value in values if isinstance(value, str))


def _process_diagnostics(
    *,
    command: list[str],
    output_path: Path,
    timeout_seconds: int,
    exit_code: int | None = None,
    timed_out: bool = False,
    stdout: str | bytes | None = None,
    stderr: str | bytes | None = None,
) -> dict[str, Any]:
    file_size_bytes = None
    if output_path.exists():
        try:
            file_size_bytes = output_path.stat().st_size
        except OSError:
            file_size_bytes = None
    return {
        "command": command,
        "exit_code": exit_code,
        "timed_out": timed_out,
        "timeout_seconds": timeout_seconds,
        "stdout_excerpt": _text_excerpt(stdout),
        "stderr_excerpt": _text_excerpt(stderr),
        "output_path": str(output_path),
        "output_exists": output_path.exists(),
        "output_file_size_bytes": file_size_bytes,
    }


def _text_excerpt(value: str | bytes | None, *, limit: int = 2000) -> str | None:
    if value is None:
        return None
    if isinstance(value, bytes):
        value = value.decode("utf-8", errors="replace")
    text = value.strip()
    if not text:
        return None
    return text[:limit]


def _summarize_process_failure(
    name: str,
    output: str | None,
    *,
    exit_code: int | None = None,
) -> str:
    details = (output or "").strip()
    if not details:
        if exit_code is not None:
            return f"{name} failed with exit code {exit_code} without returning diagnostic output."
        return f"{name} failed without returning diagnostic output."
    if exit_code is not None:
        return f"{name} failed with exit code {exit_code}: {details[-1000:]}"
    return f"{name} failed: {details[-1000:]}"


def _build_stub_musicxml(
    *,
    title: str,
    composer: str | None,
    primary_instrument: str,
    measure_count: int = 1,
) -> str:
    composer_xml = f'<creator type="composer">{_escape_xml(composer)}</creator>' if composer else ""
    clef_sign = "F" if primary_instrument.strip().lower() == "cello" else "G"
    clef_line = "4" if clef_sign == "F" else "2"
    first_octave = "3" if primary_instrument.strip().lower() == "cello" else "4"
    measures_xml = "\n".join(
        _build_stub_measure_xml(
            number=number,
            clef_sign=clef_sign,
            clef_line=clef_line,
            first_octave=first_octave,
            include_attributes=number == 1,
            include_review_marker=number == 1,
        )
        for number in range(1, max(1, measure_count) + 1)
    )
    return f"""<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE score-partwise PUBLIC
  "-//Recordare//DTD MusicXML 4.0 Partwise//EN"
  "http://www.musicxml.org/dtds/partwise.dtd">
<score-partwise version="4.0">
  <work>
    <work-title>{_escape_xml(title)}</work-title>
  </work>
  <identification>
    {composer_xml}
    <encoding>
      <software>AZMusic deterministic stub</software>
      <encoding-date>{datetime.utcnow().date().isoformat()}</encoding-date>
    </encoding>
  </identification>
  <part-list>
    <score-part id="P1">
      <part-name>{_escape_xml(primary_instrument)}</part-name>
    </score-part>
  </part-list>
  <part id="P1">
{measures_xml}
  </part>
</score-partwise>
"""


def _build_stub_measure_xml(
    *,
    number: int,
    clef_sign: str,
    clef_line: str,
    first_octave: str,
    include_attributes: bool,
    include_review_marker: bool,
) -> str:
    attributes_xml = (
        f"""      <attributes>
        <divisions>1</divisions>
        <key><fifths>0</fifths></key>
        <time><beats>4</beats><beat-type>4</beat-type></time>
        <clef><sign>{clef_sign}</sign><line>{clef_line}</line></clef>
      </attributes>
"""
        if include_attributes
        else ""
    )
    review_marker_xml = (
        """      <direction placement="above">
        <direction-type>
          <words>Review candidate generated by AZMusic</words>
        </direction-type>
        <sound tempo="96"/>
      </direction>
"""
        if include_review_marker
        else ""
    )
    return f"""    <measure number="{number}">
{attributes_xml}{review_marker_xml}      <note>
        <pitch><step>C</step><octave>{first_octave}</octave></pitch>
        <duration>1</duration>
        <type>quarter</type>
      </note>
      <note>
        <pitch><step>D</step><octave>{first_octave}</octave></pitch>
        <duration>1</duration>
        <type>quarter</type>
      </note>
      <note>
        <pitch><step>E</step><octave>{first_octave}</octave></pitch>
        <duration>1</duration>
        <type>quarter</type>
      </note>
      <note>
        <pitch><step>F</step><octave>{first_octave}</octave></pitch>
        <duration>1</duration>
        <type>quarter</type>
      </note>
    </measure>"""


def _escape_xml(value: str | None) -> str:
    if not value:
        return ""
    return (
        value.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
        .replace("'", "&apos;")
    )

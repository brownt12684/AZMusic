"""File-backed catalog for human-approved notation training samples."""

from __future__ import annotations

import hashlib
import json
import shutil
import uuid
from datetime import datetime
from pathlib import Path
from typing import Any

from server.config import settings
from server.models.orm import Piece, ReviewItem, ScoreVersion
from server.services.piece_state import PieceStateService


class TrainingCatalogError(RuntimeError):
    """Raised when a training sample cannot be preserved safely."""


def ensure_omr_baseline_copy(
    *,
    piece_id: str,
    canonical_score_version: ScoreVersion,
    piece_state_service: PieceStateService | None = None,
) -> Path:
    """Preserve the original OMR MusicXML before human edits can overwrite it."""
    piece_state_service = piece_state_service or PieceStateService()
    metadata = piece_state_service.score_version_metadata(
        piece_id,
        canonical_score_version.id,
    )
    existing_path = _metadata_path(metadata.get("omr_baseline_file_path"))
    if existing_path and existing_path.exists():
        return existing_path

    canonical_path = Path(canonical_score_version.file_path)
    if not canonical_path.exists():
        raise TrainingCatalogError(
            f"Cannot preserve OMR baseline; missing file: {canonical_path}"
        )

    suffix = canonical_path.suffix or ".musicxml"
    baseline_path = canonical_path.with_name(
        f"omr_baseline_{canonical_score_version.id}{suffix}"
    )
    if not baseline_path.exists():
        shutil.copy2(canonical_path, baseline_path)

    piece_state_service.set_score_version_metadata(
        piece_id,
        canonical_score_version.id,
        omr_baseline_file_path=str(baseline_path),
        training_baseline_file_path=str(baseline_path),
        training_role="omr_baseline_musicxml",
    )
    return baseline_path


def catalog_notation_training_sample(
    *,
    piece: Piece,
    review_item: ReviewItem,
    candidate_data: dict[str, Any],
    raw_score_version: ScoreVersion,
    canonical_score_version: ScoreVersion,
    rendered_score_version: ScoreVersion,
    piece_state_service: PieceStateService | None = None,
) -> dict[str, Any]:
    """Copy the full original/baseline/final pair into immutable storage."""
    piece_state_service = piece_state_service or PieceStateService()
    baseline_path = ensure_omr_baseline_copy(
        piece_id=piece.id,
        canonical_score_version=canonical_score_version,
        piece_state_service=piece_state_service,
    )
    raw_path = _required_file(raw_score_version.file_path, "original source")
    final_musicxml_path = _required_file(
        canonical_score_version.file_path,
        "final MusicXML",
    )
    final_render_path = _required_file(
        rendered_score_version.file_path,
        "final rendered PDF",
    )

    sample_id = str(uuid.uuid4())
    sample_dir = settings.storage_path / "training_samples" / sample_id
    sample_dir.mkdir(parents=True, exist_ok=False)

    copied_files = {
        "original_source": _copy_artifact(raw_path, sample_dir, "original_source"),
        "omr_baseline_musicxml": _copy_artifact(
            baseline_path,
            sample_dir,
            "omr_baseline",
        ),
        "final_musicxml": _copy_artifact(
            final_musicxml_path,
            sample_dir,
            "final",
        ),
        "final_render_pdf": _copy_artifact(
            final_render_path,
            sample_dir,
            "final_render",
        ),
    }
    manifest = {
        "sample_id": sample_id,
        "created_at": datetime.utcnow().isoformat(),
        "piece_id": piece.id,
        "review_item_id": review_item.id,
        "title": piece.title,
        "composer": piece.composer,
        "file_name": piece.file_name,
        "source_book_id": candidate_data.get("source_book_id"),
        "source_page_start": candidate_data.get("source_page_start"),
        "source_page_end": candidate_data.get("source_page_end"),
        "contained_piece_titles": candidate_data.get("contained_piece_titles"),
        "multi_piece_page": candidate_data.get("multi_piece_page"),
        "engine_name": candidate_data.get("engine_name"),
        "engine_version": candidate_data.get("engine_version"),
        "renderer_name": candidate_data.get("renderer_name"),
        "renderer_version": candidate_data.get("renderer_version"),
        "human_edit_status": (
            "human_edited"
            if candidate_data.get("human_edited_musicxml")
            else "accepted_as_is"
        ),
        "human_edited_at": candidate_data.get("human_edited_at"),
        "raw_score_version_id": raw_score_version.id,
        "canonical_score_version_id": canonical_score_version.id,
        "rendered_score_version_id": rendered_score_version.id,
        "selected_omr_candidate_id": candidate_data.get("selected_omr_candidate_id"),
        "processed_metadata": candidate_data.get("processed_metadata") or {},
        "catalog_metadata": candidate_data.get("catalog_metadata") or {},
        "files": copied_files,
    }
    manifest_path = sample_dir / "manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, indent=2, sort_keys=True),
        encoding="utf-8",
    )

    piece_state_service.set_score_version_metadata(
        piece.id,
        canonical_score_version.id,
        training_sample_id=sample_id,
        training_role="final_human_approved_musicxml",
        human_approved_for_training=True,
    )
    piece_state_service.set_score_version_metadata(
        piece.id,
        rendered_score_version.id,
        training_sample_id=sample_id,
        training_role="final_human_approved_render_pdf",
        human_approved_for_training=True,
    )
    piece_state_service.set_score_version_metadata(
        piece.id,
        raw_score_version.id,
        training_sample_id=sample_id,
        training_role="original_source",
        human_approved_for_training=True,
    )
    return manifest


def list_training_samples() -> list[dict[str, Any]]:
    """Return stored training sample manifests newest first."""
    root = settings.storage_path / "training_samples"
    if not root.exists():
        return []
    manifests = []
    for manifest_path in root.glob("*/manifest.json"):
        try:
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        manifest["manifest_path"] = str(manifest_path)
        manifests.append(manifest)
    manifests.sort(key=lambda item: item.get("created_at") or "", reverse=True)
    return manifests


def _metadata_path(value: object) -> Path | None:
    if not isinstance(value, str) or not value.strip():
        return None
    return Path(value).expanduser()


def _required_file(file_path: str, label: str) -> Path:
    path = Path(file_path)
    if not path.exists() or not path.is_file():
        raise TrainingCatalogError(f"Cannot catalog {label}; missing file: {path}")
    return path


def _copy_artifact(source: Path, sample_dir: Path, stem: str) -> dict[str, Any]:
    target = sample_dir / f"{stem}{source.suffix}"
    shutil.copy2(source, target)
    content = target.read_bytes()
    return {
        "path": str(target),
        "original_path": str(source),
        "sha256": hashlib.sha256(content).hexdigest(),
        "size_bytes": len(content),
    }

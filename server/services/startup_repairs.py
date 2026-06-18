"""Data repairs that make preserved installs compatible with current workflow."""

from __future__ import annotations

import uuid
from datetime import datetime
from pathlib import Path

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from server.models.orm import Piece, PieceStatus, ScoreVersion, ScoreVersionType
from server.services.piece_state import PieceStateService

_STUDENT_SCORE_EXTENSIONS = {
    ".pdf",
    ".png",
    ".jpg",
    ".jpeg",
    ".webp",
    ".tif",
    ".tiff",
}


async def repair_missing_book_student_pdfs(db: AsyncSession) -> int:
    """Repair preserved book imports that predate the PDF-first book artifact."""
    piece_state = PieceStateService()
    repaired_count = 0
    result = await db.execute(select(Piece))
    for piece in result.scalars().all():
        metadata = piece_state.metadata_for_piece(piece)
        if metadata["piece_kind"] != "book" or piece.status == PieceStatus.archived:
            continue
        cleaned_version = await _load_cleaned_student_score_version(db, piece.id)
        if cleaned_version is None:
            raw_version = await _load_raw_student_score_version(db, piece.id)
            if raw_version is None:
                continue
            cleaned_version = await _create_cleaned_book_score_version(
                db,
                piece=piece,
                raw_version=raw_version,
                mark_approved=piece.status == PieceStatus.approved
                or bool(metadata["visible_to_profile_ids"]),
            )
            repaired_count += 1

        if metadata["visible_to_profile_ids"]:
            await _cascade_book_assignment_to_children(
                db,
                piece_state=piece_state,
                source_book_id=piece.id,
                profile_ids=metadata["visible_to_profile_ids"],
            )

    return repaired_count


async def _load_cleaned_student_score_version(
    db: AsyncSession,
    piece_id: str,
) -> ScoreVersion | None:
    result = await db.execute(
        select(ScoreVersion)
        .where(ScoreVersion.piece_id == piece_id)
        .order_by(ScoreVersion.is_default.desc(), ScoreVersion.created_at.desc())
    )
    for version in result.scalars().all():
        metadata = PieceStateService().score_version_metadata(piece_id, version.id)
        if metadata.get("artifact_role") != "cleaned_pdf":
            continue
        if Path(version.file_path).suffix.lower() not in _STUDENT_SCORE_EXTENSIONS:
            continue
        return version
    return None


async def _load_raw_student_score_version(
    db: AsyncSession,
    piece_id: str,
) -> ScoreVersion | None:
    result = await db.execute(
        select(ScoreVersion)
        .where(
            ScoreVersion.piece_id == piece_id,
            ScoreVersion.version_type == ScoreVersionType.raw,
        )
        .order_by(ScoreVersion.created_at.asc())
    )
    for version in result.scalars().all():
        raw_path = Path(version.file_path)
        if raw_path.suffix.lower() in _STUDENT_SCORE_EXTENSIONS and raw_path.exists():
            return version
    return None


async def _create_cleaned_book_score_version(
    db: AsyncSession,
    *,
    piece: Piece,
    raw_version: ScoreVersion,
    mark_approved: bool,
) -> ScoreVersion:
    raw_path = Path(raw_version.file_path)
    cleaned_path = raw_path.parent / "student_cleaned.pdf"
    cleaned_path.parent.mkdir(parents=True, exist_ok=True)
    if not cleaned_path.exists():
        cleaned_path.write_bytes(raw_path.read_bytes())

    await db.execute(
        update(ScoreVersion).where(ScoreVersion.piece_id == piece.id).values(is_default=False)
    )
    cleaned_version = ScoreVersion(
        id=str(uuid.uuid4()),
        piece_id=piece.id,
        version_type=ScoreVersionType.approved
        if mark_approved
        else ScoreVersionType.reconstructed_candidate,
        file_path=str(cleaned_path),
        is_default=True,
        created_at=datetime.utcnow(),
    )
    db.add(cleaned_version)

    piece_state = PieceStateService()
    piece_state.set_score_version_metadata(
        piece.id,
        raw_version.id,
        artifact_role="original_import",
        display_rank=100,
        student_default=False,
        approved_by_parent=True,
    )
    piece_state.set_score_version_metadata(
        piece.id,
        cleaned_version.id,
        artifact_role="cleaned_pdf",
        replaces_score_version_id=raw_version.id,
        display_rank=10,
        student_default=True,
        approved_by_parent=mark_approved,
    )
    return cleaned_version


async def _cascade_book_assignment_to_children(
    db: AsyncSession,
    *,
    piece_state: PieceStateService,
    source_book_id: str,
    profile_ids: list[str],
) -> None:
    if not profile_ids:
        return

    child_result = await db.execute(select(Piece))
    for child_piece in child_result.scalars().all():
        if child_piece.id == source_book_id or child_piece.status != PieceStatus.approved:
            continue
        child_metadata = piece_state.metadata_for_piece(child_piece)
        if child_metadata["source_book_id"] != source_book_id:
            continue
        if not await _load_cleaned_student_score_version(db, child_piece.id):
            continue
        piece_state.assign_profiles(child_piece.id, profile_ids)
        child_piece.updated_at = datetime.utcnow()

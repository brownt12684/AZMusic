"""Logical piece identity and duplicate-attempt handling."""

from __future__ import annotations

import hashlib
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from server.models.orm import (
    BackgroundJob,
    JobStatus,
    Piece,
    PieceStatus,
    ReviewItem,
    ScoreVersion,
    ScoreVersionType,
)
from server.services.debug_cleanup import _backup_runtime_state
from server.services.piece_state import PieceStateService

HIDDEN_ATTEMPT_STATUSES = {"duplicate_archived", "superseded", "failed_attempt"}

_piece_state_service = PieceStateService()


@dataclass(slots=True)
class PieceIdentity:
    key: str
    source_content_sha256: str | None
    source_book_fingerprint: str | None


@dataclass(slots=True)
class DuplicateGroup:
    logical_piece_key: str
    canonical_piece_id: str | None
    pieces: list[Piece]


def sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def source_book_fingerprint(source_content_sha256: str | None) -> str | None:
    if not source_content_sha256:
        return None
    return f"book_sha256:{source_content_sha256}"


def logical_piece_key(
    *,
    source_book_fingerprint: str | None,
    book_or_collection: str | None,
    source_page_start: int | None,
    source_page_end: int | None,
    title: str,
    composer: str | None,
    primary_instrument: str | None,
    source_content_sha256: str | None = None,
) -> str:
    if source_book_fingerprint:
        book_part = source_book_fingerprint
    elif book_or_collection:
        book_part = f"book_meta:{_normalize(book_or_collection)}"
    elif source_content_sha256:
        book_part = f"standalone_sha256:{source_content_sha256}"
    else:
        book_part = "standalone"

    page_part = (
        f"{source_page_start or ''}-{source_page_end or source_page_start or ''}"
        if source_page_start or source_page_end
        else ""
    )
    return "|".join(
        (
            "piece",
            book_part,
            f"pages:{page_part}",
            f"title:{_normalize(title)}",
            f"composer:{_normalize(composer or '')}",
            f"instrument:{_normalize(primary_instrument or '')}",
        )
    )


def book_logical_key(
    *,
    source_content_sha256: str | None,
    title: str,
    composer: str | None,
    file_name: str,
) -> str:
    fingerprint = source_book_fingerprint(source_content_sha256)
    if fingerprint:
        return f"book|{fingerprint}"
    return "|".join(
        (
            "book_legacy",
            f"title:{_normalize(title)}",
            f"composer:{_normalize(composer or '')}",
            f"file:{_normalize(Path(file_name).name)}",
        )
    )


async def find_active_book_by_source_hash(
    db: AsyncSession,
    source_content_sha256: str,
) -> Piece | None:
    for piece in await _all_pieces(db):
        metadata = _piece_state_service.metadata_for_piece(piece)
        if is_duplicate_metadata(metadata):
            continue
        if metadata.get("piece_kind") != "book":
            continue
        if metadata.get("source_content_sha256") == source_content_sha256:
            return piece
    return None


async def find_active_piece_by_source_hash(
    db: AsyncSession,
    source_content_sha256: str,
) -> Piece | None:
    for piece in await _all_pieces(db):
        metadata = _piece_state_service.metadata_for_piece(piece)
        if is_duplicate_metadata(metadata):
            continue
        if metadata.get("piece_kind") == "book":
            continue
        if metadata.get("source_content_sha256") == source_content_sha256:
            return piece
    return None


async def find_active_piece_by_logical_key(
    db: AsyncSession,
    key: str,
) -> Piece | None:
    for piece in await _all_pieces(db):
        metadata = _piece_state_service.metadata_for_piece(piece)
        if is_duplicate_metadata(metadata):
            continue
        if metadata.get("logical_piece_key") == key:
            return piece
    return None


def is_duplicate_metadata(metadata: dict[str, Any]) -> bool:
    return bool(metadata.get("is_duplicate_attempt")) or metadata.get(
        "attempt_status"
    ) in HIDDEN_ATTEMPT_STATUSES


async def derive_piece_identity(db: AsyncSession, piece: Piece) -> PieceIdentity:
    metadata = _piece_state_service.metadata_for_piece(piece)
    source_hash = _clean_string(metadata.get("source_content_sha256"))
    if not source_hash:
        source_hash = await _raw_score_hash(db, piece.id)

    existing_key = _clean_string(metadata.get("logical_piece_key"))
    existing_book_fingerprint = _clean_string(metadata.get("source_book_fingerprint"))
    if existing_key:
        return PieceIdentity(
            key=existing_key,
            source_content_sha256=source_hash,
            source_book_fingerprint=existing_book_fingerprint,
        )

    piece_kind = metadata.get("piece_kind") or "piece"
    if piece_kind == "book":
        fingerprint = source_book_fingerprint(source_hash)
        return PieceIdentity(
            key=book_logical_key(
                source_content_sha256=source_hash,
                title=piece.title,
                composer=piece.composer,
                file_name=piece.file_name,
            ),
            source_content_sha256=source_hash,
            source_book_fingerprint=fingerprint,
        )

    catalog_metadata = metadata.get("catalog_metadata") or {}
    book_or_collection = _first_string(
        metadata.get("book_or_collection"),
        catalog_metadata.get("book_or_collection") if isinstance(catalog_metadata, dict) else None,
        catalog_metadata.get("source_file_name") if isinstance(catalog_metadata, dict) else None,
    )
    title = _first_string(
        catalog_metadata.get("title") if isinstance(catalog_metadata, dict) else None,
        piece.title,
    )
    composer = _first_string(
        catalog_metadata.get("composer") if isinstance(catalog_metadata, dict) else None,
        piece.composer,
    )
    primary_instrument = _first_string(
        metadata.get("primary_instrument"),
        catalog_metadata.get("primary_instrument") if isinstance(catalog_metadata, dict) else None,
    )
    source_page_start = _first_int(
        metadata.get("source_page_start"),
        catalog_metadata.get("source_page_start") if isinstance(catalog_metadata, dict) else None,
    )
    source_page_end = _first_int(
        metadata.get("source_page_end"),
        catalog_metadata.get("source_page_end") if isinstance(catalog_metadata, dict) else None,
        source_page_start,
    )

    key = logical_piece_key(
        source_book_fingerprint=existing_book_fingerprint,
        book_or_collection=book_or_collection,
        source_page_start=source_page_start,
        source_page_end=source_page_end,
        title=title or piece.title,
        composer=composer,
        primary_instrument=primary_instrument,
        source_content_sha256=source_hash,
    )
    return PieceIdentity(
        key=key,
        source_content_sha256=source_hash,
        source_book_fingerprint=existing_book_fingerprint,
    )


async def list_duplicate_groups(db: AsyncSession) -> list[dict[str, Any]]:
    groups = await _collect_duplicate_groups(db)
    output: list[dict[str, Any]] = []
    for group in groups:
        canonical = await _choose_canonical_piece(db, group.pieces)
        output.append(
            {
                "logical_piece_key": group.logical_piece_key,
                "canonical_piece_id": canonical.id if canonical else None,
                "count": len(group.pieces),
                "pieces": [
                    {
                        "id": piece.id,
                        "title": piece.title,
                        "composer": piece.composer,
                        "status": piece.status,
                        "file_name": piece.file_name,
                        "created_at": piece.created_at,
                    }
                    for piece in group.pieces
                ],
            }
        )
    return output


async def cleanup_duplicate_attempts(db: AsyncSession) -> dict[str, Any]:
    backup_dir = _backup_runtime_state(db)
    groups = await _collect_duplicate_groups(db)
    archived_piece_ids: list[str] = []
    superseded_review_item_ids: list[str] = []
    canceled_job_ids: list[str] = []

    for group in groups:
        canonical = await _choose_canonical_piece(db, group.pieces)
        if not canonical:
            continue
        canonical_identity = await derive_piece_identity(db, canonical)
        _piece_state_service.update_identity(
            canonical.id,
            source_content_sha256=canonical_identity.source_content_sha256,
            source_book_fingerprint=canonical_identity.source_book_fingerprint,
            logical_piece_key=group.logical_piece_key,
            canonical_piece_id=canonical.id,
            attempt_status="canonical",
            duplicate_attempt_count=len(group.pieces) - 1,
        )
        for piece in group.pieces:
            if piece.id == canonical.id:
                continue
            archived_piece_ids.append(piece.id)
            piece.status = PieceStatus.archived
            piece.updated_at = datetime.utcnow()
            identity = await derive_piece_identity(db, piece)
            _piece_state_service.update_identity(
                piece.id,
                source_content_sha256=identity.source_content_sha256,
                source_book_fingerprint=identity.source_book_fingerprint,
                logical_piece_key=group.logical_piece_key,
                canonical_piece_id=canonical.id,
                attempt_status="duplicate_archived",
                duplicate_reason="Archived by duplicate cleanup.",
            )
            superseded_review_item_ids.extend(
                await _supersede_pending_reviews_for_piece(
                    db,
                    duplicate_piece_id=piece.id,
                    canonical_piece_id=canonical.id,
                    reason="Superseded by duplicate cleanup.",
                )
            )
            canceled_job_ids.extend(
                await _cancel_active_jobs_for_piece(
                    db,
                    piece_id=piece.id,
                    reason="Canceled because duplicate attempt was archived.",
                )
            )

    await db.commit()
    return {
        "status": "cleaned",
        "backup_dir": str(backup_dir),
        "duplicate_group_count": len(groups),
        "archived_piece_count": len(archived_piece_ids),
        "superseded_review_item_count": len(superseded_review_item_ids),
        "canceled_job_count": len(canceled_job_ids),
        "archived_piece_ids": archived_piece_ids,
        "superseded_review_item_ids": superseded_review_item_ids,
        "canceled_job_ids": canceled_job_ids,
    }


async def supersede_duplicate_pending_reviews(
    db: AsyncSession,
    *,
    canonical_piece_id: str,
    resolved_review_item_id: str | None = None,
) -> list[str]:
    canonical = await db.get(Piece, canonical_piece_id)
    if not canonical:
        return []
    canonical_identity = await derive_piece_identity(db, canonical)
    superseded_ids: list[str] = []
    for piece in await _all_pieces(db):
        if piece.id == canonical_piece_id:
            continue
        identity = await derive_piece_identity(db, piece)
        if identity.key != canonical_identity.key:
            continue
        if piece.status != PieceStatus.approved:
            piece.status = PieceStatus.archived
            piece.updated_at = datetime.utcnow()
        _piece_state_service.update_identity(
            piece.id,
            source_content_sha256=identity.source_content_sha256,
            source_book_fingerprint=identity.source_book_fingerprint,
            logical_piece_key=canonical_identity.key,
            canonical_piece_id=canonical_piece_id,
            attempt_status="duplicate_archived",
            duplicate_reason="Superseded by canonical review decision.",
        )
        superseded_ids.extend(
            await _supersede_pending_reviews_for_piece(
                db,
                duplicate_piece_id=piece.id,
                canonical_piece_id=canonical_piece_id,
                reason="Superseded by canonical review decision.",
                exclude_review_item_id=resolved_review_item_id,
            )
        )

    _piece_state_service.update_identity(
        canonical_piece_id,
        source_content_sha256=canonical_identity.source_content_sha256,
        source_book_fingerprint=canonical_identity.source_book_fingerprint,
        logical_piece_key=canonical_identity.key,
        canonical_piece_id=canonical_piece_id,
        attempt_status="canonical",
    )
    return superseded_ids


async def _collect_duplicate_groups(db: AsyncSession) -> list[DuplicateGroup]:
    grouped: dict[str, list[Piece]] = {}
    for piece in await _all_pieces(db):
        identity = await derive_piece_identity(db, piece)
        grouped.setdefault(identity.key, []).append(piece)

    return [
        DuplicateGroup(logical_piece_key=key, canonical_piece_id=None, pieces=pieces)
        for key, pieces in grouped.items()
        if len(pieces) > 1
    ]


async def _choose_canonical_piece(db: AsyncSession, pieces: list[Piece]) -> Piece | None:
    if not pieces:
        return None
    scored = []
    for piece in pieces:
        scored.append((await _canonical_priority(db, piece), piece))
    scored.sort(key=lambda item: item[0], reverse=True)
    return scored[0][1]


async def _canonical_priority(db: AsyncSession, piece: Piece) -> tuple[int, int, datetime]:
    status_rank = {
        PieceStatus.approved: 40,
        PieceStatus.review_pending: 30,
        PieceStatus.processing: 20,
        PieceStatus.imported: 10,
        PieceStatus.archived: 0,
    }.get(piece.status, 0)
    valid_render_rank = 1 if await _has_valid_render_candidate(db, piece.id) else 0
    return (status_rank, valid_render_rank, piece.updated_at or piece.created_at)


async def _has_valid_render_candidate(db: AsyncSession, piece_id: str) -> bool:
    result = await db.execute(select(ReviewItem).where(ReviewItem.piece_id == piece_id))
    for item in result.scalars().all():
        candidate_data = dict(item.candidate_data or {})
        if candidate_data.get("render_validation_status") == "valid":
            return True
    return False


async def _supersede_pending_reviews_for_piece(
    db: AsyncSession,
    *,
    duplicate_piece_id: str,
    canonical_piece_id: str,
    reason: str,
    exclude_review_item_id: str | None = None,
) -> list[str]:
    result = await db.execute(
        select(ReviewItem).where(
            ReviewItem.piece_id == duplicate_piece_id,
            ReviewItem.status == "pending",
        )
    )
    superseded_ids: list[str] = []
    for item in result.scalars().all():
        if item.id == exclude_review_item_id:
            continue
        candidate_data = dict(item.candidate_data or {})
        candidate_data["superseded_by_piece_id"] = canonical_piece_id
        candidate_data["superseded_reason"] = reason
        candidate_data["superseded_at"] = datetime.utcnow().isoformat()
        item.status = "superseded"
        item.candidate_data = candidate_data
        superseded_ids.append(item.id)
    return superseded_ids


async def _cancel_active_jobs_for_piece(
    db: AsyncSession,
    *,
    piece_id: str,
    reason: str,
) -> list[str]:
    result = await db.execute(
        select(BackgroundJob).where(
            BackgroundJob.piece_id == piece_id,
            BackgroundJob.status.in_([JobStatus.queued, JobStatus.running]),
        )
    )
    canceled_ids: list[str] = []
    for job in result.scalars().all():
        result_data = dict(job.result_data or {})
        result_data["canceled_by"] = "duplicate_cleanup"
        result_data["canceled_at"] = datetime.utcnow().isoformat()
        job.status = JobStatus.canceled
        job.progress = 100.0
        job.error_message = reason
        job.result_data = result_data
        job.updated_at = datetime.utcnow()
        canceled_ids.append(job.id)
    return canceled_ids


async def _all_pieces(db: AsyncSession) -> list[Piece]:
    result = await db.execute(select(Piece).order_by(Piece.created_at.asc()))
    return list(result.scalars().all())


async def _raw_score_hash(db: AsyncSession, piece_id: str) -> str | None:
    result = await db.execute(
        select(ScoreVersion)
        .where(
            ScoreVersion.piece_id == piece_id,
            ScoreVersion.version_type == ScoreVersionType.raw,
        )
        .order_by(ScoreVersion.created_at.asc())
        .limit(1)
    )
    raw_version = result.scalar_one_or_none()
    if not raw_version:
        return None
    path = Path(raw_version.file_path)
    if not path.exists() or not path.is_file():
        return None
    try:
        return hashlib.sha256(path.read_bytes()).hexdigest()
    except OSError:
        return None


def _clean_string(value: object) -> str | None:
    if isinstance(value, str) and value.strip():
        return value.strip()
    return None


def _first_string(*values: object) -> str | None:
    for value in values:
        cleaned = _clean_string(value)
        if cleaned:
            return cleaned
    return None


def _first_int(*values: object) -> int | None:
    for value in values:
        if isinstance(value, int):
            return value
        if isinstance(value, str) and value.strip().isdigit():
            return int(value.strip())
    return None


def _normalize(value: str) -> str:
    return " ".join("".join(char.lower() if char.isalnum() else " " for char in value).split())

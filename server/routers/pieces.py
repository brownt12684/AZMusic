"""Router for piece import, listing, metadata management, and score file access."""

import asyncio
import hashlib
import json
import subprocess
import uuid
from datetime import datetime
from io import BytesIO
from pathlib import Path

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import FileResponse
from pydantic import ValidationError
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from server.config import settings
from server.database import get_db
from server.models.orm import (
    BackgroundJob,
    JobStatus,
    MediaAsset,
    Piece,
    PieceHistoryDraft,
    PieceStatus,
    ReviewItem,
    ScoreVersion,
    ScoreVersionType,
)
from server.models.schemas import (
    JobResponse,
    MediaAssetResponse,
    PieceCreate,
    PieceDetailResponse,
    PieceHistoryDraftCreate,
    PieceHistoryDraftResponse,
    PiecePushMode,
    PiecePushRequest,
    PieceResponse,
    PieceUpdate,
    ScoreVersionRerenderRequest,
    ScoreVersionResponse,
)
from server.services.piece_identity import (
    find_active_book_by_source_hash,
    find_active_piece_by_logical_key,
    find_active_piece_by_source_hash,
    is_duplicate_metadata,
    logical_piece_key,
    sha256_bytes,
    source_book_fingerprint,
)
from server.services.piece_state import PieceStateService
from server.services.processing_engines import (
    MuseScoreRenderEngine,
    ProcessingEngineError,
    _normalize_musicxml_metadata,
    _validate_musicxml,
)
from server.services.processing_settings import ProcessingSettingsStore, executable_status
from server.services.score_processing import (
    BookSplitHint,
    ScoreProcessingService,
    _child_file_name,
    _extract_pdf_page_range,
    _repair_multi_piece_review_pdf_titles,
)
from server.services.training_catalog import TrainingCatalogError, ensure_omr_baseline_copy

router = APIRouter()
_piece_state_service = PieceStateService()
_SUPPORTED_IMPORT_EXTENSIONS = {".pdf", ".png", ".jpg", ".jpeg", ".webp", ".tif", ".tiff"}
_IMAGE_IMPORT_EXTENSIONS = _SUPPORTED_IMPORT_EXTENSIONS - {".pdf"}
_MUSICXML_EXTENSIONS = {".musicxml", ".xml", ".mxl"}
_AUTO_BOOK_IMPORT_PAGE_THRESHOLD = 8
_import_locks: dict[str, asyncio.Lock] = {}
_BOOK_IMPORT_KEYWORDS = (
    "book",
    "collection",
    "method",
    "volume",
    "vol",
    "school",
    "position pieces",
    "suzuki",
)


def _import_lock_for(source_hash: str, *, import_kind: str) -> asyncio.Lock:
    key = f"{import_kind}:{source_hash}"
    lock = _import_locks.get(key)
    if lock is None:
        lock = asyncio.Lock()
        _import_locks[key] = lock
    return lock


def _piece_to_response(piece: Piece) -> PieceResponse:
    metadata = _piece_state_service.metadata_for_piece(piece)
    return PieceResponse(
        id=piece.id,
        title=piece.title,
        composer=piece.composer,
        primary_instrument=metadata["primary_instrument"],
        book_or_collection=metadata["book_or_collection"],
        key_signature=piece.key_signature,
        tempo=piece.tempo,
        difficulty_level=piece.difficulty_level,
        notes=metadata["notes"],
        processed_metadata=metadata["processed_metadata"],
        piece_kind=metadata["piece_kind"],
        source_book_id=metadata["source_book_id"],
        source_page_start=metadata["source_page_start"],
        source_page_end=metadata["source_page_end"],
        catalog_metadata=metadata["catalog_metadata"],
        catalog_suggestions=metadata["catalog_suggestions"],
        validation_warnings=metadata["validation_warnings"],
        split_confidence=metadata["split_confidence"],
        workflow_closed=metadata["workflow_closed"],
        visible_to_profile_ids=metadata["visible_to_profile_ids"],
        previous_visible_to_profile_ids=metadata["previous_visible_to_profile_ids"],
        library_status=metadata["library_status"],
        source_content_sha256=metadata["source_content_sha256"],
        source_book_fingerprint=metadata["source_book_fingerprint"],
        logical_piece_key=metadata["logical_piece_key"],
        canonical_piece_id=metadata["canonical_piece_id"],
        attempt_status=metadata["attempt_status"],
        duplicate_attempt_count=metadata["duplicate_attempt_count"],
        duplicate_reason=metadata["duplicate_reason"],
        is_duplicate_attempt=metadata["is_duplicate_attempt"],
        status=piece.status,
        created_at=piece.created_at,
        updated_at=piece.updated_at,
    )


def _score_version_file_url(request: Request, piece_id: str, score_version_id: str) -> str:
    return str(
        request.url_for(
            "get_score_version_file",
            piece_id=piece_id,
            score_version_id=score_version_id,
        )
    )


def _score_version_content_type(file_path: Path) -> str:
    suffix = file_path.suffix.lower()
    if suffix == ".pdf":
        return "application/pdf"
    if suffix == ".png":
        return "image/png"
    if suffix in {".jpg", ".jpeg"}:
        return "image/jpeg"
    if suffix == ".webp":
        return "image/webp"
    if suffix in {".tif", ".tiff"}:
        return "image/tiff"
    if suffix in {".musicxml", ".xml", ".mxl"}:
        return "application/vnd.recordare.musicxml+xml"
    return "application/octet-stream"


def _score_version_download_metadata(file_path: Path) -> tuple[str, int | None, str | None]:
    content_type = _score_version_content_type(file_path)
    if not file_path.exists():
        return content_type, None, None
    return (
        content_type,
        file_path.stat().st_size,
        hashlib.sha256(file_path.read_bytes()).hexdigest(),
    )


def _score_version_role(score_version: ScoreVersion) -> str:
    workflow_metadata = _piece_state_service.score_version_metadata(
        score_version.piece_id,
        score_version.id,
    )
    artifact_role = workflow_metadata.get("artifact_role")
    if isinstance(artifact_role, str) and artifact_role.strip():
        normalized_role = artifact_role.strip()
        if normalized_role == "original_import":
            return "original_pdf"
        if normalized_role in {
            "cleaned_pdf",
            "musescore_render_pdf",
            "corrected_render_pdf",
            "human_approved_render_pdf",
        }:
            return "processed_render_pdf"
        if normalized_role in {
            "musicxml_candidate",
            "corrected_musicxml",
            "human_approved_musicxml",
            "omr_baseline_musicxml",
        }:
            return "canonical_musicxml"
        return normalized_role
    file_path = Path(score_version.file_path)
    suffix = file_path.suffix.lower()
    name = file_path.name.lower()
    if suffix in _MUSICXML_EXTENSIONS:
        return "canonical_musicxml"
    if score_version.version_type == ScoreVersionType.raw or name.startswith("raw_source"):
        return "original_pdf"
    if suffix in _SUPPORTED_IMPORT_EXTENSIONS:
        return "processed_render_pdf"
    return "unknown"


def _piece_to_detail_response(request: Request, piece: Piece) -> PieceDetailResponse:
    sorted_score_versions = sorted(
        piece.score_versions,
        key=lambda version: (version.is_default, version.created_at),
        reverse=True,
    )
    score_versions = []
    for score_version in sorted_score_versions:
        file_path = Path(score_version.file_path)
        content_type, file_size_bytes, content_sha256 = _score_version_download_metadata(file_path)
        workflow_metadata = _piece_state_service.score_version_metadata(
            piece.id,
            score_version.id,
        )
        score_versions.append(
            ScoreVersionResponse(
                id=score_version.id,
                piece_id=score_version.piece_id,
                version_type=score_version.version_type,
                file_path=score_version.file_path,
                file_url=_score_version_file_url(request, piece.id, score_version.id),
                content_type=content_type,
                file_size_bytes=file_size_bytes,
                content_sha256=content_sha256,
                score_version_role=_score_version_role(score_version),
                artifact_role=_metadata_string(workflow_metadata, "artifact_role"),
                replaces_score_version_id=_metadata_string(
                    workflow_metadata,
                    "replaces_score_version_id",
                ),
                display_rank=_metadata_int(workflow_metadata, "display_rank") or 0,
                student_default=bool(workflow_metadata.get("student_default")),
                approved_by_parent=bool(workflow_metadata.get("approved_by_parent")),
                is_default=score_version.is_default,
                created_at=score_version.created_at,
            )
        )
    media_assets = [
        MediaAssetResponse(
            id=ma.id,
            piece_id=ma.piece_id,
            asset_type=ma.asset_type,
            file_path=ma.file_path,
            status=ma.status,
            created_at=ma.created_at,
        )
        for ma in piece.media_assets
    ]
    history_drafts = [
        PieceHistoryDraftResponse(
            id=hd.id,
            piece_id=hd.piece_id,
            content=hd.content,
            status=hd.status,
            confidence=hd.confidence,
            provenance=hd.provenance,
            created_at=hd.created_at,
        )
        for hd in piece.history_drafts
    ]
    metadata = _piece_state_service.metadata_for_piece(piece)
    return PieceDetailResponse(
        id=piece.id,
        title=piece.title,
        composer=piece.composer,
        primary_instrument=metadata["primary_instrument"],
        book_or_collection=metadata["book_or_collection"],
        key_signature=piece.key_signature,
        tempo=piece.tempo,
        difficulty_level=piece.difficulty_level,
        notes=metadata["notes"],
        processed_metadata=metadata["processed_metadata"],
        piece_kind=metadata["piece_kind"],
        source_book_id=metadata["source_book_id"],
        source_page_start=metadata["source_page_start"],
        source_page_end=metadata["source_page_end"],
        catalog_metadata=metadata["catalog_metadata"],
        catalog_suggestions=metadata["catalog_suggestions"],
        validation_warnings=metadata["validation_warnings"],
        split_confidence=metadata["split_confidence"],
        workflow_closed=metadata["workflow_closed"],
        visible_to_profile_ids=metadata["visible_to_profile_ids"],
        previous_visible_to_profile_ids=metadata["previous_visible_to_profile_ids"],
        library_status=metadata["library_status"],
        source_content_sha256=metadata["source_content_sha256"],
        source_book_fingerprint=metadata["source_book_fingerprint"],
        logical_piece_key=metadata["logical_piece_key"],
        canonical_piece_id=metadata["canonical_piece_id"],
        attempt_status=metadata["attempt_status"],
        duplicate_attempt_count=metadata["duplicate_attempt_count"],
        duplicate_reason=metadata["duplicate_reason"],
        is_duplicate_attempt=metadata["is_duplicate_attempt"],
        status=piece.status,
        created_at=piece.created_at,
        updated_at=piece.updated_at,
        file_name=piece.file_name,
        score_versions=score_versions,
        media_assets=media_assets,
        history_drafts=history_drafts,
    )


async def _load_piece_with_relations(piece_id: str, db: AsyncSession) -> Piece | None:
    result = await db.execute(
        select(Piece)
        .options(
            selectinload(Piece.score_versions),
            selectinload(Piece.media_assets),
            selectinload(Piece.history_drafts),
            selectinload(Piece.review_items),
            selectinload(Piece.annotations),
        )
        .where(Piece.id == piece_id)
    )
    return result.scalar_one_or_none()


async def _piece_has_raw_score_version(db: AsyncSession, piece_id: str) -> bool:
    result = await db.execute(
        select(ScoreVersion.id)
        .where(
            ScoreVersion.piece_id == piece_id,
            ScoreVersion.version_type == ScoreVersionType.raw,
        )
        .limit(1)
    )
    return result.scalar_one_or_none() is not None


async def _load_raw_score_version(db: AsyncSession, piece_id: str) -> ScoreVersion | None:
    result = await db.execute(
        select(ScoreVersion)
        .where(
            ScoreVersion.piece_id == piece_id,
            ScoreVersion.version_type == ScoreVersionType.raw,
        )
        .order_by(ScoreVersion.created_at.asc())
        .limit(1)
    )
    return result.scalar_one_or_none()


async def _load_student_default_score_version(
    db: AsyncSession,
    piece_id: str,
) -> ScoreVersion | None:
    result = await db.execute(
        select(ScoreVersion)
        .where(ScoreVersion.piece_id == piece_id)
        .order_by(ScoreVersion.is_default.desc(), ScoreVersion.created_at.desc())
    )
    versions = result.scalars().all()
    for version in versions:
        metadata = _piece_state_service.score_version_metadata(piece_id, version.id)
        if metadata.get("student_default") and Path(version.file_path).suffix.lower() in {
            ".pdf",
            ".png",
            ".jpg",
            ".jpeg",
            ".webp",
            ".tif",
            ".tiff",
        }:
            return version
    for version in versions:
        metadata = _piece_state_service.score_version_metadata(piece_id, version.id)
        if metadata.get("artifact_role") == "cleaned_pdf":
            return version
    for version in versions:
        if (
            version.is_default
            and Path(version.file_path).suffix.lower() in _SUPPORTED_IMPORT_EXTENSIONS
        ):
            return version
    return await _load_raw_score_version(db, piece_id)


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
        metadata = _piece_state_service.score_version_metadata(piece_id, version.id)
        if metadata.get("artifact_role") != "cleaned_pdf":
            continue
        if Path(version.file_path).suffix.lower() not in {
            ".pdf",
            ".png",
            ".jpg",
            ".jpeg",
            ".webp",
            ".tif",
            ".tiff",
        }:
            continue
        return version
    return None


async def _load_existing_score_version_file(
    db: AsyncSession,
    *,
    piece_id: str,
    score_version_id: str,
    require_exists: bool = True,
) -> tuple[ScoreVersion, Path]:
    result = await db.execute(
        select(ScoreVersion).where(
            ScoreVersion.id == score_version_id,
            ScoreVersion.piece_id == piece_id,
        )
    )
    score_version = result.scalar_one_or_none()
    if not score_version:
        raise HTTPException(status_code=404, detail="Score version not found.")
    file_path = Path(score_version.file_path)
    if require_exists and not file_path.exists():
        raise HTTPException(status_code=404, detail="Stored score file missing from disk.")
    return score_version, file_path


async def _mark_review_render_refreshed(
    db: AsyncSession,
    *,
    piece_id: str,
    canonical_score_version_id: str,
    rendered_score_version_id: str,
    rendered_at: str,
    renderer_name: str,
    renderer_version: str | None,
    render_validation_status: str,
    render_validation_error: str | None,
    rendered_file_size_bytes: int | None,
    rendered_page_count: int | None,
    render_diagnostics: dict,
    warnings: list[str],
) -> None:
    result = await db.execute(
        select(ReviewItem).where(
            ReviewItem.piece_id == piece_id,
            ReviewItem.status == "pending",
        )
    )
    changed = False
    for item in result.scalars().all():
        candidate_data = dict(item.candidate_data or {})
        refresh_payload = {
            "manual_musescore_rendered_at": rendered_at,
            "renderer_name": renderer_name,
            "renderer_version": renderer_version,
            "render_validation_status": render_validation_status,
            "render_validation_error": render_validation_error,
            "rendered_file_size_bytes": rendered_file_size_bytes,
            "rendered_page_count": rendered_page_count,
            "render_diagnostics": render_diagnostics,
        }
        matched_top_level = (
            candidate_data.get("canonical_score_version_id") == canonical_score_version_id
            and candidate_data.get("score_version_id") == rendered_score_version_id
        )
        matched_option = False
        updated_options = []
        for option in candidate_data.get("omr_candidates") or []:
            if not isinstance(option, dict):
                continue
            updated_option = dict(option)
            if (
                updated_option.get("canonical_score_version_id") == canonical_score_version_id
                and updated_option.get("score_version_id") == rendered_score_version_id
            ):
                updated_option.update(refresh_payload)
                if warnings:
                    updated_option["warnings"] = sorted(
                        set(list(updated_option.get("warnings") or []) + warnings)
                    )
                matched_option = True
            updated_options.append(updated_option)
        if matched_option:
            candidate_data["omr_candidates"] = updated_options
        if matched_top_level:
            candidate_data.update(refresh_payload)
            if warnings:
                candidate_data["warnings"] = sorted(
                    set(list(candidate_data.get("warnings") or []) + warnings)
                )
        if not matched_top_level and not matched_option:
            continue
        item.candidate_data = candidate_data
        changed = True
    if changed:
        await db.commit()


async def _mark_review_human_edited(
    db: AsyncSession,
    *,
    piece_id: str,
    canonical_score_version_id: str,
    rendered_score_version_id: str,
    uploaded_file_name: str,
    baseline_path: Path,
    edited_at: str,
) -> None:
    result = await db.execute(
        select(ReviewItem).where(
            ReviewItem.piece_id == piece_id,
            ReviewItem.status == "pending",
        )
    )
    changed = False
    for item in result.scalars().all():
        candidate_data = dict(item.candidate_data or {})
        matched_top_level = (
            candidate_data.get("canonical_score_version_id") == canonical_score_version_id
            and candidate_data.get("score_version_id") == rendered_score_version_id
        )
        matched_option = False
        updated_options = []
        for option in candidate_data.get("omr_candidates") or []:
            if not isinstance(option, dict):
                continue
            updated_option = dict(option)
            if (
                updated_option.get("canonical_score_version_id") == canonical_score_version_id
                and updated_option.get("score_version_id") == rendered_score_version_id
            ):
                updated_option.update(
                    {
                        "human_edited_musicxml": True,
                        "human_edited_at": edited_at,
                        "human_edited_file_name": uploaded_file_name,
                        "omr_baseline_file_path": str(baseline_path),
                    }
                )
                matched_option = True
            updated_options.append(updated_option)
        if matched_option:
            candidate_data["omr_candidates"] = updated_options
        if matched_top_level:
            candidate_data.update(
                {
                    "human_edited_musicxml": True,
                    "human_edited_at": edited_at,
                    "human_edited_file_name": uploaded_file_name,
                    "omr_baseline_file_path": str(baseline_path),
                }
            )
        if not matched_top_level and not matched_option:
            continue
        item.candidate_data = candidate_data
        changed = True
    if changed:
        await db.commit()


async def _candidate_data_for_score_versions(
    db: AsyncSession,
    *,
    piece_id: str,
    canonical_score_version_id: str,
    rendered_score_version_id: str,
) -> dict:
    result = await db.execute(
        select(ReviewItem).where(
            ReviewItem.piece_id == piece_id,
            ReviewItem.status == "pending",
        )
    )
    for item in result.scalars().all():
        candidate_data = dict(item.candidate_data or {})
        if candidate_data.get("canonical_score_version_id") != canonical_score_version_id:
            option_data = _candidate_option_data_for_score_versions(
                candidate_data,
                canonical_score_version_id=canonical_score_version_id,
                rendered_score_version_id=rendered_score_version_id,
            )
            if option_data is not None:
                return {**candidate_data, **option_data}
            continue
        if candidate_data.get("score_version_id") != rendered_score_version_id:
            option_data = _candidate_option_data_for_score_versions(
                candidate_data,
                canonical_score_version_id=canonical_score_version_id,
                rendered_score_version_id=rendered_score_version_id,
            )
            if option_data is not None:
                return {**candidate_data, **option_data}
            continue
        return candidate_data
    return {}


def _candidate_option_data_for_score_versions(
    candidate_data: dict,
    *,
    canonical_score_version_id: str,
    rendered_score_version_id: str,
) -> dict | None:
    for option in candidate_data.get("omr_candidates") or []:
        if not isinstance(option, dict):
            continue
        if option.get("canonical_score_version_id") != canonical_score_version_id:
            continue
        if option.get("score_version_id") != rendered_score_version_id:
            continue
        return dict(option)
    return None


@router.get("/")
async def list_pieces(include_attempts: bool = False, db: AsyncSession = Depends(get_db)):
    """List all imported pieces."""
    result = await db.execute(select(Piece).order_by(Piece.created_at.desc()))
    pieces = result.scalars().all()
    responses = []
    for piece in pieces:
        metadata = _piece_state_service.metadata_for_piece(piece)
        if not include_attempts and is_duplicate_metadata(metadata):
            continue
        responses.append(_piece_to_response(piece))
    return responses


@router.get("/assigned/{profile_id}")
async def list_assigned_pieces(profile_id: str, db: AsyncSession = Depends(get_db)):
    """List student-visible approved pieces and cleaned book packages."""
    result = await db.execute(select(Piece).order_by(Piece.updated_at.desc()))
    pieces: list[PieceResponse] = []
    for piece in result.scalars().all():
        metadata = _piece_state_service.metadata_for_piece(piece)
        if is_duplicate_metadata(metadata):
            continue
        if profile_id not in metadata["visible_to_profile_ids"]:
            continue
        can_show_book_package = (
            metadata["piece_kind"] == "book"
            and (await _load_cleaned_student_score_version(db, piece.id)) is not None
        )
        can_show_raw = (
            piece.status == PieceStatus.needs_edits
            and await _piece_has_raw_score_version(
                db,
                piece.id,
            )
        )
        if piece.status != PieceStatus.approved and not can_show_book_package and not can_show_raw:
            continue
        pieces.append(_piece_to_response(piece))
    return pieces


@router.post("/")
async def create_piece(body: PieceCreate, db: AsyncSession = Depends(get_db)):
    """Create a piece row without processing artifacts."""
    if body.piece_id:
        piece = await db.get(Piece, body.piece_id)
        if piece:
            piece.status = PieceStatus.imported
            piece.title = body.title
            piece.composer = body.composer
            piece.file_name = body.file_name
            await db.commit()
            await db.refresh(piece)
            _piece_state_service.upsert_metadata(
                piece.id,
                title=piece.title,
                composer=piece.composer,
            )
            return _piece_to_response(piece)

    piece = Piece(
        id=str(uuid.uuid4()),
        title=body.title,
        composer=body.composer,
        file_name=body.file_name,
        status=PieceStatus.imported,
    )
    db.add(piece)
    await db.commit()
    await db.refresh(piece)
    _piece_state_service.upsert_metadata(
        piece.id,
        title=piece.title,
        composer=piece.composer,
    )
    return _piece_to_response(piece)


@router.post("/import")
async def import_piece(
    title: str | None = Form(None),
    composer: str | None = Form(None),
    primary_instrument: str | None = Form(None),
    book_or_collection: str | None = Form(None),
    catalog_mode: str | None = Form(None),
    split_hints: str | None = Form(None),
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
):
    """Import a raw PDF or image scan and prepare metadata for parent review."""
    file_name = file.filename or f"{(title or 'Imported score').strip()}.pdf"
    file_suffix = Path(file_name).suffix.lower()
    if file_suffix not in _SUPPORTED_IMPORT_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail="Only PDF and image score uploads are supported.",
        )

    resolved_title, title_source = _resolve_import_title(title, file_name)
    resolved_composer, composer_source = _resolve_import_composer(composer, file_name)

    file_bytes = await file.read()
    if not file_bytes:
        raise HTTPException(status_code=400, detail="Uploaded file was empty.")
    source_hash = sha256_bytes(file_bytes)

    parsed_split_hints = _parse_split_hints(split_hints)
    should_import_as_book = (
        catalog_mode == "book"
        or bool(parsed_split_hints)
        or (
            file_suffix == ".pdf"
            and _should_auto_import_as_book(
                file_name=file_name,
                title=resolved_title,
                book_or_collection=book_or_collection,
                file_bytes=file_bytes,
            )
        )
    )
    import_lock = _import_lock_for(
        source_hash,
        import_kind="book" if should_import_as_book else "piece",
    )
    async with import_lock:
        if should_import_as_book:
            if file_suffix != ".pdf":
                raise HTTPException(status_code=400, detail="Book imports must be PDF files.")
            existing_book = await find_active_book_by_source_hash(db, source_hash)
            if existing_book:
                return await _resume_existing_book_import(
                    db,
                    existing_book=existing_book,
                    source_hash=source_hash,
                    source_file_name=file_name,
                    file_bytes=file_bytes,
                    split_hints=parsed_split_hints,
                    primary_instrument=primary_instrument,
                    book_or_collection=book_or_collection,
                )
            return await _import_book_piece(
                db,
                title=resolved_title,
                composer=resolved_composer,
                primary_instrument=primary_instrument,
                book_or_collection=book_or_collection,
                file_name=file_name,
                file_bytes=file_bytes,
                source_hash=source_hash,
                split_hints=parsed_split_hints,
                allow_title_override=title_source == "filename_heuristic",
                allow_composer_override=composer_source != "import_form",
            )

        existing_piece = await find_active_piece_by_source_hash(db, source_hash)
        if existing_piece:
            return _piece_to_response(existing_piece)

        return await _import_standalone_piece(
            db,
            file_suffix=file_suffix,
            file_name=file_name,
            file_bytes=file_bytes,
            source_hash=source_hash,
            resolved_title=resolved_title,
            resolved_composer=resolved_composer,
            primary_instrument=primary_instrument,
            book_or_collection=book_or_collection,
            title_source=title_source,
            composer_source=composer_source,
        )


async def _import_standalone_piece(
    db: AsyncSession,
    *,
    file_suffix: str,
    file_name: str,
    file_bytes: bytes,
    source_hash: str,
    resolved_title: str,
    resolved_composer: str | None,
    primary_instrument: str | None,
    book_or_collection: str | None,
    title_source: str,
    composer_source: str,
) -> PieceResponse:
    try:
        if file_suffix in _IMAGE_IMPORT_EXTENSIONS:
            artifacts = await ScoreProcessingService().import_image_scan(
                db,
                title=resolved_title,
                composer=resolved_composer,
                file_name=file_name,
                file_bytes=file_bytes,
                allow_title_override=title_source == "filename_heuristic",
                allow_composer_override=composer_source != "import_form",
            )
        else:
            artifacts = await ScoreProcessingService().import_pdf(
                db,
                title=resolved_title,
                composer=resolved_composer,
                file_name=file_name,
                file_bytes=file_bytes,
                primary_instrument=primary_instrument,
                allow_title_override=title_source == "filename_heuristic",
                allow_composer_override=composer_source != "import_form",
            )
    except ProcessingEngineError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    processed_metadata = _processed_metadata_from_artifacts(artifacts)
    standalone_key = logical_piece_key(
        source_book_fingerprint=None,
        book_or_collection=book_or_collection,
        source_page_start=None,
        source_page_end=None,
        title=artifacts.piece.title,
        composer=artifacts.piece.composer,
        primary_instrument=primary_instrument
        or _metadata_string(processed_metadata, "primary_instrument"),
        source_content_sha256=source_hash,
    )
    filename_suggestions = _filename_catalog_suggestions(
        title=resolved_title,
        composer=resolved_composer if composer_source == "filename_heuristic" else None,
        file_name=file_name,
        enabled=title_source == "filename_heuristic" or composer_source == "filename_heuristic",
    )
    catalog_suggestions = (
        filename_suggestions
        + artifacts.ocr_catalog_suggestions
        + _catalog_suggestions_from_metadata(
            artifacts.musicxml_metadata,
            source="musicxml_processing",
        )
    )
    catalog_metadata = _catalog_metadata_from_piece(
        artifacts.piece,
        primary_instrument=primary_instrument
        or _metadata_string(processed_metadata, "primary_instrument"),
        book_or_collection=book_or_collection
        or _metadata_string(processed_metadata, "book_or_collection"),
        notes=None,
    )
    _piece_state_service.upsert_metadata(
        artifacts.piece.id,
        title=artifacts.piece.title,
        composer=artifacts.piece.composer,
        primary_instrument=primary_instrument
        or _metadata_string(processed_metadata, "primary_instrument"),
        book_or_collection=book_or_collection
        or _metadata_string(processed_metadata, "book_or_collection"),
        processed_metadata=processed_metadata,
        piece_kind="piece",
        catalog_metadata=catalog_metadata,
        catalog_suggestions=catalog_suggestions,
        visible_to_profile_ids=[],
    )
    _piece_state_service.update_identity(
        artifacts.piece.id,
        source_content_sha256=source_hash,
        logical_piece_key=standalone_key,
        canonical_piece_id=artifacts.piece.id,
        attempt_status="canonical",
    )
    if artifacts.review_item:
        candidate_data = dict(artifacts.review_item.candidate_data or {})
        candidate_data.update(
            {
                "piece_title": artifacts.piece.title,
                "catalog_metadata": catalog_metadata,
                "catalog_suggestions": catalog_suggestions,
                "processed_metadata": processed_metadata,
            }
        )
        artifacts.review_item.candidate_data = candidate_data
        await db.commit()
    return _piece_to_response(artifacts.piece)


@router.get("/{piece_id}")
async def get_piece(
    piece_id: str,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Get piece detail by ID with score versions and review-relevant data."""
    piece = await _load_piece_with_relations(piece_id, db)
    if not piece:
        raise HTTPException(status_code=404, detail="Piece not found")
    return _piece_to_detail_response(request, piece)


@router.post("/{piece_id}/push")
async def push_piece_to_profiles(
    piece_id: str,
    body: PiecePushRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Assign the current student PDF/default artifact to profiles."""
    piece = await db.get(Piece, piece_id)
    if not piece:
        raise HTTPException(status_code=404, detail="Piece not found")
    metadata = _piece_state_service.metadata_for_piece(piece)
    if body.mode == PiecePushMode.original_pdf:
        raw_version = await _load_raw_score_version(db, piece_id)
        if raw_version is None:
            raise HTTPException(
                status_code=409,
                detail="No original PDF/image score version is available to push.",
            )
        if piece.status != PieceStatus.needs_edits:
            raise HTTPException(
                status_code=409,
                detail="Use the cleaned student PDF for approved pieces.",
            )
        default_result = await db.execute(
            select(ScoreVersion.id)
            .where(
                ScoreVersion.piece_id == piece_id,
                ScoreVersion.is_default.is_(True),
            )
            .limit(1)
        )
        if default_result.scalar_one_or_none() is None:
            raw_version.is_default = True
        _piece_state_service.set_score_version_metadata(
            piece_id,
            raw_version.id,
            artifact_role="original_import",
            student_default=True,
            approved_by_parent=True,
            display_rank=10,
        )
    elif body.mode in {PiecePushMode.processed, PiecePushMode.cleaned_pdf}:
        student_version = await _load_cleaned_student_score_version(db, piece_id)
        if student_version is None:
            raise HTTPException(
                status_code=409,
                detail="No student PDF is available to push yet.",
            )
        is_book_package = metadata["piece_kind"] == "book"
        if piece.status != PieceStatus.approved and not is_book_package:
            raise HTTPException(
                status_code=409,
                detail="Approve metadata before pushing the student PDF.",
            )
        workflow_metadata = _piece_state_service.score_version_metadata(
            piece_id,
            student_version.id,
        )
        if workflow_metadata.get("artifact_role") != "cleaned_pdf":
            raise HTTPException(
                status_code=409,
                detail="No cleaned student PDF is available to push yet.",
            )
        await db.execute(
            update(ScoreVersion).where(ScoreVersion.piece_id == piece_id).values(is_default=False)
        )
        student_version.is_default = True
        if student_version.version_type != ScoreVersionType.approved:
            student_version.version_type = ScoreVersionType.approved
        if is_book_package and piece.status != PieceStatus.approved:
            piece.status = PieceStatus.approved
        _piece_state_service.set_score_version_metadata(
            piece_id,
            student_version.id,
            artifact_role="cleaned_pdf",
            student_default=True,
            approved_by_parent=True,
            display_rank=workflow_metadata.get("display_rank") or 10,
        )
    else:
        raise HTTPException(
            status_code=400,
            detail="Unsupported push mode.",
        )

    _piece_state_service.assign_profiles(piece_id, body.profile_ids)
    if (
        body.mode in {PiecePushMode.processed, PiecePushMode.cleaned_pdf}
        and metadata["piece_kind"] == "book"
    ):
        child_result = await db.execute(select(Piece))
        for child_piece in child_result.scalars().all():
            if child_piece.id == piece_id or child_piece.status != PieceStatus.approved:
                continue
            child_metadata = _piece_state_service.metadata_for_piece(child_piece)
            if child_metadata["source_book_id"] != piece_id:
                continue
            _piece_state_service.assign_profiles(child_piece.id, body.profile_ids)
            child_piece.updated_at = datetime.utcnow()
    piece.updated_at = datetime.utcnow()
    await db.commit()
    refreshed_piece = await _load_piece_with_relations(piece_id, db)
    if refreshed_piece is None:
        raise HTTPException(status_code=404, detail="Piece not found")
    return _piece_to_detail_response(request, refreshed_piece)


@router.post("/{piece_id}/notation-lab/start", response_model=JobResponse)
async def start_notation_lab_processing(
    piece_id: str,
    db: AsyncSession = Depends(get_db),
):
    """Queue optional MusicXML/MuseScore reconstruction after PDF-first approval."""
    piece = await db.get(Piece, piece_id)
    if not piece:
        raise HTTPException(status_code=404, detail="Piece not found")
    raw_version = await _load_raw_score_version(db, piece_id)
    if raw_version is None:
        raise HTTPException(
            status_code=409,
            detail="No original score is available for notation processing.",
        )
    metadata = _piece_state_service.metadata_for_piece(piece)
    now = datetime.utcnow()
    job = BackgroundJob(
        id=str(uuid.uuid4()),
        piece_id=piece_id,
        job_type="score_processing",
        status=JobStatus.queued,
        progress=0.0,
        result_data={
            "raw_score_version_id": raw_version.id,
            "processing_stage": "queued_after_metadata_review",
            "source_book_id": metadata["source_book_id"],
            "source_page_start": metadata["source_page_start"],
            "source_page_end": metadata["source_page_end"],
            "primary_instrument": metadata["primary_instrument"],
            "contained_piece_titles": metadata["catalog_metadata"].get("contained_piece_titles")
            if isinstance(metadata["catalog_metadata"], dict)
            else None,
            "multi_piece_page": metadata["catalog_metadata"].get("multi_piece_page")
            if isinstance(metadata["catalog_metadata"], dict)
            else None,
        },
        created_at=now,
        updated_at=now,
    )
    piece.status = PieceStatus.processing
    piece.updated_at = now
    db.add(job)
    await db.commit()
    await db.refresh(job)
    return JobResponse(
        id=job.id,
        piece_id=job.piece_id,
        piece_title=piece.title,
        piece_composer=piece.composer,
        piece_status=piece.status,
        job_type=job.job_type,
        status=job.status,
        progress=job.progress,
        error_message=job.error_message,
        result_data=job.result_data,
        created_at=job.created_at,
        updated_at=job.updated_at,
    )


@router.post("/{piece_id}/workflow/pull-for-edits")
async def pull_piece_for_edits(
    piece_id: str,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Return a pushed piece to parent edit workflow and remove student assignment."""
    piece = await db.get(Piece, piece_id)
    if not piece:
        raise HTTPException(status_code=404, detail="Piece not found")
    metadata = _piece_state_service.metadata_for_piece(piece)
    if not metadata["visible_to_profile_ids"]:
        raise HTTPException(
            status_code=409,
            detail="Only pieces already pushed to at least one profile can be pulled back.",
        )
    previous_visible_to_profile_ids = sorted(
        set(metadata["previous_visible_to_profile_ids"]) | set(metadata["visible_to_profile_ids"])
    )
    piece.status = PieceStatus.needs_edits
    piece.updated_at = datetime.utcnow()
    _piece_state_service.upsert_metadata(
        piece.id,
        title=piece.title,
        composer=piece.composer,
        primary_instrument=metadata["primary_instrument"],
        book_or_collection=metadata["book_or_collection"],
        visible_to_profile_ids=[],
        processed_metadata=metadata["processed_metadata"],
        piece_kind=metadata["piece_kind"],
        source_book_id=metadata["source_book_id"],
        source_page_start=metadata["source_page_start"],
        source_page_end=metadata["source_page_end"],
        catalog_metadata=metadata["catalog_metadata"],
        catalog_suggestions=metadata["catalog_suggestions"],
        validation_warnings=sorted(
            set(
                list(metadata["validation_warnings"])
                + [
                    "Parent pulled this piece back for edits; it is hidden "
                    "from student libraries until repushed."
                ]
            )
        ),
        split_confidence=metadata["split_confidence"],
        workflow_closed=False,
        previous_visible_to_profile_ids=previous_visible_to_profile_ids,
        notes=metadata["notes"],
    )
    await db.commit()
    refreshed_piece = await _load_piece_with_relations(piece_id, db)
    if refreshed_piece is None:
        raise HTTPException(status_code=404, detail="Piece not found")
    return _piece_to_detail_response(request, refreshed_piece)


@router.post("/{piece_id}/workflow/close")
async def close_piece_workflow(
    piece_id: str,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Hide a pushed piece from the parent processing workflow."""
    piece = await _load_piece_with_relations(piece_id, db)
    if not piece:
        raise HTTPException(status_code=404, detail="Piece not found")

    metadata = _piece_state_service.metadata_for_piece(piece)
    if not metadata["visible_to_profile_ids"]:
        raise HTTPException(
            status_code=409,
            detail="Only pieces that have been pushed to at least one profile can be closed.",
        )

    _piece_state_service.close_workflow(piece_id)
    piece.updated_at = datetime.utcnow()
    await db.commit()
    await db.refresh(piece)
    refreshed_piece = await _load_piece_with_relations(piece_id, db)
    if refreshed_piece is None:
        raise HTTPException(status_code=404, detail="Piece not found")
    return _piece_to_detail_response(request, refreshed_piece)


@router.get(
    "/{piece_id}/score_versions/{score_version_id}/file",
    name="get_score_version_file",
)
async def get_score_version_file(
    piece_id: str,
    score_version_id: str,
    db: AsyncSession = Depends(get_db),
):
    """Serve a stored score-version artifact."""
    result = await db.execute(
        select(ScoreVersion).where(
            ScoreVersion.id == score_version_id,
            ScoreVersion.piece_id == piece_id,
        )
    )
    score_version = result.scalar_one_or_none()
    if not score_version:
        raise HTTPException(status_code=404, detail="Score version not found")

    file_path = Path(score_version.file_path)
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="Stored score file missing from disk")

    return FileResponse(
        path=file_path,
        media_type=_score_version_content_type(file_path),
        filename=file_path.name,
    )


async def _render_score_version_for_review(
    db: AsyncSession,
    *,
    piece_id: str,
    canonical_version: ScoreVersion,
    canonical_path: Path,
    rendered_version: ScoreVersion,
    rendered_path: Path,
) -> dict:
    raw_result = await db.execute(
        select(ScoreVersion)
        .where(
            ScoreVersion.piece_id == piece_id,
            ScoreVersion.version_type == ScoreVersionType.raw,
        )
        .order_by(ScoreVersion.created_at.asc())
        .limit(1)
    )
    raw_version = raw_result.scalar_one_or_none()
    if not raw_version:
        raise HTTPException(status_code=404, detail="Raw score version not found.")
    raw_path = Path(raw_version.file_path)
    if not raw_path.exists():
        raise HTTPException(status_code=404, detail="Raw score file missing from disk.")

    try:
        render_result = MuseScoreRenderEngine().render(
            canonical_path=canonical_path,
            raw_pdf_path=raw_path,
            output_pdf_path=rendered_path,
            processing_settings=ProcessingSettingsStore().load(),
        )
    except ProcessingEngineError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc

    candidate_data = await _candidate_data_for_score_versions(
        db,
        piece_id=piece_id,
        canonical_score_version_id=canonical_version.id,
        rendered_score_version_id=rendered_version.id,
    )
    _repair_multi_piece_review_pdf_titles(
        render_result,
        contained_piece_titles=[
            title
            for title in candidate_data.get("contained_piece_titles") or []
            if isinstance(title, str)
        ],
        multi_piece_page=bool(candidate_data.get("multi_piece_page")),
    )
    rendered_at = datetime.utcnow().isoformat()
    await _mark_review_render_refreshed(
        db,
        piece_id=piece_id,
        canonical_score_version_id=canonical_version.id,
        rendered_score_version_id=rendered_version.id,
        rendered_at=rendered_at,
        renderer_name=render_result.renderer_name,
        renderer_version=render_result.renderer_version,
        render_validation_status=render_result.validation_status,
        render_validation_error=render_result.validation_error,
        rendered_file_size_bytes=render_result.file_size_bytes,
        rendered_page_count=render_result.page_count,
        render_diagnostics=render_result.diagnostics,
        warnings=render_result.warnings,
    )
    content_type, file_size_bytes, content_sha256 = _score_version_download_metadata(rendered_path)
    return {
        "status": "rendered",
        "piece_id": piece_id,
        "canonical_score_version_id": canonical_version.id,
        "rendered_score_version_id": rendered_version.id,
        "rendered_at": rendered_at,
        "renderer_name": render_result.renderer_name,
        "renderer_version": render_result.renderer_version,
        "render_validation_status": render_result.validation_status,
        "render_validation_error": render_result.validation_error,
        "rendered_page_count": render_result.page_count,
        "render_diagnostics": render_result.diagnostics,
        "warnings": render_result.warnings,
        "rendered_content_type": content_type,
        "rendered_file_size_bytes": file_size_bytes,
        "rendered_content_sha256": content_sha256,
    }


@router.post("/{piece_id}/score_versions/{score_version_id}/open-musescore")
async def open_score_version_in_musescore(
    piece_id: str,
    score_version_id: str,
    db: AsyncSession = Depends(get_db),
):
    """Open a MusicXML/MXL score version in the configured MuseScore app."""
    score_version, file_path = await _load_existing_score_version_file(
        db,
        piece_id=piece_id,
        score_version_id=score_version_id,
    )
    if file_path.suffix.lower() not in _MUSICXML_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail="Only MusicXML/MXL score versions can be opened in MuseScore.",
        )

    processing_settings = ProcessingSettingsStore().load()
    status = executable_status(
        name="MuseScore",
        configured_path=processing_settings.get("musescore_cli_path"),
        fallback_names=("musescore", "mscore", "MuseScore4"),
    )
    if not status.discovered_path:
        raise HTTPException(
            status_code=409,
            detail="MuseScore is not configured or discoverable on the server.",
        )

    try:
        subprocess.Popen(
            [status.discovered_path, str(file_path)],
            cwd=str(file_path.parent),
        )
    except OSError as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Unable to open MuseScore: {exc}",
        ) from exc

    return {
        "status": "opened",
        "piece_id": piece_id,
        "score_version_id": score_version.id,
        "file_path": str(file_path),
        "musescore_path": status.discovered_path,
    }


@router.post("/{piece_id}/score_versions/{score_version_id}/edited-candidate")
async def upload_edited_score_version_candidate(
    piece_id: str,
    score_version_id: str,
    rendered_score_version_id: str = Form(...),
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
):
    """Accept a parent-edited MusicXML/MXL candidate and rerender the review PDF."""
    canonical_version, canonical_path = await _load_existing_score_version_file(
        db,
        piece_id=piece_id,
        score_version_id=score_version_id,
    )
    if canonical_path.suffix.lower() not in _MUSICXML_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail="Only MusicXML/MXL score versions can be replaced with an edited candidate.",
        )

    upload_name = file.filename or "edited_candidate.musicxml"
    upload_suffix = Path(upload_name).suffix.lower()
    if upload_suffix not in _MUSICXML_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail="Edited candidate must be a MusicXML, XML, or MXL file.",
        )
    file_bytes = await file.read()
    if not file_bytes:
        raise HTTPException(status_code=400, detail="Edited candidate file was empty.")

    rendered_version, rendered_path = await _load_existing_score_version_file(
        db,
        piece_id=piece_id,
        score_version_id=rendered_score_version_id,
        require_exists=False,
    )
    if rendered_path.suffix.lower() != ".pdf":
        raise HTTPException(
            status_code=400,
            detail="Rendered score version must be a PDF.",
        )

    try:
        baseline_path = ensure_omr_baseline_copy(
            piece_id=piece_id,
            canonical_score_version=canonical_version,
            piece_state_service=_piece_state_service,
        )
    except TrainingCatalogError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc

    if canonical_path.suffix.lower() == upload_suffix or upload_suffix in {
        ".musicxml",
        ".xml",
    }:
        target_path = canonical_path
    else:
        target_path = canonical_path.with_name(f"candidate_edited{upload_suffix}")
        canonical_version.file_path = str(target_path)
    target_path.write_bytes(file_bytes)
    await db.commit()

    response = await _render_score_version_for_review(
        db,
        piece_id=piece_id,
        canonical_version=canonical_version,
        canonical_path=target_path,
        rendered_version=rendered_version,
        rendered_path=rendered_path,
    )
    edited_at = datetime.utcnow().isoformat()
    await _mark_review_human_edited(
        db,
        piece_id=piece_id,
        canonical_score_version_id=canonical_version.id,
        rendered_score_version_id=rendered_version.id,
        uploaded_file_name=upload_name,
        baseline_path=baseline_path,
        edited_at=edited_at,
    )
    response["uploaded_file_name"] = upload_name
    response["canonical_file_path"] = str(target_path)
    response["omr_baseline_file_path"] = str(baseline_path)
    response["human_edited_at"] = edited_at
    return response


@router.post("/{piece_id}/score_versions/{score_version_id}/rerender")
async def rerender_score_version(
    piece_id: str,
    score_version_id: str,
    body: ScoreVersionRerenderRequest,
    db: AsyncSession = Depends(get_db),
):
    """Render a saved MusicXML/MXL edit back to the review PDF."""
    canonical_version, canonical_path = await _load_existing_score_version_file(
        db,
        piece_id=piece_id,
        score_version_id=score_version_id,
    )
    if canonical_path.suffix.lower() not in _MUSICXML_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail="Only MusicXML/MXL score versions can be rendered by MuseScore.",
        )
    rendered_version, rendered_path = await _load_existing_score_version_file(
        db,
        piece_id=piece_id,
        score_version_id=body.rendered_score_version_id,
        require_exists=False,
    )
    if rendered_path.suffix.lower() != ".pdf":
        raise HTTPException(
            status_code=400,
            detail="Rendered score version must be a PDF.",
        )

    return await _render_score_version_for_review(
        db,
        piece_id=piece_id,
        canonical_version=canonical_version,
        canonical_path=canonical_path,
        rendered_version=rendered_version,
        rendered_path=rendered_path,
    )


@router.patch("/{piece_id}")
async def update_piece(
    piece_id: str,
    body: PieceUpdate,
    db: AsyncSession = Depends(get_db),
):
    """Update piece metadata."""
    piece = await db.get(Piece, piece_id)
    if not piece:
        raise HTTPException(status_code=404, detail="Piece not found")

    update_data = body.model_dump(exclude_unset=True)
    if "title" in update_data:
        title_value = update_data["title"]
        if not isinstance(title_value, str) or not title_value.strip():
            raise HTTPException(status_code=400, detail="Title cannot be blank.")
        piece.title = title_value.strip()
    for field in ("composer", "key_signature", "tempo", "difficulty_level"):
        if field in update_data:
            value = update_data[field]
            if isinstance(value, str):
                value = value.strip() or None
            setattr(piece, field, value)
    piece.updated_at = datetime.utcnow()

    await db.commit()
    await db.refresh(piece)
    metadata = _piece_state_service.metadata_for_piece(piece)
    primary_instrument = (
        _clean_optional_string(body.primary_instrument)
        if "primary_instrument" in body.model_fields_set
        else metadata["primary_instrument"]
    )
    book_or_collection = (
        _clean_optional_string(body.book_or_collection)
        if "book_or_collection" in body.model_fields_set
        else metadata["book_or_collection"]
    )
    notes = (
        _clean_optional_string(body.notes)
        if "notes" in body.model_fields_set
        else metadata["notes"]
    )
    source_book_id = (
        body.source_book_id
        if "source_book_id" in body.model_fields_set
        else metadata["source_book_id"]
    )
    source_page_start = (
        body.source_page_start
        if "source_page_start" in body.model_fields_set
        else metadata["source_page_start"]
    )
    source_page_end = (
        body.source_page_end
        if "source_page_end" in body.model_fields_set
        else metadata["source_page_end"]
    )
    catalog_metadata = _updated_catalog_metadata(
        previous=metadata["catalog_metadata"],
        explicit=body.catalog_metadata if "catalog_metadata" in body.model_fields_set else None,
        piece=piece,
        primary_instrument=primary_instrument,
        book_or_collection=book_or_collection,
        source_page_start=source_page_start,
        source_page_end=source_page_end,
        notes=notes,
    )
    updated_state = _piece_state_service.upsert_metadata(
        piece.id,
        title=piece.title,
        composer=piece.composer,
        primary_instrument=primary_instrument,
        book_or_collection=book_or_collection,
        visible_to_profile_ids=metadata["visible_to_profile_ids"],
        processed_metadata=metadata["processed_metadata"],
        piece_kind=body.piece_kind.value if body.piece_kind is not None else metadata["piece_kind"],
        source_book_id=source_book_id,
        source_page_start=source_page_start,
        source_page_end=source_page_end,
        catalog_metadata=catalog_metadata,
        catalog_suggestions=body.catalog_suggestions
        if body.catalog_suggestions is not None
        else metadata["catalog_suggestions"],
        validation_warnings=body.validation_warnings
        if body.validation_warnings is not None
        else metadata["validation_warnings"],
        split_confidence=metadata["split_confidence"],
        notes=notes,
    )
    for field_name, value in (
        ("notes", notes),
        ("source_book_id", source_book_id),
        ("source_page_start", source_page_start),
        ("source_page_end", source_page_end),
    ):
        if field_name in body.model_fields_set:
            updated_state[field_name] = value
    if any(
        field_name in body.model_fields_set
        for field_name in (
            "notes",
            "source_book_id",
            "source_page_start",
            "source_page_end",
        )
    ):
        _piece_state_service.save(piece.id, updated_state)
    await _sync_pending_review_metadata(
        db,
        piece_id=piece.id,
        catalog_metadata=catalog_metadata,
    )
    try:
        await _refresh_pending_candidate_outputs_for_piece(
            db,
            piece=piece,
            catalog_metadata=catalog_metadata,
        )
    except ProcessingEngineError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    await db.commit()
    await db.refresh(piece)
    return _piece_to_response(piece)


async def _resume_existing_book_import(
    db: AsyncSession,
    *,
    existing_book: Piece,
    source_hash: str,
    source_file_name: str,
    file_bytes: bytes,
    split_hints: list[BookSplitHint],
    primary_instrument: str | None,
    book_or_collection: str | None,
):
    """Resume an exact book reimport without duplicating existing child pieces."""
    existing_metadata = _piece_state_service.metadata_for_piece(existing_book)
    book_fingerprint = existing_metadata["source_book_fingerprint"] or source_book_fingerprint(
        source_hash
    )
    book_title = (
        book_or_collection or existing_metadata["book_or_collection"] or existing_book.title
    )
    _piece_state_service.update_identity(
        existing_book.id,
        source_content_sha256=source_hash,
        source_book_fingerprint=book_fingerprint,
        logical_piece_key=f"book|{book_fingerprint}" if book_fingerprint else None,
        canonical_piece_id=existing_book.id,
        attempt_status="canonical",
    )

    created_children = 0
    for split_hint in split_hints:
        child_primary_instrument = (
            split_hint.primary_instrument
            or primary_instrument
            or existing_metadata["primary_instrument"]
        )
        child_key = logical_piece_key(
            source_book_fingerprint=book_fingerprint,
            book_or_collection=book_title,
            source_page_start=split_hint.page_start,
            source_page_end=split_hint.page_end,
            title=split_hint.title,
            composer=split_hint.composer or existing_book.composer,
            primary_instrument=child_primary_instrument,
        )
        if await find_active_piece_by_logical_key(db, child_key):
            continue

        child_bytes = _extract_pdf_page_range(
            file_bytes,
            start_page=split_hint.page_start,
            end_page=split_hint.page_end,
        )
        child_artifact = await ScoreProcessingService().create_book_child_proposal(
            db,
            title=split_hint.title,
            composer=split_hint.composer or existing_book.composer,
            file_name=_child_file_name(source_file_name, split_hint),
            file_bytes=child_bytes,
            source_book_id=existing_book.id,
            source_page_start=split_hint.page_start,
            source_page_end=split_hint.page_end,
            split_confidence=split_hint.confidence,
            validation_warnings=split_hint.validation_warnings,
            primary_instrument=child_primary_instrument,
            contained_piece_titles=split_hint.contained_piece_titles,
            multi_piece_page=split_hint.multi_piece_page,
        )
        processed_metadata = _processed_metadata_from_artifacts(child_artifact)
        child_catalog_metadata = _catalog_metadata_from_split_hint(
            split_hint,
            book_title=book_title,
            file_name=source_file_name,
        )
        if child_primary_instrument:
            child_catalog_metadata["primary_instrument"] = child_primary_instrument
            processed_metadata["primary_instrument"] = child_primary_instrument
        suggestions = _catalog_suggestions_from_metadata(
            child_catalog_metadata,
            source="book_split_hint",
            confidence=split_hint.confidence,
        )
        _piece_state_service.upsert_metadata(
            child_artifact.piece.id,
            title=child_artifact.piece.title,
            composer=child_artifact.piece.composer,
            primary_instrument=child_primary_instrument,
            book_or_collection=book_title,
            processed_metadata=processed_metadata,
            piece_kind="piece",
            source_book_id=existing_book.id,
            source_page_start=split_hint.page_start,
            source_page_end=split_hint.page_end,
            catalog_metadata=child_catalog_metadata,
            catalog_suggestions=suggestions,
            validation_warnings=split_hint.validation_warnings,
            split_confidence=split_hint.confidence,
            visible_to_profile_ids=[],
        )
        _piece_state_service.update_identity(
            child_artifact.piece.id,
            source_content_sha256=sha256_bytes(child_bytes),
            source_book_fingerprint=book_fingerprint,
            logical_piece_key=child_key,
            canonical_piece_id=child_artifact.piece.id,
            attempt_status="canonical",
        )
        if child_artifact.review_item:
            candidate_data = dict(child_artifact.review_item.candidate_data or {})
            candidate_data.update(
                {
                    "catalog_metadata": child_catalog_metadata,
                    "catalog_suggestions": suggestions,
                    "source_book_id": existing_book.id,
                    "source_page_start": split_hint.page_start,
                    "source_page_end": split_hint.page_end,
                    "source_book_fingerprint": book_fingerprint,
                    "logical_piece_key": child_key,
                    "split_confidence": split_hint.confidence,
                    "contained_piece_titles": split_hint.contained_piece_titles,
                    "multi_piece_page": split_hint.multi_piece_page,
                    "validation_warnings": split_hint.validation_warnings,
                }
            )
            child_artifact.review_item.candidate_data = candidate_data
        created_children += 1

    if created_children:
        existing_book.updated_at = datetime.utcnow()
    await db.commit()
    await db.refresh(existing_book)
    return _piece_to_response(existing_book)


async def _import_book_piece(
    db: AsyncSession,
    *,
    title: str,
    composer: str | None,
    primary_instrument: str | None,
    book_or_collection: str | None,
    file_name: str,
    file_bytes: bytes,
    source_hash: str,
    split_hints: list[BookSplitHint],
    allow_title_override: bool = False,
    allow_composer_override: bool = False,
):
    if not split_hints:
        try:
            artifacts = await ScoreProcessingService().create_queued_book_import(
                db,
                title=title,
                composer=composer,
                file_name=file_name,
                file_bytes=file_bytes,
                source_hash=source_hash,
                split_hints=split_hints,
                primary_instrument=primary_instrument,
                book_or_collection=book_or_collection,
                allow_title_override=allow_title_override,
                allow_composer_override=allow_composer_override,
            )
        except ProcessingEngineError as exc:
            raise HTTPException(status_code=409, detail=str(exc)) from exc
        return _piece_to_response(artifacts.book_piece)

    try:
        artifacts = await ScoreProcessingService().import_book_pdf(
            db,
            title=title,
            composer=composer,
            file_name=file_name,
            file_bytes=file_bytes,
            split_hints=split_hints,
            allow_title_override=allow_title_override,
            allow_composer_override=allow_composer_override,
        )
    except ProcessingEngineError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    book_catalog_metadata = {
        "title": artifacts.book_piece.title,
        "composer": artifacts.book_piece.composer,
        "primary_instrument": primary_instrument,
        "book_or_collection": book_or_collection or artifacts.book_piece.title,
        "source_file_name": file_name,
        **artifacts.ocr_metadata,
    }
    book_processed_metadata = dict(artifacts.ocr_metadata)
    if artifacts.preprocessing_result is not None:
        book_processed_metadata["book_preprocessing"] = artifacts.preprocessing_result.to_dict()
        book_catalog_metadata.update(artifacts.preprocessing_result.book_metadata)
    book_primary_instrument = primary_instrument or _metadata_string(
        book_catalog_metadata, "primary_instrument"
    )
    book_fingerprint = source_book_fingerprint(source_hash)
    _piece_state_service.upsert_metadata(
        artifacts.book_piece.id,
        title=artifacts.book_piece.title,
        composer=artifacts.book_piece.composer,
        primary_instrument=book_primary_instrument,
        book_or_collection=book_or_collection or artifacts.book_piece.title,
        piece_kind="book",
        processed_metadata=book_processed_metadata,
        catalog_metadata=book_catalog_metadata,
        catalog_suggestions=artifacts.ocr_catalog_suggestions,
        validation_warnings=artifacts.validation_warnings,
        visible_to_profile_ids=[],
    )
    _piece_state_service.update_identity(
        artifacts.book_piece.id,
        source_content_sha256=source_hash,
        source_book_fingerprint=book_fingerprint,
        logical_piece_key=f"book|{book_fingerprint}" if book_fingerprint else None,
        canonical_piece_id=artifacts.book_piece.id,
        attempt_status="canonical",
    )

    for child_artifact, split_hint in zip(
        artifacts.child_artifacts,
        artifacts.child_split_hints,
    ):
        processed_metadata = _processed_metadata_from_artifacts(child_artifact)
        child_catalog_metadata = _catalog_metadata_from_split_hint(
            split_hint,
            book_title=book_or_collection or artifacts.book_piece.title,
            file_name=file_name,
        )
        child_primary_instrument = (
            split_hint.primary_instrument
            or book_primary_instrument
            or _metadata_string(processed_metadata, "primary_instrument")
        )
        if child_primary_instrument:
            child_catalog_metadata["primary_instrument"] = child_primary_instrument
            processed_metadata["primary_instrument"] = child_primary_instrument
        child_key = logical_piece_key(
            source_book_fingerprint=book_fingerprint,
            book_or_collection=book_or_collection or artifacts.book_piece.title,
            source_page_start=split_hint.page_start,
            source_page_end=split_hint.page_end,
            title=child_artifact.piece.title,
            composer=child_artifact.piece.composer,
            primary_instrument=child_primary_instrument,
        )
        child_source_hash = _score_version_hash(child_artifact.raw_score_version)
        suggestions = _catalog_suggestions_from_metadata(
            child_catalog_metadata,
            source="book_split_hint",
            confidence=split_hint.confidence,
        )
        suggestions += child_artifact.ocr_catalog_suggestions
        suggestions += _catalog_suggestions_from_metadata(
            child_artifact.musicxml_metadata,
            source="musicxml_processing",
        )
        _piece_state_service.upsert_metadata(
            child_artifact.piece.id,
            title=child_artifact.piece.title,
            composer=child_artifact.piece.composer,
            primary_instrument=child_primary_instrument,
            book_or_collection=book_or_collection or artifacts.book_piece.title,
            processed_metadata=processed_metadata,
            piece_kind="piece",
            source_book_id=artifacts.book_piece.id,
            source_page_start=split_hint.page_start,
            source_page_end=split_hint.page_end,
            catalog_metadata=child_catalog_metadata,
            catalog_suggestions=suggestions,
            validation_warnings=split_hint.validation_warnings,
            split_confidence=split_hint.confidence,
            visible_to_profile_ids=[],
        )
        _piece_state_service.update_identity(
            child_artifact.piece.id,
            source_content_sha256=child_source_hash,
            source_book_fingerprint=book_fingerprint,
            logical_piece_key=child_key,
            canonical_piece_id=child_artifact.piece.id,
            attempt_status="canonical",
        )
        if child_artifact.review_item:
            candidate_data = dict(child_artifact.review_item.candidate_data or {})
            candidate_data.update(
                {
                    "catalog_metadata": child_catalog_metadata,
                    "catalog_suggestions": suggestions,
                    "source_book_id": artifacts.book_piece.id,
                    "source_book_fingerprint": book_fingerprint,
                    "logical_piece_key": child_key,
                    "source_page_start": split_hint.page_start,
                    "source_page_end": split_hint.page_end,
                    "split_confidence": split_hint.confidence,
                    "contained_piece_titles": split_hint.contained_piece_titles,
                    "multi_piece_page": split_hint.multi_piece_page,
                    "validation_warnings": split_hint.validation_warnings,
                }
            )
            child_artifact.review_item.candidate_data = candidate_data

    await db.commit()
    await db.refresh(artifacts.book_piece)
    return _piece_to_response(artifacts.book_piece)


def _processed_metadata_from_artifacts(artifacts) -> dict:
    if artifacts.review_item and artifacts.review_item.candidate_data:
        processed_metadata = artifacts.review_item.candidate_data.get("processed_metadata")
        if isinstance(processed_metadata, dict):
            return processed_metadata
    if artifacts.job.result_data:
        processed_metadata = artifacts.job.result_data.get("processed_metadata")
        if isinstance(processed_metadata, dict):
            return processed_metadata
    return {}


def _score_version_hash(score_version: ScoreVersion) -> str | None:
    file_path = Path(score_version.file_path)
    if not file_path.exists():
        return None
    try:
        return hashlib.sha256(file_path.read_bytes()).hexdigest()
    except OSError:
        return None


async def _sync_pending_review_metadata(
    db: AsyncSession,
    *,
    piece_id: str,
    catalog_metadata: dict,
) -> None:
    result = await db.execute(
        select(ReviewItem).where(
            ReviewItem.piece_id == piece_id,
            ReviewItem.status == "pending",
        )
    )
    changed = False
    for item in result.scalars().all():
        candidate_data = dict(item.candidate_data or {})
        candidate_data["piece_title"] = catalog_metadata.get("title") or item.title
        candidate_data["catalog_metadata"] = catalog_metadata
        existing_suggestions = candidate_data.get("catalog_suggestions")
        if not isinstance(existing_suggestions, list):
            candidate_data["catalog_suggestions"] = []
        item.candidate_data = candidate_data
        changed = True
    if changed:
        await db.commit()


async def _refresh_pending_candidate_outputs_for_piece(
    db: AsyncSession,
    *,
    piece: Piece,
    catalog_metadata: dict,
) -> None:
    result = await db.execute(
        select(ReviewItem).where(
            ReviewItem.piece_id == piece.id,
            ReviewItem.status == "pending",
        )
    )
    for item in result.scalars().all():
        candidate_data = dict(item.candidate_data or {})
        canonical_id = candidate_data.get("canonical_score_version_id")
        rendered_id = candidate_data.get("score_version_id")
        raw_id = candidate_data.get("raw_score_version_id")
        if not canonical_id or not rendered_id or not raw_id:
            continue

        canonical_version = await db.get(ScoreVersion, canonical_id)
        rendered_version = await db.get(ScoreVersion, rendered_id)
        raw_version = await db.get(ScoreVersion, raw_id)
        if not canonical_version or not rendered_version or not raw_version:
            continue

        canonical_path = Path(canonical_version.file_path)
        raw_path = Path(raw_version.file_path)
        rendered_path = Path(rendered_version.file_path)
        if not canonical_path.exists() or not raw_path.exists():
            continue

        current_state = _piece_state_service.metadata_for_piece(piece)
        title = str(catalog_metadata.get("title") or piece.title)
        composer = catalog_metadata.get("composer") or piece.composer
        primary_instrument = (
            catalog_metadata.get("primary_instrument") or current_state["primary_instrument"]
        )
        contained_piece_titles = (
            candidate_data.get("contained_piece_titles")
            or catalog_metadata.get("contained_piece_titles")
            or [title]
        )
        multi_piece_page = bool(
            candidate_data.get("multi_piece_page") or catalog_metadata.get("multi_piece_page")
        )

        normalized_path = _normalize_musicxml_metadata(
            canonical_path,
            output_path=canonical_path,
            title=title,
            composer=composer,
            primary_instrument=primary_instrument,
            contained_piece_titles=contained_piece_titles,
            multi_piece_page=multi_piece_page,
        )
        musicxml_metadata = _validate_musicxml(normalized_path)
        render_result = MuseScoreRenderEngine().render(
            canonical_path=normalized_path,
            raw_pdf_path=raw_path,
            output_pdf_path=rendered_path,
            processing_settings=ProcessingSettingsStore().load(),
        )
        _repair_multi_piece_review_pdf_titles(
            render_result,
            contained_piece_titles=[
                title for title in contained_piece_titles if isinstance(title, str)
            ],
            multi_piece_page=multi_piece_page,
        )

        processed_metadata = dict(candidate_data.get("processed_metadata") or {})
        processed_metadata.update(
            {key: value for key, value in musicxml_metadata.items() if value not in (None, "", [])}
        )
        if primary_instrument:
            processed_metadata["primary_instrument"] = primary_instrument
        candidate_data["processed_metadata"] = processed_metadata
        candidate_data["renderer_name"] = render_result.renderer_name
        candidate_data["renderer_version"] = render_result.renderer_version
        candidate_data["renderer_provenance"] = render_result.provenance
        candidate_data["render_validation_status"] = render_result.validation_status
        candidate_data["render_validation_error"] = render_result.validation_error
        candidate_data["rendered_file_size_bytes"] = render_result.file_size_bytes
        candidate_data["rendered_page_count"] = render_result.page_count
        candidate_data["render_diagnostics"] = render_result.diagnostics
        candidate_data["metadata_rerendered_at"] = datetime.utcnow().isoformat()
        if render_result.warnings:
            candidate_data["warnings"] = sorted(
                set(list(candidate_data.get("warnings") or []) + render_result.warnings)
            )
        item.candidate_data = candidate_data


def _metadata_string(metadata: dict, key: str) -> str | None:
    value = metadata.get(key)
    if isinstance(value, str) and value.strip():
        return value.strip()
    return None


def _metadata_int(metadata: dict, key: str) -> int | None:
    value = metadata.get(key)
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, str):
        try:
            return int(value.strip())
        except ValueError:
            return None
    return None


def _resolve_import_title(title: str | None, file_name: str) -> tuple[str, str]:
    cleaned_title = " ".join((title or "").split())
    if cleaned_title and not _is_generic_import_title(cleaned_title):
        return cleaned_title, "import_form"
    metadata = _filename_metadata_from_name(file_name)
    return metadata["title"], "filename_heuristic"


def _resolve_import_composer(composer: str | None, file_name: str) -> tuple[str | None, str]:
    cleaned_composer = " ".join((composer or "").split())
    if cleaned_composer:
        return cleaned_composer, "import_form"
    metadata = _filename_metadata_from_name(file_name)
    if metadata["composer"]:
        return metadata["composer"], "filename_heuristic"
    return None, "unknown"


def _is_generic_import_title(title: str) -> bool:
    normalized = " ".join(
        "".join(char.lower() if char.isalnum() else " " for char in title).split()
    )
    return normalized in {
        "",
        "imported score",
        "untitled",
        "untitled score",
        "unknown",
        "unknown score",
        "score",
        "new score",
    }


def _title_from_file_name(file_name: str) -> str:
    stem = Path(file_name).stem.strip()
    title = " ".join(stem.replace("_", " ").replace("-", " ").split())
    return title or "Imported score"


def _filename_metadata_from_name(file_name: str) -> dict[str, str | None]:
    stem = " ".join(Path(file_name).stem.replace("_", " ").split())
    by_parts = stem.lower().rpartition(" by ")
    if by_parts[1]:
        title = stem[: len(by_parts[0])].strip()
        composer = stem[len(by_parts[0]) + len(by_parts[1]) :].strip()
        if title and composer:
            return {"title": title, "composer": composer}

    parts = [part.strip() for part in stem.split(" - ") if part.strip()]
    if len(parts) == 2:
        left, right = parts
        if _looks_like_composer_name(left) and not _looks_like_composer_name(right):
            return {"title": right, "composer": left}
        if _looks_like_composer_name(right):
            return {"title": left, "composer": right}

    return {"title": _title_from_file_name(file_name), "composer": None}


def _looks_like_composer_name(value: str) -> bool:
    normalized = " ".join(
        "".join(char.lower() if char.isalnum() else " " for char in value).split()
    )
    if not normalized:
        return False
    known_surnames = {
        "bach",
        "bartok",
        "beethoven",
        "brahms",
        "burgmuller",
        "chopin",
        "corelli",
        "czerny",
        "debussy",
        "dvorak",
        "grieg",
        "handel",
        "haydn",
        "kabalevsky",
        "liszt",
        "mahler",
        "mendelssohn",
        "mozart",
        "pachelbel",
        "prokofiev",
        "purcell",
        "rachmaninoff",
        "saint",
        "saens",
        "scarlatti",
        "schubert",
        "schumann",
        "stravinsky",
        "suzuki",
        "tchaikovsky",
        "telemann",
        "vivaldi",
    }
    return bool(set(normalized.split()) & known_surnames)


def _filename_catalog_suggestions(
    *,
    title: str,
    composer: str | None,
    file_name: str,
    enabled: bool,
) -> list[dict]:
    if not enabled:
        return []
    return [
        {
            "source": "filename_heuristic",
            "confidence": 0.35,
            "fields": {
                key: value
                for key, value in {
                    "title": title,
                    "composer": composer,
                    "source_file_name": file_name,
                }.items()
                if value not in (None, "")
            },
        }
    ]


def _parse_split_hints(split_hints: str | None) -> list[BookSplitHint]:
    if not split_hints:
        return []
    try:
        payload = json.loads(split_hints)
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=400, detail="split_hints must be valid JSON.") from exc
    if not isinstance(payload, list):
        raise HTTPException(status_code=400, detail="split_hints must be a JSON list.")
    try:
        return [BookSplitHint.model_validate(item) for item in payload]
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=exc.errors()) from exc


def _should_auto_import_as_book(
    *,
    file_name: str,
    title: str,
    book_or_collection: str | None,
    file_bytes: bytes,
) -> bool:
    """Conservatively route obvious books away from full-PDF OMR."""

    normalized_text = _normalize_for_book_detection(
        " ".join(value for value in (file_name, title, book_or_collection or "") if value)
    )
    padded_text = f" {normalized_text} "
    if any(
        keyword in normalized_text if " " in keyword else f" {keyword} " in padded_text
        for keyword in _BOOK_IMPORT_KEYWORDS
    ):
        return True

    page_count = _pdf_page_count(file_bytes)
    return page_count is not None and page_count >= _AUTO_BOOK_IMPORT_PAGE_THRESHOLD


def _pdf_page_count(file_bytes: bytes) -> int | None:
    try:
        from pypdf import PdfReader

        return len(PdfReader(BytesIO(file_bytes)).pages)
    except Exception:
        return None


def _normalize_for_book_detection(value: str) -> str:
    return " ".join("".join(char.lower() if char.isalnum() else " " for char in value).split())


def _catalog_metadata_from_piece(
    piece: Piece,
    *,
    primary_instrument: str | None,
    book_or_collection: str | None,
    notes: str | None,
) -> dict:
    return {
        key: value
        for key, value in {
            "title": piece.title,
            "composer": piece.composer,
            "primary_instrument": primary_instrument,
            "book_or_collection": book_or_collection,
            "key_signature": piece.key_signature,
            "tempo": piece.tempo,
            "notes": notes,
        }.items()
        if value not in (None, "")
    }


def _clean_optional_string(value: str | None) -> str | None:
    if value is None:
        return None
    cleaned = " ".join(value.split())
    return cleaned or None


def _updated_catalog_metadata(
    *,
    previous: dict,
    explicit: dict | None,
    piece: Piece,
    primary_instrument: str | None,
    book_or_collection: str | None,
    source_page_start: int | None,
    source_page_end: int | None,
    notes: str | None,
) -> dict:
    metadata = dict(previous or {})
    if explicit is not None:
        metadata.update(explicit)

    canonical = {
        "title": piece.title,
        "composer": piece.composer,
        "primary_instrument": primary_instrument,
        "book_or_collection": book_or_collection,
        "key_signature": piece.key_signature,
        "tempo": piece.tempo,
        "source_page_start": source_page_start,
        "source_page_end": source_page_end,
        "notes": notes,
    }
    for key, value in canonical.items():
        if value in (None, "", []):
            metadata.pop(key, None)
        else:
            metadata[key] = value

    return {key: value for key, value in metadata.items() if value not in (None, "", [])}


def _catalog_metadata_from_split_hint(
    split_hint: BookSplitHint,
    *,
    book_title: str,
    file_name: str,
) -> dict:
    return {
        key: value
        for key, value in {
            "title": split_hint.title,
            "composer": split_hint.composer,
            "primary_instrument": split_hint.primary_instrument,
            "book_or_collection": book_title,
            "key_signature": split_hint.key_signature,
            "tempo": split_hint.tempo,
            "aliases": split_hint.aliases,
            "source_page_start": split_hint.page_start,
            "source_page_end": split_hint.page_end,
            "source_file_name": file_name,
            "contained_piece_titles": split_hint.contained_piece_titles,
            "multi_piece_page": split_hint.multi_piece_page,
        }.items()
        if value not in (None, "", [])
    }


def _catalog_suggestions_from_metadata(
    metadata: dict,
    *,
    source: str,
    confidence: float | None = None,
) -> list[dict]:
    if not metadata:
        return []
    return [
        {
            "source": source,
            "confidence": confidence,
            "fields": {
                key: value
                for key, value in metadata.items()
                if key
                in {
                    "title",
                    "composer",
                    "primary_instrument",
                    "book_or_collection",
                    "key_signature",
                    "tempo",
                    "aliases",
                    "arranger",
                    "editor",
                    "opus",
                    "catalog_number",
                    "publisher",
                    "source_page_start",
                    "source_page_end",
                    "source_file_name",
                    "contained_piece_titles",
                    "multi_piece_page",
                    "notes",
                }
                and value not in (None, "", [])
            },
        }
    ]


@router.delete("/{piece_id}")
async def delete_piece(piece_id: str, db: AsyncSession = Depends(get_db)):
    """Delete a piece and its associated data."""
    piece = await db.get(Piece, piece_id)
    if not piece:
        raise HTTPException(status_code=404, detail="Piece not found")
    await db.delete(piece)
    await db.commit()
    return {"deleted": piece_id}


@router.get("/{piece_id}/history_drafts")
async def list_history_drafts(piece_id: str, db: AsyncSession = Depends(get_db)):
    """List all history drafts for a piece."""
    piece = await db.get(Piece, piece_id)
    if not piece:
        raise HTTPException(status_code=404, detail="Piece not found")
    return [
        PieceHistoryDraftResponse(
            id=hd.id,
            piece_id=hd.piece_id,
            content=hd.content,
            status=hd.status,
            confidence=hd.confidence,
            provenance=hd.provenance,
            created_at=hd.created_at,
        )
        for hd in piece.history_drafts
    ]


@router.post("/{piece_id}/history_drafts")
async def create_history_draft(
    piece_id: str,
    body: PieceHistoryDraftCreate,
    db: AsyncSession = Depends(get_db),
):
    """Create a new history draft for a piece."""
    piece = await db.get(Piece, piece_id)
    if not piece:
        raise HTTPException(status_code=404, detail="Piece not found")

    draft = PieceHistoryDraft(
        id=str(uuid.uuid4()),
        piece_id=piece_id,
        content=body.content,
        status=body.status,
        confidence=body.confidence,
        provenance=body.provenance,
        created_at=datetime.utcnow(),
    )
    db.add(draft)
    await db.commit()
    await db.refresh(draft)
    return PieceHistoryDraftResponse(
        id=draft.id,
        piece_id=draft.piece_id,
        content=draft.content,
        status=draft.status,
        confidence=draft.confidence,
        provenance=draft.provenance,
        created_at=draft.created_at,
    )


@router.get("/{piece_id}/history_drafts/{draft_id}")
async def get_history_draft(
    piece_id: str,
    draft_id: str,
    db: AsyncSession = Depends(get_db),
):
    """Get a specific history draft."""
    result = await db.execute(
        select(PieceHistoryDraft).where(
            PieceHistoryDraft.id == draft_id,
            PieceHistoryDraft.piece_id == piece_id,
        )
    )
    draft = result.scalar_one_or_none()
    if not draft:
        raise HTTPException(status_code=404, detail="History draft not found")
    return PieceHistoryDraftResponse(
        id=draft.id,
        piece_id=draft.piece_id,
        content=draft.content,
        status=draft.status,
        confidence=draft.confidence,
        provenance=draft.provenance,
        created_at=draft.created_at,
    )


@router.delete("/{piece_id}/history_drafts/{draft_id}")
async def delete_history_draft(
    piece_id: str,
    draft_id: str,
    db: AsyncSession = Depends(get_db),
):
    """Delete a history draft."""
    result = await db.execute(
        select(PieceHistoryDraft).where(
            PieceHistoryDraft.id == draft_id,
            PieceHistoryDraft.piece_id == piece_id,
        )
    )
    draft = result.scalar_one_or_none()
    if not draft:
        raise HTTPException(status_code=404, detail="History draft not found")
    await db.delete(draft)
    await db.commit()
    return {"deleted": draft_id}


@router.post("/{piece_id}/media")
async def upload_media(
    piece_id: str,
    file: UploadFile = File(...),
    asset_type: str = "image",
    db: AsyncSession = Depends(get_db),
):
    """Upload a media file (image, scan, audio) for a piece."""
    piece = await db.get(Piece, piece_id)
    if not piece:
        raise HTTPException(status_code=404, detail="Piece not found")

    valid_types = {"image", "scan", "audio"}
    if asset_type not in valid_types:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid asset_type. Must be one of: {', '.join(sorted(valid_types))}",
        )

    file_ext = Path(file.filename).suffix if file.filename else ".bin"
    asset_id = str(uuid.uuid4())
    media_dir = settings.storage_path / "media" / piece_id
    media_dir.mkdir(parents=True, exist_ok=True)
    file_path = media_dir / f"{asset_id}{file_ext}"

    content = await file.read()
    file_path.write_bytes(content)

    media_asset = MediaAsset(
        id=asset_id,
        piece_id=piece_id,
        asset_type=asset_type,
        file_path=str(file_path),
        status="approved",
        created_at=datetime.utcnow(),
    )
    db.add(media_asset)
    await db.commit()
    await db.refresh(media_asset)

    return MediaAssetResponse(
        id=media_asset.id,
        piece_id=media_asset.piece_id,
        asset_type=media_asset.asset_type,
        file_path=media_asset.file_path,
        status=media_asset.status,
        created_at=media_asset.created_at,
    )

"""Router for piece import, listing, metadata management, and score file access."""

import uuid
from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import FileResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from server.config import settings
from server.database import get_db
from server.models.orm import MediaAsset, Piece, PieceHistoryDraft, PieceStatus, ScoreVersion
from server.models.schemas import (
    MediaAssetResponse,
    PieceCreate,
    PieceDetailResponse,
    PieceHistoryDraftCreate,
    PieceHistoryDraftResponse,
    PiecePushRequest,
    PieceResponse,
    PieceUpdate,
    ScoreVersionResponse,
)
from server.services.piece_state import PieceStateService
from server.services.score_processing import ScoreProcessingService

router = APIRouter()
_piece_state_service = PieceStateService()


def _piece_to_response(piece: Piece) -> PieceResponse:
    metadata = _piece_state_service.metadata_for_piece(piece)
    return PieceResponse(
        id=piece.id,
        title=piece.title,
        composer=piece.composer,
        primary_instrument=metadata["primary_instrument"],
        book_or_collection=metadata["book_or_collection"],
        visible_to_profile_ids=metadata["visible_to_profile_ids"],
        library_status=metadata["library_status"],
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


def _piece_to_detail_response(request: Request, piece: Piece) -> PieceDetailResponse:
    sorted_score_versions = sorted(
        piece.score_versions,
        key=lambda version: (version.is_default, version.created_at),
        reverse=True,
    )
    score_versions = [
        ScoreVersionResponse(
            id=sv.id,
            piece_id=sv.piece_id,
            version_type=sv.version_type,
            file_path=sv.file_path,
            file_url=_score_version_file_url(request, piece.id, sv.id),
            is_default=sv.is_default,
            created_at=sv.created_at,
        )
        for sv in sorted_score_versions
    ]
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
        visible_to_profile_ids=metadata["visible_to_profile_ids"],
        library_status=metadata["library_status"],
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


@router.get("/")
async def list_pieces(db: AsyncSession = Depends(get_db)):
    """List all imported pieces."""
    result = await db.execute(select(Piece).order_by(Piece.created_at.desc()))
    pieces = result.scalars().all()
    return [_piece_to_response(piece) for piece in pieces]


@router.get("/assigned/{profile_id}")
async def list_assigned_pieces(profile_id: str, db: AsyncSession = Depends(get_db)):
    """List approved pieces assigned to a specific student profile."""
    result = await db.execute(
        select(Piece)
        .where(Piece.status == PieceStatus.approved)
        .order_by(Piece.updated_at.desc())
    )
    pieces: list[PieceResponse] = []
    for piece in result.scalars().all():
        metadata = _piece_state_service.metadata_for_piece(piece)
        if profile_id not in metadata["visible_to_profile_ids"]:
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
    title: str = Form(...),
    composer: str | None = Form(None),
    primary_instrument: str | None = Form(None),
    book_or_collection: str | None = Form(None),
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
):
    """Import a raw PDF and immediately generate a deterministic review candidate."""
    file_name = file.filename or f"{title}.pdf"
    if Path(file_name).suffix.lower() != ".pdf":
        raise HTTPException(
            status_code=400,
            detail="Only PDF upload is supported for server-side processing right now.",
        )

    file_bytes = await file.read()
    if not file_bytes:
        raise HTTPException(status_code=400, detail="Uploaded file was empty.")

    artifacts = await ScoreProcessingService().import_pdf(
        db,
        title=title,
        composer=composer,
        file_name=file_name,
        file_bytes=file_bytes,
    )
    _piece_state_service.upsert_metadata(
        artifacts.piece.id,
        title=title,
        composer=composer,
        primary_instrument=primary_instrument,
        book_or_collection=book_or_collection,
        visible_to_profile_ids=[],
    )
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
    """Assign an approved piece to one or more student profiles."""
    piece = await db.get(Piece, piece_id)
    if not piece:
        raise HTTPException(status_code=404, detail="Piece not found")
    if piece.status != PieceStatus.approved:
        raise HTTPException(
            status_code=409,
            detail="Only approved pieces can be pushed to student profiles.",
        )

    _piece_state_service.assign_profiles(piece_id, body.profile_ids)
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

    media_type = "application/octet-stream"
    suffix = file_path.suffix.lower()
    if suffix == ".pdf":
        media_type = "application/pdf"
    elif suffix in {".musicxml", ".xml", ".mxl"}:
        media_type = "application/vnd.recordare.musicxml+xml"

    return FileResponse(
        path=file_path,
        media_type=media_type,
        filename=file_path.name,
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
    for field, value in update_data.items():
        if hasattr(piece, field):
            setattr(piece, field, value)

    await db.commit()
    await db.refresh(piece)
    metadata = _piece_state_service.metadata_for_piece(piece)
    _piece_state_service.upsert_metadata(
        piece.id,
        title=piece.title,
        composer=piece.composer,
        primary_instrument=body.primary_instrument
        if body.primary_instrument is not None
        else metadata["primary_instrument"],
        book_or_collection=body.book_or_collection
        if body.book_or_collection is not None
        else metadata["book_or_collection"],
        visible_to_profile_ids=metadata["visible_to_profile_ids"],
    )
    return _piece_to_response(piece)


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

"""Router for YouTube reference media management and sync delta delivery."""

from __future__ import annotations

import hashlib
import logging
from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from server.database import get_db
from server.models.orm import MediaAsset, Piece
from server.models.schemas import (
    MediaCandidateResponse,
    MediaPushRequest,
    MediaRevokeResponse,
    MediaSyncItem,
    MediaSyncPayload,
)
from server.services.media_downloader import download_approved_audio

logger = logging.getLogger(__name__)

router = APIRouter()


def _media_file_url(piece_id: str, asset_id: str) -> str:
    """Build the download URL for a media file."""
    return f"/api/v1/media/{piece_id}/{asset_id}/file"


def _media_download_metadata(file_path: Path) -> tuple[str | None, int | None, str | None]:
    """Extract content type, size, and SHA-256 from a local media file."""
    if not file_path.exists():
        return "audio/mpeg", None, None

    suffix = file_path.suffix.lower()
    if suffix == ".mp3":
        content_type = "audio/mpeg"
    elif suffix in {".m4a", ".aac"}:
        content_type = "audio/mp4"
    else:
        content_type = "application/octet-stream"

    try:
        file_size = file_path.stat().st_size
        content_sha256 = hashlib.sha256(file_path.read_bytes()).hexdigest()
    except OSError:
        file_size = None
        content_sha256 = None

    return content_type, file_size, content_sha256


def _candidate_to_response(asset: MediaAsset) -> MediaCandidateResponse:
    """Convert a MediaAsset (youtube_candidate) to a parent-dashboard response."""
    video_id = asset.youtube_video_id or "unknown"
    title = f"Reference: {video_id}"
    return MediaCandidateResponse(
        id=asset.id,
        piece_id=asset.piece_id,
        youtube_video_id=video_id,
        title=title,
        thumbnail_url=asset.thumbnail_url,
        is_approved=asset.is_approved,
        pushed_at=asset.pushed_at,
        updated_at=asset.updated_at,
    )


@router.get("/pieces/{piece_id}/candidates")
async def list_media_candidates(
    piece_id: str,
    db: AsyncSession = Depends(get_db),
) -> list[MediaCandidateResponse]:
    """List unapproved YouTube reference candidates for a piece (parent dashboard)."""
    # Verify the piece exists
    result = await db.execute(select(Piece).where(Piece.id == piece_id))
    piece = result.scalar_one_or_none()
    if not piece:
        raise HTTPException(status_code=404, detail="Piece not found")

    query = (
        select(MediaAsset)
        .where(
            MediaAsset.piece_id == piece_id,
            MediaAsset.asset_type == "youtube_candidate",
        )
        .order_by(MediaAsset.created_at.desc())
    )
    result = await db.execute(query)
    assets = result.scalars().all()

    return [_candidate_to_response(asset) for asset in assets]


@router.post("/pieces/{piece_id}/search")
async def trigger_media_search(
    piece_id: str,
    db: AsyncSession = Depends(get_db),
) -> list[MediaCandidateResponse]:
    """Trigger a YouTube reference search for a piece and return staged candidates."""
    result = await db.execute(select(Piece).where(Piece.id == piece_id))
    piece = result.scalar_one_or_none()
    if not piece:
        raise HTTPException(status_code=404, detail="Piece not found")

    from server.services.youtube_search import search_reference_media  # noqa: PLC0414

    staged = await search_reference_media(piece, db)
    return [_candidate_to_response(asset) for asset in staged]


@router.post("/media/{asset_id}/push", response_model=MediaRevokeResponse)
async def push_media_asset(
    asset_id: str,
    body: MediaPushRequest | None = None,  # noqa: ARG001 - reserved for future request body fields
    db: AsyncSession = Depends(get_db),
) -> MediaRevokeResponse:
    """Approve a media asset and trigger background download of the audio file."""
    result = await db.execute(
        select(MediaAsset).where(MediaAsset.id == asset_id)
    )
    asset = result.scalar_one_or_none()
    if not asset:
        raise HTTPException(status_code=404, detail="Media asset not found")

    # Toggle approval on
    now = datetime.utcnow()
    asset.is_approved = True
    asset.pushed_at = now
    asset.updated_at = now
    await db.commit()
    await db.refresh(asset)

    # Trigger async download in background (non-blocking)
    import asyncio  # noqa: PLC0414

    asyncio.create_task(download_approved_audio(asset_id, db))

    return MediaRevokeResponse(
        id=asset.id,
        is_approved=True,
        updated_at=now,
    )


@router.post("/media/{asset_id}/revoke", response_model=MediaRevokeResponse)
async def revoke_media_asset(
    asset_id: str,
    db: AsyncSession = Depends(get_db),
) -> MediaRevokeResponse:
    """Revoke approval for a media asset (restricts student access)."""
    result = await db.execute(
        select(MediaAsset).where(MediaAsset.id == asset_id)
    )
    asset = result.scalar_one_or_none()
    if not asset:
        raise HTTPException(status_code=404, detail="Media asset not found")

    now = datetime.utcnow()
    asset.is_approved = False
    asset.pushed_at = None
    asset.updated_at = now
    await db.commit()
    await db.refresh(asset)

    return MediaRevokeResponse(
        id=asset.id,
        is_approved=False,
        updated_at=now,
    )


@router.get("/media/{piece_id}/{asset_id}/file")
async def get_media_file(
    piece_id: str,
    asset_id: str,
    db: AsyncSession = Depends(get_db),
):
    """Serve a local media file for download (used by sync clients)."""
    from fastapi.responses import FileResponse  # noqa: PLC0414

    result = await db.execute(
        select(MediaAsset)
        .options(selectinload(MediaAsset.piece))
        .where(MediaAsset.id == asset_id, MediaAsset.piece_id == piece_id)
    )
    asset = result.scalar_one_or_none()
    if not asset:
        raise HTTPException(status_code=404, detail="Media asset not found")

    local_path = Path(asset.local_file_path or asset.file_path or "")
    if not local_path.exists():
        raise HTTPException(
            status_code=404,
            detail=f"Local media file not found: {local_path}",
        )

    content_type, _, _ = _media_download_metadata(local_path)
    return FileResponse(
        path=str(local_path),
        media_type=content_type or "application/octet-stream",
        filename=local_path.name,
    )


@router.get("/pieces/{piece_id}/sync-delta")
async def get_media_sync_delta(
    piece_id: str,
    client_last_sync: datetime = Query(..., alias="client_last_sync"),
    db: AsyncSession = Depends(get_db),
) -> MediaSyncPayload:
    """Return media sync delta for a piece since the client's last sync time.

    Returns two arrays:
    - media_attachments: approved assets with local files (for download push)
    - media_deletions: revoked asset IDs that changed after client_last_sync
      (tells client to evict and wipe local copies)
    """
    # Verify piece exists
    result = await db.execute(select(Piece).where(Piece.id == piece_id))
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Piece not found")

    media_attachments: list[MediaSyncItem] = []
    media_deletions: list[str] = []

    # Fetch all media assets for this piece updated since client_last_sync
    query = (
        select(MediaAsset)
        .where(
            MediaAsset.piece_id == piece_id,
            MediaAsset.updated_at > client_last_sync,
        )
    )
    result = await db.execute(query)
    assets = result.scalars().all()

    for asset in assets:
        if asset.asset_type != "youtube_candidate":
            continue

        local_path_str = asset.local_file_path or asset.file_path
        if asset.is_approved and local_path_str:
            # Approved with a local file → push to client
            local_path = Path(local_path_str)
            content_type, file_size, content_sha256 = _media_download_metadata(
                local_path,
            )

            download_url = _media_file_url(asset.piece_id, asset.id)
            video_id = asset.youtube_video_id or "unknown"
            media_title = f"Reference: {video_id}"

            media_attachments.append(
                MediaSyncItem(
                    id=asset.id,
                    piece_id=asset.piece_id,
                    youtube_video_id=asset.youtube_video_id,
                    title=media_title,
                    thumbnail_url=asset.thumbnail_url,
                    download_url=download_url,
                    file_size_bytes=file_size,
                    content_sha256=content_sha256,
                )
            )
        elif not asset.is_approved and asset.updated_at and asset.updated_at > client_last_sync:
            # Revoked after client's last sync → tell client to delete
            media_deletions.append(asset.id)

    return MediaSyncPayload(
        media_attachments=media_attachments,
        media_deletions=media_deletions,
    )

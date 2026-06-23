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
    import re
    import uuid

    result = await db.execute(
        select(MediaAsset).where(MediaAsset.id == asset_id)
    )
    asset = result.scalar_one_or_none()
    if not asset:
        raise HTTPException(status_code=404, detail="Media asset not found")

    # Fetch the parent piece to get title/composer for propagation
    piece_result = await db.execute(
        select(Piece).where(Piece.id == asset.piece_id)
    )
    piece = piece_result.scalar_one_or_none()

    # Toggle approval on
    now = datetime.utcnow()
    asset.is_approved = True
    asset.status = "approved"
    asset.pushed_at = now
    asset.updated_at = now

    # Propagate to any matching pieces across all student profiles
    if piece:
        def normalize(val: str | None) -> str:
            return re.sub(r"[^a-zA-Z0-9]", "", val or "").lower().strip()

        norm_title = normalize(piece.title)
        norm_composer = normalize(piece.composer)

        pieces_result = await db.execute(select(Piece))
        all_pieces = pieces_result.scalars().all()
        matching_pieces = [
            p for p in all_pieces
            if p.id != piece.id
            and normalize(p.title) == norm_title
            and normalize(p.composer) == norm_composer
        ]

        for mp in matching_pieces:
            # Check if matching piece already has this YouTube video staged or approved
            exist_res = await db.execute(
                select(MediaAsset).where(
                    MediaAsset.piece_id == mp.id,
                    MediaAsset.youtube_video_id == asset.youtube_video_id,
                )
            )
            existing_asset = exist_res.scalar_one_or_none()
            if existing_asset:
                existing_asset.is_approved = True
                existing_asset.local_file_path = asset.local_file_path
                existing_asset.file_path = asset.file_path
                existing_asset.status = "approved"
                existing_asset.pushed_at = now
                existing_asset.updated_at = now
            else:
                new_asset = MediaAsset(
                    id=str(uuid.uuid4()),
                    piece_id=mp.id,
                    asset_type=asset.asset_type,
                    file_path=asset.file_path,
                    status="approved",
                    created_at=now,
                    updated_at=now,
                    youtube_video_id=asset.youtube_video_id,
                    thumbnail_url=asset.thumbnail_url,
                    local_file_path=asset.local_file_path,
                    is_approved=True,
                    pushed_at=now,
                )
                db.add(new_asset)

    await db.commit()
    await db.refresh(asset)

    # Trigger async download in background (non-blocking)
    import asyncio  # noqa: PLC0414

    asyncio.create_task(download_approved_audio(asset.id, db))

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


@router.post("/media/retroactive-sync")
async def trigger_retroactive_media_sync(
    db: AsyncSession = Depends(get_db),
):
    """Scan the library, propagate approved media to matching pieces, and run missing searches."""
    import re
    import uuid
    from server.services.youtube_search import search_reference_media

    # 1. Fetch all pieces and all media assets
    pieces_res = await db.execute(select(Piece))
    pieces = pieces_res.scalars().all()

    assets_res = await db.execute(select(MediaAsset))
    assets = assets_res.scalars().all()

    def normalize(val: str | None) -> str:
        return re.sub(r"[^a-zA-Z0-9]", "", val or "").lower().strip()

    # Map normalized keys to lists of pieces
    groups: dict[tuple[str, str], list[Piece]] = {}
    for p in pieces:
        key = (normalize(p.title), normalize(p.composer))
        groups.setdefault(key, []).append(p)

    # 2. Propagate existing approved assets within groups
    propagated_count = 0
    now = datetime.utcnow()

    # Find approved YouTube assets
    approved_assets = [a for a in assets if a.is_approved and a.asset_type == "youtube_candidate"]

    for asset in approved_assets:
        # Find which piece this asset originally belongs to
        parent_piece = next((p for p in pieces if p.id == asset.piece_id), None)
        if not parent_piece:
            continue

        key = (normalize(parent_piece.title), normalize(parent_piece.composer))
        group_pieces = groups.get(key, [])

        for p in group_pieces:
            if p.id == asset.piece_id:
                continue

            # Check if this piece already has this YouTube asset
            exists = any(
                a.piece_id == p.id and a.youtube_video_id == asset.youtube_video_id
                for a in assets
            )
            if not exists:
                new_asset = MediaAsset(
                    id=str(uuid.uuid4()),
                    piece_id=p.id,
                    asset_type=asset.asset_type,
                    file_path=asset.file_path,
                    status="approved",
                    created_at=now,
                    updated_at=now,
                    youtube_video_id=asset.youtube_video_id,
                    thumbnail_url=asset.thumbnail_url,
                    local_file_path=asset.local_file_path,
                    is_approved=True,
                    pushed_at=now,
                )
                db.add(new_asset)
                propagated_count += 1

    await db.commit()

    # 3. Trigger searches for any piece that has no staged candidates or approved media
    # Re-fetch assets to get updated state
    updated_assets_res = await db.execute(select(MediaAsset))
    updated_assets = updated_assets_res.scalars().all()

    search_triggered_count = 0
    for p in pieces:
        has_media = any(
            a.piece_id == p.id and a.asset_type == "youtube_candidate"
            for a in updated_assets
        )
        if not has_media:
            # Trigger async search with a clean background session
            import asyncio
            asyncio.create_task(search_reference_media(p, None))
            search_triggered_count += 1

    return {
        "status": "success",
        "propagated_assets_count": propagated_count,
        "searches_triggered_count": search_triggered_count,
    }


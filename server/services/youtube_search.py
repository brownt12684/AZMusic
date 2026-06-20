"""Asynchronous YouTube reference performance search for AZMusic pieces."""

from __future__ import annotations

import logging
import os
import re
import uuid
from datetime import datetime

from googleapiclient.discovery import build
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from server.database import async_session
from server.models.orm import MediaAsset, Piece

logger = logging.getLogger(__name__)

# Keywords that indicate tutorial/clutter content to filter out
_TUTORIAL_PATTERNS = re.compile(
    r"\b(tutorial|how\s+to\s+play|synthesia|learn\s+to\s+play|"
    r"easy\s+piano|beginner|\blesson\b|play\s+along|\bsheet\s*music\s*(download|pdf)\b)"
    r"\s*$",
    re.IGNORECASE,
)

# Maximum candidates to stage per piece
_MAX_CANDIDATES = 5


def _build_search_query(piece: Piece) -> str:
    """Build a highly specific YouTube search query from piece metadata."""
    parts = []
    if piece.composer:
        parts.append(piece.composer.strip())
    if piece.title:
        parts.append(piece.title.strip())
    # Primary instrument is stored in piece state metadata, not on the Piece model directly.
    # We'll rely on composer + title for now; instrument can be added later via metadata lookup.
    query = " ".join(parts) if parts else piece.title
    return f"{query} piano performance"


def _is_low_quality(title: str) -> bool:
    """Return True if the video title looks like tutorial/clutter."""
    # Strip common YouTube suffixes first
    cleaned = re.sub(
        r"\s*\|\s*.*$", "", title
    ).strip()
    return bool(_TUTORIAL_PATTERNS.search(cleaned))


async def search_reference_media(
    piece: Piece,
    db_session: AsyncSession | None = None,
) -> list[MediaAsset]:
    """Search YouTube for reference performances and stage candidates.

    Queries the YouTube Data API v3 using piece metadata (composer, title).
    Filters out low-quality tutorial content. Stages up to _MAX_CANDIDATES
    items into media_assets with is_approved=False.

    Args:
        piece: The Piece to search reference media for.
        db_session: Optional existing async session; creates one if not provided.

    Returns:
        List of newly staged MediaAsset records.
    """
    query = _build_search_query(piece)
    logger.info("Searching YouTube for piece %s: %r", piece.id, query)

    api_key = os.environ.get("YOUTUBE_API_KEY") or os.environ.get("GOOGLE_API_KEY")
    if not api_key:
        logger.warning(
            "No YOUTUBE_API_KEY/GOOGLE_API_KEY configured; skipping YouTube search for %s",
            piece.id,
        )
        return []

    close_session = db_session is None
    try:
        if close_session:
            async with async_session() as local_db:
                return await _search_and_stage(piece, query, api_key, local_db)
        else:
            return await _search_and_stage(piece, query, api_key, db_session)
    except Exception as exc:
        logger.error("YouTube search failed for piece %s: %s", piece.id, exc, exc_info=True)
        return []


async def _search_and_stage(
    piece: Piece,
    query: str,
    api_key: str,
    db: AsyncSession,
) -> list[MediaAsset]:
    """Execute YouTube API search and stage results as MediaAssets."""
    try:
        youtube = build("youtube", "v3", developerKey=api_key)
    except Exception as exc:
        logger.error("Failed to build YouTube client: %s", exc)
        return []

    try:
        search_response = youtube.search().list(
            q=query,
            part="snippet",
            type="video",
            maxResults=_MAX_CANDIDATES,
            safeSearch="strict",
            videoEmbeddable=True,
            fields="items/snippet/videoId,title,thumbnails/default/url",
        ).execute()
    except Exception as exc:
        logger.error("YouTube API search request failed: %s", exc)
        return []

    items = search_response.get("items", [])
    staged: list[MediaAsset] = []

    # Remove existing candidates for this piece to avoid duplicates on re-run
    result = await db.execute(
        select(MediaAsset).where(
            MediaAsset.piece_id == piece.id,
            MediaAsset.asset_type == "youtube_candidate",
        )
    )
    existing = result.scalars().all()
    for ma in existing:
        await db.delete(ma)

    now = datetime.utcnow()
    for item in items[:_MAX_CANDIDATES]:
        snippet = item.get("snippet", {})
        video_id = item.get("videoId")
        title = snippet.get("title", "")
        thumbnail = snippet.get("thumbnails", {}).get("default", {}).get("url")

        if not video_id or _is_low_quality(title):
            logger.debug("Skipping low-quality candidate: %r", title)
            continue

        # Check for duplicate video IDs across all pieces
        dup_result = await db.execute(
            select(MediaAsset.id).where(
                MediaAsset.youtube_video_id == video_id,
            )
        )
        if dup_result.scalar_one_or_none():
            logger.debug("Skipping duplicate YouTube ID: %s", video_id)
            continue

        media_asset = MediaAsset(
            id=str(uuid.uuid4()),
            piece_id=piece.id,
            asset_type="youtube_candidate",
            file_path=None,
            status="staged",
            created_at=now,
            updated_at=now,
            youtube_video_id=video_id,
            thumbnail_url=thumbnail,
            local_file_path=None,
            is_approved=False,
            pushed_at=None,
        )
        db.add(media_asset)
        staged.append(media_asset)

    if staged:
        await db.commit()
        for ma in staged:
            await db.refresh(ma)
        logger.info(
            "Staged %d YouTube candidates for piece %s", len(staged), piece.id
        )

    return staged

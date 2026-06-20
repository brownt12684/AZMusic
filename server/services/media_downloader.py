"""Local audio extraction and transcoding for approved YouTube media assets."""

from __future__ import annotations

import asyncio
import hashlib
import logging
import subprocess
from datetime import datetime
from pathlib import Path

from sqlalchemy.ext.asyncio import AsyncSession

from server.config import settings
from server.models.orm import MediaAsset

logger = logging.getLogger(__name__)

# Local storage directory for downloaded media
_MEDIA_DIR_NAME = "media"

# yt-dlp output template: filename with video ID to avoid collisions
_YTDLP_OUTPUT_TEMPLATE = "%(id)s.%(ext)s"


def _ensure_media_dir() -> Path:
    """Create the local media storage directory if it doesn't exist."""
    media_dir = settings.storage_path / _MEDIA_DIR_NAME
    media_dir.mkdir(parents=True, exist_ok=True)
    return media_dir


async def download_approved_audio(
    asset_id: str,
    db_session: AsyncSession | None = None,
) -> MediaAsset | None:
    """Download and transcode an approved YouTube audio asset to local storage.

    Uses yt-dlp to extract the audio stream from the YouTube video ID,
    then saves it as a compressed MP3 file in the server's local media directory.

    Args:
        asset_id: The MediaAsset record ID to download.
        db_session: Optional existing async session; creates one if not provided.

    Returns:
        The updated MediaAsset with local_file_path set, or None on failure.
    """
    close_session = db_session is None
    try:
        if close_session:
            from server.database import async_session as _session  # noqa: PLC0414

            async with _session() as local_db:
                return await _download_and_save(asset_id, local_db)
        else:
            return await _download_and_save(asset_id, db_session)
    except Exception as exc:
        logger.error("Media download failed for asset %s: %s", asset_id, exc, exc_info=True)
        return None


async def _download_and_save(
    asset_id: str,
    db: AsyncSession,
) -> MediaAsset | None:
    """Fetch the asset, run yt-dlp, and persist the local file path."""
    media_asset = await db.get(MediaAsset, asset_id)
    if not media_asset:
        logger.warning("MediaAsset %s not found", asset_id)
        return None

    if not media_asset.is_approved:
        logger.info("Asset %s is not approved; skipping download", asset_id)
        return None

    video_id = media_asset.youtube_video_id
    if not video_id:
        logger.warning("Asset %s has no youtube_video_id; cannot download", asset_id)
        return None

    # Check if already downloaded
    if media_asset.local_file_path and Path(media_asset.local_file_path).exists():
        logger.info(
            "Asset %s already downloaded at %s; skipping",
            asset_id,
            media_asset.local_file_path,
        )
        return media_asset

    media_dir = _ensure_media_dir()
    output_path = await _run_ytdlp(video_id, media_dir)

    if not output_path or not output_path.exists():
        logger.error("yt-dlp did not produce output for video %s", video_id)
        return None

    # Compute file hash and size
    file_bytes = output_path.read_bytes()
    content_sha256 = hashlib.sha256(file_bytes).hexdigest()
    file_size = len(file_bytes)

    now = datetime.utcnow()
    media_asset.local_file_path = str(output_path)
    media_asset.is_approved = True
    media_asset.pushed_at = now
    media_asset.updated_at = now
    media_asset.status = "approved"
    media_asset.file_path = str(output_path)  # keep legacy field in sync

    await db.commit()
    await db.refresh(media_asset)

    logger.info(
        "Downloaded asset %s: video=%s, file=%s (%d bytes, sha256=%s)",
        asset_id,
        video_id,
        output_path.name,
        file_size,
        content_sha256[:16],
    )

    return media_asset


def _run_ytdlp_sync(video_id: str, output_dir: Path) -> Path | None:
    """Run yt-dlp synchronously to download audio from a YouTube video.

    Uses yt-dlp with audio-only extraction and MP3 transcoding via FFmpeg.
    Returns the path to the downloaded file, or None on failure.
    """
    output_template = str(output_dir / _YTDLP_OUTPUT_TEMPLATE)

    cmd = [
        "yt-dlp",
        "--no-download",  # We'll handle the download ourselves
        "-x",  # Extract audio only
        "--audio-format", "mp3",  # Transcode to MP3
        "--audio-quality", "5",  # Reasonable quality (128k)
        "-o", output_template,
        f"https://www.youtube.com/watch?v={video_id}",
    ]

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=300,  # 5 minute timeout for large files
            check=False,
        )
        if result.returncode != 0:
            stderr = (result.stderr or "").strip()
            # Extract the actual filename from yt-dlp output
            logger.warning(
                "yt-dlp failed for video %s (exit %d): %s",
                video_id,
                result.returncode,
                stderr[:200],
            )
            return None

        # Find the created file in the output directory
        files = list(output_dir.glob(f"{video_id}.*"))
        if not files:
            logger.warning("yt-dlp succeeded but no output file found for %s", video_id)
            return None
        return files[0]

    except subprocess.TimeoutExpired:
        logger.error("yt-dlp timed out for video %s", video_id)
        return None
    except FileNotFoundError:
        logger.error(
            "yt-dlp executable not found. Install with: pip install yt-dlp (requires FFmpeg)",
        )
        return None
    except Exception as exc:
        logger.error("yt-dlp unexpected error for video %s: %s", video_id, exc)
        return None


async def _run_ytdlp(video_id: str, output_dir: Path) -> Path | None:
    """Run yt-dlp in a thread pool to avoid blocking the event loop."""
    return await asyncio.to_thread(_run_ytdlp_sync, video_id, output_dir)

"""Router for score table-of-contents extraction and retrieval."""

from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException

from server.config import settings
from server.database import get_db
from server.models.orm import ScoreVersion
from server.services.toc_extractor import (
    TocExtractionResult,
    extract_toc,
    toc_entries_to_dict,
)
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter()


@router.get("/score-toc/{score_version_id}")
async def get_score_toc(
    score_version_id: str,
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Return the table of contents for a score version.

    Extracts TOC from embedded bookmarks first, then falls back to
    OCR on the first page for multi-page scanned PDFs.
    """
    result = await _fetch_score_version_and_toc(db, score_version_id)
    return result


async def _fetch_score_version_and_toc(
    db: AsyncSession, score_version_id: str
) -> dict:
    """Fetch a ScoreVersion by ID and extract its TOC."""
    stmt = select(ScoreVersion).where(ScoreVersion.id == score_version_id)
    row = await db.execute(stmt)
    score_version = row.scalar_one_or_none()

    if score_version is None:
        raise HTTPException(status_code=404, detail="Score version not found")

    pdf_path = Path(score_version.file_path)
    if not pdf_path.exists():
        raise HTTPException(
            status_code=404,
            detail="Score file not found on disk",
        )

    toc_result: TocExtractionResult = extract_toc(pdf_path)

    if toc_result.error:
        raise HTTPException(
            status_code=500,
            detail=f"TOC extraction failed: {toc_result.error}",
        )

    return {
        "score_version_id": score_version.id,
        "piece_id": score_version.piece_id,
        "source": toc_result.source,
        "entries": toc_entries_to_dict(toc_result.entries),
    }

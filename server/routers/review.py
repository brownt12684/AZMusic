"""Router for score review and approval workflow."""

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from server.database import get_db
from server.models.orm import (
    Piece,
    PieceStatus,
    ReviewAction,
    ReviewItem,
    ReviewItemType,
    ScoreVersion,
    ScoreVersionType,
)
from server.models.schemas import ReviewItemCreate, ReviewItemRequest, ReviewItemResponse

router = APIRouter()


def _file_url(request: Request, piece_id: str, score_version_id: str) -> str:
    return str(
        request.url_for(
            "get_score_version_file",
            piece_id=piece_id,
            score_version_id=score_version_id,
        )
    )


def _review_item_to_response(request: Request, item: ReviewItem) -> ReviewItemResponse:
    candidate_data = dict(item.candidate_data or {})
    raw_id = candidate_data.get("raw_score_version_id")
    rendered_id = candidate_data.get("score_version_id")
    canonical_id = candidate_data.get("canonical_score_version_id")

    if raw_id:
        candidate_data.setdefault(
            "raw_file_url",
            _file_url(request, item.piece_id, raw_id),
        )
    if rendered_id:
        candidate_data.setdefault(
            "rendered_file_url",
            _file_url(request, item.piece_id, rendered_id),
        )
    if canonical_id:
        candidate_data.setdefault(
            "canonical_file_url",
            _file_url(request, item.piece_id, canonical_id),
        )

    return ReviewItemResponse(
        id=item.id,
        piece_id=item.piece_id,
        item_type=item.item_type,
        title=item.title,
        description=item.description,
        status=item.status,
        created_at=item.created_at,
        candidate_data=candidate_data,
    )


@router.get("/")
async def list_review_items(
    request: Request,
    piece_id: str | None = None,
    db: AsyncSession = Depends(get_db),
):
    """List pending review items, optionally filtered by piece."""
    query = select(ReviewItem).order_by(ReviewItem.created_at.desc())
    if piece_id:
        query = query.where(ReviewItem.piece_id == piece_id)
    result = await db.execute(query)
    return [_review_item_to_response(request, item) for item in result.scalars().all()]


@router.post("/")
async def create_review_item(
    body: ReviewItemCreate,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Create a new review item for a piece."""
    piece = await db.get(Piece, body.piece_id)
    if not piece:
        raise HTTPException(status_code=404, detail="Piece not found")

    item = ReviewItem(
        id=str(uuid.uuid4()),
        piece_id=body.piece_id,
        item_type=body.item_type,
        title=body.title,
        description=body.description,
        status="pending",
        candidate_data=body.candidate_data,
        created_at=datetime.utcnow(),
    )
    db.add(item)

    if piece.status == PieceStatus.imported:
        piece.status = PieceStatus.review_pending

    await db.commit()
    await db.refresh(item)
    return _review_item_to_response(request, item)


@router.get("/{item_id}")
async def get_review_item(
    item_id: str,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Get a specific review item detail."""
    item = await db.get(ReviewItem, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Review item not found")
    return _review_item_to_response(request, item)


@router.post("/{item_id}")
async def submit_review(
    item_id: str,
    body: ReviewItemRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Approve or reject a review item."""
    item = await db.get(ReviewItem, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Review item not found")

    if item.status != "pending":
        raise HTTPException(status_code=409, detail="Review item already resolved")

    candidate_data = item.candidate_data or {}
    rendered_score_id = candidate_data.get("score_version_id")
    canonical_score_id = candidate_data.get("canonical_score_version_id")

    if body.action == ReviewAction.approve:
        item.status = "approved"

        if item.item_type == ReviewItemType.score_candidate and rendered_score_id:
            result = await db.execute(
                select(ScoreVersion).where(ScoreVersion.id == rendered_score_id)
            )
            rendered_version = result.scalar_one_or_none()
            if rendered_version:
                await db.execute(
                    update(ScoreVersion)
                    .where(ScoreVersion.piece_id == item.piece_id)
                    .values(is_default=False)
                )
                rendered_version.is_default = True
                rendered_version.version_type = ScoreVersionType.approved

        if canonical_score_id:
            result = await db.execute(
                select(ScoreVersion).where(ScoreVersion.id == canonical_score_id)
            )
            canonical_version = result.scalar_one_or_none()
            if canonical_version:
                canonical_version.version_type = ScoreVersionType.approved

        pending_result = await db.execute(
            select(ReviewItem).where(
                ReviewItem.piece_id == item.piece_id,
                ReviewItem.status == "pending",
                ReviewItem.id != item.id,
            )
        )
        if pending_result.scalar_one_or_none() is None:
            piece = await db.get(Piece, item.piece_id)
            if piece:
                piece.status = PieceStatus.approved

    elif body.action == ReviewAction.reject:
        item.status = "rejected"

        for score_version_id in (rendered_score_id, canonical_score_id):
            if not score_version_id:
                continue
            result = await db.execute(
                select(ScoreVersion).where(ScoreVersion.id == score_version_id)
            )
            score_version = result.scalar_one_or_none()
            if score_version:
                score_version.version_type = ScoreVersionType.rejected

    await db.commit()
    await db.refresh(item)
    return _review_item_to_response(request, item)

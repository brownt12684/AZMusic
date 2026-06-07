"""Router for background job queuing and status polling."""

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from server.database import get_db
from server.models.orm import BackgroundJob, JobStatus, Piece, PieceStatus, ReviewItem
from server.models.schemas import (
    JobResponse,
    JobSummaryResponse,
    JobTriggerRequest,
    JobUpdateRequest,
)
from server.services.job_summary import build_job_summary

router = APIRouter()


def _job_to_response(job: BackgroundJob, piece: Piece | None = None) -> JobResponse:
    return JobResponse(
        id=job.id,
        piece_id=job.piece_id,
        piece_title=piece.title if piece else None,
        piece_composer=piece.composer if piece else None,
        piece_status=piece.status if piece else None,
        job_type=job.job_type,
        status=job.status,
        progress=job.progress,
        error_message=job.error_message,
        result_data=job.result_data,
        created_at=job.created_at,
        updated_at=job.updated_at,
    )


@router.get("/")
async def list_jobs(db: AsyncSession = Depends(get_db)):
    """List all background jobs, newest first."""
    result = await db.execute(
        select(BackgroundJob, Piece)
        .outerjoin(Piece, BackgroundJob.piece_id == Piece.id)
        .order_by(BackgroundJob.created_at.desc())
    )
    return [_job_to_response(job, piece) for job, piece in result.all()]


@router.get("/summary", response_model=JobSummaryResponse)
async def get_job_summary(db: AsyncSession = Depends(get_db)):
    """Return parent-facing job queue counts and latest failure."""
    return await build_job_summary(db)


@router.get("/{job_id}")
async def get_job(job_id: str, db: AsyncSession = Depends(get_db)):
    """Get job status and progress."""
    job = await db.get(BackgroundJob, job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    piece = await _piece_for_job(db, job)
    return _job_to_response(job, piece)


@router.post("/{job_id}/cancel")
async def cancel_job(job_id: str, db: AsyncSession = Depends(get_db)):
    """Cancel a queued/running background job for parent debug cleanup."""
    job = await db.get(BackgroundJob, job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")

    if job.status in {JobStatus.queued, JobStatus.running}:
        result_data = dict(job.result_data or {})
        result_data["canceled_by"] = "parent_debug_tools"
        result_data["canceled_at"] = datetime.utcnow().isoformat()
        job.status = JobStatus.canceled
        job.progress = 100.0
        job.error_message = "Canceled by parent debug tools."
        job.result_data = result_data
        job.updated_at = datetime.utcnow()
        await _restore_canceled_piece_visibility(db, job.piece_id)
        await db.commit()
        await db.refresh(job)

    piece = await _piece_for_job(db, job)
    return _job_to_response(job, piece)


@router.post("/{job_id}/retry")
async def retry_failed_job(job_id: str, db: AsyncSession = Depends(get_db)):
    """Requeue a failed score-processing job for parent debug recovery."""
    job = await db.get(BackgroundJob, job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    if job.job_type != "score_processing":
        raise HTTPException(
            status_code=409,
            detail="Only score_processing jobs can be retried.",
        )
    if job.status != JobStatus.failed:
        raise HTTPException(
            status_code=409,
            detail="Only failed jobs can be retried.",
        )
    if not job.piece_id:
        raise HTTPException(status_code=409, detail="Job has no linked piece to retry.")

    piece = await db.get(Piece, job.piece_id)
    if not piece:
        raise HTTPException(status_code=409, detail="Linked piece no longer exists.")

    result_data = dict(job.result_data or {})
    previous_error = job.error_message or result_data.get("last_error")
    if previous_error:
        result_data["previous_retry_error"] = str(previous_error)
    result_data["manual_retry_count"] = _safe_int(result_data.get("manual_retry_count")) + 1
    result_data["last_manual_retry_at"] = datetime.utcnow().isoformat()
    result_data["retry_count"] = 0
    if _can_retry_render_only(result_data):
        result_data["retry_mode"] = "render_only"
    else:
        result_data.pop("retry_mode", None)
    result_data.pop("last_error", None)
    result_data.pop("last_failed_at", None)

    job.status = JobStatus.queued
    job.progress = 0.0
    job.error_message = None
    job.result_data = result_data
    job.updated_at = datetime.utcnow()
    piece.status = PieceStatus.imported
    piece.updated_at = datetime.utcnow()
    await db.commit()
    await db.refresh(job)
    await db.refresh(piece)
    return _job_to_response(job, piece)


@router.post("/trigger")
async def trigger_job(
    body: JobTriggerRequest,
    db: AsyncSession = Depends(get_db),
):
    """Create and queue a new background job."""
    job = BackgroundJob(
        id=str(uuid.uuid4()),
        piece_id=body.piece_id,
        job_type=body.job_type,
        status=JobStatus.queued,
        progress=0.0,
        created_at=datetime.utcnow(),
    )
    db.add(job)
    await db.commit()
    await db.refresh(job)
    piece = await _piece_for_job(db, job)
    return _job_to_response(job, piece)


@router.patch("/{job_id}")
async def update_job(
    job_id: str,
    body: JobUpdateRequest,
    db: AsyncSession = Depends(get_db),
):
    """Update job status, progress, or result."""
    job = await db.get(BackgroundJob, job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")

    if body.status is not None:
        job.status = body.status
    if body.progress is not None:
        job.progress = body.progress
    if body.error_message is not None:
        job.error_message = body.error_message
    if body.result_data is not None:
        job.result_data = body.result_data

    await db.commit()
    await db.refresh(job)
    piece = await _piece_for_job(db, job)
    return _job_to_response(job, piece)


async def _piece_for_job(db: AsyncSession, job: BackgroundJob) -> Piece | None:
    if not job.piece_id:
        return None
    return await db.get(Piece, job.piece_id)


async def _restore_canceled_piece_visibility(
    db: AsyncSession,
    piece_id: str | None,
) -> None:
    if not piece_id:
        return
    piece = await db.get(Piece, piece_id)
    if not piece or piece.status != PieceStatus.processing:
        return
    pending_result = await db.execute(
        select(ReviewItem).where(
            ReviewItem.piece_id == piece_id,
            ReviewItem.status == "pending",
        )
    )
    pending_item = pending_result.scalars().first()
    piece.status = PieceStatus.review_pending if pending_item else PieceStatus.imported
    piece.updated_at = datetime.utcnow()


def _safe_int(value: object) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


def _can_retry_render_only(result_data: dict) -> bool:
    if result_data.get("render_validation_status") != "render_failed":
        return False
    return all(
        isinstance(result_data.get(key), str) and bool(str(result_data.get(key)).strip())
        for key in (
            "raw_score_version_id",
            "canonical_score_version_id",
            "rendered_score_version_id",
        )
    )

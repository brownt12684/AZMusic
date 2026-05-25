"""Router for background job queuing and status polling."""

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from server.database import get_db
from server.models.orm import BackgroundJob, JobStatus
from server.models.schemas import (
    JobResponse,
    JobSummaryResponse,
    JobTriggerRequest,
    JobUpdateRequest,
)
from server.services.job_summary import build_job_summary

router = APIRouter()


def _job_to_response(job: BackgroundJob) -> JobResponse:
    return JobResponse(
        id=job.id,
        piece_id=job.piece_id,
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
        select(BackgroundJob).order_by(BackgroundJob.created_at.desc())
    )
    return [_job_to_response(j) for j in result.scalars().all()]


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
    return _job_to_response(job)


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
    return _job_to_response(job)


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
    return _job_to_response(job)

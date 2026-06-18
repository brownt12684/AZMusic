"""Background job summary helpers for parent-facing server status."""

from sqlalchemy import case, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from server.models.orm import BackgroundJob, JobStatus, Piece
from server.models.schemas import (
    JobSummaryActiveJobResponse,
    JobSummaryFailureResponse,
    JobSummaryResponse,
)

_ACTIVE_JOB_LIMIT = 8


async def build_job_summary(db: AsyncSession) -> JobSummaryResponse:
    result = await db.execute(
        select(BackgroundJob.status, func.count(BackgroundJob.id)).group_by(BackgroundJob.status)
    )
    counts = {status: count for status, count in result.all()}

    failed_result = await db.execute(
        select(BackgroundJob)
        .where(BackgroundJob.status == JobStatus.failed)
        .order_by(BackgroundJob.updated_at.desc())
        .limit(1)
    )
    failed_job = failed_result.scalar_one_or_none()
    last_failed_job = None
    if failed_job:
        last_failed_job = JobSummaryFailureResponse(
            id=failed_job.id,
            piece_id=failed_job.piece_id,
            job_type=failed_job.job_type,
            error_message=failed_job.error_message,
            updated_at=failed_job.updated_at,
        )

    active_result = await db.execute(
        select(BackgroundJob, Piece)
        .outerjoin(Piece, BackgroundJob.piece_id == Piece.id)
        .where(BackgroundJob.status.in_([JobStatus.running, JobStatus.queued]))
        .order_by(
            case((BackgroundJob.status == JobStatus.running, 0), else_=1),
            BackgroundJob.updated_at.desc(),
        )
        .limit(_ACTIVE_JOB_LIMIT)
    )
    active_jobs = [
        JobSummaryActiveJobResponse(
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
        for job, piece in active_result.all()
    ]

    return JobSummaryResponse(
        queued_count=counts.get(JobStatus.queued, 0),
        running_count=counts.get(JobStatus.running, 0),
        failed_count=counts.get(JobStatus.failed, 0),
        succeeded_count=counts.get(JobStatus.succeeded, 0),
        canceled_count=counts.get(JobStatus.canceled, 0),
        active_jobs=active_jobs,
        last_failed_job=last_failed_job,
    )

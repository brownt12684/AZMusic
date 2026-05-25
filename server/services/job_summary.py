"""Background job summary helpers for parent-facing server status."""

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from server.models.orm import BackgroundJob, JobStatus
from server.models.schemas import JobSummaryFailureResponse, JobSummaryResponse


async def build_job_summary(db: AsyncSession) -> JobSummaryResponse:
    result = await db.execute(
        select(BackgroundJob.status, func.count(BackgroundJob.id)).group_by(
            BackgroundJob.status
        )
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

    return JobSummaryResponse(
        queued_count=counts.get(JobStatus.queued, 0),
        running_count=counts.get(JobStatus.running, 0),
        failed_count=counts.get(JobStatus.failed, 0),
        succeeded_count=counts.get(JobStatus.succeeded, 0),
        last_failed_job=last_failed_job,
    )

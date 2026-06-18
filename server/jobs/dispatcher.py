"""In-process background job dispatcher for server-side processing."""

from __future__ import annotations

import asyncio
from datetime import datetime, timedelta
from typing import Any

from sqlalchemy import select

import server.database as database
from server.config import settings
from server.models.orm import BackgroundJob, JobStatus, Piece, PieceStatus, ReviewItem
from server.services.processing_settings import ProcessingSettingsStore
from server.services.score_processing import JobCanceledError, ScoreProcessingService

_DISPATCHABLE_JOB_TYPES = ("score_processing", "book_import")


class JobDispatcher:
    """Poll and process queued jobs inside the FastAPI process."""

    def __init__(
        self,
        *,
        poll_interval_seconds: float | None = None,
        stale_after_seconds: int | None = None,
        max_retries: int | None = None,
    ) -> None:
        self.poll_interval_seconds = (
            poll_interval_seconds
            if poll_interval_seconds is not None
            else settings.job_dispatcher_poll_interval_seconds
        )
        self.stale_after_seconds = (
            stale_after_seconds
            if stale_after_seconds is not None
            else settings.job_dispatcher_stale_after_seconds
        )
        self.max_retries = (
            max_retries if max_retries is not None else settings.job_dispatcher_max_retries
        )
        self._task: asyncio.Task[None] | None = None
        self._running_tasks: set[asyncio.Task[None]] = set()
        self._stop_event = asyncio.Event()
        self._score_processing_service = ScoreProcessingService()
        self._settings_store = ProcessingSettingsStore()

    async def start(self) -> None:
        if self._task and not self._task.done():
            return
        self._stop_event.clear()
        await self.requeue_stale_running_jobs()
        self._task = asyncio.create_task(self.run_forever())

    async def stop(self) -> None:
        self._stop_event.set()
        if not self._task:
            return
        self._task.cancel()
        try:
            await self._task
        except asyncio.CancelledError:
            pass
        for task in self._running_tasks:
            task.cancel()
        if self._running_tasks:
            await asyncio.gather(*self._running_tasks, return_exceptions=True)
        self._running_tasks.clear()
        self._task = None

    async def run_forever(self) -> None:
        while not self._stop_event.is_set():
            try:
                self._discard_completed_tasks()
                started_jobs = await self.start_available_jobs()
            except asyncio.CancelledError:
                raise
            except Exception as exc:  # pragma: no cover - defensive loop guard
                self._settings_store.record_last_error(f"Job dispatcher loop failed: {exc}")
                started_jobs = 0

            if started_jobs == 0:
                if self._running_tasks:
                    done, _ = await asyncio.wait(
                        self._running_tasks,
                        timeout=self.poll_interval_seconds,
                        return_when=asyncio.FIRST_COMPLETED,
                    )
                    for task in done:
                        _ = task.exception() if not task.cancelled() else None
                    self._discard_completed_tasks()
                    continue
                try:
                    await asyncio.wait_for(
                        self._stop_event.wait(),
                        timeout=self.poll_interval_seconds,
                    )
                except asyncio.TimeoutError:
                    pass

    async def run_once(self) -> bool:
        async with database.async_session() as db:
            job = await self._claim_next_job(db)
            if job is None:
                return False

            job_id = job.id
        await self._process_claimed_job(job_id)
        return True

    async def start_available_jobs(self) -> int:
        max_jobs = self._configured_max_concurrent_jobs()
        self._discard_completed_tasks()
        available_slots = max(0, max_jobs - len(self._running_tasks))
        started = 0
        for _ in range(available_slots):
            async with database.async_session() as db:
                job = await self._claim_next_job(db)
                if job is None:
                    break
                job_id = job.id
            task = asyncio.create_task(self._process_claimed_job(job_id))
            self._running_tasks.add(task)
            started += 1
        return started

    async def _process_claimed_job(self, job_id: str) -> None:
        async with database.async_session() as db:
            job = await db.get(BackgroundJob, job_id)
            if job is None or job.status != JobStatus.running:
                return
            try:
                await self._process_job(db, job)
            except JobCanceledError:
                await db.rollback()
            except Exception as exc:
                await db.rollback()
                await self._record_job_failure(job_id, exc)

    def _configured_max_concurrent_jobs(self) -> int:
        payload = self._settings_store.load()
        value = payload.get("max_concurrent_jobs", settings.max_concurrent_jobs)
        try:
            parsed = int(value)
        except (TypeError, ValueError):
            parsed = settings.max_concurrent_jobs
        return max(1, min(4, parsed))

    def _discard_completed_tasks(self) -> None:
        self._running_tasks = {task for task in self._running_tasks if not task.done()}

    async def requeue_stale_running_jobs(self) -> int:
        cutoff = datetime.utcnow() - timedelta(seconds=self.stale_after_seconds)
        async with database.async_session() as db:
            result = await db.execute(
                select(BackgroundJob).where(
                    BackgroundJob.job_type.in_(_DISPATCHABLE_JOB_TYPES),
                    BackgroundJob.status == JobStatus.running,
                    BackgroundJob.updated_at < cutoff,
                )
            )
            jobs = result.scalars().all()
            for job in jobs:
                result_data = dict(job.result_data or {})
                result_data["requeued_after_stale_running"] = True
                result_data["last_requeued_at"] = datetime.utcnow().isoformat()
                job.status = JobStatus.queued
                job.progress = 0.0
                job.error_message = None
                job.result_data = result_data
                job.updated_at = datetime.utcnow()
            await db.commit()
            return len(jobs)

    async def _claim_next_job(self, db) -> BackgroundJob | None:
        result = await db.execute(
            select(BackgroundJob)
            .where(
                BackgroundJob.job_type.in_(_DISPATCHABLE_JOB_TYPES),
                BackgroundJob.status == JobStatus.queued,
            )
            .order_by(BackgroundJob.created_at.asc())
            .limit(1)
        )
        job = result.scalar_one_or_none()
        if job is None:
            return None

        result_data = dict(job.result_data or {})
        result_data["last_attempt_at"] = datetime.utcnow().isoformat()
        job.status = JobStatus.running
        job.progress = max(job.progress or 0.0, 5.0)
        job.error_message = None
        job.result_data = result_data
        job.updated_at = datetime.utcnow()

        if job.piece_id:
            piece = await db.get(Piece, job.piece_id)
            if piece:
                piece.status = PieceStatus.processing
                piece.updated_at = datetime.utcnow()

        await db.commit()
        await db.refresh(job)
        return job

    async def _process_job(self, db, job: BackgroundJob) -> None:
        if job.job_type == "score_processing":
            await self._score_processing_service.process_existing_pdf_job(db, job=job)
            return
        if job.job_type == "book_import":
            await self._score_processing_service.process_book_import_job(db, job=job)

    async def _record_job_failure(self, job_id: str, exc: Exception) -> None:
        async with database.async_session() as db:
            job = await db.get(BackgroundJob, job_id)
            if job is None:
                return

            result_data: dict[str, Any] = dict(job.result_data or {})
            retry_count = _safe_int(result_data.get("retry_count"))
            result_data["last_error"] = str(exc)
            result_data["last_failed_at"] = datetime.utcnow().isoformat()

            if retry_count < self.max_retries:
                result_data["retry_count"] = retry_count + 1
                job.status = JobStatus.queued
                job.progress = 0.0
                job.error_message = str(exc)
            else:
                result_data["retry_count"] = retry_count
                job.status = JobStatus.failed
                job.progress = 100.0
                job.error_message = str(exc)
                self._settings_store.record_last_error(str(exc))
                await self._restore_failed_piece_visibility(db, job.piece_id)

            job.result_data = result_data
            job.updated_at = datetime.utcnow()
            await db.commit()

    async def _restore_failed_piece_visibility(self, db, piece_id: str | None) -> None:
        if not piece_id:
            return
        piece = await db.get(Piece, piece_id)
        if not piece:
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


def _safe_int(value: Any) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0

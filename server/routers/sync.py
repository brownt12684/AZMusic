"""Router for client sync state management."""

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from server.database import get_db
from server.models.orm import Profile, RecordingRequest, SyncState
from server.models.schemas import (
    PracticeAlertItem,
    SyncDownloadRequest,
    SyncStateResponse,
    SyncStateStatus,
    SyncStateUpdateRequest,
    SyncUploadRequest,
)
from server.services.sync_state import SyncStateMetadataService

router = APIRouter()
_sync_state_metadata_service = SyncStateMetadataService()


async def _sync_state_to_response(
    client_id: str,
    state: SyncState | None,
    db: AsyncSession | None = None,
) -> SyncStateResponse:
    metadata = _sync_state_metadata_service.metadata_for_client(client_id)
    pending_uploads = state.pending_uploads if state else 0
    pending_downloads = state.pending_downloads if state else 0
    has_pending_work = pending_uploads > 0 or pending_downloads > 0
    retry_required = bool(metadata["retry_required"])
    last_sync = state.last_sync if state else None
    last_success_at = metadata["last_success_at"] or last_sync

    # Fetch pending practice requests for student profiles
    pending_requests: list[PracticeAlertItem] = []
    if db is not None:
        pending_requests = await _fetch_student_alerts(client_id, db)

    return SyncStateResponse(
        client_id=client_id,
        last_sync=last_sync or last_success_at,
        pending_uploads=pending_uploads,
        pending_downloads=pending_downloads,
        status=_derive_sync_status(
            metadata=metadata,
            has_pending_work=has_pending_work,
            has_last_sync=bool(last_sync or last_success_at),
            retry_required=retry_required,
        ),
        has_pending_work=has_pending_work,
        retry_required=retry_required,
        last_attempt_at=metadata["last_attempt_at"],
        last_success_at=last_success_at,
        last_failure_at=metadata["last_failure_at"],
        last_error=metadata["last_error"],
        pending_requests=pending_requests,
    )


async def _fetch_student_alerts(client_id: str, db: AsyncSession) -> list[PracticeAlertItem]:
    """Fetch unread practice requests for a student profile identified by client_id."""
    result = await db.execute(
        select(Profile).where(Profile.id == client_id, Profile.role == "student")
    )
    student = result.scalar_one_or_none()
    if not student:
        return []

    stmt = (
        select(
            RecordingRequest,
            Profile.name.label("teacher_name"),
        )
        .join(Profile, RecordingRequest.teacher_profile_id == Profile.id)
        .where(
            RecordingRequest.student_profile_id == student.id,
            RecordingRequest.is_read == False,  # noqa: E712
        )
        .order_by(RecordingRequest.created_at.desc())
    )
    result = await db.execute(stmt)
    rows = result.all()

    alerts = []
    for req, teacher_name in rows:
        alerts.append(PracticeAlertItem(
            id=req.id,
            teacher_profile_id=req.teacher_profile_id,
            teacher_name=teacher_name or "Teacher",
            student_profile_id=req.student_profile_id,
            piece_id=req.piece_id,
            piece_title=None,
            message_notes=req.message_notes,
            is_read=req.is_read,
            created_at=req.created_at,
        ))
    return alerts


@router.get("/{client_id}")
async def get_sync_state(client_id: str, db: AsyncSession = Depends(get_db)):
    """Get sync state for a specific client."""
    result = await db.execute(
        select(SyncState).where(SyncState.client_id == client_id)
    )
    state = result.scalar_one_or_none()
    return await _sync_state_to_response(client_id, state, db)


@router.patch("/{client_id}")
async def patch_sync_state(
    client_id: str,
    body: SyncStateUpdateRequest,
    db: AsyncSession = Depends(get_db),
):
    """Patch sync counts plus user-facing banner or retry metadata."""
    now = datetime.utcnow()
    result = await db.execute(
        select(SyncState).where(SyncState.client_id == client_id)
    )
    state = result.scalar_one_or_none()

    derived_last_sync = body.last_sync
    if derived_last_sync is None and body.status == SyncStateStatus.synced:
        derived_last_sync = body.last_success_at or now

    if (
        body.pending_uploads is not None
        or body.pending_downloads is not None
        or derived_last_sync is not None
    ):
        if state is None:
            state = SyncState(
                id=str(uuid.uuid4()),
                client_id=client_id,
                pending_uploads=0,
                pending_downloads=0,
                created_at=now,
            )
            db.add(state)
        if body.pending_uploads is not None:
            state.pending_uploads = body.pending_uploads
        if body.pending_downloads is not None:
            state.pending_downloads = body.pending_downloads
        if derived_last_sync is not None:
            state.last_sync = derived_last_sync
        state.updated_at = now
        await db.commit()
        await db.refresh(state)

    metadata_updates = {}
    if body.status is not None:
        metadata_updates["status"] = body.status
        if body.status == SyncStateStatus.syncing:
            metadata_updates.setdefault("last_attempt_at", body.last_attempt_at or now)
        elif body.status == SyncStateStatus.synced:
            metadata_updates.setdefault(
                "last_success_at",
                body.last_success_at or derived_last_sync or now,
            )
            metadata_updates.setdefault("retry_required", False)
            metadata_updates.setdefault("last_error", None)
        elif body.status == SyncStateStatus.sync_failed_usable:
            metadata_updates.setdefault("last_attempt_at", body.last_attempt_at or now)
            metadata_updates.setdefault("last_failure_at", body.last_failure_at or now)
            metadata_updates.setdefault("retry_required", True)
    if body.retry_required is not None:
        metadata_updates["retry_required"] = body.retry_required
    if "last_attempt_at" in body.model_fields_set:
        metadata_updates["last_attempt_at"] = body.last_attempt_at
    if "last_success_at" in body.model_fields_set:
        metadata_updates["last_success_at"] = body.last_success_at
    if "last_failure_at" in body.model_fields_set:
        metadata_updates["last_failure_at"] = body.last_failure_at
    if "last_error" in body.model_fields_set:
        metadata_updates["last_error"] = body.last_error

    if metadata_updates:
        _sync_state_metadata_service.update(client_id, **metadata_updates)

    return await _sync_state_to_response(client_id, state, db)


@router.post("/{client_id}/upload")
async def upload_sync(
    client_id: str,
    body: SyncUploadRequest,
    db: AsyncSession = Depends(get_db),
):
    """Record pending uploads for a client."""
    result = await db.execute(
        select(SyncState).where(SyncState.client_id == client_id)
    )
    state = result.scalar_one_or_none()

    if state:
        state.pending_uploads = body.pending_uploads
        state.updated_at = datetime.utcnow()
    else:
        state = SyncState(
            id=str(uuid.uuid4()),
            client_id=client_id,
            pending_uploads=body.pending_uploads,
            created_at=datetime.utcnow(),
        )
        db.add(state)

    await db.commit()
    await db.refresh(state)
    return await _sync_state_to_response(client_id, state, db)


@router.post("/{client_id}/download")
async def download_sync(
    client_id: str,
    body: SyncDownloadRequest,
    db: AsyncSession = Depends(get_db),
):
    """Record pending downloads and last sync time for a client."""
    result = await db.execute(
        select(SyncState).where(SyncState.client_id == client_id)
    )
    state = result.scalar_one_or_none()

    if state:
        state.pending_downloads = body.pending_downloads
        state.last_sync = body.last_sync or datetime.utcnow()
        state.updated_at = datetime.utcnow()
    else:
        state = SyncState(
            id=str(uuid.uuid4()),
            client_id=client_id,
            pending_downloads=body.pending_downloads,
            last_sync=body.last_sync or datetime.utcnow(),
            created_at=datetime.utcnow(),
        )
        db.add(state)

    await db.commit()
    await db.refresh(state)
    return await _sync_state_to_response(client_id, state, db)


def _derive_sync_status(
    *,
    metadata: dict,
    has_pending_work: bool,
    has_last_sync: bool,
    retry_required: bool,
) -> SyncStateStatus:
    status = metadata["status"]
    if status is not None:
        return status

    last_failure_at = metadata["last_failure_at"]
    last_success_at = metadata["last_success_at"]
    if retry_required or (
        last_failure_at
        and (last_success_at is None or last_failure_at >= last_success_at)
    ):
        return SyncStateStatus.sync_failed_usable
    if has_pending_work:
        return SyncStateStatus.syncing
    if has_last_sync:
        return SyncStateStatus.synced
    return SyncStateStatus.offline_ready

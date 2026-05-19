"""Router for client sync state management."""

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from server.database import get_db
from server.models.orm import SyncState
from server.models.schemas import (
    SyncDownloadRequest,
    SyncStateResponse,
    SyncUploadRequest,
)

router = APIRouter()


def _sync_state_to_response(state: SyncState) -> SyncStateResponse:
    return SyncStateResponse(
        client_id=state.client_id,
        last_sync=state.last_sync,
        pending_uploads=state.pending_uploads,
        pending_downloads=state.pending_downloads,
    )


@router.get("/{client_id}")
async def get_sync_state(client_id: str, db: AsyncSession = Depends(get_db)):
    """Get sync state for a specific client."""
    result = await db.execute(
        select(SyncState).where(SyncState.client_id == client_id)
    )
    state = result.scalar_one_or_none()
    if not state:
        return SyncStateResponse(client_id=client_id)
    return _sync_state_to_response(state)


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
    return _sync_state_to_response(state)


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
    return _sync_state_to_response(state)

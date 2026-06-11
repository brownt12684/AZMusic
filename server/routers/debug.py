"""Parent debug endpoints for development and test cleanup."""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from server.database import get_db
from server.services.debug_cleanup import (
    DebugCleanupError,
    DebugPieceNotFoundError,
    clear_piece_workflow_data,
    clear_workflow_data,
)
from server.services.piece_identity import cleanup_duplicate_attempts, list_duplicate_groups
from server.services.training_catalog import list_training_samples

router = APIRouter()


@router.post("/clear-workflow")
async def clear_debug_workflow(db: AsyncSession = Depends(get_db)):
    """Clear import workflow data while preserving pairing and server settings."""
    return await clear_workflow_data(db)


@router.delete("/pieces/{piece_id}")
async def clear_debug_piece(piece_id: str, db: AsyncSession = Depends(get_db)):
    """Clear one piece and its generated workflow data."""
    try:
        return await clear_piece_workflow_data(db, piece_id)
    except DebugPieceNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except DebugCleanupError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/duplicates")
async def list_debug_duplicates(db: AsyncSession = Depends(get_db)):
    """Inspect logical duplicate piece groups without mutating workflow data."""
    groups = await list_duplicate_groups(db)
    return {
        "duplicate_group_count": len(groups),
        "duplicate_piece_count": sum(max(0, group["count"] - 1) for group in groups),
        "groups": groups,
    }


@router.post("/duplicates/cleanup")
async def cleanup_debug_duplicates(db: AsyncSession = Depends(get_db)):
    """Archive duplicate attempts while preserving their files for debugging."""
    return await cleanup_duplicate_attempts(db)


@router.get("/training-samples")
async def list_debug_training_samples():
    """Inspect human-approved notation samples retained for retraining."""
    samples = list_training_samples()
    return {
        "sample_count": len(samples),
        "samples": samples,
    }

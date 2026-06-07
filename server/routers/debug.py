"""Parent debug endpoints for development and test cleanup."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from server.database import get_db
from server.services.debug_cleanup import clear_workflow_data
from server.services.piece_identity import cleanup_duplicate_attempts, list_duplicate_groups

router = APIRouter()


@router.post("/clear-workflow")
async def clear_debug_workflow(db: AsyncSession = Depends(get_db)):
    """Clear import workflow data while preserving pairing and server settings."""
    return await clear_workflow_data(db)


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

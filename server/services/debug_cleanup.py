"""Debug cleanup helpers for resetting import workflow data safely."""

from __future__ import annotations

import shutil
import sys
from datetime import datetime
from pathlib import Path
from urllib.parse import unquote, urlparse

from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from server.config import settings
from server.models.orm import (
    AnnotationLayer,
    BackgroundJob,
    MediaAsset,
    Piece,
    PieceHistoryDraft,
    ReviewItem,
    ScoreVersion,
)


class DebugCleanupError(RuntimeError):
    """Raised when a debug cleanup target cannot be safely resolved."""


async def clear_workflow_data(db: AsyncSession) -> dict[str, object]:
    """Clear import/review/generated workflow data while preserving configuration."""
    backup_dir = _backup_runtime_state(db)

    for model in (
        AnnotationLayer,
        PieceHistoryDraft,
        MediaAsset,
        ReviewItem,
        BackgroundJob,
        ScoreVersion,
        Piece,
    ):
        await db.execute(delete(model))
    await db.commit()

    cleared_dirs = []
    for directory in _generated_storage_dirs():
        if _clear_directory_contents(directory):
            cleared_dirs.append(str(directory))

    return {
        "status": "cleared",
        "backup_dir": str(backup_dir),
        "cleared_storage_dirs": cleared_dirs,
        "preserved": [
            "pairing_state",
            "processing_settings",
            "server_identity",
            "device_pairings",
        ],
    }


def _backup_runtime_state(db: AsyncSession) -> Path:
    backup_root = _install_root() / "cleanup-backups"
    backup_dir = backup_root / f"debug-clear-{datetime.utcnow():%Y%m%d-%H%M%S}"
    backup_dir.mkdir(parents=True, exist_ok=True)

    for path in _database_files(db):
        if path.exists() and path.is_file():
            shutil.copy2(path, backup_dir / path.name)

    for directory in _generated_storage_dirs():
        if directory.exists() and directory.is_dir():
            destination = backup_dir / directory.name
            shutil.copytree(directory, destination, dirs_exist_ok=True)

    return backup_dir


def _database_files(db: AsyncSession) -> list[Path]:
    database_path = _sqlite_database_path(str(db.get_bind().url))
    if database_path is None:
        return []
    return [
        database_path,
        Path(f"{database_path}-wal"),
        Path(f"{database_path}-shm"),
    ]


def _sqlite_database_path(database_url: str) -> Path | None:
    parsed = urlparse(database_url)
    if parsed.scheme not in {"sqlite+aiosqlite", "sqlite"}:
        return None
    if parsed.path in {"", "/:memory:"}:
        return None
    return Path(unquote(parsed.path.lstrip("/"))).resolve()


def _install_root() -> Path:
    storage_parent = settings.storage_path.resolve().parent
    if getattr(sys, "frozen", False):
        return storage_parent.parent
    return storage_parent


def _generated_storage_dirs() -> list[Path]:
    storage_root = settings.storage_path.resolve()
    return [
        storage_root / "pieces",
        storage_root / "piece_state",
    ]


def _clear_directory_contents(directory: Path) -> bool:
    directory = directory.resolve()
    storage_root = settings.storage_path.resolve()
    try:
        directory.relative_to(storage_root)
    except ValueError as exc:
        raise DebugCleanupError(
            f"Refusing to clear path outside server storage: {directory}"
        ) from exc

    if not directory.exists():
        directory.mkdir(parents=True, exist_ok=True)
        return False

    for child in directory.iterdir():
        if child.is_dir():
            shutil.rmtree(child)
        else:
            child.unlink()
    return True

"""Adult-owned cloud sync scaffolding for restorable AZMusic libraries."""

from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path
from typing import Any

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from server.config import settings
from server.database import get_db
from server.models.orm import Piece, ScoreVersion
from server.models.schemas import (
    CloudConnectGithubRequest,
    CloudStatusResponse,
    CloudSyncManifestResponse,
)
from server.services.piece_state import PieceStateService

router = APIRouter()
_piece_state_service = PieceStateService()


@router.get("/status", response_model=CloudStatusResponse)
async def get_cloud_status():
    """Return the configured adult-owned cloud sync target."""
    return _status_response(_load_cloud_state())


@router.post("/connect/github", response_model=CloudStatusResponse)
async def connect_github_cloud(body: CloudConnectGithubRequest):
    """Configure GitHub as the interim parent/teacher-owned cloud sync provider."""
    state = _load_cloud_state()
    state.update(
        {
            "provider": "github",
            "configured": True,
            "connected": bool(body.repository),
            "repository": body.repository,
            "branch": body.branch,
            "path_prefix": body.path_prefix,
            "last_error": None
            if body.repository
            else "GitHub repository is not configured yet.",
        }
    )
    _save_cloud_state(state)
    return _status_response(state)


@router.post("/sync", response_model=CloudSyncManifestResponse)
async def sync_cloud_manifest(db: AsyncSession = Depends(get_db)):
    """Export a restorable family manifest for the configured cloud provider."""
    now = datetime.utcnow()
    pieces_result = await db.execute(select(Piece).order_by(Piece.created_at.asc()))
    score_versions_result = await db.execute(
        select(ScoreVersion).order_by(ScoreVersion.created_at.asc())
    )
    pieces = pieces_result.scalars().all()
    score_versions = score_versions_result.scalars().all()

    manifest = {
        "schema_version": 1,
        "provider": "github",
        "account_scope": "parent_teacher",
        "synced_at": now.isoformat(),
        "pieces": [
            {
                "id": piece.id,
                "title": piece.title,
                "composer": piece.composer,
                "file_name": piece.file_name,
                "status": piece.status,
                "created_at": piece.created_at.isoformat(),
                "updated_at": piece.updated_at.isoformat(),
                "state": _piece_state_service.load(piece.id),
            }
            for piece in pieces
        ],
        "score_versions": [
            {
                "id": version.id,
                "piece_id": version.piece_id,
                "version_type": version.version_type,
                "file_path": version.file_path,
                "content_sha256": _sha256_or_none(Path(version.file_path)),
                "is_default": version.is_default,
                "created_at": version.created_at.isoformat(),
                "workflow": _piece_state_service.score_version_metadata(
                    version.piece_id,
                    version.id,
                ),
            }
            for version in score_versions
        ],
        "notes": _load_sync_collection("notes"),
        "annotations": _load_sync_collection("annotations"),
    }

    manifest_path = _cloud_root() / "family-manifest.json"
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True), encoding="utf-8")

    state = _load_cloud_state()
    state["last_sync_at"] = now.isoformat()
    state["last_error"] = None
    _save_cloud_state(state)

    return CloudSyncManifestResponse(
        family_manifest_path=str(manifest_path),
        pieces_count=len(pieces),
        score_versions_count=len(score_versions),
        assignments_count=sum(
            len(_piece_state_service.metadata_for_piece(piece)["visible_to_profile_ids"])
            for piece in pieces
        ),
        notes_count=len(manifest["notes"]),
        annotations_count=len(manifest["annotations"]),
        synced_at=now,
    )


@router.post("/restore", response_model=CloudSyncManifestResponse)
async def restore_cloud_manifest():
    """Report the currently available manifest for reinstall/resync restore."""
    manifest_path = _cloud_root() / "family-manifest.json"
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    else:
        manifest = {
            "pieces": [],
            "score_versions": [],
            "notes": [],
            "annotations": [],
        }
    now = datetime.utcnow()
    state = _load_cloud_state()
    state["last_restore_at"] = now.isoformat()
    _save_cloud_state(state)
    return CloudSyncManifestResponse(
        family_manifest_path=str(manifest_path),
        pieces_count=len(manifest.get("pieces") or []),
        score_versions_count=len(manifest.get("score_versions") or []),
        assignments_count=sum(
            len((piece.get("state") or {}).get("visible_to_profile_ids") or [])
            for piece in manifest.get("pieces") or []
            if isinstance(piece, dict)
        ),
        notes_count=len(manifest.get("notes") or []),
        annotations_count=len(manifest.get("annotations") or []),
        synced_at=now,
    )


def _cloud_root() -> Path:
    return settings.storage_path / "cloud_sync"


def _cloud_state_path() -> Path:
    return _cloud_root() / "cloud_state.json"


def _load_cloud_state() -> dict[str, Any]:
    path = _cloud_state_path()
    if not path.exists():
        return {
            "provider": "github",
            "configured": False,
            "connected": False,
            "account_scope": "parent_teacher",
            "branch": "main",
            "path_prefix": "azmusic-sync",
        }
    return json.loads(path.read_text(encoding="utf-8"))


def _save_cloud_state(state: dict[str, Any]) -> None:
    path = _cloud_state_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(state, indent=2, sort_keys=True), encoding="utf-8")


def _status_response(state: dict[str, Any]) -> CloudStatusResponse:
    configured = bool(state.get("configured"))
    repository = state.get("repository")
    connected = bool(state.get("connected")) and bool(repository)
    notes = [
        "Cloud sync is owned by the parent/teacher account.",
        "GitHub is the interim provider; production can replace it with Google.",
        "Student devices restore only their paired profile assignments, notes, and annotations.",
    ]
    if not connected:
        notes.append("Configure a private GitHub repository before relying on cloud restore.")
    return CloudStatusResponse(
        provider=str(state.get("provider") or "github"),
        configured=configured,
        connected=connected,
        repository=repository if isinstance(repository, str) else None,
        branch=str(state.get("branch") or "main"),
        path_prefix=str(state.get("path_prefix") or "azmusic-sync"),
        last_sync_at=_datetime_or_none(state.get("last_sync_at")),
        last_restore_at=_datetime_or_none(state.get("last_restore_at")),
        last_error=state.get("last_error") if isinstance(state.get("last_error"), str) else None,
        notes=notes,
    )


def _load_sync_collection(name: str) -> list[dict[str, Any]]:
    directory = _cloud_root() / name
    if not directory.exists():
        return []
    items: list[dict[str, Any]] = []
    for path in sorted(directory.glob("*.json")):
        payload = json.loads(path.read_text(encoding="utf-8"))
        if isinstance(payload, list):
            items.extend(item for item in payload if isinstance(item, dict))
    return items


def _datetime_or_none(value: object) -> datetime | None:
    if not isinstance(value, str) or not value.strip():
        return None
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        return None


def _sha256_or_none(path: Path) -> str | None:
    if not path.exists():
        return None
    try:
        import hashlib

        return hashlib.sha256(path.read_bytes()).hexdigest()
    except OSError:
        return None

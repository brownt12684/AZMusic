"""Sync endpoint for drawn score annotation layers."""

from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path

from fastapi import APIRouter

from server.config import settings
from server.models.schemas import AnnotationSyncRequest, AnnotationSyncResponse

router = APIRouter()


@router.post("/sync", response_model=AnnotationSyncResponse)
async def sync_annotations(body: AnnotationSyncRequest):
    """Merge client annotation layers into the adult-owned restorable sync store."""
    current = _load_items("annotations", body.profile_id)
    by_id = {item["id"]: dict(item) for item in current if isinstance(item.get("id"), str)}
    for annotation in body.annotations:
        payload = annotation.model_dump(mode="json")
        payload["updated_at"] = payload.get("updated_at") or datetime.utcnow().isoformat()
        by_id[annotation.id] = payload
    items = sorted(by_id.values(), key=lambda item: str(item.get("updated_at") or ""))
    _save_items("annotations", body.profile_id, items)
    return AnnotationSyncResponse(
        client_id=body.client_id,
        profile_id=body.profile_id,
        accepted_count=len(body.annotations),
        annotations=items,
        synced_at=datetime.utcnow(),
    )


def _collection_path(collection: str, profile_id: str) -> Path:
    safe_profile_id = "".join(
        char if char.isalnum() or char in {"-", "_"} else "_"
        for char in profile_id
    )
    return settings.storage_path / "cloud_sync" / collection / f"{safe_profile_id}.json"


def _load_items(collection: str, profile_id: str) -> list[dict]:
    path = _collection_path(collection, profile_id)
    if not path.exists():
        return []
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, list):
        return []
    return [dict(item) for item in payload if isinstance(item, dict)]


def _save_items(collection: str, profile_id: str, items: list[dict]) -> None:
    path = _collection_path(collection, profile_id)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(items, indent=2, sort_keys=True), encoding="utf-8")

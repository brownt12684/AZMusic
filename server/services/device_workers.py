"""Durable registry for experimental on-device processing workers."""

from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path
from typing import Any

from server.config import settings
from server.models.schemas import DeviceWorkerRegistrationRequest, DeviceWorkerResponse


class DeviceWorkerRegistry:
    """JSON-backed registry for devices that can accept experimental work packages."""

    def __init__(self, registry_path: Path | None = None) -> None:
        self._registry_path = registry_path

    @property
    def path(self) -> Path:
        return self._registry_path or settings.storage_path / "device_workers.json"

    def list_workers(self) -> list[DeviceWorkerResponse]:
        return [
            DeviceWorkerResponse(**worker)
            for worker in self._load().values()
        ]

    def register(self, request: DeviceWorkerRegistrationRequest) -> DeviceWorkerResponse:
        workers = self._load()
        now = datetime.utcnow().isoformat()
        existing = workers.get(request.device_id, {})
        worker = {
            "device_id": request.device_id,
            "device_name": request.device_name,
            "platform": request.platform,
            "capabilities": request.capabilities,
            "metadata": request.metadata,
            "enabled": existing.get("enabled", True),
            "registered_at": existing.get("registered_at", now),
            "last_seen_at": now,
        }
        workers[request.device_id] = worker
        self._write(workers)
        return DeviceWorkerResponse(**worker)

    def _load(self) -> dict[str, dict[str, Any]]:
        if not self.path.exists():
            return {}

        try:
            payload = json.loads(self.path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return {}

        if not isinstance(payload, dict):
            return {}
        return {
            str(device_id): dict(worker)
            for device_id, worker in payload.items()
            if isinstance(worker, dict)
        }

    def _write(self, payload: dict[str, dict[str, Any]]) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp_path = self.path.with_suffix(".tmp")
        tmp_path.write_text(
            json.dumps(payload, indent=2, sort_keys=True),
            encoding="utf-8",
        )
        tmp_path.replace(self.path)

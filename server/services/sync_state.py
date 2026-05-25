"""JSON-backed sync banner and retry metadata."""

from __future__ import annotations

import json
import re
from datetime import datetime
from pathlib import Path
from typing import Any

from server.config import settings
from server.models.schemas import SyncStateStatus

_UNSET = object()


class SyncStateMetadataService:
    def load(self, client_id: str) -> dict[str, Any]:
        file_path = self._state_file(client_id)
        if not file_path.exists():
            return {}
        return json.loads(file_path.read_text(encoding="utf-8"))

    def save(self, client_id: str, state: dict[str, Any]) -> dict[str, Any]:
        file_path = self._state_file(client_id)
        file_path.parent.mkdir(parents=True, exist_ok=True)
        file_path.write_text(
            json.dumps(state, indent=2, sort_keys=True),
            encoding="utf-8",
        )
        return state

    def metadata_for_client(self, client_id: str) -> dict[str, Any]:
        state = self.load(client_id)
        return {
            "status": _coerce_status(state.get("status")),
            "retry_required": bool(state.get("retry_required", False)),
            "last_attempt_at": _parse_datetime(state.get("last_attempt_at")),
            "last_success_at": _parse_datetime(state.get("last_success_at")),
            "last_failure_at": _parse_datetime(state.get("last_failure_at")),
            "last_error": state.get("last_error"),
        }

    def update(
        self,
        client_id: str,
        *,
        status: SyncStateStatus | str | None | object = _UNSET,
        retry_required: bool | None | object = _UNSET,
        last_attempt_at: datetime | None | object = _UNSET,
        last_success_at: datetime | None | object = _UNSET,
        last_failure_at: datetime | None | object = _UNSET,
        last_error: str | None | object = _UNSET,
    ) -> dict[str, Any]:
        state = self.load(client_id)
        _update_field(state, "status", status, _serialize_status)
        _update_field(state, "retry_required", retry_required)
        _update_field(state, "last_attempt_at", last_attempt_at, _serialize_datetime)
        _update_field(state, "last_success_at", last_success_at, _serialize_datetime)
        _update_field(state, "last_failure_at", last_failure_at, _serialize_datetime)
        _update_field(state, "last_error", last_error)
        state.setdefault("status", SyncStateStatus.offline_ready.value)
        state["updated_at"] = datetime.utcnow().isoformat()
        return self.save(client_id, state)

    def _state_file(self, client_id: str) -> Path:
        safe_client_id = re.sub(r"[^A-Za-z0-9_.-]+", "_", client_id).strip("._")
        file_name = safe_client_id or "client"
        return settings.storage_path / "sync_state" / f"{file_name}.json"


def _update_field(
    state: dict[str, Any],
    field_name: str,
    value: object,
    serializer=lambda item: item,
) -> None:
    if value is _UNSET:
        return
    state[field_name] = None if value is None else serializer(value)


def _serialize_status(value: SyncStateStatus | str) -> str:
    if isinstance(value, SyncStateStatus):
        return value.value
    return SyncStateStatus(value).value


def _serialize_datetime(value: datetime) -> str:
    return value.isoformat()


def _parse_datetime(value: Any) -> datetime | None:
    if not value:
        return None
    if isinstance(value, datetime):
        return value
    return datetime.fromisoformat(str(value))


def _coerce_status(value: Any) -> SyncStateStatus | None:
    if not value:
        return None
    if isinstance(value, SyncStateStatus):
        return value
    return SyncStateStatus(str(value))

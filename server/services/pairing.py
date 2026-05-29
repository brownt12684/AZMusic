"""Short-lived server pairing codes for family devices."""

from __future__ import annotations

import json
import secrets
import uuid
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any
from urllib.parse import urlencode

from server.config import settings
from server.models.schemas import PairingClaimResponse, PairingCodeResponse

PAIRING_TTL_MINUTES = 10


class PairingService:
    """JSON-backed pairing service for LAN setup and development pairing."""

    def __init__(self, state_path: Path | None = None) -> None:
        self._state_path = state_path

    @property
    def path(self) -> Path:
        return self._state_path or settings.storage_path / "pairing_state.json"

    def create_code(
        self,
        *,
        server_url: str,
        alternate_server_urls: list[str] | None = None,
        qr_png_url: str,
        purpose: str = "student_device",
        profile_id: str | None = None,
        profile_name: str | None = None,
        role: str | None = None,
    ) -> PairingCodeResponse:
        state = self._load()
        now = datetime.utcnow()
        code = _friendly_code()
        expires_at = now + timedelta(minutes=PAIRING_TTL_MINUTES)
        server_id = state["server_id"]
        alternate_server_urls = _clean_alternate_server_urls(
            server_url,
            alternate_server_urls or [],
        )
        pairing_uri = _pairing_uri(
            server_url=server_url,
            alternate_server_urls=alternate_server_urls,
            server_id=server_id,
            pairing_code=code,
            purpose=purpose,
            profile_id=profile_id,
            profile_name=profile_name,
            role=role,
        )
        state["codes"][code] = {
            "server_url": server_url,
            "alternate_server_urls": alternate_server_urls,
            "pairing_uri": pairing_uri,
            "expires_at": expires_at.isoformat(),
            "claimed": False,
            "purpose": purpose,
            "profile_id": profile_id,
            "profile_name": profile_name,
            "role": role,
        }
        self._write(state)

        return PairingCodeResponse(
            server_id=server_id,
            server_name=settings.app_name,
            server_url=server_url,
            alternate_server_urls=alternate_server_urls,
            pairing_code=code,
            pairing_uri=pairing_uri,
            qr_png_url=qr_png_url,
            expires_at=expires_at,
            purpose=purpose,
            profile_id=profile_id,
            profile_name=profile_name,
            role=role,
        )

    def pairing_uri_for_code(self, pairing_code: str) -> str | None:
        state = self._load()
        code_state = state["codes"].get(pairing_code)
        if not code_state or code_state.get("claimed"):
            return None
        expires_at = datetime.fromisoformat(code_state["expires_at"])
        if expires_at < datetime.utcnow():
            return None
        return str(code_state["pairing_uri"])

    def claim_code(
        self,
        *,
        pairing_code: str,
        device_id: str,
        device_name: str,
        platform: str,
    ) -> PairingClaimResponse | None:
        state = self._load()
        code_state = state["codes"].get(pairing_code)
        if not code_state or code_state.get("claimed"):
            return None

        expires_at = datetime.fromisoformat(code_state["expires_at"])
        if expires_at < datetime.utcnow():
            return None

        now = datetime.utcnow()
        device_token = secrets.token_urlsafe(32)
        state["codes"][pairing_code]["claimed"] = True
        state["devices"][device_id] = {
            "device_id": device_id,
            "device_name": device_name,
            "platform": platform,
            "device_token": device_token,
            "paired_at": now.isoformat(),
            "purpose": code_state.get("purpose") or "student_device",
            "profile_id": code_state.get("profile_id"),
            "profile_name": code_state.get("profile_name"),
            "role": code_state.get("role"),
        }
        self._write(state)

        return PairingClaimResponse(
            server_id=state["server_id"],
            server_name=settings.app_name,
            server_url=str(code_state["server_url"]),
            device_id=device_id,
            device_token=device_token,
            paired_at=now,
            purpose=str(code_state.get("purpose") or "student_device"),
            profile_id=code_state.get("profile_id"),
            profile_name=code_state.get("profile_name"),
            role=code_state.get("role"),
        )

    def validate_device_token(self, token: str | None) -> dict[str, Any] | None:
        """Return paired device metadata when a token matches active pairing state."""
        normalized_token = (token or "").strip()
        if not normalized_token:
            return None

        state = self._load()
        for device in state["devices"].values():
            if device.get("device_token") == normalized_token:
                return dict(device)
        return None

    def _load(self) -> dict[str, Any]:
        if not self.path.exists():
            return {
                "server_id": str(uuid.uuid4()),
                "codes": {},
                "devices": {},
            }

        try:
            payload = json.loads(self.path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            payload = {}

        return {
            "server_id": payload.get("server_id") or str(uuid.uuid4()),
            "codes": dict(payload.get("codes") or {}),
            "devices": dict(payload.get("devices") or {}),
        }

    def _write(self, payload: dict[str, Any]) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp_path = self.path.with_suffix(".tmp")
        tmp_path.write_text(
            json.dumps(payload, indent=2, sort_keys=True),
            encoding="utf-8",
        )
        tmp_path.replace(self.path)


def _friendly_code() -> str:
    alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    return "-".join("".join(secrets.choice(alphabet) for _ in range(4)) for _ in range(2))


def _pairing_uri(
    *,
    server_url: str,
    alternate_server_urls: list[str],
    server_id: str,
    pairing_code: str,
    purpose: str,
    profile_id: str | None,
    profile_name: str | None,
    role: str | None,
) -> str:
    payload = {
        "server_url": server_url,
        "alt_server_url": alternate_server_urls,
        "server_id": server_id,
        "code": pairing_code,
        "purpose": purpose,
    }
    if profile_id:
        payload["profile_id"] = profile_id
    if profile_name:
        payload["profile_name"] = profile_name
    if role:
        payload["role"] = role
    return "azmusic://pair?" + urlencode(payload, doseq=True)


def _clean_alternate_server_urls(
    server_url: str,
    alternate_server_urls: list[str],
) -> list[str]:
    primary = server_url.strip().rstrip("/")
    cleaned: list[str] = []
    seen = {primary}
    for url in alternate_server_urls:
        normalized = url.strip().rstrip("/")
        if not normalized or normalized in seen:
            continue
        seen.add(normalized)
        cleaned.append(normalized)
    return cleaned

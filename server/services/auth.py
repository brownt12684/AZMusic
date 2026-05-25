"""Production device-token auth for LAN-paired AZMusic clients."""

from __future__ import annotations

from fastapi import Header, HTTPException, Request

from server.config import settings
from server.services.pairing import PairingService

_pairing_service = PairingService()


async def require_paired_device(
    request: Request,
    authorization: str | None = Header(default=None),
    x_azmusic_device_token: str | None = Header(default=None),
) -> dict | None:
    """Require a QR-paired device token when production auth is enabled."""
    if not settings.require_device_auth:
        return None

    token = _extract_bearer_token(authorization) or x_azmusic_device_token
    device = _pairing_service.validate_device_token(token)
    if device is None:
        raise HTTPException(status_code=401, detail="Paired device token required.")

    request.state.azmusic_device = device
    return device


def _extract_bearer_token(value: str | None) -> str | None:
    if not value:
        return None
    prefix = "bearer "
    if not value.lower().startswith(prefix):
        return None
    token = value[len(prefix) :].strip()
    return token or None

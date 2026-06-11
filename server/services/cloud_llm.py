"""Experimental cloud LLM provider status boundary."""

from __future__ import annotations

from typing import Any

from server.models.schemas import ProcessingExecutableStatus
from server.services.gemini_oauth import GeminiOAuthManager


def cloud_llm_status(settings_payload: dict[str, Any]) -> ProcessingExecutableStatus:
    """Report cloud provider configuration without invoking a model."""
    enabled = bool(settings_payload.get("cloud_enabled"))
    provider = settings_payload.get("cloud_provider") or "gemini"
    model = settings_payload.get("cloud_model") or "gemini-2.5-flash"
    auth_mode = settings_payload.get("cloud_auth_mode") or "oauth"
    api_key_configured = bool(settings_payload.get("cloud_api_key"))

    if provider == "gemini" and auth_mode == "oauth":
        gemini_status = GeminiOAuthManager().status()
        configured = gemini_status.configured
        return ProcessingExecutableStatus(
            name="Gemini Vision Review",
            configured_path="Google OAuth",
            discovered_path="Google OAuth" if gemini_status.connected else None,
            configured=configured,
            available=gemini_status.available,
            version=model,
            error=None if gemini_status.available else gemini_status.error,
        )

    configured = enabled and bool(provider)

    error = None
    if enabled and not provider:
        error = "Cloud processing is enabled but no provider is configured."
    elif enabled and not api_key_configured:
        error = "Cloud processing is enabled but no API key has been saved."
    elif configured:
        error = "Cloud processing provider is configured but adapter execution is experimental."

    return ProcessingExecutableStatus(
        name="Cloud LLM",
        configured_path=provider,
        discovered_path=provider if configured else None,
        configured=configured,
        available=configured and api_key_configured,
        version=model,
        error=error,
    )

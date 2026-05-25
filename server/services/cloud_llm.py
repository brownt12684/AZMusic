"""Experimental cloud LLM provider status boundary."""

from __future__ import annotations

from typing import Any

from server.models.schemas import ProcessingExecutableStatus


def cloud_llm_status(settings_payload: dict[str, Any]) -> ProcessingExecutableStatus:
    """Report cloud provider configuration without making network calls."""
    enabled = bool(settings_payload.get("cloud_enabled"))
    provider = settings_payload.get("cloud_provider")
    model = settings_payload.get("cloud_model")
    api_key_configured = bool(settings_payload.get("cloud_api_key"))
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

"""Local LLM provider abstraction for review reprocessing."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from server.models.schemas import ProcessingExecutableStatus


class LocalLlmUnavailableError(RuntimeError):
    """Raised when a requested local LLM reprocess cannot run."""


@dataclass(slots=True)
class LocalLlmReviewResult:
    suggestions: list[dict[str, Any]]
    warnings: list[str]
    provider: str
    model: str | None


class LocalLlmProvider:
    """Adapter boundary for local model runtimes.

    The first implementation only reports configuration state. Runtime-specific
    clients such as Ollama or LM Studio should plug in behind this interface.
    """

    def __init__(self, settings_payload: dict[str, Any]) -> None:
        self._provider = settings_payload.get("local_llm_provider")
        self._model = settings_payload.get("local_llm_model")

    def status(self) -> ProcessingExecutableStatus:
        configured = bool(self._provider)
        return ProcessingExecutableStatus(
            name="Local LLM",
            configured_path=self._provider,
            discovered_path=self._provider if configured else None,
            configured=configured,
            available=False,
            version=self._model,
            error=None
            if not configured
            else "Local LLM runtime adapter is configured but not implemented yet.",
        )

    def reprocess_review_item(
        self,
        *,
        reprocess_type: str,
        candidate_data: dict[str, Any],
        parent_notes: str | None,
    ) -> LocalLlmReviewResult:
        if not self._provider:
            raise LocalLlmUnavailableError("Local LLM provider is not configured.")
        raise LocalLlmUnavailableError(
            "Local LLM runtime adapter is configured but not implemented yet."
        )


def local_llm_status(settings_payload: dict[str, Any]) -> ProcessingExecutableStatus:
    return LocalLlmProvider(settings_payload).status()

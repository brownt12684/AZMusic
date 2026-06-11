"""Local LLM provider abstraction for review reprocessing."""

from __future__ import annotations

import base64
import io
import json
import mimetypes
import subprocess
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any
from urllib import error, request
from xml.etree import ElementTree as ET

from server.models.schemas import ProcessingExecutableStatus
from server.services.score_mcp_tools import ScoreMcpToolController

LM_STUDIO_DEFAULT_BASE_URL = "http://127.0.0.1:1234/v1"
LM_STUDIO_PROVIDER_ALIASES = {"lmstudio", "lm_studio", "lm studio", "lm-studio"}
LOCAL_LLM_SCORE_REVIEW_PAGE_LIMIT = 2
LOCAL_LLM_SCORE_REVIEW_IMAGE_EDGE = 1600
LOCAL_LLM_SCORE_REVIEW_MUSICXML_CHAR_LIMIT = 30000
LOCAL_LLM_EMBEDDING_MODEL_MARKERS = ("embedding", "embed-text", "nomic-embed")
LOCAL_LLM_VISION_MODEL_MARKERS = (
    "vision",
    "llava",
    "moondream",
    "pixtral",
    "qwen-vl",
    "qwen2-vl",
    "qwen2.5-vl",
    "qwen3-vl",
    "minicpm-v",
    "vlm",
)


class LocalLlmUnavailableError(RuntimeError):
    """Raised when a requested local LLM reprocess cannot run."""


@dataclass(slots=True)
class LocalLlmScoreReviewResult:
    summary: str
    confidence: float | None = None
    tool_calls: list[dict[str, Any]] | None = None
    warnings: list[str] | None = None
    provider: str = "lmstudio"
    model: str | None = None
    raw_response_text: str = ""
    review_status: str = "audit_only"
    notation_findings: list[dict[str, Any]] = field(default_factory=list)
    audit_summary: str | None = None
    vision_model_hint: bool = False
    model_auto_selected: bool = False


@dataclass(slots=True)
class LocalLlmScoreVerificationResult:
    accepted: bool
    confidence: float | None = None
    summary: str = ""
    evidence: str = ""
    warnings: list[str] = field(default_factory=list)
    raw_response_text: str = ""


class LocalLlmProvider:
    """Adapter boundary for local model runtimes."""

    def __init__(self, settings_payload: dict[str, Any]) -> None:
        self._provider = _normalize_provider(settings_payload.get("local_llm_provider"))
        self._model = _normalize_text(settings_payload.get("local_llm_model"))
        self._base_url = _normalize_base_url(
            settings_payload.get("local_llm_base_url"),
            provider=self._provider,
        )

    def status(self, *, probe: bool = False) -> ProcessingExecutableStatus:
        configured = bool(self._provider)
        if not configured:
            return ProcessingExecutableStatus(
                name="Local LLM",
                configured=False,
                available=False,
            )

        if not _is_lm_studio_provider(self._provider):
            return ProcessingExecutableStatus(
                name="Local LLM",
                configured_path=self._provider,
                discovered_path=self._base_url,
                configured=True,
                available=False,
                version=self._model,
                error=(
                    f"Local LLM provider '{self._provider}' is not implemented. "
                    "Choose LM Studio or use an OpenAI-compatible endpoint through LM Studio."
                ),
            )

        try:
            models = self._lm_studio_models()
        except LocalLlmUnavailableError as exc:
            return ProcessingExecutableStatus(
                name="LM Studio",
                configured_path=self._provider,
                discovered_path=self._base_url,
                configured=True,
                available=False,
                version=self._model,
                error=str(exc),
            )

        default_model = self._model or _first_chat_model_id(models)
        if not default_model:
            return ProcessingExecutableStatus(
                name="LM Studio",
                configured_path=self._provider,
                discovered_path=self._base_url,
                configured=True,
                available=False,
                error=(
                    "LM Studio is reachable, but no usable chat model was reported. "
                    "Load a chat or vision model in LM Studio and start the Developer server."
                ),
            )
        if probe:
            try:
                self._probe_lm_studio_chat_model(default_model)
            except LocalLlmUnavailableError as exc:
                return ProcessingExecutableStatus(
                    name="LM Studio",
                    configured_path=self._provider,
                    discovered_path=self._base_url,
                    configured=True,
                    available=False,
                    version=default_model,
                    error=(
                        "LM Studio is reachable, but the selected default model failed "
                        f"a structured chat probe: {exc}"
                    ),
                )

        return ProcessingExecutableStatus(
            name="LM Studio",
            configured_path=self._provider,
            discovered_path=self._base_url,
            configured=True,
            available=True,
            version=default_model,
        )

    def review_score(
        self,
        *,
        raw_pdf_path: Path,
        rendered_pdf_path: Path,
        canonical_musicxml_path: Path,
        candidate_data: dict[str, Any],
        parent_notes: str | None,
    ) -> LocalLlmScoreReviewResult:
        if not self._provider:
            raise LocalLlmUnavailableError("Local LLM provider is not configured.")
        if not _is_lm_studio_provider(self._provider):
            raise LocalLlmUnavailableError(
                f"Local LLM provider '{self._provider}' is not implemented. Choose LM Studio."
            )

        models = self._lm_studio_models()
        model, model_auto_selected, model_warning, vision_model_hint = (
            self._score_review_model(models)
        )
        locator_map = build_musicxml_locator_map(canonical_musicxml_path)
        audit_payload = {
            "model": model,
            "messages": self._score_notation_audit_messages(
                raw_pdf_path=raw_pdf_path,
                rendered_pdf_path=rendered_pdf_path,
                canonical_musicxml_path=canonical_musicxml_path,
                candidate_data=candidate_data,
                parent_notes=parent_notes,
                locator_map=locator_map,
            ),
            "response_format": _score_audit_response_format(),
            "temperature": 0.1,
            "max_tokens": 1200,
            "stream": False,
        }
        audit_response = _http_json_request(
            "POST",
            f"{self._base_url}/chat/completions",
            payload=audit_payload,
            timeout=180,
        )
        audit_content = _chat_response_content(audit_response)
        audit_parsed = _parse_json_response(audit_content)
        notation_findings = _normalize_notation_findings(
            audit_parsed.get("notation_findings")
        )
        audit_warnings = _normalize_warnings(audit_parsed.get("warnings"))
        if model_warning:
            audit_warnings.insert(0, model_warning)

        correction_payload = {
            "model": model,
            "messages": self._score_notation_correction_messages(
                raw_pdf_path=raw_pdf_path,
                rendered_pdf_path=rendered_pdf_path,
                canonical_musicxml_path=canonical_musicxml_path,
                candidate_data=candidate_data,
                parent_notes=parent_notes,
                audit_result={
                    "summary": audit_parsed.get("summary"),
                    "confidence": audit_parsed.get("confidence"),
                    "notation_findings": notation_findings,
                    "warnings": audit_warnings,
                },
                locator_map=locator_map,
            ),
            "response_format": _score_response_format(),
            "temperature": 0.05,
            "max_tokens": 1800,
            "stream": False,
        }
        correction_response = _http_json_request(
            "POST",
            f"{self._base_url}/chat/completions",
            payload=correction_payload,
            timeout=240,
        )
        correction_content = _chat_response_content(correction_response)
        correction_parsed = _parse_json_response(correction_content)
        tool_calls = _normalize_tool_calls(correction_parsed.get("tool_calls"))
        correction_warnings = _normalize_warnings(correction_parsed.get("warnings"))
        warnings = [*audit_warnings, *correction_warnings]
        confidence = correction_parsed.get("confidence")
        try:
            confidence_value = float(confidence)
        except (TypeError, ValueError):
            confidence_value = None
        review_status = "notation_correction_requested" if tool_calls else "no_safe_notation_edit"
        return LocalLlmScoreReviewResult(
            summary=str(
                correction_parsed.get("summary")
                or audit_parsed.get("summary")
                or "Local LLM score review completed."
            ),
            confidence=confidence_value,
            tool_calls=tool_calls,
            warnings=warnings,
            provider="lmstudio",
            model=model,
            raw_response_text="\n\n--- audit ---\n"
            + audit_content
            + "\n\n--- correction ---\n"
            + correction_content,
            review_status=review_status,
            notation_findings=notation_findings,
            audit_summary=str(audit_parsed.get("summary") or ""),
            vision_model_hint=vision_model_hint,
            model_auto_selected=model_auto_selected,
        )

    def retry_score_correction(
        self,
        *,
        raw_pdf_path: Path,
        rendered_pdf_path: Path,
        canonical_musicxml_path: Path,
        candidate_data: dict[str, Any],
        parent_notes: str | None,
        audit_result: dict[str, Any],
        retry_context: dict[str, Any],
    ) -> LocalLlmScoreReviewResult:
        if not self._provider:
            raise LocalLlmUnavailableError("Local LLM provider is not configured.")
        if not _is_lm_studio_provider(self._provider):
            raise LocalLlmUnavailableError(
                f"Local LLM provider '{self._provider}' is not implemented. Choose LM Studio."
            )

        models = self._lm_studio_models()
        model, model_auto_selected, model_warning, vision_model_hint = (
            self._score_review_model(models)
        )
        locator_map = build_musicxml_locator_map(canonical_musicxml_path)
        correction_payload = {
            "model": model,
            "messages": self._score_notation_correction_messages(
                raw_pdf_path=raw_pdf_path,
                rendered_pdf_path=rendered_pdf_path,
                canonical_musicxml_path=canonical_musicxml_path,
                candidate_data=candidate_data,
                parent_notes=parent_notes,
                audit_result=audit_result,
                locator_map=locator_map,
                retry_context=retry_context,
            ),
            "response_format": _score_response_format(),
            "temperature": 0.03,
            "max_tokens": 1800,
            "stream": False,
        }
        correction_response = _http_json_request(
            "POST",
            f"{self._base_url}/chat/completions",
            payload=correction_payload,
            timeout=240,
        )
        correction_content = _chat_response_content(correction_response)
        correction_parsed = _parse_json_response(correction_content)
        tool_calls = _normalize_tool_calls(correction_parsed.get("tool_calls"))
        warnings = _normalize_warnings(correction_parsed.get("warnings"))
        if model_warning:
            warnings.insert(0, model_warning)
        confidence = correction_parsed.get("confidence")
        try:
            confidence_value = float(confidence)
        except (TypeError, ValueError):
            confidence_value = None
        notation_findings = _normalize_notation_findings(
            audit_result.get("notation_findings")
        )
        review_status = "notation_correction_requested" if tool_calls else "no_safe_notation_edit"
        return LocalLlmScoreReviewResult(
            summary=str(
                correction_parsed.get("summary")
                or "Local LLM score correction retry completed."
            ),
            confidence=confidence_value,
            tool_calls=tool_calls,
            warnings=warnings,
            provider="lmstudio",
            model=model,
            raw_response_text="\n\n--- retry correction ---\n" + correction_content,
            review_status=review_status,
            notation_findings=notation_findings,
            audit_summary=str(audit_result.get("summary") or ""),
            vision_model_hint=vision_model_hint,
            model_auto_selected=model_auto_selected,
        )

    def verify_score_edit(
        self,
        *,
        raw_pdf_path: Path,
        before_rendered_pdf_path: Path,
        after_rendered_pdf_path: Path,
        candidate_data: dict[str, Any],
        parent_notes: str | None,
        target_finding: dict[str, Any] | None,
        tool_call: dict[str, Any],
        tool_result: dict[str, Any],
        visual_diff: dict[str, Any],
    ) -> LocalLlmScoreVerificationResult:
        if not self._provider:
            raise LocalLlmUnavailableError("Local LLM provider is not configured.")
        if not _is_lm_studio_provider(self._provider):
            raise LocalLlmUnavailableError(
                f"Local LLM provider '{self._provider}' is not implemented. Choose LM Studio."
            )

        models = self._lm_studio_models()
        model, _, model_warning, _ = self._score_review_model(models)
        payload = {
            "model": model,
            "messages": self._score_edit_verification_messages(
                raw_pdf_path=raw_pdf_path,
                before_rendered_pdf_path=before_rendered_pdf_path,
                after_rendered_pdf_path=after_rendered_pdf_path,
                candidate_data=candidate_data,
                parent_notes=parent_notes,
                target_finding=target_finding,
                tool_call=tool_call,
                tool_result=tool_result,
                visual_diff=visual_diff,
            ),
            "response_format": _score_verification_response_format(),
            "temperature": 0,
            "max_tokens": 700,
            "stream": False,
        }
        response = _http_json_request(
            "POST",
            f"{self._base_url}/chat/completions",
            payload=payload,
            timeout=180,
        )
        content = _chat_response_content(response)
        parsed = _parse_json_response(content)
        confidence = parsed.get("confidence")
        try:
            confidence_value = float(confidence)
        except (TypeError, ValueError):
            confidence_value = None
        warnings = _normalize_warnings(parsed.get("warnings"))
        if model_warning:
            warnings.insert(0, model_warning)
        return LocalLlmScoreVerificationResult(
            accepted=bool(parsed.get("accepted") is True),
            confidence=confidence_value,
            summary=str(parsed.get("summary") or ""),
            evidence=str(parsed.get("evidence") or ""),
            warnings=warnings,
            raw_response_text=content,
        )

    def _lm_studio_models(self) -> list[dict[str, Any]]:
        response = _http_json_request("GET", f"{self._base_url}/models", timeout=4)
        models = response.get("data")
        if not isinstance(models, list):
            raise LocalLlmUnavailableError(
                "LM Studio did not return an OpenAI-compatible /models response."
            )
        return [model for model in models if isinstance(model, dict)]

    def _score_review_model(
        self,
        models: list[dict[str, Any]],
    ) -> tuple[str, bool, str | None, bool]:
        capability_models = _lm_studio_cli_models()
        vision_model = _first_vision_model_id(models, capability_models)
        if self._model:
            resolved_model = _resolve_lm_studio_model_id(self._model, capability_models)
            if _is_model_vision_capable(self._model, models, capability_models):
                return resolved_model or self._model, False, None, True
        if vision_model:
            if self._model and self._model != vision_model:
                return (
                    vision_model,
                    True,
                    (
                        "Configured local LLM model "
                        f"'{self._model}' does not look vision-capable; "
                        f"auto-selected vision model '{vision_model}' for score check."
                    ),
                    True,
                )
            return vision_model, False, None, True
        if self._model:
            raise LocalLlmUnavailableError(
                "Local LLM score check requires a vision-capable model. "
                f"Configured model '{self._model}' does not look vision-capable, "
                "and LM Studio did not report any vision model ids."
            )
        raise LocalLlmUnavailableError(
            "Local LLM score check requires a vision-capable model. "
            "Load a vision model in LM Studio, then run the check again."
        )

    def _probe_lm_studio_chat_model(self, model: str) -> None:
        payload = {
            "model": model,
            "messages": [
                {
                    "role": "system",
                    "content": "Return JSON only.",
                },
                {
                    "role": "user",
                    "content": 'Return {"ok": true, "message": "ready"}.',
                },
            ],
            "response_format": _health_response_format(),
            "temperature": 0,
            "max_tokens": 80,
            "stream": False,
        }
        response = _http_json_request(
            "POST",
            f"{self._base_url}/chat/completions",
            payload=payload,
            timeout=20,
        )
        content = _chat_response_content(response)
        parsed = _parse_json_response(content)
        if parsed.get("ok") is not True:
            raise LocalLlmUnavailableError("LM Studio health probe returned an unexpected body.")

    def _score_notation_audit_messages(
        self,
        *,
        raw_pdf_path: Path,
        rendered_pdf_path: Path,
        canonical_musicxml_path: Path,
        candidate_data: dict[str, Any],
        parent_notes: str | None,
        locator_map: list[dict[str, Any]],
    ) -> list[dict[str, Any]]:
        content = _score_review_content(
            raw_pdf_path=raw_pdf_path,
            rendered_pdf_path=rendered_pdf_path,
            leading_text=_score_audit_prompt(
                canonical_musicxml_path=canonical_musicxml_path,
                candidate_data=candidate_data,
                parent_notes=parent_notes,
                locator_map=locator_map,
            ),
        )
        return [
            {
                "role": "system",
                "content": (
                    "You are a careful sheet-music notation auditor. Return JSON only. "
                    "Compare original score images to the rendered candidate images. "
                    "Report visible notation discrepancies only; ignore catalog metadata."
                ),
            },
            {
                "role": "user",
                "content": content,
            },
        ]

    def _score_notation_correction_messages(
        self,
        *,
        raw_pdf_path: Path,
        rendered_pdf_path: Path,
        canonical_musicxml_path: Path,
        candidate_data: dict[str, Any],
        parent_notes: str | None,
        audit_result: dict[str, Any],
        locator_map: list[dict[str, Any]],
        retry_context: dict[str, Any] | None = None,
    ) -> list[dict[str, Any]]:
        content = _score_review_content(
            raw_pdf_path=raw_pdf_path,
            rendered_pdf_path=rendered_pdf_path,
            leading_text=_score_correction_prompt(
                canonical_musicxml_path=canonical_musicxml_path,
                candidate_data=candidate_data,
                parent_notes=parent_notes,
                audit_result=audit_result,
                locator_map=locator_map,
                retry_context=retry_context,
            ),
        )
        return [
            {
                "role": "system",
                "content": (
                    "You are a careful sheet-music conversion correction agent. "
                    "Return JSON only. Do not include Markdown. Only request safe "
                    "bounded tool calls from the provided schema. If you cannot "
                    "identify the exact MusicXML target safely, return no tool calls."
                ),
            },
            {
                "role": "user",
                "content": content,
            },
        ]

    def _score_edit_verification_messages(
        self,
        *,
        raw_pdf_path: Path,
        before_rendered_pdf_path: Path,
        after_rendered_pdf_path: Path,
        candidate_data: dict[str, Any],
        parent_notes: str | None,
        target_finding: dict[str, Any] | None,
        tool_call: dict[str, Any],
        tool_result: dict[str, Any],
        visual_diff: dict[str, Any],
    ) -> list[dict[str, Any]]:
        content = _score_edit_verification_content(
            raw_pdf_path=raw_pdf_path,
            before_rendered_pdf_path=before_rendered_pdf_path,
            after_rendered_pdf_path=after_rendered_pdf_path,
            leading_text=_score_verification_prompt(
                candidate_data=candidate_data,
                parent_notes=parent_notes,
                target_finding=target_finding,
                tool_call=tool_call,
                tool_result=tool_result,
                visual_diff=visual_diff,
            ),
        )
        return [
            {
                "role": "system",
                "content": (
                    "You are a conservative sheet-music correction verifier. "
                    "Return JSON only. Accept an edit only when the after image "
                    "is visibly closer to the original for the targeted measure."
                ),
            },
            {
                "role": "user",
                "content": content,
            },
        ]


def local_llm_status(settings_payload: dict[str, Any]) -> ProcessingExecutableStatus:
    return LocalLlmProvider(settings_payload).status(probe=True)


def _normalize_provider(value: object) -> str | None:
    text = _normalize_text(value)
    if not text:
        return None
    normalized = text.strip().lower()
    if normalized in LM_STUDIO_PROVIDER_ALIASES:
        return "lmstudio"
    return normalized


def _normalize_base_url(value: object, *, provider: str | None) -> str | None:
    text = _normalize_text(value)
    if not text and _is_lm_studio_provider(provider):
        text = LM_STUDIO_DEFAULT_BASE_URL
    if not text:
        return None
    return text.rstrip("/")


def _normalize_text(value: object) -> str | None:
    if not isinstance(value, str):
        return None
    stripped = value.strip()
    return stripped or None


def _is_lm_studio_provider(provider: str | None) -> bool:
    return bool(provider and provider.lower() == "lmstudio")


def _first_model_id(models: list[dict[str, Any]]) -> str | None:
    for model in models:
        model_id = model.get("id")
        if isinstance(model_id, str) and model_id.strip():
            return model_id.strip()
    return None


def _first_chat_model_id(models: list[dict[str, Any]]) -> str | None:
    for model in models:
        model_id = model.get("id")
        if not isinstance(model_id, str):
            continue
        normalized = model_id.strip()
        if normalized and not _is_embedding_model_id(normalized):
            return normalized
    return None


def _first_vision_model_id(
    models: list[dict[str, Any]],
    capability_models: list[dict[str, Any]] | None = None,
) -> str | None:
    for model in capability_models or []:
        if model.get("vision") is not True:
            continue
        model_id = _preferred_lm_studio_model_id(model)
        if model_id and not _is_embedding_model_id(model_id):
            return model_id
    for model in models:
        model_id = model.get("id")
        if not isinstance(model_id, str):
            continue
        normalized = model_id.strip()
        if normalized and _is_model_vision_capable(
            normalized,
            models,
            capability_models or [],
        ):
            return normalized
    return None


def _is_model_vision_capable(
    model_id: str,
    openai_models: list[dict[str, Any]],
    capability_models: list[dict[str, Any]],
) -> bool:
    capability_match = _find_lm_studio_capability_model(model_id, capability_models)
    if capability_match is not None and "vision" in capability_match:
        return capability_match.get("vision") is True

    openai_match = _find_openai_model(model_id, openai_models)
    if openai_match is not None:
        if isinstance(openai_match.get("vision"), bool):
            return openai_match.get("vision") is True
        capabilities = openai_match.get("capabilities")
        if isinstance(capabilities, list):
            return any(str(capability).lower() == "vision" for capability in capabilities)

    return _is_vision_model_id(model_id)


def _lm_studio_cli_models() -> list[dict[str, Any]]:
    models: list[dict[str, Any]] = []
    seen: set[str] = set()
    for command in (("lms", "ps", "--json"), ("lms", "ls", "--json")):
        try:
            completed = subprocess.run(
                command,
                capture_output=True,
                check=False,
                text=True,
                timeout=5,
            )
        except (OSError, subprocess.SubprocessError):
            continue
        if completed.returncode != 0 or not completed.stdout.strip():
            continue
        try:
            parsed = json.loads(completed.stdout)
        except json.JSONDecodeError:
            continue
        if not isinstance(parsed, list):
            continue
        for item in parsed:
            if not isinstance(item, dict):
                continue
            model_id = _preferred_lm_studio_model_id(item)
            key = _normalize_model_match_key(model_id or json.dumps(item, sort_keys=True))
            if key in seen:
                continue
            seen.add(key)
            models.append(item)
    return models


def _resolve_lm_studio_model_id(
    configured_model: str,
    capability_models: list[dict[str, Any]],
) -> str | None:
    model = _find_lm_studio_capability_model(configured_model, capability_models)
    if model is None:
        return None
    return _preferred_lm_studio_model_id(model)


def _find_lm_studio_capability_model(
    model_id: str,
    capability_models: list[dict[str, Any]],
) -> dict[str, Any] | None:
    for model in capability_models:
        if _lm_studio_model_matches(model_id, model):
            return model
    return None


def _find_openai_model(
    model_id: str,
    openai_models: list[dict[str, Any]],
) -> dict[str, Any] | None:
    normalized = _normalize_model_match_key(model_id)
    for model in openai_models:
        candidate = model.get("id")
        if isinstance(candidate, str) and _normalize_model_match_key(candidate) == normalized:
            return model
    return None


def _preferred_lm_studio_model_id(model: dict[str, Any]) -> str | None:
    for key in ("identifier", "modelKey", "id"):
        value = model.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return None


def _lm_studio_model_matches(configured_model: str, model: dict[str, Any]) -> bool:
    configured = _normalize_model_match_key(configured_model)
    if not configured:
        return False
    for key in (
        "identifier",
        "modelKey",
        "id",
        "path",
        "indexedModelIdentifier",
        "displayName",
    ):
        value = model.get(key)
        if not isinstance(value, str):
            continue
        candidate = _normalize_model_match_key(value)
        if (
            configured == candidate
            or configured.endswith(f"/{candidate}")
            or candidate.endswith(f"/{configured}")
        ):
            return True
    return False


def _normalize_model_match_key(value: str | None) -> str:
    if not value:
        return ""
    normalized = value.strip().replace("\\", "/").lower()
    marker = "/.lmstudio/models/"
    if marker in normalized:
        normalized = normalized.split(marker, 1)[1]
    return normalized.strip("/")


def _is_embedding_model_id(model_id: str) -> bool:
    lowered = model_id.lower()
    return any(marker in lowered for marker in LOCAL_LLM_EMBEDDING_MODEL_MARKERS)


def _is_vision_model_id(model_id: str) -> bool:
    lowered = model_id.lower()
    return any(marker in lowered for marker in LOCAL_LLM_VISION_MODEL_MARKERS)


def _http_json_request(
    method: str,
    url: str,
    *,
    payload: dict[str, Any] | None = None,
    timeout: float,
) -> dict[str, Any]:
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    headers = {"Accept": "application/json"}
    if body is not None:
        headers["Content-Type"] = "application/json"
    http_request = request.Request(url, data=body, headers=headers, method=method)
    try:
        with request.urlopen(http_request, timeout=timeout) as response:  # noqa: S310
            raw = response.read().decode("utf-8", errors="replace")
    except error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")[:500]
        if exc.code == 400 and _payload_contains_image_input(payload):
            raise LocalLlmUnavailableError(
                "LM Studio rejected the image review request (HTTP 400). "
                "Use a vision-capable model in LM Studio's Developer server and "
                "confirm the OpenAI-compatible endpoint accepts image_url inputs. "
                f"Details: {detail or exc.reason}"
            ) from exc
        raise LocalLlmUnavailableError(
            f"LM Studio returned HTTP {exc.code}: {detail or exc.reason}"
        ) from exc
    except (OSError, TimeoutError) as exc:
        raise LocalLlmUnavailableError(
            f"LM Studio is not reachable at {url}. Start LM Studio's Developer server."
        ) from exc
    try:
        decoded = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise LocalLlmUnavailableError("LM Studio returned invalid JSON.") from exc
    if not isinstance(decoded, dict):
        raise LocalLlmUnavailableError("LM Studio returned an unexpected JSON response.")
    return decoded


def _payload_contains_image_input(payload: object) -> bool:
    if isinstance(payload, dict):
        return any(_payload_contains_image_input(value) for value in payload.values())
    if isinstance(payload, list):
        return any(_payload_contains_image_input(value) for value in payload)
    return isinstance(payload, str) and "data:image/" in payload


def _chat_response_content(response: dict[str, Any]) -> str:
    choices = response.get("choices")
    if not isinstance(choices, list) or not choices:
        raise LocalLlmUnavailableError("LM Studio returned no chat choices.")
    first_choice = choices[0]
    if not isinstance(first_choice, dict):
        raise LocalLlmUnavailableError("LM Studio returned an invalid chat choice.")
    message = first_choice.get("message")
    if isinstance(message, dict):
        content = message.get("content")
        if isinstance(content, str) and content.strip():
            return content.strip()
        if isinstance(content, list):
            text_parts = [
                str(part.get("text") or "").strip()
                for part in content
                if isinstance(part, dict) and str(part.get("text") or "").strip()
            ]
            if text_parts:
                return "\n".join(text_parts).strip()
    raise LocalLlmUnavailableError("LM Studio returned an empty chat response.")


def _parse_json_response(content: str) -> dict[str, Any]:
    stripped = content.strip()
    if stripped.startswith("```"):
        stripped = stripped.strip("`")
        if stripped.lower().startswith("json"):
            stripped = stripped[4:].strip()
    errors: list[json.JSONDecodeError] = []
    for candidate in _json_response_candidates(stripped):
        try:
            parsed = json.loads(candidate)
            break
        except json.JSONDecodeError as exc:
            errors.append(exc)
    else:
        raise LocalLlmUnavailableError("LM Studio did not return valid JSON.") from (
            errors[-1] if errors else None
        )
    if not isinstance(parsed, dict):
        raise LocalLlmUnavailableError("LM Studio JSON response must be an object.")
    return parsed


def _json_response_candidates(content: str) -> list[str]:
    candidates = [content]
    start = content.find("{")
    end = content.rfind("}")
    if start >= 0 and end > start:
        candidates.append(content[start : end + 1])

    repaired = []
    for candidate in candidates:
        repaired_candidate = _repair_missing_tool_call_braces(candidate)
        if repaired_candidate != candidate:
            repaired.append(repaired_candidate)
    trailing_repairs = []
    for candidate in [*candidates, *repaired]:
        trailing_candidate = _repair_score_response_after_tool_calls(candidate)
        if trailing_candidate != candidate:
            trailing_repairs.append(trailing_candidate)
    return [*candidates, *repaired, *trailing_repairs]


def _repair_missing_tool_call_braces(content: str) -> str:
    """Repair a common LM Studio JSON-schema failure around nested tool calls.

    Some local models produce the required nested object but close the array as:
    ``"tool_calls":[{"name":"...","arguments":{...}],``. The tool arguments are
    still usable, so we insert only the missing object braces immediately before
    the tool_calls array closes.
    """

    marker_index = content.find('"tool_calls"')
    if marker_index < 0:
        return content
    array_start = content.find("[", marker_index)
    if array_start < 0:
        return content

    in_string = False
    escaped = False
    brace_depth = 0
    bracket_depth = 0
    for index in range(array_start + 1, len(content)):
        char = content[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            continue

        if char == '"':
            in_string = True
        elif char == "{":
            brace_depth += 1
        elif char == "}":
            brace_depth = max(0, brace_depth - 1)
        elif char == "[":
            bracket_depth += 1
        elif char == "]":
            if bracket_depth > 0:
                bracket_depth -= 1
                continue
            if brace_depth > 0:
                return f"{content[:index]}{'}' * brace_depth}{content[index:]}"
            return content
    return content


def _repair_score_response_after_tool_calls(content: str) -> str:
    marker_index = content.find('"tool_calls"')
    if marker_index < 0:
        return content
    array_start = content.find("[", marker_index)
    if array_start < 0:
        return content

    array_end = _json_array_end(content, array_start)
    if array_end is None:
        repaired = _repair_missing_tool_call_braces(content)
        array_end = _json_array_end(repaired, array_start)
        if array_end is None:
            return content
        content = repaired
    prefix = content[: array_end + 1]
    if not prefix.lstrip().startswith("{"):
        return content
    return f'{prefix},"warnings":[]}}'


def _json_array_end(content: str, array_start: int) -> int | None:
    in_string = False
    escaped = False
    bracket_depth = 0
    for index in range(array_start + 1, len(content)):
        char = content[index]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            continue

        if char == '"':
            in_string = True
        elif char == "[":
            bracket_depth += 1
        elif char == "]":
            if bracket_depth > 0:
                bracket_depth -= 1
            else:
                return index
    return None


def _score_audit_response_format() -> dict[str, Any]:
    return _json_schema_response_format(
        name="azmusic_score_notation_audit",
        schema={
            "type": "object",
            "additionalProperties": False,
            "properties": {
                "summary": {"type": "string", "maxLength": 240},
                "confidence": {"type": "number"},
                "notation_findings": {
                    "type": "array",
                    "maxItems": 4,
                    "items": {
                        "type": "object",
                        "additionalProperties": False,
                        "properties": {
                            "finding_id": {"type": "string", "maxLength": 40},
                            "part_id": {"type": "string", "maxLength": 40},
                            "staff": {"type": "string", "maxLength": 20},
                            "voice": {"type": "string", "maxLength": 20},
                            "physical_measure_index": {"type": "integer", "minimum": 0},
                            "measure_number": {"type": "integer", "minimum": 0},
                            "section_title": {"type": "string", "maxLength": 120},
                            "note_index": {"type": "integer", "minimum": 0},
                            "issue": {"type": "string", "maxLength": 300},
                            "evidence": {"type": "string", "maxLength": 300},
                            "severity": {
                                "type": "string",
                                "enum": ["none", "minor", "major"],
                            },
                            "recommended_action": {
                                "type": "string",
                                "maxLength": 300,
                            },
                        },
                        "required": [
                            "finding_id",
                            "part_id",
                            "physical_measure_index",
                            "measure_number",
                            "section_title",
                            "note_index",
                            "issue",
                            "evidence",
                            "severity",
                            "recommended_action",
                        ],
                    },
                },
                "warnings": {
                    "type": "array",
                    "maxItems": 5,
                    "items": {"type": "string", "maxLength": 240},
                },
            },
            "required": ["summary", "confidence", "notation_findings", "warnings"],
        },
    )


def _score_response_format() -> dict[str, Any]:
    return _json_schema_response_format(
        name="azmusic_score_notation_correction",
        schema={
            "type": "object",
            "additionalProperties": False,
            "properties": {
                "summary": {"type": "string", "maxLength": 240},
                "confidence": {"type": "number"},
                "tool_calls": {
                    "type": "array",
                    "maxItems": 3,
                    "items": {
                        "type": "object",
                        "additionalProperties": False,
                        "properties": {
                            "name": {
                                "type": "string",
                                "enum": [
                                    "replace_musicxml_text",
                                    "replace_note_xml",
                                    "update_note_pitch",
                                    "update_note_duration",
                                    "update_rest",
                                    "update_measure_time",
                                    "update_measure_key",
                                    "upsert_direction_words",
                                ],
                            },
                            "arguments": {
                                "type": "object",
                                "additionalProperties": False,
                                "properties": {
                                    "old_text": {"type": "string", "maxLength": 12000},
                                    "new_text": {"type": "string", "maxLength": 12000},
                                    "part_id": {"type": "string", "maxLength": 40},
                                    "staff": {"type": "string", "maxLength": 20},
                                    "voice": {"type": "string", "maxLength": 20},
                                    "physical_measure_index": {
                                        "type": "integer",
                                        "minimum": 1,
                                    },
                                    "measure_number": {"type": "integer", "minimum": 0},
                                    "note_index": {"type": "integer", "minimum": 1},
                                    "note_xml": {"type": "string", "maxLength": 6000},
                                    "step": {"type": "string", "maxLength": 1},
                                    "octave": {"type": "integer"},
                                    "alter": {"type": "integer"},
                                    "duration": {"type": "integer", "minimum": 1},
                                    "type": {"type": "string", "maxLength": 20},
                                    "dots": {"type": "integer", "minimum": 0},
                                    "is_rest": {"type": "boolean"},
                                    "measure_rest": {"type": "boolean"},
                                    "display_step": {"type": "string", "maxLength": 1},
                                    "display_octave": {"type": "integer"},
                                    "beats": {"type": "integer", "minimum": 1},
                                    "beat_type": {"type": "integer", "minimum": 1},
                                    "symbol": {"type": "string", "maxLength": 20},
                                    "text": {"type": "string", "maxLength": 300},
                                    "placement": {"type": "string", "maxLength": 20},
                                    "replace_text": {"type": "string", "maxLength": 300},
                                    "reason": {"type": "string", "maxLength": 240},
                                },
                                "required": ["reason"],
                            },
                        },
                        "required": ["name", "arguments"],
                    },
                },
                "warnings": {
                    "type": "array",
                    "maxItems": 5,
                    "items": {"type": "string", "maxLength": 240},
                },
            },
            "required": ["summary", "confidence", "tool_calls", "warnings"],
        },
    )


def _score_verification_response_format() -> dict[str, Any]:
    return _json_schema_response_format(
        name="azmusic_score_edit_verification",
        schema={
            "type": "object",
            "additionalProperties": False,
            "properties": {
                "accepted": {"type": "boolean"},
                "confidence": {"type": "number"},
                "summary": {"type": "string", "maxLength": 240},
                "evidence": {"type": "string", "maxLength": 360},
                "warnings": {
                    "type": "array",
                    "maxItems": 4,
                    "items": {"type": "string", "maxLength": 240},
                },
            },
            "required": ["accepted", "confidence", "summary", "evidence", "warnings"],
        },
    )


def _health_response_format() -> dict[str, Any]:
    return _json_schema_response_format(
        name="azmusic_lmstudio_health",
        schema={
            "type": "object",
            "additionalProperties": False,
            "properties": {
                "ok": {"type": "boolean"},
                "message": {"type": "string"},
            },
            "required": ["ok", "message"],
        },
    )


def _json_schema_response_format(*, name: str, schema: dict[str, Any]) -> dict[str, Any]:
    return {
        "type": "json_schema",
        "json_schema": {
            "name": name,
            "strict": True,
            "schema": schema,
        },
    }


def _normalize_warnings(value: object) -> list[str]:
    if isinstance(value, str) and value.strip():
        return [value.strip()]
    if not isinstance(value, list):
        return []
    return [str(item).strip() for item in value if str(item).strip()]


def _normalize_tool_calls(value: object) -> list[dict[str, Any]]:
    if not isinstance(value, list):
        return []
    tool_calls: list[dict[str, Any]] = []
    for item in value:
        if not isinstance(item, dict):
            continue
        name = str(item.get("name") or item.get("tool") or "").strip()
        arguments = item.get("arguments") or {}
        if not name or not isinstance(arguments, dict):
            continue
        tool_calls.append({"name": name, "arguments": arguments})
    return tool_calls


def _normalize_notation_findings(value: object) -> list[dict[str, Any]]:
    if isinstance(value, dict):
        value = [value]
    if not isinstance(value, list):
        return []
    findings: list[dict[str, Any]] = []
    for index, item in enumerate(value, start=1):
        if not isinstance(item, dict):
            continue
        issue = str(item.get("issue") or "").strip()
        recommended_action = str(item.get("recommended_action") or "").strip()
        if not issue and not recommended_action:
            continue
        severity = str(item.get("severity") or "minor").strip().lower()
        if severity not in {"none", "minor", "major"}:
            severity = "minor"
        findings.append(
            {
                "finding_id": str(item.get("finding_id") or f"finding-{index}").strip(),
                "part_id": str(item.get("part_id") or "").strip(),
                "staff": str(item.get("staff") or "").strip(),
                "voice": str(item.get("voice") or "").strip(),
                "physical_measure_index": _safe_int(item.get("physical_measure_index")),
                "measure_number": _safe_int(item.get("measure_number")),
                "section_title": str(item.get("section_title") or "").strip(),
                "note_index": _safe_int(item.get("note_index")),
                "issue": issue,
                "evidence": str(item.get("evidence") or "").strip(),
                "severity": severity,
                "recommended_action": recommended_action,
            }
        )
    return findings


def _safe_int(value: object) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


def build_musicxml_locator_map(canonical_musicxml_path: Path) -> list[dict[str, Any]]:
    """Build a compact measure/note address book for LLM-guided corrections."""
    try:
        root = ET.parse(canonical_musicxml_path).getroot()
    except ET.ParseError:
        return []

    locator_map: list[dict[str, Any]] = []
    for part in root.iter():
        if _xml_local_name(part.tag) != "part":
            continue
        part_id = part.get("id") or ""
        if not part_id:
            continue
        current_section = ""
        physical_measure_index = 0
        for measure in part:
            if _xml_local_name(measure.tag) != "measure":
                continue
            physical_measure_index += 1
            direction_words = _measure_direction_words(measure)
            if direction_words:
                current_section = " / ".join(direction_words[:2])
            locator_map.append(
                {
                    "part_id": part_id,
                    "physical_measure_index": physical_measure_index,
                    "measure_number": _safe_int(measure.get("number")),
                    "printed_measure_number": measure.get("number"),
                    "section_title": current_section,
                    "direction_words": direction_words,
                    "attributes": _measure_attributes_summary(measure),
                    "staff_voice_summary": _measure_staff_voice_summary(measure),
                    "notes": _measure_note_summaries(measure),
                }
            )
    return locator_map[:120]


def _measure_direction_words(measure: ET.Element) -> list[str]:
    words: list[str] = []
    for element in measure.iter():
        if _xml_local_name(element.tag) != "words":
            continue
        text = " ".join((element.text or "").split())
        if text:
            words.append(text)
    return words[:6]


def _measure_attributes_summary(measure: ET.Element) -> dict[str, Any]:
    attributes = _xml_first_child(measure, "attributes")
    if attributes is None:
        return {}
    summary: dict[str, Any] = {}
    key = _xml_first_child(attributes, "key")
    if key is not None:
        summary["key_fifths"] = _xml_child_text(key, "fifths")
    time = _xml_first_child(attributes, "time")
    if time is not None:
        beats = _xml_child_text(time, "beats")
        beat_type = _xml_child_text(time, "beat-type")
        if beats and beat_type:
            summary["time"] = f"{beats}/{beat_type}"
    clef = _xml_first_child(attributes, "clef")
    if clef is not None:
        sign = _xml_child_text(clef, "sign")
        line = _xml_child_text(clef, "line")
        if sign:
            summary["clef"] = f"{sign}{line or ''}"
    return summary


def _measure_note_summaries(measure: ET.Element) -> list[dict[str, Any]]:
    notes = [child for child in measure if _xml_local_name(child.tag) == "note"]
    staff_counters: dict[str, int] = {}
    voice_counters: dict[str, int] = {}
    staff_voice_counters: dict[str, int] = {}
    summaries: list[dict[str, Any]] = []
    for note_index, note in enumerate(notes, start=1):
        staff = _xml_child_text(note, "staff") or ""
        voice = _xml_child_text(note, "voice") or ""
        staff_key = staff or "unspecified"
        voice_key = voice or "unspecified"
        staff_voice_key = f"{staff_key}:{voice_key}"
        staff_counters[staff_key] = staff_counters.get(staff_key, 0) + 1
        voice_counters[voice_key] = voice_counters.get(voice_key, 0) + 1
        staff_voice_counters[staff_voice_key] = staff_voice_counters.get(staff_voice_key, 0) + 1
        summaries.append(
            {
                "note_index": note_index,
                "staff_note_index": staff_counters[staff_key],
                "voice_note_index": voice_counters[voice_key],
                "staff_voice_note_index": staff_voice_counters[staff_voice_key],
                "kind": "rest" if _xml_first_child(note, "rest") is not None else "note",
                "measure_rest": _note_is_measure_rest(note),
                "pitch": _note_pitch_summary(note),
                "duration": _xml_child_text(note, "duration"),
                "type": _xml_child_text(note, "type"),
                "voice": voice,
                "staff": staff,
            }
        )
    return summaries[:16]


def _measure_staff_voice_summary(measure: ET.Element) -> dict[str, Any]:
    notes = [child for child in measure if _xml_local_name(child.tag) == "note"]
    staff_values = sorted(
        {
            staff
            for note in notes
            if (staff := _xml_child_text(note, "staff")) not in (None, "")
        }
    )
    voice_values = sorted(
        {
            voice
            for note in notes
            if (voice := _xml_child_text(note, "voice")) not in (None, "")
        }
    )
    return {
        "staffs": staff_values,
        "voices": voice_values,
        "requires_staff": len(staff_values) > 1,
        "requires_voice": len(voice_values) > 1,
        "note_count": len(notes),
        "rest_count": sum(1 for note in notes if _xml_first_child(note, "rest") is not None),
    }


def _note_is_measure_rest(note: ET.Element) -> bool:
    rest = _xml_first_child(note, "rest")
    return bool(rest is not None and rest.get("measure") == "yes")


def _note_pitch_summary(note: ET.Element) -> str | None:
    pitch = _xml_first_child(note, "pitch")
    if pitch is None:
        return None
    step = _xml_child_text(pitch, "step") or "?"
    alter = _xml_child_text(pitch, "alter") or ""
    octave = _xml_child_text(pitch, "octave") or "?"
    return f"{step}{alter}{octave}"


def _xml_local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1] if "}" in tag else tag


def _xml_first_child(element: ET.Element, name: str) -> ET.Element | None:
    for child in element:
        if _xml_local_name(child.tag) == name:
            return child
    return None


def _xml_child_text(element: ET.Element, name: str) -> str | None:
    child = _xml_first_child(element, name)
    if child is None or child.text is None:
        return None
    text = child.text.strip()
    return text or None


def _compact_candidate_data(candidate_data: dict[str, Any]) -> dict[str, Any]:
    allowed_keys = {
        "catalog_metadata",
        "processed_metadata",
        "catalog_suggestions",
        "validation_warnings",
        "title",
        "composer",
        "primary_instrument",
        "book_or_collection",
        "contained_piece_titles",
        "source_page_start",
        "source_page_end",
        "source_file_name",
        "ocr_metadata",
        "raw_ocr_text",
    }
    compact = {
        key: value
        for key, value in candidate_data.items()
        if key in allowed_keys and value not in (None, "", [])
    }
    encoded = json.dumps(compact, sort_keys=True, default=str)
    if len(encoded) <= 9000:
        return compact
    compact.pop("raw_ocr_text", None)
    compact["truncated"] = True
    return compact


def _score_review_content(
    *,
    raw_pdf_path: Path,
    rendered_pdf_path: Path,
    leading_text: str,
) -> list[dict[str, Any]]:
    content: list[dict[str, Any]] = [{"type": "text", "text": leading_text}]
    for label, file_path in (
        ("Original score", raw_pdf_path),
        ("Rendered MuseScore candidate", rendered_pdf_path),
    ):
        for image in _score_review_image_inputs(file_path, label=label):
            content.append({"type": "text", "text": image["label"]})
            content.append(
                {
                    "type": "image_url",
                    "image_url": {"url": image["data_url"]},
                }
            )
    return content


def _score_edit_verification_content(
    *,
    raw_pdf_path: Path,
    before_rendered_pdf_path: Path,
    after_rendered_pdf_path: Path,
    leading_text: str,
) -> list[dict[str, Any]]:
    content: list[dict[str, Any]] = [{"type": "text", "text": leading_text}]
    for label, file_path in (
        ("Original score", raw_pdf_path),
        ("Rendered candidate before this edit", before_rendered_pdf_path),
        ("Rendered candidate after this edit", after_rendered_pdf_path),
    ):
        for image in _score_review_image_inputs(file_path, label=label):
            content.append({"type": "text", "text": image["label"]})
            content.append(
                {
                    "type": "image_url",
                    "image_url": {"url": image["data_url"]},
                }
            )
    return content


def _score_audit_prompt(
    *,
    canonical_musicxml_path: Path,
    candidate_data: dict[str, Any],
    parent_notes: str | None,
    locator_map: list[dict[str, Any]],
) -> str:
    musicxml_text = canonical_musicxml_path.read_text(encoding="utf-8", errors="replace")
    if len(musicxml_text) > LOCAL_LLM_SCORE_REVIEW_MUSICXML_CHAR_LIMIT:
        musicxml_text = musicxml_text[:LOCAL_LLM_SCORE_REVIEW_MUSICXML_CHAR_LIMIT]
    metadata = {
        "piece_title": candidate_data.get("piece_title"),
        "catalog_metadata": candidate_data.get("catalog_metadata"),
        "processed_metadata": candidate_data.get("processed_metadata"),
        "engine_name": candidate_data.get("engine_name"),
        "engine_version": candidate_data.get("engine_version"),
        "render_diagnostics": candidate_data.get("render_diagnostics"),
        "warnings": candidate_data.get("warnings"),
    }
    return (
        "You are auditing a score conversion for AZMusic.\n"
        "Compare original score images to the rendered MuseScore candidate images. "
        "Identify visible notation discrepancies only: missing notes, wrong note "
        "heads, wrong/rest durations, wrong rests, wrong time/key/clef, missing "
        "visible direction text, or obvious measure structure errors. Ignore "
        "catalog metadata, part names, title spelling, composer, and instrument "
        "labels unless they change visible notation on the page.\n\n"
        "Return JSON only. Include up to four specific findings. If the exact "
        "part, physical_measure_index, or note index is unknown, use an empty "
        "part_id and 0 for physical_measure_index, measure_number, or note_index. "
        "When printed measure numbers repeat, physical_measure_index from the "
        "locator map is the only valid measure address.\n\n"
        "Parent notes:\n"
        f"{parent_notes or 'None'}\n\n"
        "Candidate metadata:\n"
        f"{json.dumps(metadata, indent=2, default=str)}\n\n"
        "MusicXML locator map. Use this as the only valid address book for "
        "part_id, physical_measure_index, printed measure_number, section/title, "
        "staff, voice, and note/rest indexes. When staff_voice_summary says "
        "requires_staff or requires_voice, include those fields in findings and "
        "tool calls or report the issue as ambiguous instead of editing:\n"
        f"{json.dumps(locator_map, indent=2, default=str)}\n\n"
        "Return JSON with this shape:\n"
        "{"
        '"summary":"what you checked",'
        '"confidence":0.0,'
        '"notation_findings":[{"finding_id":"f1","part_id":"P1",'
        '"staff":"2","voice":"1","physical_measure_index":9,'
        '"measure_number":1,"section_title":"Hoedown",'
        '"note_index":1,"issue":"wrong rest",'
        '"evidence":"original shows rest, candidate shows note",'
        '"severity":"major","recommended_action":"replace note with rest"}],'
        '"warnings":["parent-visible issue"]'
        "}\n\n"
        "Current MusicXML excerpt for locating measures only:\n"
        "```xml\n"
        f"{musicxml_text}\n"
        "```"
    )


def _score_verification_prompt(
    *,
    candidate_data: dict[str, Any],
    parent_notes: str | None,
    target_finding: dict[str, Any] | None,
    tool_call: dict[str, Any],
    tool_result: dict[str, Any],
    visual_diff: dict[str, Any],
) -> str:
    metadata = {
        "piece_title": candidate_data.get("piece_title"),
        "catalog_metadata": candidate_data.get("catalog_metadata"),
        "processed_metadata": candidate_data.get("processed_metadata"),
    }
    return (
        "Verify one attempted AZMusic score correction.\n"
        "You will see the original score, the rendered candidate before this "
        "edit, and the rendered candidate after this edit. Accept only if the "
        "after image is visibly closer to the original for the targeted measure "
        "and the edit did not introduce an obvious new notation problem. Reject "
        "if the target is unclear, if the before image was already closer, if "
        "the after image merely changed but is not closer, or if you are unsure.\n\n"
        "Parent notes:\n"
        f"{parent_notes or 'None'}\n\n"
        "Candidate metadata:\n"
        f"{json.dumps(metadata, indent=2, default=str)}\n\n"
        "Target finding:\n"
        f"{json.dumps(target_finding or {}, indent=2, default=str)}\n\n"
        "Attempted tool call:\n"
        f"{json.dumps(tool_call, indent=2, default=str)}\n\n"
        "Tool result:\n"
        f"{json.dumps(tool_result, indent=2, default=str)}\n\n"
        "Rendered visual diff:\n"
        f"{json.dumps(visual_diff, indent=2, default=str)}\n\n"
        "Return JSON only with this shape:\n"
        "{"
        '"accepted":false,'
        '"confidence":0.0,'
        '"summary":"short decision",'
        '"evidence":"what changed and whether it is closer",'
        '"warnings":["parent-visible issue"]'
        "}"
    )


def _score_correction_prompt(
    *,
    canonical_musicxml_path: Path,
    candidate_data: dict[str, Any],
    parent_notes: str | None,
    audit_result: dict[str, Any],
    locator_map: list[dict[str, Any]],
    retry_context: dict[str, Any] | None = None,
) -> str:
    musicxml_text = canonical_musicxml_path.read_text(encoding="utf-8", errors="replace")
    if len(musicxml_text) > LOCAL_LLM_SCORE_REVIEW_MUSICXML_CHAR_LIMIT:
        musicxml_text = musicxml_text[:LOCAL_LLM_SCORE_REVIEW_MUSICXML_CHAR_LIMIT]
    metadata = {
        "piece_title": candidate_data.get("piece_title"),
        "catalog_metadata": candidate_data.get("catalog_metadata"),
        "processed_metadata": candidate_data.get("processed_metadata"),
        "engine_name": candidate_data.get("engine_name"),
        "engine_version": candidate_data.get("engine_version"),
        "render_diagnostics": candidate_data.get("render_diagnostics"),
        "warnings": candidate_data.get("warnings"),
    }
    return (
        "You are correcting a MusicXML score conversion for AZMusic.\n"
        "Use the audit findings and the original/rendered images to request safe "
        "bounded MusicXML tool calls. Prefer structured tools over "
        "replace_musicxml_text. Return at most three tool calls. Each tool call "
        "must target a visible notation problem. Do not request metadata-only, "
        "instrument-name-only, title-only, composer-only, or style-only changes. "
        "If you cannot identify the exact MusicXML target safely, return an empty "
        "tool_calls array and explain the manual review need in warnings.\n\n"
        "For note tools, note_index is 1-based among <note> elements in the "
        "target measure, or 1-based among the matching staff/voice when staff "
        "and/or voice are supplied. Use physical_measure_index from the locator "
        "map whenever available. If the locator says requires_staff or "
        "requires_voice, include staff and voice from the locator map in the tool "
        "arguments. Never use printed measure_number alone when measure numbers "
        "repeat in the same part. Never use 0 in a correction tool call; if the "
        "exact note index, staff/voice, or physical measure is unknown, do not "
        "request a note/rest tool. For update_measure_time/key, target the first "
        "physical measure where "
        "the attribute should appear. replace_musicxml_text old_text must be copied "
        "from the Current MusicXML block only.\n\n"
        "Available tools:\n"
        f"{json.dumps(ScoreMcpToolController.tool_definitions(), indent=2)}\n\n"
        "Parent notes:\n"
        f"{parent_notes or 'None'}\n\n"
        "Audit result:\n"
        f"{json.dumps(audit_result, indent=2, default=str)}\n\n"
        "Retry context from the previous failed tool attempt:\n"
        f"{json.dumps(retry_context or {}, indent=2, default=str)}\n\n"
        "Candidate metadata:\n"
        f"{json.dumps(metadata, indent=2, default=str)}\n\n"
        "MusicXML locator map. Use this as the only valid address book for "
        "correction tool targets:\n"
        f"{json.dumps(locator_map, indent=2, default=str)}\n\n"
        "Return JSON with this shape:\n"
        "{"
        '"summary":"what notation edit you requested",'
        '"confidence":0.0,'
        '"tool_calls":[{"name":"update_note_pitch","arguments":{'
        '"part_id":"P1","staff":"2","voice":"1",'
        '"physical_measure_index":9,"measure_number":1,"note_index":1,'
        '"step":"D","octave":4,"reason":"match original pitch"}}],'
        '"warnings":["parent-visible issue"]'
        "}\n\n"
        "Current MusicXML:\n"
        "```xml\n"
        f"{musicxml_text}\n"
        "```"
    )


def _score_review_image_inputs(path: Path, *, label: str) -> list[dict[str, str]]:
    if not path.exists():
        raise LocalLlmUnavailableError(f"Local LLM check cannot find {label}: {path}")
    suffix = path.suffix.lower()
    if suffix == ".pdf":
        return _pdf_page_image_inputs(path, label=label)
    if suffix in {".png", ".jpg", ".jpeg", ".webp"}:
        return [
            {
                "label": f"{label} image",
                "data_url": _image_file_data_url(path),
            }
        ]
    mime_type = mimetypes.guess_type(path.name)[0]
    if mime_type and mime_type.startswith("image/"):
        return [
            {
                "label": f"{label} image",
                "data_url": _image_file_data_url(path, mime_type=mime_type),
            }
        ]
    raise LocalLlmUnavailableError(f"Local LLM check cannot read {label} file type: {path.name}")


def _pdf_page_image_inputs(path: Path, *, label: str) -> list[dict[str, str]]:
    try:
        import pypdfium2 as pdfium
    except Exception as exc:  # noqa: BLE001
        raise LocalLlmUnavailableError(
            "Local LLM score checks require pypdfium2 to render PDF pages."
        ) from exc

    try:
        document = pdfium.PdfDocument(str(path))
    except Exception as exc:  # noqa: BLE001
        raise LocalLlmUnavailableError(f"Local LLM check could not open {label}: {exc}") from exc

    page_count = min(len(document), LOCAL_LLM_SCORE_REVIEW_PAGE_LIMIT)
    images: list[dict[str, str]] = []
    try:
        for page_index in range(page_count):
            page = document[page_index]
            try:
                bitmap = page.render(scale=1.5)
                pil_image = bitmap.to_pil()
                pil_image.thumbnail(
                    (
                        LOCAL_LLM_SCORE_REVIEW_IMAGE_EDGE,
                        LOCAL_LLM_SCORE_REVIEW_IMAGE_EDGE,
                    )
                )
                buffer = io.BytesIO()
                pil_image.save(buffer, format="PNG", optimize=True)
                data_url = "data:image/png;base64," + base64.b64encode(buffer.getvalue()).decode(
                    "ascii"
                )
                images.append(
                    {
                        "label": f"{label} page {page_index + 1}",
                        "data_url": data_url,
                    }
                )
            finally:
                close = getattr(page, "close", None)
                if callable(close):
                    close()
    finally:
        close = getattr(document, "close", None)
        if callable(close):
            close()

    if not images:
        raise LocalLlmUnavailableError(f"Local LLM check found no pages in {label}.")
    return images


def _image_file_data_url(path: Path, mime_type: str | None = None) -> str:
    mime_type = mime_type or mimetypes.guess_type(path.name)[0] or "image/png"
    data = path.read_bytes()
    return f"data:{mime_type};base64,{base64.b64encode(data).decode('ascii')}"

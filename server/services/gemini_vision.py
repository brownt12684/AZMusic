"""Gemini vision adapter for parent-triggered score review."""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from server.services.gemini_oauth import GeminiOAuthError, GeminiOAuthManager
from server.services.score_mcp_tools import ScoreMcpToolController


class GeminiVisionReviewError(RuntimeError):
    """Raised when Gemini vision review cannot produce safe tool calls."""


@dataclass(slots=True)
class GeminiVisionReviewResult:
    summary: str
    confidence: float | None = None
    tool_calls: list[dict[str, Any]] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    raw_response_text: str = ""


class GeminiVisionReviewAdapter:
    """Calls Gemini with the original PDF, rendered candidate, and MusicXML."""

    def __init__(self, oauth_manager: GeminiOAuthManager | None = None) -> None:
        self._oauth_manager = oauth_manager or GeminiOAuthManager()

    def review_score(
        self,
        *,
        raw_pdf_path: Path,
        rendered_pdf_path: Path,
        canonical_musicxml_path: Path,
        candidate_data: dict[str, Any],
        parent_notes: str | None,
    ) -> GeminiVisionReviewResult:
        credentials_bundle = self._oauth_manager.load_credentials(refresh=True)
        client = self._new_client(credentials_bundle.credentials)
        prompt = _score_review_prompt(
            canonical_musicxml_path=canonical_musicxml_path,
            candidate_data=candidate_data,
            parent_notes=parent_notes,
        )
        contents: list[Any] = [prompt]
        uploaded_files = []
        for file_path, mime_type in (
            (raw_pdf_path, "application/pdf"),
            (rendered_pdf_path, "application/pdf"),
        ):
            if file_path.exists() and file_path.stat().st_size <= 50 * 1024 * 1024:
                try:
                    uploaded_files.append(
                        client.files.upload(
                            file=str(file_path),
                            config={"mime_type": mime_type},
                        )
                    )
                except TypeError:
                    uploaded_files.append(client.files.upload(file=str(file_path)))
        contents.extend(uploaded_files)
        try:
            response = client.models.generate_content(
                model=credentials_bundle.model,
                contents=contents,
            )
        except Exception as exc:  # noqa: BLE001
            raise GeminiVisionReviewError(f"Gemini vision review failed: {exc}") from exc
        response_text = str(getattr(response, "text", "") or "").strip()
        if not response_text:
            raise GeminiVisionReviewError("Gemini returned an empty score review response.")
        payload = _extract_json_payload(response_text)
        tool_calls = payload.get("tool_calls") or []
        if not isinstance(tool_calls, list):
            raise GeminiVisionReviewError("Gemini returned malformed tool_calls.")
        warnings = payload.get("warnings") or []
        if not isinstance(warnings, list):
            warnings = [str(warnings)]
        confidence = payload.get("confidence")
        return GeminiVisionReviewResult(
            summary=str(payload.get("summary") or "Gemini score review completed."),
            confidence=float(confidence) if isinstance(confidence, (int, float)) else None,
            tool_calls=[call for call in tool_calls if isinstance(call, dict)],
            warnings=[str(warning) for warning in warnings],
            raw_response_text=response_text,
        )

    def _new_client(self, credentials: Any) -> Any:
        try:
            from google import genai
        except Exception as exc:  # noqa: BLE001
            raise GeminiVisionReviewError(
                "Gemini SDK is not installed. Install google-genai in the server package."
            ) from exc
        try:
            return genai.Client(credentials=credentials)
        except TypeError as exc:
            raise GeminiVisionReviewError(
                "Installed google-genai package does not support OAuth credentials."
            ) from exc


def _score_review_prompt(
    *,
    canonical_musicxml_path: Path,
    candidate_data: dict[str, Any],
    parent_notes: str | None,
) -> str:
    musicxml_text = canonical_musicxml_path.read_text(encoding="utf-8", errors="replace")
    if len(musicxml_text) > 60000:
        musicxml_text = musicxml_text[:60000]
    metadata = {
        "piece_title": candidate_data.get("piece_title"),
        "catalog_metadata": candidate_data.get("catalog_metadata"),
        "processed_metadata": candidate_data.get("processed_metadata"),
        "engine_name": candidate_data.get("engine_name"),
        "engine_version": candidate_data.get("engine_version"),
        "render_diagnostics": candidate_data.get("render_diagnostics"),
        "warnings": candidate_data.get("warnings"),
    }
    tool_definitions = ScoreMcpToolController.tool_definitions()
    return (
        "You are reviewing a music score conversion for AZMusic.\n"
        "Compare the original PDF with the rendered MuseScore candidate and the "
        "MusicXML below. If the MusicXML needs correction, return JSON only using "
        "the available tool call schema. Do not invent unsupported tools. If no safe "
        "exact MusicXML replacement is possible, return an empty tool_calls array "
        "with warnings explaining what the parent should edit manually.\n\n"
        "Available tools:\n"
        f"{json.dumps(tool_definitions, indent=2)}\n\n"
        "Parent notes:\n"
        f"{parent_notes or 'None'}\n\n"
        "Candidate metadata:\n"
        f"{json.dumps(metadata, indent=2, default=str)}\n\n"
        "Return JSON with this shape:\n"
        "{"
        '"summary":"what you checked",'
        '"confidence":0.0,'
        '"tool_calls":[{"name":"replace_musicxml_text","arguments":{'
        '"old_text":"exact existing XML fragment",'
        '"new_text":"replacement XML fragment",'
        '"reason":"why"}}],'
        '"warnings":["parent-visible issue"]'
        "}\n\n"
        "Current MusicXML:\n"
        "```xml\n"
        f"{musicxml_text}\n"
        "```"
    )


def _extract_json_payload(response_text: str) -> dict[str, Any]:
    text = response_text.strip()
    if text.startswith("```"):
        lines = text.splitlines()
        if lines and lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].strip() == "```":
            lines = lines[:-1]
        text = "\n".join(lines).strip()
    start = text.find("{")
    end = text.rfind("}")
    if start == -1 or end == -1 or end <= start:
        raise GeminiVisionReviewError("Gemini response did not contain a JSON object.")
    try:
        payload = json.loads(text[start : end + 1])
    except json.JSONDecodeError as exc:
        raise GeminiVisionReviewError(f"Gemini response JSON was invalid: {exc}") from exc
    if not isinstance(payload, dict):
        raise GeminiVisionReviewError("Gemini response JSON was not an object.")
    return payload


def gemini_unavailable_message(exc: Exception) -> str:
    if isinstance(exc, (GeminiOAuthError, GeminiVisionReviewError)):
        return str(exc)
    return f"Gemini vision review is unavailable: {exc}"

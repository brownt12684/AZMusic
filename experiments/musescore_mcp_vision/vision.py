"""LM Studio vision call for one-measure notation facts."""

from __future__ import annotations

import base64
import json
import mimetypes
from pathlib import Path
from typing import Any
from urllib import error, request

from .measure_schema import load_measure_schema, validate_measure_facts


class VisionAnalysisError(RuntimeError):
    """Raised when the vision model cannot produce usable measure facts."""


def analyze_measure_image(
    *,
    image_path: Path,
    source: dict[str, Any],
    lm_studio_config: dict[str, Any],
    raw_response_path: Path,
    output_path: Path,
) -> dict[str, Any]:
    base_url = str(lm_studio_config.get("base_url") or "").rstrip("/")
    if not base_url:
        raise VisionAnalysisError("lm_studio.base_url is required.")
    model = str(lm_studio_config.get("model") or "").strip() or _default_model(base_url)
    if not model:
        raise VisionAnalysisError("LM Studio did not report a usable model.")

    payload = {
        "model": model,
        "messages": [
            {
                "role": "system",
                "content": (
                    "You are a conservative music notation reader. Return JSON only. "
                    "Read the single cropped measure image and describe only visible facts. "
                    "If uncertain, keep confidence low and explain uncertainty."
                ),
            },
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": _analysis_prompt(source)},
                    {
                        "type": "image_url",
                        "image_url": {"url": _data_url(image_path)},
                    },
                ],
            },
        ],
        "response_format": {
            "type": "json_schema",
            "json_schema": {
                "name": "azmusic_measure_facts",
                "strict": True,
                "schema": load_measure_schema(),
            },
        },
        "temperature": float(lm_studio_config.get("temperature", 0.0)),
        "max_tokens": int(lm_studio_config.get("max_tokens", 1600)),
        "stream": False,
    }
    response = _http_json("POST", f"{base_url}/chat/completions", payload=payload, timeout=90)
    raw_response_path.parent.mkdir(parents=True, exist_ok=True)
    raw_response_path.write_text(json.dumps(response, indent=2), encoding="utf-8")
    facts = _parse_chat_json(response)
    # The model should return these fields, but the experiment owns provenance.
    facts["schema_version"] = "azmusic.musescore_mcp_vision.measure_facts.v1"
    facts["source"] = source
    validate_measure_facts(facts)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(facts, indent=2), encoding="utf-8")
    return facts


def _analysis_prompt(source: dict[str, Any]) -> str:
    return (
        "Analyze this single measure crop from a cello score. Identify: "
        "time signature, note/rest sequence, pitch, duration, accidentals, articulations, "
        "ties/slurs, dynamics/text, and fingering numbers. Use 1-based event_index values "
        "for fingerings. Do not infer beyond what is visible. Return JSON matching the "
        "provided schema.\n\n"
        f"Source context:\n{json.dumps(source, indent=2)}"
    )


def _default_model(base_url: str) -> str | None:
    try:
        response = _http_json("GET", f"{base_url}/models", timeout=20)
    except VisionAnalysisError:
        return None
    data = response.get("data")
    if not isinstance(data, list):
        return None
    for item in data:
        if not isinstance(item, dict):
            continue
        model_id = item.get("id")
        if not isinstance(model_id, str) or not model_id.strip():
            continue
        lowered = model_id.lower()
        if "embedding" in lowered or "embed" in lowered:
            continue
        return model_id.strip()
    return None


def _data_url(path: Path) -> str:
    mime = mimetypes.guess_type(path.name)[0] or "image/png"
    encoded = base64.b64encode(path.read_bytes()).decode("ascii")
    return f"data:{mime};base64,{encoded}"


def _http_json(
    method: str,
    url: str,
    *,
    payload: dict[str, Any] | None = None,
    timeout: int = 30,
) -> dict[str, Any]:
    data = None
    headers = {"Accept": "application/json"}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = request.Request(url, method=method, data=data, headers=headers)
    try:
        with request.urlopen(req, timeout=timeout) as response:
            body = response.read().decode("utf-8")
    except error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise VisionAnalysisError(f"LM Studio returned HTTP {exc.code}: {detail}") from exc
    except error.URLError as exc:
        raise VisionAnalysisError(f"LM Studio is not reachable at {url}: {exc}") from exc
    try:
        parsed = json.loads(body)
    except json.JSONDecodeError as exc:
        raise VisionAnalysisError("LM Studio returned invalid JSON.") from exc
    if not isinstance(parsed, dict):
        raise VisionAnalysisError("LM Studio returned a non-object JSON response.")
    return parsed


def _parse_chat_json(response: dict[str, Any]) -> dict[str, Any]:
    choices = response.get("choices")
    if not isinstance(choices, list) or not choices:
        raise VisionAnalysisError("LM Studio returned no choices.")
    message = choices[0].get("message") if isinstance(choices[0], dict) else None
    content = message.get("content") if isinstance(message, dict) else None
    if isinstance(content, list):
        content = "".join(str(item.get("text") or "") for item in content if isinstance(item, dict))
    if not isinstance(content, str) or not content.strip():
        raise VisionAnalysisError("LM Studio returned an empty response.")
    try:
        parsed = json.loads(_strip_json_fence(content))
    except json.JSONDecodeError as exc:
        raise VisionAnalysisError("LM Studio response was not valid measure JSON.") from exc
    if not isinstance(parsed, dict):
        raise VisionAnalysisError("LM Studio measure JSON must be an object.")
    return parsed


def _strip_json_fence(content: str) -> str:
    stripped = content.strip()
    if stripped.startswith("```"):
        lines = stripped.splitlines()
        if lines and lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].startswith("```"):
            lines = lines[:-1]
        return "\n".join(lines).strip()
    if not stripped.startswith("{"):
        start = stripped.find("{")
        end = stripped.rfind("}")
        if start >= 0 and end > start:
            return stripped[start : end + 1]
    return stripped

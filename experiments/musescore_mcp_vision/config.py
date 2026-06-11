"""Configuration helpers for the MuseScore MCP vision experiment."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


EXPERIMENT_ROOT = Path(__file__).resolve().parent
DEFAULT_CONFIG_PATH = EXPERIMENT_ROOT / "config.local.json"


class ExperimentConfigError(RuntimeError):
    """Raised when the experiment configuration is incomplete."""


def load_config(path: str | Path | None = None) -> dict[str, Any]:
    config_path = Path(path or DEFAULT_CONFIG_PATH).expanduser()
    if not config_path.is_absolute():
        config_path = Path.cwd() / config_path
    if not config_path.exists():
        raise ExperimentConfigError(
            f"Config file not found: {config_path}. Copy config.example.json first."
        )
    try:
        data = json.loads(config_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ExperimentConfigError(f"Config is not valid JSON: {config_path}") from exc
    if not isinstance(data, dict):
        raise ExperimentConfigError("Config root must be a JSON object.")
    data["_config_path"] = str(config_path)
    return data


def run_dir(config: dict[str, Any]) -> Path:
    output = _object(config, "output")
    path = Path(str(output.get("run_dir") or "experiments/musescore_mcp_vision/runs/latest"))
    if not path.is_absolute():
        path = Path.cwd() / path
    return path


def measure_image_path(config: dict[str, Any]) -> Path:
    return run_dir(config) / "measure.png"


def measure_facts_path(config: dict[str, Any]) -> Path:
    return run_dir(config) / "measure_facts.json"


def raw_response_path(config: dict[str, Any]) -> Path:
    return run_dir(config) / "lm_studio_raw_response.json"


def sequence_path(config: dict[str, Any]) -> Path:
    return run_dir(config) / "musescore_sequence.json"


def mcp_result_path(config: dict[str, Any]) -> Path:
    return run_dir(config) / "mcp_result.json"


def pdf_path(config: dict[str, Any]) -> Path:
    path = Path(str(_object(config, "input").get("pdf_path") or "")).expanduser()
    if not path.is_absolute():
        path = Path.cwd() / path
    if not path.exists():
        raise ExperimentConfigError(f"PDF does not exist: {path}")
    return path


def source_payload(config: dict[str, Any]) -> dict[str, Any]:
    input_config = _object(config, "input")
    return {
        "pdf_path": str(pdf_path(config)),
        "page_number": page_number(config),
        "measure_region": dict(_object(input_config, "measure_region")),
    }


def page_number(config: dict[str, Any]) -> int:
    value = _object(config, "input").get("page_number")
    if not isinstance(value, int) or value < 1:
        raise ExperimentConfigError("input.page_number must be a positive integer.")
    return value


def measure_region(config: dict[str, Any]) -> dict[str, Any]:
    region = _object(_object(config, "input"), "measure_region")
    required = ("x", "y", "width", "height")
    missing = [key for key in required if key not in region]
    if missing:
        raise ExperimentConfigError(
            "input.measure_region is missing required key(s): " + ", ".join(missing)
        )
    return dict(region)


def render_scale(config: dict[str, Any]) -> float:
    value = _object(config, "output").get("render_scale", 3.0)
    try:
        scale = float(value)
    except (TypeError, ValueError) as exc:
        raise ExperimentConfigError("output.render_scale must be numeric.") from exc
    if scale <= 0:
        raise ExperimentConfigError("output.render_scale must be greater than zero.")
    return scale


def minimum_confidence(config: dict[str, Any]) -> float:
    value = _object(config, "safety").get("minimum_confidence", 0.65)
    try:
        confidence = float(value)
    except (TypeError, ValueError) as exc:
        raise ExperimentConfigError("safety.minimum_confidence must be numeric.") from exc
    return max(0.0, min(1.0, confidence))


def _object(config: dict[str, Any], key: str) -> dict[str, Any]:
    value = config.get(key)
    if not isinstance(value, dict):
        raise ExperimentConfigError(f"{key} must be a JSON object.")
    return value

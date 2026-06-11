"""Measure fact schema loading and validation."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator


SCHEMA_PATH = Path(__file__).resolve().parent / "schemas" / "measure_facts.schema.json"


class MeasureFactsValidationError(RuntimeError):
    """Raised when measure facts are not safe to apply."""


def load_measure_schema() -> dict[str, Any]:
    return json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))


def validate_measure_facts(facts: dict[str, Any]) -> None:
    validator = Draft202012Validator(load_measure_schema())
    errors = sorted(validator.iter_errors(facts), key=lambda error: list(error.path))
    if errors:
        first = errors[0]
        path = ".".join(str(part) for part in first.absolute_path) or "<root>"
        raise MeasureFactsValidationError(f"{path}: {first.message}")

    measure = facts.get("measure") or {}
    confidence = measure.get("confidence")
    events = measure.get("events") or []
    if not events:
        raise MeasureFactsValidationError("measure.events must contain at least one event.")
    for index, event in enumerate(events, start=1):
        if event.get("kind") == "note" and not isinstance(event.get("pitch"), dict):
            raise MeasureFactsValidationError(
                f"measure.events[{index}] note events require pitch."
            )
    if not isinstance(confidence, (int, float)):
        raise MeasureFactsValidationError("measure.confidence must be numeric.")


def load_measure_facts(path: str | Path) -> dict[str, Any]:
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise MeasureFactsValidationError("Measure facts root must be an object.")
    validate_measure_facts(data)
    return data

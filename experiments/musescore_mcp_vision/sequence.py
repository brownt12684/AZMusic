"""Convert measure facts into mcp-musescore actions."""

from __future__ import annotations

from fractions import Fraction
from typing import Any

from .measure_schema import validate_measure_facts


class SequenceBuildError(RuntimeError):
    """Raised when measure facts cannot be safely mapped to MuseScore commands."""


_STEP_TO_SEMITONE = {
    "C": 0,
    "D": 2,
    "E": 4,
    "F": 5,
    "G": 7,
    "A": 9,
    "B": 11,
}


def build_musescore_sequence(
    facts: dict[str, Any],
    *,
    minimum_confidence: float,
) -> dict[str, Any]:
    validate_measure_facts(facts)
    measure = facts["measure"]
    confidence = float(measure["confidence"])
    if confidence < minimum_confidence:
        raise SequenceBuildError(
            f"Measure confidence {confidence:.2f} is below minimum {minimum_confidence:.2f}."
        )

    duration_result = duration_check(measure)
    if not duration_result["matches"]:
        raise SequenceBuildError(
            "Measure duration does not match time signature: "
            f"expected {duration_result['expected']}, observed {duration_result['observed']}."
        )

    sequence: list[dict[str, Any]] = [
        {"action": "goToBeginningOfScore", "params": {}},
        {
            "action": "setTimeSignature",
            "params": {
                "numerator": int(measure["time_signature"]["beats"]),
                "denominator": int(measure["time_signature"]["beat_type"]),
            },
        },
    ]
    unsupported: list[dict[str, Any]] = []
    for event in measure["events"]:
        duration = event["duration"]
        params = {
            "duration": {
                "numerator": int(duration["numerator"]),
                "denominator": int(duration["denominator"]),
            },
            "advanceCursorAfterAction": True,
        }
        if event["kind"] == "note":
            params["pitch"] = pitch_to_midi(event["pitch"])
            sequence.append({"action": "addNote", "params": params})
        elif event["kind"] == "rest":
            sequence.append({"action": "addRest", "params": params})
        else:  # pragma: no cover - schema protects this
            raise SequenceBuildError(f"Unsupported event kind: {event['kind']}")

        if event.get("dots"):
            unsupported.append({"kind": "dots", "event": event})
        for key in ("tie", "slur"):
            if event.get(key) not in (None, "none"):
                unsupported.append({"kind": key, "event": event})
        if event.get("articulations"):
            unsupported.append({"kind": "articulations", "event": event})

    for fingering in measure.get("fingerings") or []:
        unsupported.append({"kind": "fingering", "data": fingering})
    for notation in measure.get("notations") or []:
        unsupported.append({"kind": "notation", "data": notation})

    return {
        "schema_version": "azmusic.musescore_mcp_vision.sequence.v1",
        "measure_index": measure["measure_index"],
        "sequence": sequence,
        "unsupported": unsupported,
        "duration_check": duration_result,
    }


def pitch_to_midi(pitch: dict[str, Any]) -> int:
    step = str(pitch["step"]).upper()
    if step not in _STEP_TO_SEMITONE:
        raise SequenceBuildError(f"Unsupported pitch step: {step}")
    octave = int(pitch["octave"])
    alter = int(pitch.get("alter") or 0)
    return 12 * (octave + 1) + _STEP_TO_SEMITONE[step] + alter


def duration_check(measure: dict[str, Any]) -> dict[str, Any]:
    expected = Fraction(
        int(measure["time_signature"]["beats"]),
        int(measure["time_signature"]["beat_type"]),
    )
    observed = Fraction(0, 1)
    for event in measure["events"]:
        duration = event["duration"]
        observed += Fraction(int(duration["numerator"]), int(duration["denominator"]))
    return {
        "expected": {"numerator": expected.numerator, "denominator": expected.denominator},
        "observed": {"numerator": observed.numerator, "denominator": observed.denominator},
        "matches": expected == observed,
    }

from __future__ import annotations

import json
from pathlib import Path

import pytest

from experiments.musescore_mcp_vision.measure_schema import (
    MeasureFactsValidationError,
    validate_measure_facts,
)
from experiments.musescore_mcp_vision.scripts.apply_measure_with_mcp import main as apply_main
from experiments.musescore_mcp_vision.sequence import (
    SequenceBuildError,
    build_musescore_sequence,
    duration_check,
    pitch_to_midi,
)
from experiments.musescore_mcp_vision.vision import _parse_chat_json, _strip_json_fence


def test_validate_measure_facts_accepts_valid_measure() -> None:
    validate_measure_facts(valid_measure_facts())


def test_validate_measure_facts_rejects_note_without_pitch() -> None:
    facts = valid_measure_facts()
    facts["measure"]["events"][0].pop("pitch")

    with pytest.raises(MeasureFactsValidationError, match="note events require pitch"):
        validate_measure_facts(facts)


def test_build_musescore_sequence_maps_notes_and_rests() -> None:
    sequence = build_musescore_sequence(valid_measure_facts(), minimum_confidence=0.65)

    assert [step["action"] for step in sequence["sequence"]] == [
        "goToBeginningOfScore",
        "setTimeSignature",
        "addNote",
        "addRest",
    ]
    assert sequence["sequence"][2]["params"]["pitch"] == 62
    assert sequence["duration_check"]["matches"] is True
    assert sequence["unsupported"][0]["kind"] == "fingering"


def test_build_musescore_sequence_stops_on_low_confidence() -> None:
    facts = valid_measure_facts()
    facts["measure"]["confidence"] = 0.4

    with pytest.raises(SequenceBuildError, match="below minimum"):
        build_musescore_sequence(facts, minimum_confidence=0.65)


def test_duration_check_reports_mismatch() -> None:
    facts = valid_measure_facts()
    facts["measure"]["events"] = facts["measure"]["events"][:1]

    result = duration_check(facts["measure"])

    assert result["matches"] is False
    assert result["observed"] == {"numerator": 1, "denominator": 4}


def test_build_musescore_sequence_stops_on_duration_mismatch() -> None:
    facts = valid_measure_facts()
    facts["measure"]["events"] = facts["measure"]["events"][:1]

    with pytest.raises(SequenceBuildError, match="duration does not match"):
        build_musescore_sequence(facts, minimum_confidence=0.65)


def test_pitch_to_midi_handles_accidentals() -> None:
    assert pitch_to_midi({"step": "C", "octave": 4}) == 60
    assert pitch_to_midi({"step": "B", "octave": 3, "alter": -1}) == 58


def test_parse_chat_json_accepts_fenced_json() -> None:
    response = {
        "choices": [
            {
                "message": {
                    "content": "```json\n" + json.dumps(valid_measure_facts()) + "\n```"
                }
            }
        ]
    }

    assert _parse_chat_json(response)["measure"]["measure_index"] == 1


def test_strip_json_fence_extracts_object_from_prose() -> None:
    content = "Here is the result:\n{\"ok\": true}\nThanks."

    assert _strip_json_fence(content) == '{"ok": true}'


def test_apply_measure_dry_run_writes_sequence(tmp_path: Path) -> None:
    facts_path = tmp_path / "facts.json"
    config_path = tmp_path / "config.json"
    run_dir = tmp_path / "run"
    facts_path.write_text(json.dumps(valid_measure_facts()), encoding="utf-8")
    config_path.write_text(
        json.dumps(
            {
                "output": {"run_dir": str(run_dir)},
                "safety": {"minimum_confidence": 0.65},
                "mcp": {
                    "server_command": ["python", "unused.py"],
                    "tool_names": {
                        "ping": "ping_musescore",
                        "process_sequence": "processSequence",
                    },
                    "request_timeout_seconds": 1,
                },
            }
        ),
        encoding="utf-8",
    )

    assert apply_main(["--config", str(config_path), "--facts", str(facts_path), "--dry-run"]) == 0

    sequence_path = run_dir / "musescore_sequence.json"
    assert sequence_path.exists()
    sequence = json.loads(sequence_path.read_text(encoding="utf-8"))
    assert sequence["duration_check"]["matches"] is True


def valid_measure_facts() -> dict:
    return {
        "schema_version": "azmusic.musescore_mcp_vision.measure_facts.v1",
        "source": {
            "pdf_path": "C:/fake/book.pdf",
            "page_number": 38,
            "measure_region": {
                "x": 0.1,
                "y": 0.2,
                "width": 0.3,
                "height": 0.1,
                "units": "normalized",
            },
        },
        "measure": {
            "measure_index": 1,
            "printed_measure_number": None,
            "staff_count": 1,
            "clef": "bass",
            "key_signature": "C major",
            "time_signature": {"beats": 2, "beat_type": 4},
            "events": [
                {
                    "kind": "note",
                    "pitch": {"step": "D", "octave": 4, "alter": 0},
                    "duration": {"numerator": 1, "denominator": 4},
                    "confidence": 0.9,
                },
                {
                    "kind": "rest",
                    "pitch": None,
                    "duration": {"numerator": 1, "denominator": 4},
                    "confidence": 0.8,
                },
            ],
            "notations": [],
            "fingerings": [
                {
                    "text": "1",
                    "event_index": 1,
                    "placement": "above",
                    "confidence": 0.8,
                }
            ],
            "confidence": 0.92,
            "uncertainties": [],
        },
        "warnings": [],
    }

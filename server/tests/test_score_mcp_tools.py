from pathlib import Path

import pytest
from server.config import settings
from server.services.score_mcp_tools import (
    ScoreMcpToolController,
    ScoreMcpToolError,
)


def _write_musicxml(storage_path: Path, text: str) -> Path:
    source_path = storage_path / "pieces" / "piece-1" / "candidate.musicxml"
    source_path.parent.mkdir(parents=True, exist_ok=True)
    source_path.write_text(text, encoding="utf-8")
    return source_path


def _sample_musicxml() -> str:
    return """<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
  <work><work-title>Tool Test</work-title></work>
  <part-list>
    <score-part id="P1"><part-name>Cello</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>1</divisions>
        <key><fifths>0</fifths></key>
        <time><beats>4</beats><beat-type>4</beat-type></time>
        <clef><sign>F</sign><line>4</line></clef>
      </attributes>
      <note>
        <pitch><step>C</step><octave>3</octave></pitch>
        <duration>1</duration>
        <type>quarter</type>
      </note>
      <note>
        <pitch><step>D</step><octave>3</octave></pitch>
        <duration>1</duration>
        <type>quarter</type>
      </note>
    </measure>
  </part>
</score-partwise>
"""


def _repeated_measure_musicxml() -> str:
    return """<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
  <part-list>
    <score-part id="P1"><part-name>Cello</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <direction><direction-type><words>The Troubadour</words></direction-type></direction>
      <note>
        <pitch><step>C</step><octave>3</octave></pitch>
        <duration>4</duration>
        <type>whole</type>
      </note>
    </measure>
    <measure number="1">
      <direction><direction-type><words>Hoedown</words></direction-type></direction>
      <note>
        <pitch><step>D</step><octave>3</octave></pitch>
        <duration>4</duration>
        <type>whole</type>
      </note>
    </measure>
  </part>
</score-partwise>
"""


def _multi_staff_musicxml() -> str:
    return """<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
  <part-list>
    <score-part id="P1"><part-name>Cello</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>2</divisions>
        <time><beats>2</beats><beat-type>2</beat-type></time>
      </attributes>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>2</duration>
        <voice>1</voice>
        <type>quarter</type>
        <staff>1</staff>
      </note>
      <note>
        <pitch><step>A</step><octave>2</octave></pitch>
        <duration>2</duration>
        <voice>2</voice>
        <type>quarter</type>
        <staff>2</staff>
        <stem>up</stem>
        <beam number="1">begin</beam>
        <notations><slur type="start" number="1" /></notations>
      </note>
    </measure>
  </part>
</score-partwise>
"""


def test_score_mcp_structured_tools_update_notation(tmp_path, monkeypatch) -> None:
    storage_path = tmp_path / "storage"
    monkeypatch.setattr(settings, "storage_path", storage_path)
    source_path = _write_musicxml(storage_path, _sample_musicxml())
    controller = ScoreMcpToolController(
        source_musicxml_path=source_path,
        workspace_path=storage_path / "review-workspace",
    )

    pitch_result = controller.call_tool(
        "update_note_pitch",
        {
            "part_id": "P1",
            "measure_number": 1,
            "note_index": 1,
            "step": "E",
            "octave": 4,
            "reason": "Match original pitch.",
        },
    )
    duration_result = controller.call_tool(
        "update_note_duration",
        {
            "part_id": "P1",
            "measure_number": 1,
            "note_index": 1,
            "duration": 2,
            "type": "half",
            "dots": 1,
            "reason": "Match original rhythm.",
        },
    )
    rest_result = controller.call_tool(
        "update_rest",
        {
            "part_id": "P1",
            "measure_number": 1,
            "note_index": 2,
            "is_rest": True,
            "measure_rest": False,
            "reason": "Second event is a rest.",
        },
    )
    time_result = controller.call_tool(
        "update_measure_time",
        {
            "part_id": "P1",
            "measure_number": 1,
            "beats": 3,
            "beat_type": 4,
            "reason": "Original is 3/4.",
        },
    )

    assert all(
        result.affects_notation
        for result in (pitch_result, duration_result, rest_result, time_result)
    )
    updated = controller.working_musicxml_path.read_text(encoding="utf-8")
    assert "<step>E</step>" in updated
    assert "<octave>4</octave>" in updated
    assert "<type>half</type>" in updated
    assert "<dot" in updated
    assert "<rest" in updated
    assert "<beats>3</beats>" in updated


def test_score_mcp_physical_measure_index_disambiguates_repeated_numbers(
    tmp_path,
    monkeypatch,
) -> None:
    storage_path = tmp_path / "storage"
    monkeypatch.setattr(settings, "storage_path", storage_path)
    source_path = _write_musicxml(storage_path, _repeated_measure_musicxml())
    controller = ScoreMcpToolController(
        source_musicxml_path=source_path,
        workspace_path=storage_path / "review-workspace",
    )

    ambiguous_results = controller.apply_tool_calls(
        [
            {
                "name": "update_rest",
                "arguments": {
                    "part_id": "P1",
                    "measure_number": 1,
                    "note_index": 1,
                    "is_rest": True,
                    "reason": "Ambiguous printed measure number.",
                },
            }
        ]
    )

    assert ambiguous_results[0].status == "failed"
    assert "ambiguous" in ambiguous_results[0].message
    assert "physical_measure_index" in ambiguous_results[0].message

    result = controller.call_tool(
        "update_rest",
        {
            "part_id": "P1",
            "physical_measure_index": 2,
            "measure_number": 1,
            "note_index": 1,
            "is_rest": True,
            "reason": "Correct Hoedown measure 1.",
        },
    )

    assert result.status == "succeeded"
    updated = controller.working_musicxml_path.read_text(encoding="utf-8")
    assert updated.count("<rest") == 1
    assert updated.index("<words>Hoedown</words>") < updated.index("<rest")

    result_with_unknown_printed_number = controller.call_tool(
        "update_measure_key",
        {
            "part_id": "P1",
            "physical_measure_index": 2,
            "measure_number": 0,
            "fifths": 1,
            "reason": "Printed measure number unknown, physical index is known.",
        },
    )

    assert result_with_unknown_printed_number.status == "succeeded"


def test_score_mcp_text_replacement_classifies_metadata_only(
    tmp_path,
    monkeypatch,
) -> None:
    storage_path = tmp_path / "storage"
    monkeypatch.setattr(settings, "storage_path", storage_path)
    source_path = _write_musicxml(storage_path, _sample_musicxml())
    controller = ScoreMcpToolController(
        source_musicxml_path=source_path,
        workspace_path=storage_path / "review-workspace",
    )

    result = controller.call_tool(
        "replace_musicxml_text",
        {
            "old_text": "<part-name>Cello</part-name>",
            "new_text": "<part-name>Violoncello</part-name>",
            "reason": "Metadata label cleanup.",
        },
    )

    assert result.affects_notation is False
    assert result.structured_content["affects_notation"] is False


def test_score_mcp_continues_after_failed_tool_call(tmp_path, monkeypatch) -> None:
    storage_path = tmp_path / "storage"
    monkeypatch.setattr(settings, "storage_path", storage_path)
    source_path = _write_musicxml(storage_path, _sample_musicxml())
    controller = ScoreMcpToolController(
        source_musicxml_path=source_path,
        workspace_path=storage_path / "review-workspace",
    )

    results = controller.apply_tool_calls(
        [
            {
                "name": "update_rest",
                "arguments": {
                    "part_id": "P1",
                    "measure_number": 1,
                    "note_index": 0,
                    "reason": "Invalid note index from model.",
                },
            },
            {
                "name": "update_measure_key",
                "arguments": {
                    "part_id": "P1",
                    "measure_number": 1,
                    "fifths": 1,
                    "reason": "Valid key update still applies.",
                },
            },
        ]
    )

    assert results[0].status == "failed"
    assert results[0].affects_notation is False
    assert results[1].status == "succeeded"
    assert results[1].affects_notation is True
    assert "<fifths>1</fifths>" in controller.working_musicxml_path.read_text(
        encoding="utf-8"
    )


def test_score_mcp_requires_staff_voice_for_ambiguous_note_targets(
    tmp_path,
    monkeypatch,
) -> None:
    storage_path = tmp_path / "storage"
    monkeypatch.setattr(settings, "storage_path", storage_path)
    source_path = _write_musicxml(storage_path, _multi_staff_musicxml())
    controller = ScoreMcpToolController(
        source_musicxml_path=source_path,
        workspace_path=storage_path / "review-workspace",
    )

    ambiguous = controller.apply_tool_calls(
        [
            {
                "name": "update_rest",
                "arguments": {
                    "part_id": "P1",
                    "physical_measure_index": 1,
                    "note_index": 1,
                    "is_rest": True,
                    "reason": "Missing staff/voice should be rejected.",
                },
            }
        ]
    )[0]

    assert ambiguous.status == "failed"
    assert "multiple staffs" in ambiguous.message

    result = controller.call_tool(
        "update_rest",
        {
            "part_id": "P1",
            "physical_measure_index": 1,
            "staff": "2",
            "voice": "2",
            "note_index": 1,
            "is_rest": True,
            "measure_rest": True,
            "reason": "Replace lower staff event with a full-measure rest.",
        },
    )

    assert result.status == "succeeded"
    updated = controller.working_musicxml_path.read_text(encoding="utf-8")
    assert '<rest measure="yes"' in updated
    assert "<duration>8</duration>" in updated
    assert "<stem>" not in updated
    assert "<beam" not in updated
    assert "<slur" not in updated


def test_score_mcp_rejects_out_of_scope_files(tmp_path, monkeypatch) -> None:
    storage_path = tmp_path / "storage"
    monkeypatch.setattr(settings, "storage_path", storage_path)
    source_path = tmp_path / "outside.musicxml"
    source_path.write_text(_sample_musicxml(), encoding="utf-8")

    with pytest.raises(ScoreMcpToolError, match="server storage"):
        ScoreMcpToolController(
            source_musicxml_path=source_path,
            workspace_path=storage_path / "review-workspace",
        )

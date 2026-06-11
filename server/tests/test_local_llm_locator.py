from pathlib import Path

from server.services.local_llm import build_musicxml_locator_map


def test_musicxml_locator_includes_staff_voice_indexes(tmp_path: Path) -> None:
    path = tmp_path / "multi_staff.musicxml"
    path.write_text(
        """<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Cello</part-name></score-part></part-list>
  <part id="P1">
    <measure number="9">
      <direction><direction-type><words>Hoedown</words></direction-type></direction>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>2</duration><voice>1</voice><staff>1</staff><type>quarter</type>
      </note>
      <note>
        <rest measure="yes" />
        <duration>4</duration><voice>2</voice><staff>2</staff><type>whole</type>
      </note>
    </measure>
  </part>
</score-partwise>
""",
        encoding="utf-8",
    )

    locator = build_musicxml_locator_map(path)

    assert locator[0]["section_title"] == "Hoedown"
    assert locator[0]["staff_voice_summary"]["requires_staff"] is True
    assert locator[0]["staff_voice_summary"]["requires_voice"] is True
    assert locator[0]["notes"][0]["staff"] == "1"
    assert locator[0]["notes"][1]["staff"] == "2"
    assert locator[0]["notes"][1]["measure_rest"] is True
    assert locator[0]["notes"][1]["staff_voice_note_index"] == 1

"""Bounded MCP-style tools for AI-directed score correction."""

from __future__ import annotations

import shutil
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any
from xml.etree import ElementTree as ET

from server.config import settings
from server.services.processing_engines import _validate_musicxml


class ScoreMcpToolError(RuntimeError):
    """Raised when an AI tool request is unsafe or invalid."""


@dataclass(slots=True)
class ScoreMcpToolResult:
    name: str
    status: str
    message: str
    structured_content: dict[str, Any] = field(default_factory=dict)
    affects_notation: bool = False


class ScoreMcpToolController:
    """A restricted tool executor scoped to one MusicXML working copy."""

    def __init__(self, *, source_musicxml_path: Path, workspace_path: Path) -> None:
        self.workspace_path = workspace_path.resolve()
        self._assert_path_allowed(self.workspace_path)
        self.workspace_path.mkdir(parents=True, exist_ok=True)
        self.working_musicxml_path = (self.workspace_path / "candidate.musicxml").resolve()
        self._assert_path_allowed(source_musicxml_path.resolve())
        self._assert_path_allowed(self.working_musicxml_path)
        shutil.copy2(source_musicxml_path, self.working_musicxml_path)

    @staticmethod
    def tool_definitions() -> list[dict[str, Any]]:
        return [
            {
                "name": "read_musicxml",
                "description": "Read the bounded MusicXML working copy.",
                "input_schema": {"type": "object", "additionalProperties": False},
            },
            {
                "name": "replace_musicxml_text",
                "description": (
                    "Replace one exact MusicXML text fragment in the working copy. "
                    "Use only when the old fragment appears exactly once. Prefer the "
                    "structured note, rest, time, key, and direction tools for notation."
                ),
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "old_text": {"type": "string"},
                        "new_text": {"type": "string"},
                        "reason": {"type": "string"},
                    },
                    "required": ["old_text", "new_text"],
                    "additionalProperties": False,
                },
            },
            {
                "name": "replace_note_xml",
                "description": (
                    "Replace a single note/rest element by part id, physical measure "
                    "index or printed measure number, and 1-based note index within "
                    "that measure. Prefer physical_measure_index when measure numbers repeat."
                ),
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "part_id": {"type": "string"},
                        "staff": {"type": "string"},
                        "voice": {"type": "string"},
                        "physical_measure_index": {"type": "integer"},
                        "measure_number": {"type": "integer"},
                        "note_index": {"type": "integer"},
                        "note_xml": {"type": "string"},
                        "reason": {"type": "string"},
                    },
                    "required": ["part_id", "note_index", "note_xml"],
                    "additionalProperties": False,
                },
            },
            {
                "name": "update_note_pitch",
                "description": (
                    "Update the pitch of one existing note by part id, physical measure "
                    "index or printed measure number, and 1-based note index. Prefer "
                    "physical_measure_index when measure numbers repeat. Do not use for rests."
                ),
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "part_id": {"type": "string"},
                        "staff": {"type": "string"},
                        "voice": {"type": "string"},
                        "physical_measure_index": {"type": "integer"},
                        "measure_number": {"type": "integer"},
                        "note_index": {"type": "integer"},
                        "step": {"type": "string"},
                        "octave": {"type": "integer"},
                        "alter": {"type": "integer"},
                        "reason": {"type": "string"},
                    },
                    "required": ["part_id", "note_index"],
                    "additionalProperties": False,
                },
            },
            {
                "name": "update_note_duration",
                "description": (
                    "Update duration/type/dot count for one note or rest by part id, "
                    "physical measure index or printed measure number, and 1-based "
                    "note index. Prefer physical_measure_index when measure numbers repeat."
                ),
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "part_id": {"type": "string"},
                        "staff": {"type": "string"},
                        "voice": {"type": "string"},
                        "physical_measure_index": {"type": "integer"},
                        "measure_number": {"type": "integer"},
                        "note_index": {"type": "integer"},
                        "duration": {"type": "integer"},
                        "type": {"type": "string"},
                        "dots": {"type": "integer"},
                        "reason": {"type": "string"},
                    },
                    "required": ["part_id", "note_index"],
                    "additionalProperties": False,
                },
            },
            {
                "name": "update_rest",
                "description": (
                    "Set or update rest state for one note by part id, physical measure "
                    "index or printed measure number, and 1-based note index. Prefer "
                    "physical_measure_index when measure numbers repeat. Use measure_rest "
                    "for full-measure rests."
                ),
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "part_id": {"type": "string"},
                        "staff": {"type": "string"},
                        "voice": {"type": "string"},
                        "physical_measure_index": {"type": "integer"},
                        "measure_number": {"type": "integer"},
                        "note_index": {"type": "integer"},
                        "is_rest": {"type": "boolean"},
                        "measure_rest": {"type": "boolean"},
                        "display_step": {"type": "string"},
                        "display_octave": {"type": "integer"},
                        "reason": {"type": "string"},
                    },
                    "required": ["part_id", "note_index"],
                    "additionalProperties": False,
                },
            },
            {
                "name": "update_measure_time",
                "description": "Update the time signature attributes for one measure.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "part_id": {"type": "string"},
                        "physical_measure_index": {"type": "integer"},
                        "measure_number": {"type": "integer"},
                        "beats": {"type": "integer"},
                        "beat_type": {"type": "integer"},
                        "symbol": {"type": "string"},
                        "reason": {"type": "string"},
                    },
                    "required": ["part_id", "beats", "beat_type"],
                    "additionalProperties": False,
                },
            },
            {
                "name": "update_measure_key",
                "description": "Update the key signature fifths value for one measure.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "part_id": {"type": "string"},
                        "physical_measure_index": {"type": "integer"},
                        "measure_number": {"type": "integer"},
                        "fifths": {"type": "integer"},
                        "reason": {"type": "string"},
                    },
                    "required": ["part_id", "fifths"],
                    "additionalProperties": False,
                },
            },
            {
                "name": "upsert_direction_words",
                "description": (
                    "Insert or replace visible direction text in one measure, such as "
                    "a title, expression marking, tempo text, or rehearsal text."
                ),
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "part_id": {"type": "string"},
                        "physical_measure_index": {"type": "integer"},
                        "measure_number": {"type": "integer"},
                        "text": {"type": "string"},
                        "placement": {"type": "string"},
                        "replace_text": {"type": "string"},
                        "reason": {"type": "string"},
                    },
                    "required": ["part_id", "text"],
                    "additionalProperties": False,
                },
            },
            {
                "name": "validate_musicxml",
                "description": "Validate the edited MusicXML working copy.",
                "input_schema": {"type": "object", "additionalProperties": False},
            },
        ]

    def apply_tool_calls(self, tool_calls: list[dict[str, Any]]) -> list[ScoreMcpToolResult]:
        results: list[ScoreMcpToolResult] = []
        for call in tool_calls:
            if not isinstance(call, dict):
                raise ScoreMcpToolError("The LLM returned a malformed tool call.")
            name = str(call.get("name") or call.get("tool") or "").strip()
            arguments = call.get("arguments") or {}
            if not isinstance(arguments, dict):
                raise ScoreMcpToolError(f"Tool {name or '<unknown>'} arguments were malformed.")
            try:
                results.append(self.call_tool(name, arguments))
            except ScoreMcpToolError as exc:
                results.append(
                    ScoreMcpToolResult(
                        name=name or "<unknown>",
                        status="failed",
                        message=str(exc),
                        structured_content={
                            "arguments": arguments,
                            "affects_notation": False,
                        },
                        affects_notation=False,
                    )
                )
        return results

    def call_tool(self, name: str, arguments: dict[str, Any]) -> ScoreMcpToolResult:
        if name == "read_musicxml":
            text = self._read_working_text()
            return ScoreMcpToolResult(
                name=name,
                status="succeeded",
                message="MusicXML read.",
                structured_content={"characters": len(text), "musicxml": text[:20000]},
            )
        if name == "replace_musicxml_text":
            return self._replace_musicxml_text(arguments)
        if name == "replace_note_xml":
            return self._replace_note_xml(arguments)
        if name == "update_note_pitch":
            return self._update_note_pitch(arguments)
        if name == "update_note_duration":
            return self._update_note_duration(arguments)
        if name == "update_rest":
            return self._update_rest(arguments)
        if name == "update_measure_time":
            return self._update_measure_time(arguments)
        if name == "update_measure_key":
            return self._update_measure_key(arguments)
        if name == "upsert_direction_words":
            return self._upsert_direction_words(arguments)
        if name == "validate_musicxml":
            metadata = _validate_musicxml(self.working_musicxml_path)
            return ScoreMcpToolResult(
                name=name,
                status="succeeded",
                message="MusicXML validated.",
                structured_content=metadata,
            )
        raise ScoreMcpToolError(f"The LLM requested unsupported tool: {name}")

    def _replace_musicxml_text(self, arguments: dict[str, Any]) -> ScoreMcpToolResult:
        old_text = str(arguments.get("old_text") or "")
        new_text = str(arguments.get("new_text") or "")
        reason = str(arguments.get("reason") or "").strip()
        if not old_text:
            raise ScoreMcpToolError("replace_musicxml_text requires old_text.")
        if len(old_text) > 20000 or len(new_text) > 30000:
            raise ScoreMcpToolError("MusicXML replacement was too large for the safe tool.")

        text = self._read_working_text()
        occurrences = text.count(old_text)
        if occurrences != 1:
            raise ScoreMcpToolError(
                f"MusicXML replacement must match exactly one fragment; matched {occurrences}."
            )
        updated = text.replace(old_text, new_text, 1)
        self.working_musicxml_path.write_text(updated, encoding="utf-8")
        metadata = _validate_musicxml(self.working_musicxml_path)
        affects_notation = _replacement_affects_notation(old_text, new_text)
        return ScoreMcpToolResult(
            name="replace_musicxml_text",
            status="succeeded",
            message=reason or "MusicXML fragment replaced.",
            structured_content={**metadata, "affects_notation": affects_notation},
            affects_notation=affects_notation,
        )

    def _replace_note_xml(self, arguments: dict[str, Any]) -> ScoreMcpToolResult:
        note_xml = str(arguments.get("note_xml") or "").strip()
        if not note_xml:
            raise ScoreMcpToolError("replace_note_xml requires note_xml.")
        if len(note_xml) > 6000:
            raise ScoreMcpToolError("Replacement note XML is too large.")
        try:
            replacement = ET.fromstring(note_xml)
        except ET.ParseError as exc:
            raise ScoreMcpToolError(f"Replacement note XML is invalid: {exc}") from exc
        if _local_name(replacement.tag) != "note":
            raise ScoreMcpToolError("replace_note_xml requires a single <note> element.")

        tree = self._load_tree()
        note = self._target_note(tree.getroot(), arguments)
        parent = self._target_measure(tree.getroot(), arguments)
        children = list(parent)
        try:
            target_index = children.index(note)
        except ValueError as exc:
            raise ScoreMcpToolError("Target note was not found in the target measure.") from exc
        parent.remove(note)
        parent.insert(target_index, replacement)
        metadata = self._save_tree(tree)
        return ScoreMcpToolResult(
            name="replace_note_xml",
            status="succeeded",
            message=str(arguments.get("reason") or "Note XML replaced."),
            structured_content={**metadata, "affects_notation": True},
            affects_notation=True,
        )

    def _update_note_pitch(self, arguments: dict[str, Any]) -> ScoreMcpToolResult:
        tree = self._load_tree()
        note = self._target_note(tree.getroot(), arguments)
        if _first_child(note, "rest") is not None:
            raise ScoreMcpToolError("update_note_pitch cannot update a rest.")
        pitch = _ensure_child(note, "pitch", insert_index=0)
        step = _optional_step(arguments.get("step"))
        octave = _optional_int(arguments.get("octave"), "octave")
        alter = _optional_int(arguments.get("alter"), "alter")
        if step is None and octave is None and alter is None:
            raise ScoreMcpToolError("update_note_pitch requires step, octave, or alter.")
        if step is not None:
            _set_child_text(pitch, "step", step)
        if alter is None:
            alter_element = _first_child(pitch, "alter")
            if alter_element is not None and "alter" in arguments:
                pitch.remove(alter_element)
        else:
            _set_child_text(pitch, "alter", str(alter))
        if octave is not None:
            _set_child_text(pitch, "octave", str(octave))
        metadata = self._save_tree(tree)
        return ScoreMcpToolResult(
            name="update_note_pitch",
            status="succeeded",
            message=str(arguments.get("reason") or "Note pitch updated."),
            structured_content={**metadata, "affects_notation": True},
            affects_notation=True,
        )

    def _update_note_duration(self, arguments: dict[str, Any]) -> ScoreMcpToolResult:
        tree = self._load_tree()
        note = self._target_note(tree.getroot(), arguments)
        duration = _optional_int(arguments.get("duration"), "duration")
        note_type = _optional_musicxml_type(arguments.get("type"))
        dots = _optional_int(arguments.get("dots"), "dots")
        if duration is None and note_type is None and dots is None:
            raise ScoreMcpToolError("update_note_duration requires duration, type, or dots.")
        if duration is not None:
            if duration <= 0:
                raise ScoreMcpToolError("duration must be positive.")
            _set_child_text(note, "duration", str(duration))
        if note_type is not None:
            _set_child_text(note, "type", note_type)
        if dots is not None:
            if dots < 0 or dots > 4:
                raise ScoreMcpToolError("dots must be between 0 and 4.")
            for dot in list(_children(note, "dot")):
                note.remove(dot)
            type_element = _first_child(note, "type")
            insert_index = (
                list(note).index(type_element) + 1
                if type_element is not None
                else len(note)
            )
            for _ in range(dots):
                note.insert(insert_index, ET.Element("dot"))
                insert_index += 1
        metadata = self._save_tree(tree)
        return ScoreMcpToolResult(
            name="update_note_duration",
            status="succeeded",
            message=str(arguments.get("reason") or "Note duration updated."),
            structured_content={**metadata, "affects_notation": True},
            affects_notation=True,
        )

    def _update_rest(self, arguments: dict[str, Any]) -> ScoreMcpToolResult:
        tree = self._load_tree()
        note = self._target_note(tree.getroot(), arguments)
        is_rest = bool(arguments.get("is_rest", True))
        measure_rest = bool(arguments.get("measure_rest", False))
        display_step = _optional_step(arguments.get("display_step"))
        display_octave = _optional_int(arguments.get("display_octave"), "display_octave")

        rest = _first_child(note, "rest")
        if is_rest:
            _remove_children(note, {"pitch", "stem", "beam", "notations", "accidental", "tie"})
            rest = rest or ET.Element("rest")
            if rest not in list(note):
                note.insert(0, rest)
            if measure_rest:
                rest.set("measure", "yes")
                full_duration = _measure_full_duration(
                    self._target_measure(tree.getroot(), arguments)
                )
                if full_duration is not None:
                    _set_child_text(note, "duration", str(full_duration))
                _set_child_text(note, "type", "whole")
                _remove_children(note, {"dot"})
            else:
                rest.attrib.pop("measure", None)
            if display_step is not None:
                _set_child_text(rest, "display-step", display_step)
            if display_octave is not None:
                _set_child_text(rest, "display-octave", str(display_octave))
        elif rest is not None:
            note.remove(rest)
        else:
            raise ScoreMcpToolError(
                "Target note is already not a rest. "
                f"Target note summary: {_note_summary(note)}"
            )

        metadata = self._save_tree(tree)
        return ScoreMcpToolResult(
            name="update_rest",
            status="succeeded",
            message=str(arguments.get("reason") or "Rest state updated."),
            structured_content={**metadata, "affects_notation": True},
            affects_notation=True,
        )

    def _update_measure_time(self, arguments: dict[str, Any]) -> ScoreMcpToolResult:
        beats = _required_positive_int(arguments.get("beats"), "beats")
        beat_type = _required_positive_int(arguments.get("beat_type"), "beat_type")
        symbol = str(arguments.get("symbol") or "").strip()
        tree = self._load_tree()
        measure = self._target_measure(tree.getroot(), arguments)
        attributes = _ensure_measure_attributes(measure)
        time_element = _ensure_child(attributes, "time")
        if symbol:
            time_element.set("symbol", symbol)
        _set_child_text(time_element, "beats", str(beats))
        _set_child_text(time_element, "beat-type", str(beat_type))
        metadata = self._save_tree(tree)
        return ScoreMcpToolResult(
            name="update_measure_time",
            status="succeeded",
            message=str(arguments.get("reason") or "Measure time signature updated."),
            structured_content={**metadata, "affects_notation": True},
            affects_notation=True,
        )

    def _update_measure_key(self, arguments: dict[str, Any]) -> ScoreMcpToolResult:
        fifths = _optional_int(arguments.get("fifths"), "fifths")
        if fifths is None:
            raise ScoreMcpToolError("update_measure_key requires fifths.")
        tree = self._load_tree()
        measure = self._target_measure(tree.getroot(), arguments)
        attributes = _ensure_measure_attributes(measure)
        key_element = _ensure_child(attributes, "key")
        _set_child_text(key_element, "fifths", str(fifths))
        metadata = self._save_tree(tree)
        return ScoreMcpToolResult(
            name="update_measure_key",
            status="succeeded",
            message=str(arguments.get("reason") or "Measure key signature updated."),
            structured_content={**metadata, "affects_notation": True},
            affects_notation=True,
        )

    def _upsert_direction_words(self, arguments: dict[str, Any]) -> ScoreMcpToolResult:
        text = str(arguments.get("text") or "").strip()
        if not text:
            raise ScoreMcpToolError("upsert_direction_words requires text.")
        if len(text) > 300:
            raise ScoreMcpToolError("Direction text is too long.")
        replace_text = str(arguments.get("replace_text") or "").strip()
        placement = str(arguments.get("placement") or "above").strip() or "above"
        if placement not in {"above", "below"}:
            placement = "above"

        tree = self._load_tree()
        measure = self._target_measure(tree.getroot(), arguments)
        if replace_text:
            for words in measure.iter():
                if _local_name(words.tag) == "words" and (words.text or "").strip() == replace_text:
                    words.text = text
                    metadata = self._save_tree(tree)
                    return ScoreMcpToolResult(
                        name="upsert_direction_words",
                        status="succeeded",
                        message=str(arguments.get("reason") or "Direction text replaced."),
                        structured_content={**metadata, "affects_notation": True},
                        affects_notation=True,
                    )

        direction = ET.Element("direction", {"placement": placement})
        direction_type = ET.SubElement(direction, "direction-type")
        words = ET.SubElement(direction_type, "words")
        words.text = text
        insert_index = 0
        attributes = _first_child(measure, "attributes")
        if attributes is not None:
            insert_index = list(measure).index(attributes) + 1
        measure.insert(insert_index, direction)
        metadata = self._save_tree(tree)
        return ScoreMcpToolResult(
            name="upsert_direction_words",
            status="succeeded",
            message=str(arguments.get("reason") or "Direction text inserted."),
            structured_content={**metadata, "affects_notation": True},
            affects_notation=True,
        )

    def _read_working_text(self) -> str:
        self._assert_path_allowed(self.working_musicxml_path)
        return self.working_musicxml_path.read_text(encoding="utf-8", errors="replace")

    def _load_tree(self) -> ET.ElementTree:
        self._assert_path_allowed(self.working_musicxml_path)
        try:
            return ET.parse(self.working_musicxml_path)
        except ET.ParseError as exc:
            raise ScoreMcpToolError(f"MusicXML is not parseable: {exc}") from exc

    def _save_tree(self, tree: ET.ElementTree) -> dict[str, Any]:
        self._assert_path_allowed(self.working_musicxml_path)
        tree.write(self.working_musicxml_path, encoding="utf-8", xml_declaration=True)
        return _validate_musicxml(self.working_musicxml_path)

    def _target_measure(self, root: ET.Element, arguments: dict[str, Any]) -> ET.Element:
        part_id = str(arguments.get("part_id") or "").strip()
        physical_measure_index = _optional_int(
            arguments.get("physical_measure_index"), "physical_measure_index"
        )
        measure_number = _optional_int(arguments.get("measure_number"), "measure_number")
        if not part_id:
            raise ScoreMcpToolError("Tool call requires part_id.")
        if physical_measure_index is not None and physical_measure_index < 0:
            raise ScoreMcpToolError("physical_measure_index must be a positive integer.")
        if measure_number is not None and measure_number < 0:
            raise ScoreMcpToolError("measure_number must be a positive integer.")
        if physical_measure_index == 0:
            physical_measure_index = None
        if measure_number == 0:
            measure_number = None
        if physical_measure_index is None and measure_number is None:
            raise ScoreMcpToolError(
                "Tool call requires physical_measure_index or measure_number."
            )
        for part in root.iter():
            if _local_name(part.tag) != "part" or part.get("id") != part_id:
                continue
            measures = [measure for measure in part if _local_name(measure.tag) == "measure"]
            if physical_measure_index is not None:
                if physical_measure_index <= len(measures):
                    return measures[physical_measure_index - 1]
                raise ScoreMcpToolError(
                    f"Could not find part {part_id} physical_measure_index "
                    f"{physical_measure_index}; part contains {len(measures)} measures. "
                    f"Available: {_measure_locator_summaries(measures)}"
                )
            matches = [
                (index, measure)
                for index, measure in enumerate(measures, start=1)
                if measure.get("number") == str(measure_number)
            ]
            if len(matches) == 1:
                return matches[0][1]
            if len(matches) > 1:
                indexes = ", ".join(str(index) for index, _ in matches)
                raise ScoreMcpToolError(
                    f"Printed measure_number {measure_number} is ambiguous in part "
                    f"{part_id}; matching physical_measure_index values are {indexes}. "
                    "Use physical_measure_index from the locator map."
                )
            raise ScoreMcpToolError(
                f"Could not find part {part_id} printed measure_number {measure_number}. "
                f"Available: {_measure_locator_summaries(measures)}"
            )
        raise ScoreMcpToolError(f"Could not find part {part_id}.")

    def _target_note(self, root: ET.Element, arguments: dict[str, Any]) -> ET.Element:
        note_index = _required_positive_int(arguments.get("note_index"), "note_index")
        measure = self._target_measure(root, arguments)
        notes = [child for child in measure if _local_name(child.tag) == "note"]
        requested_staff = _optional_text(arguments.get("staff"))
        requested_voice = _optional_text(arguments.get("voice"))
        staff_values = {
            staff
            for note in notes
            if (staff := _child_text(note, "staff")) not in (None, "")
        }
        voice_values = {
            voice
            for note in notes
            if (voice := _child_text(note, "voice")) not in (None, "")
        }
        if len(staff_values) > 1 and requested_staff is None:
            raise ScoreMcpToolError(
                "Target measure contains multiple staffs; include staff in the tool call. "
                f"Measure summary: {_measure_summary(measure)}"
            )
        if len(voice_values) > 1 and requested_voice is None:
            raise ScoreMcpToolError(
                "Target measure contains multiple voices; include voice in the tool call. "
                f"Measure summary: {_measure_summary(measure)}"
            )
        if requested_staff is not None:
            notes = [note for note in notes if _child_text(note, "staff") == requested_staff]
        if requested_voice is not None:
            notes = [note for note in notes if _child_text(note, "voice") == requested_voice]
        if not notes:
            raise ScoreMcpToolError(
                "Could not find any note elements matching the requested staff/voice. "
                f"Measure summary: {_measure_summary(measure)}"
            )
        if note_index > len(notes):
            raise ScoreMcpToolError(
                f"Could not find note {note_index}; measure contains {len(notes)} "
                f"note elements. Measure summary: {_measure_summary(measure)}"
            )
        return notes[note_index - 1]

    def _assert_path_allowed(self, path: Path) -> None:
        storage_root = settings.storage_path.resolve()
        try:
            path.resolve().relative_to(storage_root)
        except ValueError as exc:
            raise ScoreMcpToolError(
                "Score MCP tools can only access server storage files."
            ) from exc


_NOTATION_TEXT_MARKERS = (
    "<note",
    "</note",
    "<rest",
    "<pitch",
    "<duration",
    "<type",
    "<dot",
    "<attributes",
    "<time",
    "<beats",
    "<beat-type",
    "<key",
    "<fifths",
    "<clef",
    "<direction",
    "<measure",
    "<backup",
    "<forward",
    "<barline",
    "<accidental",
    "<alter",
    "<step",
    "<octave",
    "<voice",
    "<staff",
    "<beam",
    "<notations",
    "<tie",
    "<slur",
)


def _replacement_affects_notation(old_text: str, new_text: str) -> bool:
    combined = f"{old_text}\n{new_text}".lower()
    return any(marker in combined for marker in _NOTATION_TEXT_MARKERS)


def _local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1] if "}" in tag else tag


def _children(element: ET.Element, name: str) -> list[ET.Element]:
    return [child for child in element if _local_name(child.tag) == name]


def _first_child(element: ET.Element, name: str) -> ET.Element | None:
    for child in element:
        if _local_name(child.tag) == name:
            return child
    return None


def _ensure_child(
    element: ET.Element,
    name: str,
    *,
    insert_index: int | None = None,
) -> ET.Element:
    child = _first_child(element, name)
    if child is not None:
        return child
    child = ET.Element(name)
    if insert_index is None:
        element.append(child)
    else:
        element.insert(insert_index, child)
    return child


def _set_child_text(element: ET.Element, name: str, text: str) -> ET.Element:
    child = _ensure_child(element, name)
    child.text = text
    return child


def _remove_children(element: ET.Element, names: set[str]) -> None:
    for child in list(element):
        if _local_name(child.tag) in names:
            element.remove(child)


def _child_text(element: ET.Element, name: str) -> str | None:
    child = _first_child(element, name)
    if child is None or child.text is None:
        return None
    text = child.text.strip()
    return text or None


def _optional_text(value: object) -> str | None:
    if not isinstance(value, str):
        if value is None:
            return None
        value = str(value)
    stripped = value.strip()
    return stripped or None


def _ensure_measure_attributes(measure: ET.Element) -> ET.Element:
    attributes = _first_child(measure, "attributes")
    if attributes is not None:
        return attributes
    attributes = ET.Element("attributes")
    measure.insert(0, attributes)
    return attributes


def _measure_full_duration(measure: ET.Element) -> int | None:
    attributes = _first_child(measure, "attributes")
    if attributes is None:
        return None
    divisions = _optional_int(_child_text(attributes, "divisions"), "divisions")
    time = _first_child(attributes, "time")
    if divisions is None or divisions <= 0 or time is None:
        return None
    beats = _optional_int(_child_text(time, "beats"), "beats")
    beat_type = _optional_int(_child_text(time, "beat-type"), "beat_type")
    if beats is None or beat_type is None or beats <= 0 or beat_type <= 0:
        return None
    return max(1, round(beats * divisions * 4 / beat_type))


def _required_positive_int(value: object, field_name: str) -> int:
    parsed = _optional_int(value, field_name)
    if parsed is None or parsed <= 0:
        raise ScoreMcpToolError(f"{field_name} must be a positive integer.")
    return parsed


def _measure_locator_summaries(measures: list[ET.Element]) -> str:
    summaries = [
        (
            f"{index}:printed={measure.get('number') or '?'} "
            f"notes={len([child for child in measure if _local_name(child.tag) == 'note'])}"
        )
        for index, measure in enumerate(measures, start=1)
    ]
    return "; ".join(summaries[:20])


def _measure_summary(measure: ET.Element) -> str:
    notes = [
        f"{index}:{_note_summary(note)}"
        for index, note in enumerate(
            [child for child in measure if _local_name(child.tag) == "note"],
            start=1,
        )
    ]
    return (
        f"printed_measure_number={measure.get('number') or '?'}; "
        f"notes={' | '.join(notes[:12])}"
    )


def _note_summary(note: ET.Element) -> str:
    duration = _child_text(note, "duration")
    note_type = _child_text(note, "type")
    voice = _child_text(note, "voice")
    staff = _child_text(note, "staff")
    rest = _first_child(note, "rest")
    if rest is not None:
        kind = "rest"
        if rest.get("measure") == "yes":
            kind = "measure-rest"
        pitch = ""
    else:
        pitch_element = _first_child(note, "pitch")
        if pitch_element is None:
            kind = "unpitched-note"
            pitch = ""
        else:
            step = _child_text(pitch_element, "step") or "?"
            alter = _child_text(pitch_element, "alter")
            octave = _child_text(pitch_element, "octave") or "?"
            kind = "note"
            pitch = f" {step}{alter or ''}{octave}"
    details = [
        f"{kind}{pitch}",
        f"type={note_type}" if note_type else "",
        f"duration={duration}" if duration else "",
        f"voice={voice}" if voice else "",
        f"staff={staff}" if staff else "",
    ]
    return " ".join(detail for detail in details if detail)


def _optional_int(value: object, field_name: str) -> int | None:
    if value is None or value == "":
        return None
    try:
        return int(value)
    except (TypeError, ValueError) as exc:
        raise ScoreMcpToolError(f"{field_name} must be an integer.") from exc


def _optional_step(value: object) -> str | None:
    if value is None or value == "":
        return None
    step = str(value).strip().upper()
    if step not in {"A", "B", "C", "D", "E", "F", "G"}:
        raise ScoreMcpToolError("Pitch step must be A, B, C, D, E, F, or G.")
    return step


def _optional_musicxml_type(value: object) -> str | None:
    if value is None or value == "":
        return None
    note_type = str(value).strip().lower()
    allowed = {
        "1024th",
        "512th",
        "256th",
        "128th",
        "64th",
        "32nd",
        "16th",
        "eighth",
        "quarter",
        "half",
        "whole",
        "breve",
        "long",
        "maxima",
    }
    if note_type not in allowed:
        raise ScoreMcpToolError(f"Unsupported MusicXML note type: {note_type}")
    return note_type

"""Processing engine adapters for MusicXML generation and PDF rendering."""

from __future__ import annotations

import shutil
import subprocess
import sys
import zipfile
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any
from xml.etree import ElementTree

from server.services.processing_settings import executable_status


class ProcessingEngineError(RuntimeError):
    """Raised when a configured processing engine cannot produce an artifact."""


@dataclass(slots=True)
class MusicXmlResult:
    file_path: Path
    engine_name: str
    engine_version: str | None
    provenance: str
    confidence: float
    warnings: list[str] = field(default_factory=list)
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(slots=True)
class RenderResult:
    file_path: Path
    renderer_name: str
    renderer_version: str | None
    provenance: str
    warnings: list[str] = field(default_factory=list)


class MusicXmlEngine:
    def generate(
        self,
        *,
        raw_pdf_path: Path,
        output_path: Path,
        title: str,
        composer: str | None,
        primary_instrument: str | None = None,
        contained_piece_titles: list[str] | None = None,
        multi_piece_page: bool = False,
        processing_settings: dict[str, Any],
    ) -> MusicXmlResult:
        audiveris_path = processing_settings.get("audiveris_cli_path")
        allow_stub = processing_settings.get("allow_stub_musicxml", True)
        production_mode = bool(processing_settings.get("production_mode"))

        if audiveris_path:
            result = AudiverisMusicXmlEngine().generate(
                raw_pdf_path=raw_pdf_path,
                output_path=output_path,
                title=title,
                composer=composer,
                primary_instrument=primary_instrument,
                contained_piece_titles=contained_piece_titles,
                multi_piece_page=multi_piece_page,
                processing_settings=processing_settings,
            )
            return _normalize_result_metadata(
                result,
                output_path=output_path,
                title=title,
                composer=composer,
                primary_instrument=primary_instrument,
                contained_piece_titles=contained_piece_titles,
                multi_piece_page=multi_piece_page,
            )

        if production_mode:
            raise ProcessingEngineError(
                "Production processing requires Audiveris; stub MusicXML is disabled."
            )

        if allow_stub:
            result = StubMusicXmlEngine().generate(
                raw_pdf_path=raw_pdf_path,
                output_path=output_path,
                title=title,
                composer=composer,
                primary_instrument=primary_instrument,
                contained_piece_titles=contained_piece_titles,
                multi_piece_page=multi_piece_page,
                processing_settings=processing_settings,
            )
            return _normalize_result_metadata(
                result,
                output_path=output_path,
                title=title,
                composer=composer,
                primary_instrument=primary_instrument,
                contained_piece_titles=contained_piece_titles,
                multi_piece_page=multi_piece_page,
            )

        raise ProcessingEngineError(
            "Audiveris is not configured and stub MusicXML generation is disabled."
        )


class StubMusicXmlEngine:
    def generate(
        self,
        *,
        raw_pdf_path: Path,
        output_path: Path,
        title: str,
        composer: str | None,
        primary_instrument: str | None = None,
        contained_piece_titles: list[str] | None = None,
        multi_piece_page: bool = False,
        processing_settings: dict[str, Any],
    ) -> MusicXmlResult:
        piece_titles = _clean_piece_titles(contained_piece_titles)
        measure_count = 1
        if multi_piece_page and len(piece_titles) > 1:
            measure_count = len(piece_titles) * 2
        output_path.write_text(
            _build_stub_musicxml(
                title=title,
                composer=composer,
                primary_instrument=primary_instrument or "Violin",
                measure_count=measure_count,
            ),
            encoding="utf-8",
        )
        metadata = _validate_musicxml(output_path)
        return MusicXmlResult(
            file_path=output_path,
            engine_name="stub",
            engine_version="deterministic-v1",
            provenance="fixture_stub_musicxml",
            confidence=0.64,
            warnings=["Audiveris is not configured; generated deterministic stub MusicXML."],
            metadata=metadata,
        )


class AudiverisMusicXmlEngine:
    def generate(
        self,
        *,
        raw_pdf_path: Path,
        output_path: Path,
        title: str,
        composer: str | None,
        primary_instrument: str | None = None,
        contained_piece_titles: list[str] | None = None,
        multi_piece_page: bool = False,
        processing_settings: dict[str, Any],
    ) -> MusicXmlResult:
        cli_path = processing_settings.get("audiveris_cli_path")
        if not cli_path:
            raise ProcessingEngineError("Audiveris CLI path is not configured.")

        status = executable_status(
            name="Audiveris",
            configured_path=cli_path,
            fallback_names=("audiveris",),
        )
        if not status.discovered_path:
            raise ProcessingEngineError("Configured Audiveris executable was not found.")

        output_dir = output_path.parent / "audiveris-output"
        output_dir.mkdir(parents=True, exist_ok=True)
        command = _command_prefix(status.discovered_path) + [
            "-batch",
            "-transcribe",
            "-export",
            "-output",
            str(output_dir),
            str(raw_pdf_path),
        ]
        result = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            timeout=300,
        )
        if result.returncode != 0:
            raise ProcessingEngineError(
                _summarize_process_failure("Audiveris", result.stderr or result.stdout)
            )

        candidate_path = _find_musicxml_output(output_dir) or (
            output_path if output_path.exists() else None
        )
        if candidate_path is None:
            raise ProcessingEngineError("Audiveris completed without producing MusicXML.")

        final_path = output_path
        if candidate_path.suffix.lower() == ".mxl":
            final_path = output_path.with_suffix(".mxl")
        if candidate_path != final_path:
            shutil.copy2(candidate_path, final_path)

        metadata = _validate_musicxml(final_path)
        return MusicXmlResult(
            file_path=final_path,
            engine_name="audiveris",
            engine_version=status.version,
            provenance="audiveris_omr",
            confidence=0.82,
            warnings=[],
            metadata=metadata,
        )


class MuseScoreRenderEngine:
    def render(
        self,
        *,
        canonical_path: Path,
        raw_pdf_path: Path,
        output_pdf_path: Path,
        processing_settings: dict[str, Any],
    ) -> RenderResult:
        cli_path = processing_settings.get("musescore_cli_path")
        if not cli_path:
            if processing_settings.get("production_mode"):
                raise ProcessingEngineError("Production processing requires MuseScore rendering.")
            shutil.copy2(raw_pdf_path, output_pdf_path)
            return RenderResult(
                file_path=output_pdf_path,
                renderer_name="raw_pdf_fallback",
                renderer_version=None,
                provenance="raw_pdf_copy",
                warnings=["MuseScore is not configured; copied the raw PDF for parent review."],
            )

        status = executable_status(
            name="MuseScore",
            configured_path=cli_path,
            fallback_names=("musescore", "mscore", "MuseScore4"),
        )
        if not status.discovered_path:
            raise ProcessingEngineError("Configured MuseScore executable was not found.")

        command = _command_prefix(status.discovered_path) + [
            str(canonical_path),
            "-o",
            str(output_pdf_path),
        ]
        result = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            timeout=300,
        )
        if result.returncode != 0 or not output_pdf_path.exists():
            raise ProcessingEngineError(
                _summarize_process_failure("MuseScore", result.stderr or result.stdout)
            )

        return RenderResult(
            file_path=output_pdf_path,
            renderer_name="musescore",
            renderer_version=status.version,
            provenance="musescore_render",
            warnings=[],
        )


def _command_prefix(executable_path: str) -> list[str]:
    path = Path(executable_path)
    if path.suffix.lower() == ".py":
        return [sys.executable, str(path)]
    return [str(path)]


def _find_musicxml_output(output_dir: Path) -> Path | None:
    candidates = [
        path
        for path in output_dir.rglob("*")
        if path.suffix.lower() in {".musicxml", ".xml", ".mxl"}
    ]
    if not candidates:
        return None
    return max(candidates, key=lambda path: path.stat().st_mtime)


def _validate_musicxml(path: Path) -> dict[str, Any]:
    try:
        root = _load_musicxml_root(path)
    except (ElementTree.ParseError, zipfile.BadZipFile, KeyError) as exc:
        raise ProcessingEngineError(f"Generated MusicXML is not valid XML: {exc}") from exc

    root_name = root.tag.rsplit("}", maxsplit=1)[-1]
    if root_name not in {"score-partwise", "score-timewise"}:
        raise ProcessingEngineError(
            f"Generated MusicXML root must be score-partwise or score-timewise, got {root_name}."
        )
    return _extract_musicxml_metadata(root)


def _normalize_result_metadata(
    result: MusicXmlResult,
    *,
    output_path: Path,
    title: str,
    composer: str | None,
    primary_instrument: str | None,
    contained_piece_titles: list[str] | None = None,
    multi_piece_page: bool = False,
) -> MusicXmlResult:
    normalized_path = _normalize_musicxml_metadata(
        result.file_path,
        output_path=output_path,
        title=title,
        composer=composer,
        primary_instrument=primary_instrument,
        contained_piece_titles=contained_piece_titles,
        multi_piece_page=multi_piece_page,
    )
    metadata = _validate_musicxml(normalized_path)
    warnings = list(result.warnings)
    original_instrument = result.metadata.get("primary_instrument")
    if (
        primary_instrument
        and isinstance(original_instrument, str)
        and original_instrument.strip()
        and original_instrument.strip().lower() != primary_instrument.strip().lower()
    ):
        if original_instrument.strip().lower() == "voice":
            warnings.append(
                "A generic OMR part label was suppressed; catalog/book instrument "
                "metadata was kept."
            )
        else:
            warnings.append(
                f"MusicXML part instrument '{original_instrument}' was overridden with "
                f"'{primary_instrument}' from catalog/book metadata."
            )
            metadata["omr_primary_instrument"] = original_instrument
    if primary_instrument:
        metadata["primary_instrument"] = primary_instrument
        metadata["parts"] = [primary_instrument]
        metadata["part_count"] = 1
    return MusicXmlResult(
        file_path=normalized_path,
        engine_name=result.engine_name,
        engine_version=result.engine_version,
        provenance=result.provenance,
        confidence=result.confidence,
        warnings=warnings,
        metadata=metadata,
    )


def _normalize_musicxml_metadata(
    file_path: Path,
    *,
    output_path: Path,
    title: str,
    composer: str | None,
    primary_instrument: str | None,
    contained_piece_titles: list[str] | None = None,
    multi_piece_page: bool = False,
) -> Path:
    root = _load_musicxml_root(file_path)
    piece_titles = _clean_piece_titles(contained_piece_titles)
    display_title = piece_titles[0] if multi_piece_page and len(piece_titles) > 1 else title
    _set_musicxml_title(root, catalog_title=title, display_title=display_title)
    _set_musicxml_composer(root, composer)
    _set_musicxml_primary_instrument(root, primary_instrument)
    _set_multi_piece_title_directions(root, piece_titles, multi_piece_page)

    normalized_path = file_path if file_path.suffix.lower() != ".mxl" else output_path
    ElementTree.ElementTree(root).write(
        normalized_path,
        encoding="utf-8",
        xml_declaration=True,
    )
    return normalized_path


def _set_musicxml_title(
    root: ElementTree.Element,
    *,
    catalog_title: str,
    display_title: str,
) -> None:
    work = _first_child(root, "work")
    if work is None:
        work = ElementTree.Element("work")
        root.insert(0, work)
    work_title = _first_child(work, "work-title")
    if work_title is None:
        work_title = ElementTree.SubElement(work, "work-title")
    work_title.text = catalog_title

    movement_title = _first_child(root, "movement-title")
    if movement_title is None:
        insert_index = 1 if _first_child(root, "work") is not None else 0
        movement_title = ElementTree.Element("movement-title")
        root.insert(insert_index, movement_title)
    movement_title.text = display_title


def _set_musicxml_composer(root: ElementTree.Element, composer: str | None) -> None:
    if not composer:
        return
    identification = _first_child(root, "identification")
    if identification is None:
        identification = ElementTree.Element("identification")
        root.insert(1, identification)
    composer_creator = None
    for creator in _children(identification, "creator"):
        if creator.attrib.get("type", "").lower() == "composer":
            composer_creator = creator
            break
    if composer_creator is None:
        composer_creator = ElementTree.SubElement(identification, "creator")
        composer_creator.attrib["type"] = "composer"
    composer_creator.text = composer


def _set_musicxml_primary_instrument(
    root: ElementTree.Element,
    primary_instrument: str | None,
) -> None:
    part_list = _first_child(root, "part-list")
    if part_list is None:
        return
    score_parts = _children(part_list, "score-part")
    if not score_parts:
        return
    single_part = len(score_parts) == 1
    for index, score_part in enumerate(score_parts):
        if primary_instrument or single_part or _score_part_mentions_voice(score_part):
            _suppress_score_part_visual_label(score_part)
        elif primary_instrument and index == 0:
            part_name = _first_child(score_part, "part-name")
            if part_name is None:
                part_name = ElementTree.SubElement(score_part, "part-name")
            part_name.text = primary_instrument

        if primary_instrument:
            score_instrument = _ensure_score_instrument(score_part)
            instrument_name = _first_child(score_instrument, "instrument-name")
            if instrument_name is None:
                instrument_name = ElementTree.SubElement(score_instrument, "instrument-name")
            instrument_name.text = primary_instrument
        else:
            _remove_voice_score_instrument_names(score_part)


def _score_part_mentions_voice(score_part: ElementTree.Element) -> bool:
    for name in ("part-name", "part-abbreviation"):
        value = _first_child_text(score_part, name)
        if value and value.strip().lower() == "voice":
            return True
    for score_instrument in _children(score_part, "score-instrument"):
        value = _first_child_text(score_instrument, "instrument-name")
        if value and value.strip().lower() == "voice":
            return True
    return False


def _remove_voice_score_instrument_names(score_part: ElementTree.Element) -> None:
    for score_instrument in _children(score_part, "score-instrument"):
        instrument_name = _first_child(score_instrument, "instrument-name")
        if (
            instrument_name is not None
            and _text_or_none(instrument_name.text)
            and _text_or_none(instrument_name.text).lower() == "voice"
        ):
            instrument_name.text = ""


def _suppress_score_part_visual_label(score_part: ElementTree.Element) -> None:
    part_name = _first_child(score_part, "part-name")
    if part_name is None:
        part_name = ElementTree.Element("part-name")
        score_part.insert(0, part_name)
    part_name.text = " "
    part_name.attrib["print-object"] = "no"

    part_abbreviation = _first_child(score_part, "part-abbreviation")
    if part_abbreviation is not None:
        part_abbreviation.text = " "
        part_abbreviation.attrib["print-object"] = "no"

    for child in list(score_part):
        if _local_name(child.tag) in {
            "part-name-display",
            "part-abbreviation-display",
        }:
            score_part.remove(child)


def _ensure_score_instrument(score_part: ElementTree.Element) -> ElementTree.Element:
    score_instrument = _first_child(score_part, "score-instrument")
    if score_instrument is not None:
        return score_instrument

    part_id = score_part.attrib.get("id") or "P1"
    score_instrument = ElementTree.Element(
        "score-instrument",
        {"id": f"{part_id}-I1"},
    )
    insert_index = len(score_part)
    for index, child in enumerate(score_part):
        if _local_name(child.tag) in {"midi-device", "midi-instrument"}:
            insert_index = index
            break
    score_part.insert(insert_index, score_instrument)
    return score_instrument


def _set_multi_piece_title_directions(
    root: ElementTree.Element,
    piece_titles: list[str],
    multi_piece_page: bool,
) -> None:
    if not multi_piece_page or len(piece_titles) < 2:
        return
    parts = _iter_named(root, "part")
    if not parts:
        return
    measures = _children(parts[0], "measure")
    if not measures:
        return

    for title_index, title in enumerate(piece_titles[1:], start=1):
        measure_index = round(title_index * len(measures) / len(piece_titles))
        measure_index = min(max(measure_index, 0), len(measures) - 1)
        measure = measures[measure_index]
        if _measure_has_direction_words(measure, title):
            continue
        direction = _piece_title_direction(title)
        insert_index = _measure_direction_insert_index(measure)
        measure.insert(insert_index, direction)


def _measure_direction_insert_index(measure: ElementTree.Element) -> int:
    for index, child in enumerate(measure):
        if _local_name(child.tag) == "attributes":
            return index + 1
    return 0


def _measure_has_direction_words(measure: ElementTree.Element, title: str) -> bool:
    normalized_title = _text_or_none(title)
    if not normalized_title:
        return True
    for words in _iter_named(measure, "words"):
        if _text_or_none(words.text) == normalized_title:
            return True
    return False


def _piece_title_direction(title: str) -> ElementTree.Element:
    direction = ElementTree.Element("direction", {"placement": "above"})
    direction_type = ElementTree.SubElement(direction, "direction-type")
    words = ElementTree.SubElement(
        direction_type,
        "words",
        {
            "default-x": "500",
            "font-weight": "bold",
            "font-size": "16",
            "halign": "center",
            "justify": "center",
        },
    )
    words.text = title
    return direction


def _load_musicxml_root(path: Path) -> ElementTree.Element:
    if path.suffix.lower() != ".mxl":
        return ElementTree.parse(path).getroot()

    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        rootfile_name = _mxl_rootfile_name(archive, names)
        return ElementTree.fromstring(archive.read(rootfile_name))


def _mxl_rootfile_name(archive: zipfile.ZipFile, names: list[str]) -> str:
    if "META-INF/container.xml" in names:
        container_root = ElementTree.fromstring(archive.read("META-INF/container.xml"))
        for rootfile in _iter_named(container_root, "rootfile"):
            full_path = rootfile.attrib.get("full-path")
            if full_path:
                return full_path

    for name in names:
        lower_name = name.lower()
        if lower_name.endswith(".xml") and not lower_name.startswith("meta-inf/"):
            return name
    raise KeyError("MXL archive did not contain a MusicXML root file")


def _extract_musicxml_metadata(root: ElementTree.Element) -> dict[str, Any]:
    metadata: dict[str, Any] = {
        "musicxml_version": root.attrib.get("version"),
    }

    title = _first_text_in_named_parent(root, "work", "work-title")
    movement_title = _first_text_named(root, "movement-title")
    if not title:
        title = movement_title
    if title:
        metadata["title"] = title
    if movement_title:
        metadata["movement_title"] = movement_title

    creators = _extract_creators(root)
    if creators:
        metadata["creators"] = creators
        composer = _first_creator_of_type(creators, "composer") or creators[0]["name"]
        metadata["composer"] = composer

    parts = _extract_parts(root)
    if parts:
        metadata["parts"] = parts
        metadata["primary_instrument"] = parts[0]
        metadata["part_count"] = len(parts)

    measure_count = _measure_count(root)
    if measure_count is not None:
        metadata["measure_count"] = measure_count

    key_signatures = _extract_key_signatures(root)
    if key_signatures:
        metadata["key_signature"] = key_signatures[0]
        metadata["key_signatures"] = key_signatures

    time_signatures = _extract_time_signatures(root)
    if time_signatures:
        metadata["time_signature"] = time_signatures[0]
        metadata["time_signatures"] = time_signatures

    tempos = _extract_tempos(root)
    if tempos:
        metadata["tempo"] = tempos[0]
        metadata["tempos"] = tempos

    software = _compact_unique(
        _text_or_none(element.text) for element in _iter_named(root, "software")
    )
    if software:
        metadata["software"] = software

    return {key: value for key, value in metadata.items() if value not in (None, "", [])}


def _extract_creators(root: ElementTree.Element) -> list[dict[str, str]]:
    creators: list[dict[str, str]] = []
    seen: set[tuple[str, str]] = set()
    for creator in _iter_named(root, "creator"):
        name = _text_or_none(creator.text)
        if not name:
            continue
        creator_type = creator.attrib.get("type", "creator")
        key = (creator_type, name)
        if key in seen:
            continue
        seen.add(key)
        creators.append({"type": creator_type, "name": name})
    return creators


def _first_creator_of_type(creators: list[dict[str, str]], creator_type: str) -> str | None:
    for creator in creators:
        if creator["type"].lower() == creator_type:
            return creator["name"]
    return None


def _extract_parts(root: ElementTree.Element) -> list[str]:
    parts = []
    for score_part in _iter_named(root, "score-part"):
        if _hidden_musicxml_label(score_part, "part-name"):
            continue
        part_name = _first_child_text(score_part, "part-name")
        if part_name:
            parts.append(part_name)
    return _compact_unique(parts)


def _hidden_musicxml_label(element: ElementTree.Element, name: str) -> bool:
    child = _first_child(element, name)
    if child is None:
        return False
    return child.attrib.get("print-object", "").lower() == "no"


def _measure_count(root: ElementTree.Element) -> int | None:
    counts = [
        len(_children(part, "measure"))
        for part in _iter_named(root, "part")
        if _children(part, "measure")
    ]
    if not counts:
        return None
    return max(counts)


def _extract_key_signatures(root: ElementTree.Element) -> list[str]:
    signatures: list[str] = []
    for key_element in _iter_named(root, "key"):
        fifths_text = _first_child_text(key_element, "fifths")
        if fifths_text is None:
            continue
        try:
            fifths = int(fifths_text)
        except ValueError:
            continue
        mode = (_first_child_text(key_element, "mode") or "major").lower()
        signatures.append(_key_signature_name(fifths, mode))
    return _compact_unique(signatures)


def _extract_time_signatures(root: ElementTree.Element) -> list[str]:
    signatures: list[str] = []
    for time_element in _iter_named(root, "time"):
        beats = _first_child_text(time_element, "beats")
        beat_type = _first_child_text(time_element, "beat-type")
        if beats and beat_type:
            signatures.append(f"{beats}/{beat_type}")
    return _compact_unique(signatures)


def _extract_tempos(root: ElementTree.Element) -> list[str]:
    tempos: list[str] = []
    for sound_element in _iter_named(root, "sound"):
        tempo = _normalize_tempo(sound_element.attrib.get("tempo"))
        if tempo:
            tempos.append(tempo)
    for per_minute in _iter_named(root, "per-minute"):
        tempo = _normalize_tempo(per_minute.text)
        if tempo:
            tempos.append(tempo)
    return _compact_unique(tempos)


def _key_signature_name(fifths: int, mode: str) -> str:
    major_keys = {
        -7: "Cb major",
        -6: "Gb major",
        -5: "Db major",
        -4: "Ab major",
        -3: "Eb major",
        -2: "Bb major",
        -1: "F major",
        0: "C major",
        1: "G major",
        2: "D major",
        3: "A major",
        4: "E major",
        5: "B major",
        6: "F# major",
        7: "C# major",
    }
    minor_keys = {
        -7: "Ab minor",
        -6: "Eb minor",
        -5: "Bb minor",
        -4: "F minor",
        -3: "C minor",
        -2: "G minor",
        -1: "D minor",
        0: "A minor",
        1: "E minor",
        2: "B minor",
        3: "F# minor",
        4: "C# minor",
        5: "G# minor",
        6: "D# minor",
        7: "A# minor",
    }
    if mode == "minor":
        return minor_keys.get(fifths, f"{fifths} fifths minor")
    return major_keys.get(fifths, f"{fifths} fifths major")


def _normalize_tempo(value: str | None) -> str | None:
    if value is None:
        return None
    raw_value = value.strip()
    if not raw_value:
        return None
    try:
        numeric_value = float(raw_value)
    except ValueError:
        return raw_value
    if numeric_value.is_integer():
        return str(int(numeric_value))
    return str(numeric_value)


def _first_text_in_named_parent(
    root: ElementTree.Element,
    parent_name: str,
    child_name: str,
) -> str | None:
    for parent in _iter_named(root, parent_name):
        value = _first_child_text(parent, child_name)
        if value:
            return value
    return None


def _first_text_named(root: ElementTree.Element, name: str) -> str | None:
    for element in _iter_named(root, name):
        value = _text_or_none(element.text)
        if value:
            return value
    return None


def _first_child_text(element: ElementTree.Element, name: str) -> str | None:
    child = _first_child(element, name)
    if child is None:
        return None
    return _text_or_none(child.text)


def _first_child(element: ElementTree.Element, name: str) -> ElementTree.Element | None:
    for child in element:
        if _local_name(child.tag) == name:
            return child
    return None


def _children(element: ElementTree.Element, name: str) -> list[ElementTree.Element]:
    return [child for child in element if _local_name(child.tag) == name]


def _iter_named(root: ElementTree.Element, name: str) -> list[ElementTree.Element]:
    return [element for element in root.iter() if _local_name(element.tag) == name]


def _local_name(tag: str) -> str:
    return tag.rsplit("}", maxsplit=1)[-1]


def _text_or_none(value: str | None) -> str | None:
    if value is None:
        return None
    stripped = " ".join(value.split())
    return stripped or None


def _compact_unique(values) -> list[str]:
    compacted: list[str] = []
    seen: set[str] = set()
    for value in values:
        if not value or value in seen:
            continue
        seen.add(value)
        compacted.append(value)
    return compacted


def _clean_piece_titles(values: list[str] | None) -> list[str]:
    if not values:
        return []
    return _compact_unique(_text_or_none(value) for value in values if isinstance(value, str))


def _summarize_process_failure(name: str, output: str | None) -> str:
    details = (output or "").strip()
    if not details:
        return f"{name} failed without returning diagnostic output."
    return f"{name} failed: {details[-1000:]}"


def _build_stub_musicxml(
    *,
    title: str,
    composer: str | None,
    primary_instrument: str,
    measure_count: int = 1,
) -> str:
    composer_xml = f'<creator type="composer">{_escape_xml(composer)}</creator>' if composer else ""
    clef_sign = "F" if primary_instrument.strip().lower() == "cello" else "G"
    clef_line = "4" if clef_sign == "F" else "2"
    first_octave = "3" if primary_instrument.strip().lower() == "cello" else "4"
    measures_xml = "\n".join(
        _build_stub_measure_xml(
            number=number,
            clef_sign=clef_sign,
            clef_line=clef_line,
            first_octave=first_octave,
            include_attributes=number == 1,
            include_review_marker=number == 1,
        )
        for number in range(1, max(1, measure_count) + 1)
    )
    return f"""<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE score-partwise PUBLIC
  "-//Recordare//DTD MusicXML 4.0 Partwise//EN"
  "http://www.musicxml.org/dtds/partwise.dtd">
<score-partwise version="4.0">
  <work>
    <work-title>{_escape_xml(title)}</work-title>
  </work>
  <identification>
    {composer_xml}
    <encoding>
      <software>AZMusic deterministic stub</software>
      <encoding-date>{datetime.utcnow().date().isoformat()}</encoding-date>
    </encoding>
  </identification>
  <part-list>
    <score-part id="P1">
      <part-name>{_escape_xml(primary_instrument)}</part-name>
    </score-part>
  </part-list>
  <part id="P1">
{measures_xml}
  </part>
</score-partwise>
"""


def _build_stub_measure_xml(
    *,
    number: int,
    clef_sign: str,
    clef_line: str,
    first_octave: str,
    include_attributes: bool,
    include_review_marker: bool,
) -> str:
    attributes_xml = (
        f"""      <attributes>
        <divisions>1</divisions>
        <key><fifths>0</fifths></key>
        <time><beats>4</beats><beat-type>4</beat-type></time>
        <clef><sign>{clef_sign}</sign><line>{clef_line}</line></clef>
      </attributes>
"""
        if include_attributes
        else ""
    )
    review_marker_xml = (
        """      <direction placement="above">
        <direction-type>
          <words>Review candidate generated by AZMusic</words>
        </direction-type>
        <sound tempo="96"/>
      </direction>
"""
        if include_review_marker
        else ""
    )
    return f"""    <measure number="{number}">
{attributes_xml}{review_marker_xml}      <note>
        <pitch><step>C</step><octave>{first_octave}</octave></pitch>
        <duration>1</duration>
        <type>quarter</type>
      </note>
      <note>
        <pitch><step>D</step><octave>{first_octave}</octave></pitch>
        <duration>1</duration>
        <type>quarter</type>
      </note>
      <note>
        <pitch><step>E</step><octave>{first_octave}</octave></pitch>
        <duration>1</duration>
        <type>quarter</type>
      </note>
      <note>
        <pitch><step>F</step><octave>{first_octave}</octave></pitch>
        <duration>1</duration>
        <type>quarter</type>
      </note>
    </measure>"""


def _escape_xml(value: str | None) -> str:
    if not value:
        return ""
    return (
        value.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
        .replace("'", "&apos;")
    )

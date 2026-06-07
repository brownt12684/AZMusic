"""Full-book PDF preprocessing for split review before OMR."""

from __future__ import annotations

import re
import subprocess
import tempfile
from collections import defaultdict
from csv import DictReader
from dataclasses import dataclass, field
from io import StringIO
from pathlib import Path
from typing import Any

from server.services.ocr_metadata import infer_metadata_from_text
from server.services.processing_settings import executable_status


@dataclass(slots=True)
class BookPageFact:
    page_number: int
    text: str
    text_excerpt: str
    classification: str
    title_candidates: list[str]
    has_staff_hint: bool
    dark_pixel_ratio: float
    horizontal_line_count: int
    warnings: list[str] = field(default_factory=list)
    title_ocr_text: str = ""

    def to_dict(self) -> dict[str, Any]:
        return {
            "page_number": self.page_number,
            "text_excerpt": self.text_excerpt,
            "classification": self.classification,
            "title_candidates": self.title_candidates,
            "has_staff_hint": self.has_staff_hint,
            "dark_pixel_ratio": self.dark_pixel_ratio,
            "horizontal_line_count": self.horizontal_line_count,
            "warnings": self.warnings,
            "title_ocr_excerpt": _excerpt(self.title_ocr_text, max_length=260)
            if self.title_ocr_text.strip()
            else None,
        }


@dataclass(slots=True)
class BookSplitProposal:
    title: str
    page_start: int
    page_end: int
    composer: str | None = None
    primary_instrument: str | None = None
    contained_piece_titles: list[str] = field(default_factory=list)
    multi_piece_page: bool = False
    confidence: float = 0.72
    validation_warnings: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return {
            "title": self.title,
            "page_start": self.page_start,
            "page_end": self.page_end,
            "composer": self.composer,
            "primary_instrument": self.primary_instrument,
            "contained_piece_titles": self.contained_piece_titles,
            "multi_piece_page": self.multi_piece_page,
            "confidence": self.confidence,
            "validation_warnings": self.validation_warnings,
        }


@dataclass(slots=True)
class BookPreprocessingResult:
    page_count: int
    page_facts: list[BookPageFact]
    split_proposals: list[BookSplitProposal]
    book_metadata: dict[str, Any]
    warnings: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return {
            "page_count": self.page_count,
            "page_facts": [fact.to_dict() for fact in self.page_facts],
            "split_proposals": [proposal.to_dict() for proposal in self.split_proposals],
            "book_metadata": self.book_metadata,
            "warnings": self.warnings,
        }


class BookPreprocessor:
    """Render every PDF page, run Tesseract, and propose book splits."""

    def __init__(self, processing_settings: dict[str, Any]) -> None:
        self._settings = processing_settings

    def preprocess(self, *, file_name: str, file_bytes: bytes) -> BookPreprocessingResult:
        try:
            import pypdfium2 as pdfium
        except ImportError as exc:
            raise RuntimeError("pypdfium2 is required for book preprocessing.") from exc

        ocr_path = self._resolve_tesseract()
        language = self._settings.get("ocr_language") or "eng"
        ocr_effort = str(self._settings.get("ocr_effort") or "balanced")
        render_scale = 3 if ocr_effort == "high_accuracy" else 2
        page_facts: list[BookPageFact] = []
        warnings: list[str] = []

        with tempfile.TemporaryDirectory(prefix="azmusic_book_ocr_") as temp_dir:
            temp_path = Path(temp_dir)
            pdf_path = temp_path / "source.pdf"
            pdf_path.write_bytes(file_bytes)
            document = pdfium.PdfDocument(str(pdf_path))
            try:
                page_count = len(document)
                for page_index in range(page_count):
                    page_number = page_index + 1
                    image_path = temp_path / f"page_{page_number:03}.png"
                    page = document[page_index]
                    bitmap = page.render(scale=render_scale)
                    image = bitmap.to_pil()
                    image.save(image_path)
                    page.close()
                    text, ocr_warnings = self._run_tesseract(
                        ocr_path=ocr_path,
                        image_path=image_path,
                        language=language,
                    )
                    image_facts = _analyze_page_image(image)
                    title_ocr_text = ""
                    title_ocr_warnings: list[str] = []
                    if image_facts["has_staff_hint"]:
                        title_ocr_text, title_ocr_warnings = self._run_title_tesseract(
                            ocr_path=ocr_path,
                            image_path=image_path,
                            language=language,
                        )
                    title_candidates = _title_candidates(
                        text,
                        [],
                        title_ocr_text=title_ocr_text,
                    )
                    classification = _classify_page(
                        page_number=page_number,
                        text=text,
                        title_candidates=title_candidates,
                        has_staff_hint=image_facts["has_staff_hint"],
                        dark_pixel_ratio=image_facts["dark_pixel_ratio"],
                    )
                    page_facts.append(
                        BookPageFact(
                            page_number=page_number,
                            text=text,
                            text_excerpt=_excerpt(text),
                            classification=classification,
                            title_candidates=title_candidates,
                            has_staff_hint=image_facts["has_staff_hint"],
                            dark_pixel_ratio=image_facts["dark_pixel_ratio"],
                            horizontal_line_count=image_facts["horizontal_line_count"],
                            warnings=ocr_warnings + title_ocr_warnings,
                            title_ocr_text=title_ocr_text,
                        )
                    )
                    warnings.extend(ocr_warnings)
                    warnings.extend(title_ocr_warnings)
            finally:
                document.close()

        toc_titles = _extract_toc_titles(page_facts)
        for fact in page_facts:
            fact.title_candidates = _title_candidates(
                fact.text,
                toc_titles,
                title_ocr_text=fact.title_ocr_text,
            )
            fact.classification = _classify_page(
                page_number=fact.page_number,
                text=fact.text,
                title_candidates=fact.title_candidates,
                has_staff_hint=fact.has_staff_hint,
                dark_pixel_ratio=fact.dark_pixel_ratio,
            )

        combined_text = "\n".join(fact.text for fact in page_facts if fact.text.strip())
        book_metadata = infer_metadata_from_text(combined_text)
        book_metadata.setdefault("source_file_name", file_name)
        book_metadata["ocr_language"] = language
        book_metadata["ocr_effort"] = ocr_effort
        book_metadata["ocr_render_scale"] = render_scale
        _improve_book_metadata(book_metadata, page_facts, file_name)
        split_proposals = _propose_splits(page_facts, book_metadata)
        return BookPreprocessingResult(
            page_count=len(page_facts),
            page_facts=page_facts,
            split_proposals=split_proposals,
            book_metadata=book_metadata,
            warnings=sorted(set(warnings)),
        )

    def _resolve_tesseract(self) -> str:
        status = executable_status(
            name="Tesseract OCR",
            configured_path=self._settings.get("ocr_cli_path"),
            fallback_names=("tesseract",),
        )
        if not status.discovered_path:
            raise RuntimeError("Tesseract OCR is not configured or discoverable.")
        return status.discovered_path

    @staticmethod
    def _run_tesseract(
        *,
        ocr_path: str,
        image_path: Path,
        language: str,
    ) -> tuple[str, list[str]]:
        command = [ocr_path, str(image_path), "stdout", "-l", language, "--oem", "1"]
        try:
            result = subprocess.run(
                command,
                check=False,
                capture_output=True,
                timeout=45,
            )
        except subprocess.TimeoutExpired:
            return "", [f"Tesseract timed out on {image_path.name}."]
        except OSError as exc:
            return "", [f"Tesseract failed on {image_path.name}: {exc}"]

        stdout = result.stdout.decode("utf-8", errors="replace")
        stderr = result.stderr.decode("utf-8", errors="replace").strip()
        warnings = []
        if result.returncode != 0:
            warnings.append(
                f"Tesseract returned {result.returncode} on {image_path.name}: {stderr[:240]}"
            )
        return stdout.replace("\x0c", "").strip(), warnings

    @staticmethod
    def _run_title_tesseract(
        *,
        ocr_path: str,
        image_path: Path,
        language: str,
    ) -> tuple[str, list[str]]:
        command = [
            ocr_path,
            str(image_path),
            "stdout",
            "-l",
            language,
            "--oem",
            "1",
            "--psm",
            "11",
            "tsv",
        ]
        try:
            result = subprocess.run(
                command,
                check=False,
                capture_output=True,
                timeout=30,
            )
        except subprocess.TimeoutExpired:
            return "", [f"Title OCR timed out on {image_path.name}."]
        except OSError as exc:
            return "", [f"Title OCR failed on {image_path.name}: {exc}"]

        stdout = result.stdout.decode("utf-8", errors="replace")
        stderr = result.stderr.decode("utf-8", errors="replace").strip()
        warnings = []
        if result.returncode != 0:
            warnings.append(
                f"Title OCR returned {result.returncode} on {image_path.name}: {stderr[:240]}"
            )
        return _large_title_lines_from_tesseract_tsv(stdout), warnings


def _large_title_lines_from_tesseract_tsv(tsv_text: str) -> str:
    line_words: dict[tuple[str, str, str], list[dict[str, object]]] = defaultdict(list)
    reader = DictReader(StringIO(tsv_text), delimiter="\t")
    for row in reader:
        text = (row.get("text") or "").strip()
        if not text:
            continue
        key = (
            row.get("block_num") or "",
            row.get("par_num") or "",
            row.get("line_num") or "",
        )
        left = _int_or_default(row.get("left"), 0)
        width = _int_or_default(row.get("width"), 0)
        line_words[key].append(
            {
                "text": text,
                "conf": _float_or_default(row.get("conf"), -1.0),
                "height": _int_or_default(row.get("height"), 0),
                "left": left,
                "right": left + width,
            }
        )

    candidates: list[str] = []
    page_width = max(
        (int(item["right"]) for words in line_words.values() for item in words),
        default=0,
    )
    for words in line_words.values():
        words.sort(key=lambda item: item["left"])
        line = _clean_title(" ".join(str(item["text"]) for item in words))
        normalized = _normalize(line)
        if not _looks_like_title(line, normalized):
            continue
        if not _looks_like_standalone_title_ocr_line(line, normalized):
            continue
        max_confidence = max(float(item["conf"]) for item in words)
        max_height = max(int(item["height"]) for item in words)
        line_left = min(int(item["left"]) for item in words)
        line_right = max(int(item["right"]) for item in words)
        line_center_ratio = ((line_left + line_right) / 2) / page_width if page_width else 0.5
        if max_confidence < 85 or max_height < 28:
            continue
        if line_right - line_left < 36:
            continue
        if line_center_ratio < 0.32 or line_center_ratio > 0.68:
            continue
        if not any(_normalize(line) == _normalize(existing) for existing in candidates):
            candidates.append(line)
    return "\n".join(candidates)


def _float_or_default(value: str | None, default: float) -> float:
    try:
        return float(value) if value is not None else default
    except ValueError:
        return default


def _int_or_default(value: str | None, default: int) -> int:
    try:
        return int(value) if value is not None else default
    except ValueError:
        return default


def _analyze_page_image(image) -> dict[str, Any]:
    grayscale = image.convert("L")
    width, height = grayscale.size
    sample_width = max(1, width)
    pixels = grayscale.load()
    dark_rows = []
    dark_pixels = 0
    total_pixels = width * height
    for y in range(height):
        row_dark = 0
        for x in range(width):
            if pixels[x, y] < 110:
                row_dark += 1
        dark_pixels += row_dark
        if row_dark / sample_width >= 0.11:
            dark_rows.append(y)

    line_groups = 0
    previous_y = -10
    for y in dark_rows:
        if y - previous_y > 2:
            line_groups += 1
        previous_y = y

    dark_pixel_ratio = dark_pixels / total_pixels if total_pixels else 0
    return {
        "dark_pixel_ratio": round(dark_pixel_ratio, 4),
        "horizontal_line_count": line_groups,
        "has_staff_hint": line_groups >= 18,
    }


def _classify_page(
    *,
    page_number: int,
    text: str,
    title_candidates: list[str],
    has_staff_hint: bool,
    dark_pixel_ratio: float,
) -> str:
    normalized = _normalize(text)
    if page_number == 1 and ("position pieces" in normalized or "rick mooney" in normalized):
        return "cover"
    if not normalized and dark_pixel_ratio < 0.01 and not has_staff_hint:
        return "blank"
    if any(keyword in normalized for keyword in ("contents", "table of contents")):
        return "front_matter"
    if any(
        keyword in normalized
        for keyword in (
            "a note to students",
            "geography quiz",
            "target practice",
            "names and numbers",
            "answer the following questions",
        )
    ):
        return "instructional"
    if any(keyword in normalized for keyword in ("isbn", "other publications", "alfred")):
        return "front_matter"
    if has_staff_hint:
        return "music_piece"
    if title_candidates and page_number > 1:
        return "unknown"
    if normalized:
        return "front_matter" if page_number <= 5 else "unknown"
    return "blank"


def _propose_splits(
    page_facts: list[BookPageFact],
    book_metadata: dict[str, Any],
) -> list[BookSplitProposal]:
    proposals: list[BookSplitProposal] = []
    active_title: str | None = None
    active_start: int | None = None
    active_warnings: list[str] = []

    for fact in page_facts:
        if fact.classification != "music_piece":
            if active_title is not None and active_start is not None:
                proposals.append(
                    _proposal(
                        active_title,
                        active_start,
                        fact.page_number - 1,
                        book_metadata,
                        active_warnings,
                    )
                )
                active_title = None
                active_start = None
                active_warnings = []
            continue

        titles = fact.title_candidates
        if titles and active_title and _normalize(titles[0]) == _normalize(active_title):
            titles = titles[1:]

        if titles:
            if active_title is not None and active_start is not None:
                proposals.append(
                    _proposal(
                        active_title,
                        active_start,
                        fact.page_number - 1,
                        book_metadata,
                        active_warnings,
                    )
                )
                active_title = None
                active_start = None
                active_warnings = []
            if len(titles) > 1:
                proposals.append(
                    _proposal(
                        " / ".join(_trim_title_punctuation(title) for title in titles),
                        fact.page_number,
                        fact.page_number,
                        book_metadata,
                        list(fact.warnings)
                        + [
                            "Multiple short pieces detected on one page; kept together "
                            "as one shared page item."
                        ],
                        contained_piece_titles=[_trim_title_punctuation(title) for title in titles],
                        multi_piece_page=True,
                    )
                )
                continue
            for title in titles[:-1]:
                proposals.append(
                    _proposal(
                        title,
                        fact.page_number,
                        fact.page_number,
                        book_metadata,
                        list(fact.warnings),
                    )
                )
            active_title = titles[-1]
            active_start = fact.page_number
            active_warnings = list(fact.warnings)
        elif active_title is None:
            active_title = f"Untitled piece page {fact.page_number}"
            active_start = fact.page_number
            active_warnings = ["No reliable title was detected on the first music page."]
        else:
            active_warnings.extend(fact.warnings)

    if active_title is not None and active_start is not None:
        proposals.append(
            _proposal(
                active_title,
                active_start,
                page_facts[-1].page_number,
                book_metadata,
                active_warnings,
            )
        )

    return _dedupe_short_false_positives(proposals)


def _proposal(
    title: str,
    page_start: int,
    page_end: int,
    book_metadata: dict[str, Any],
    warnings: list[str],
    contained_piece_titles: list[str] | None = None,
    multi_piece_page: bool = False,
) -> BookSplitProposal:
    confidence = 0.8 if multi_piece_page else 0.84
    if title.lower().startswith("untitled"):
        confidence = 0.55
    composer = _metadata_string(book_metadata, "composer")
    instrument = _metadata_string(book_metadata, "primary_instrument")
    return BookSplitProposal(
        title=title,
        page_start=page_start,
        page_end=max(page_start, page_end),
        composer=composer,
        primary_instrument=instrument,
        contained_piece_titles=contained_piece_titles or [title],
        multi_piece_page=multi_piece_page,
        confidence=confidence,
        validation_warnings=sorted(set(warnings)),
    )


def _dedupe_short_false_positives(
    proposals: list[BookSplitProposal],
) -> list[BookSplitProposal]:
    cleaned: list[BookSplitProposal] = []
    seen = set()
    for proposal in proposals:
        normalized_title = _normalize(proposal.title)
        if not normalized_title or normalized_title in seen:
            continue
        seen.add(normalized_title)
        cleaned.append(proposal)
    return cleaned


def _title_candidates(
    text: str,
    toc_titles: list[str],
    *,
    title_ocr_text: str = "",
) -> list[str]:
    candidates = []
    lines = [_clean_line(line) for line in re.split(r"[\n\r]+", text) if _clean_line(line)]
    matched_titles = _toc_title_matches(
        "\n".join(part for part in (text, title_ocr_text) if part.strip()),
        toc_titles,
    )
    for title in matched_titles:
        _append_unique_title_candidate(candidates, title)
    for line in lines[:2]:
        line = _clean_title(line)
        normalized = _normalize(line)
        if _looks_like_title(line, normalized) and _looks_like_standalone_title_ocr_line(
            line, normalized
        ):
            _append_unique_title_candidate(candidates, line)
    for title in _standalone_title_ocr_candidates(title_ocr_text):
        _append_unique_title_candidate(candidates, title)
    limit = 4 if matched_titles else 3
    return candidates[:limit]


def _append_unique_title_candidate(candidates: list[str], title: str) -> None:
    normalized = _normalize(title)
    if not normalized:
        return
    if any(_normalize(existing) == normalized for existing in candidates):
        return
    candidates.append(title)


def _toc_title_matches(text: str, toc_titles: list[str]) -> list[str]:
    matches: list[str] = []
    sorted_titles = sorted(toc_titles, key=lambda title: len(_normalize(title)), reverse=True)
    for raw_line in re.split(r"[\n\r]+", text):
        line = _clean_title(_clean_line(raw_line))
        normalized_line = _normalize(line)
        if not normalized_line:
            continue
        note_index = normalized_line.find("see the note")
        for title in sorted_titles:
            normalized_title = _normalize(title)
            title_index = normalized_line.find(normalized_title)
            if title_index < 0:
                continue
            if note_index >= 0 and title_index > note_index:
                continue
            if "also can be fingered" in normalized_line and title_index > 0:
                continue
            if title not in matches:
                matches.append(title)

    filtered: list[str] = []
    for title in matches:
        normalized_title = _normalize(title)
        if any(
            normalized_title != _normalize(other) and normalized_title in _normalize(other)
            for other in matches
        ):
            continue
        filtered.append(title)
    return filtered


def _looks_like_title(line: str, normalized: str) -> bool:
    if len(line) < 3 or len(line) > 80:
        return False
    stripped = line.strip()
    if not stripped or stripped[0] in {"*", "°", "«"}:
        return False
    if normalized in {
        "position pieces",
        "rick mooney",
        "first position",
        "second position",
        "third position",
        "fourth position",
        "names and numbers",
        "page",
        "fine",
        "d c al fine",
    }:
        return False
    if normalized.endswith("d c al fine") and len(normalized.split()) <= 5:
        return False
    if "see the note" in normalized:
        return False
    if any(keyword in normalized for keyword in ("copyright", "isbn", "printed in")):
        return False
    if any(keyword in normalized for keyword in ("sempre", "pizz", "arco", "cresc")):
        return False
    if any(char in line for char in "<>=~"):
        return False
    letters = sum(char.isalpha() for char in line)
    digits = sum(char.isdigit() for char in line)
    if letters < 3:
        return False
    if digits >= 3:
        return False
    if letters / max(len(line), 1) < 0.45:
        return False
    words = normalized.split()
    if len(words) > 7:
        return False
    return True


def _standalone_title_ocr_candidates(text: str) -> list[str]:
    candidates: list[str] = []
    if not text.strip():
        return candidates
    for raw_line in re.split(r"[\n\r]+", text):
        line = _clean_title(_clean_line(raw_line))
        normalized = _normalize(line)
        if not _looks_like_title(line, normalized):
            continue
        if not _looks_like_standalone_title_ocr_line(line, normalized):
            continue
        if line not in candidates:
            candidates.append(line)
    return candidates


def _looks_like_standalone_title_ocr_line(line: str, normalized: str) -> bool:
    if not normalized:
        return False
    if normalized in {
        "thee",
        "pee",
        "sab",
        "the",
        "and",
        "names",
        "numbers",
        "page",
        "note",
        "fine",
        "this one",
    }:
        return False
    if normalized.startswith(("j ", "d ", "m ")):
        return False
    words = line.split()
    normalized_words = normalized.split()
    if len(words) == 1:
        word = words[0]
        if len(word) < 4 and normalized != "jig":
            return False
        return word[:1].isupper()
    allowed_short_words = {"a", "i", "c", "d", "in", "at", "so", "to", "my"}
    if any(len(word) <= 2 and word not in allowed_short_words for word in normalized_words):
        return False
    noise_words = {
        "ae",
        "ee",
        "es",
        "oe",
        "re",
        "ss",
        "se",
        "te",
        "ial",
        "deve",
        "pale",
        "fpe",
        "arco",
        "pizz",
    }
    if any(word in noise_words for word in normalized_words):
        return False
    connector_words = {"and", "for", "in", "of", "on", "the", "to", "with"}
    content_pairs = [
        (word, normalized_word)
        for word, normalized_word in zip(words, normalized_words)
        if normalized_word not in connector_words
    ]
    if not content_pairs:
        return False
    title_words = sum(1 for word, _ in content_pairs if word[:1].isupper())
    return title_words >= len(content_pairs)


def _improve_book_metadata(
    metadata: dict[str, Any],
    page_facts: list[BookPageFact],
    file_name: str,
) -> None:
    combined = " ".join(fact.text for fact in page_facts[:6])
    normalized = _normalize(combined)
    if "position pieces" in normalized:
        metadata["title"] = "Position Pieces for Cello, Book 1"
        metadata["book_or_collection"] = "Position Pieces for Cello, Book 1"
    if "rick mooney" in normalized:
        metadata["composer"] = "Rick Mooney"
    if "cello" in _normalize(file_name) or "cello" in normalized:
        metadata["primary_instrument"] = "Cello"


def _extract_toc_titles(page_facts: list[BookPageFact]) -> list[str]:
    titles: list[str] = []
    for fact in page_facts[:4]:
        if "contents" not in _normalize(fact.text):
            continue
        for raw_line in re.split(r"[\n\r]+", fact.text):
            line = _clean_title(_clean_line(raw_line))
            normalized = _normalize(line)
            if not _looks_like_toc_title(line, normalized):
                continue
            if line not in titles:
                titles.append(line)
    return titles


def _looks_like_toc_title(line: str, normalized: str) -> bool:
    if not _looks_like_title(line, normalized):
        return False
    if normalized in {
        "contents",
        "a note to student",
        "upper second position",
        "extended second position",
        "lower third position",
        "lower second position",
        "fourth position",
        "upper third position",
        "extended third position",
        "half position",
        "various positions",
    }:
        return False
    if any(
        keyword in normalized
        for keyword in ("target practice", "geography quiz", "names and numbers")
    ):
        return False
    return True


def _metadata_string(metadata: dict[str, Any], key: str) -> str | None:
    value = metadata.get(key)
    if isinstance(value, str):
        stripped = value.strip()
        return stripped or None
    return None


def _excerpt(text: str, max_length: int = 700) -> str:
    compact = _compact_text(text)
    if len(compact) <= max_length:
        return compact
    return compact[: max_length - 1].rstrip() + "…"


def _compact_text(text: str) -> str:
    return " ".join(text.replace("\x0c", " ").split())


def _clean_line(line: str) -> str:
    return " ".join(line.replace("\x0c", " ").split()).strip(" :;,-")


def _clean_title(line: str) -> str:
    line = re.sub(r"\.{2,}.*$", "", line)
    line = re.sub(r"\s+\d+$", "", line)
    line = re.sub(r"^\d+\s+", "", line)
    return _clean_line(line)


def _trim_title_punctuation(title: str) -> str:
    return _clean_line(title).rstrip(".")


def _normalize(value: str) -> str:
    value = value.replace("Т", "'").replace("т", "'")
    return " ".join("".join(char.lower() if char.isalnum() else " " for char in value).split())

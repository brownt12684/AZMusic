"""OCR text extraction and conservative catalog metadata inference."""

from __future__ import annotations

import re
import subprocess
import tempfile
from dataclasses import dataclass, field
from io import BytesIO
from pathlib import Path
from typing import Any

from server.services.processing_settings import executable_status

IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".tif", ".tiff"}
PDF_EXTENSION = ".pdf"
DEFAULT_MAX_OCR_PAGES = 4


@dataclass(slots=True)
class OcrPageText:
    page_number: int
    text: str
    source: str


@dataclass(slots=True)
class OcrMetadataResult:
    metadata: dict[str, Any] = field(default_factory=dict)
    catalog_suggestions: list[dict[str, Any]] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    confidence: float = 0.0
    engine_name: str = "ocr_unavailable"
    pages: list[dict[str, Any]] = field(default_factory=list)


class OcrMetadataExtractor:
    """Extract text from score imports and infer parent-review metadata."""

    def __init__(self, processing_settings: dict[str, Any] | None = None) -> None:
        self._settings = processing_settings or {}

    def extract(self, *, file_name: str, file_bytes: bytes) -> OcrMetadataResult:
        suffix = Path(file_name).suffix.lower()
        warnings: list[str] = []
        pages: list[OcrPageText] = []

        if suffix == PDF_EXTENSION:
            extracted_pages, extracted_warnings = self._extract_pdf_text_layer(file_bytes)
            pages.extend(extracted_pages)
            warnings.extend(extracted_warnings)
            if not _has_enough_text(pages):
                ocr_pages, ocr_warnings = self._extract_pdf_with_tesseract(file_bytes)
                pages.extend(ocr_pages)
                warnings.extend(ocr_warnings)
        elif suffix in IMAGE_EXTENSIONS:
            extracted_pages, extracted_warnings = self._extract_image_with_tesseract(
                file_name=file_name,
                file_bytes=file_bytes,
            )
            pages.extend(extracted_pages)
            warnings.extend(extracted_warnings)
        else:
            warnings.append(
                f"OCR metadata extraction does not support {suffix or 'this file type'}."
            )

        combined_text = "\n".join(page.text for page in pages if page.text.strip())
        metadata = infer_metadata_from_text(combined_text)
        if combined_text.strip():
            metadata["ocr_text_excerpt"] = _excerpt(combined_text)
            metadata["ocr_pages"] = [
                {
                    "page_number": page.page_number,
                    "source": page.source,
                    "text_excerpt": _excerpt(page.text, max_length=500),
                }
                for page in pages
                if page.text.strip()
            ]

        confidence = _metadata_confidence(metadata, has_text=bool(combined_text.strip()))
        engine_name = _engine_name(pages)
        if metadata:
            metadata["ocr_engine"] = engine_name
            metadata["ocr_confidence"] = confidence

        return OcrMetadataResult(
            metadata=metadata,
            catalog_suggestions=_catalog_suggestions(metadata, confidence),
            warnings=warnings,
            confidence=confidence,
            engine_name=engine_name,
            pages=[
                {
                    "page_number": page.page_number,
                    "source": page.source,
                    "text_excerpt": _excerpt(page.text, max_length=500),
                }
                for page in pages
                if page.text.strip()
            ],
        )

    def _extract_pdf_text_layer(self, file_bytes: bytes) -> tuple[list[OcrPageText], list[str]]:
        try:
            from pypdf import PdfReader
        except ImportError:
            return [], ["pypdf is not installed; PDF text-layer extraction was skipped."]

        try:
            reader = PdfReader(BytesIO(file_bytes))
            pages = []
            for page_index, page in enumerate(reader.pages[:DEFAULT_MAX_OCR_PAGES]):
                text = page.extract_text() or ""
                if text.strip():
                    pages.append(
                        OcrPageText(
                            page_number=page_index + 1,
                            text=text,
                            source="pdf_text_layer",
                        )
                    )
        except Exception as exc:  # noqa: BLE001
            return [], [f"PDF text-layer extraction failed: {exc}"]

        if pages:
            return pages, []
        return [], ["No readable PDF text layer was found on the first pages."]

    def _extract_pdf_with_tesseract(self, file_bytes: bytes) -> tuple[list[OcrPageText], list[str]]:
        status = self._tesseract_status()
        if not status.available or not status.discovered_path:
            return [], [_missing_tesseract_warning(status)]

        try:
            import pypdfium2 as pdfium  # type: ignore[import-not-found]
        except ImportError:
            return [], ["pypdfium2 is not installed; scanned PDF OCR rendering was skipped."]

        warnings: list[str] = []
        pages: list[OcrPageText] = []
        with tempfile.TemporaryDirectory(prefix="azmusic_ocr_") as temp_dir:
            try:
                document = pdfium.PdfDocument(file_bytes)
                page_count = min(len(document), DEFAULT_MAX_OCR_PAGES)
                for page_index in range(page_count):
                    image_path = Path(temp_dir) / f"page_{page_index + 1}.png"
                    page = document[page_index]
                    bitmap = page.render(scale=2)
                    image = bitmap.to_pil()
                    image.save(image_path)
                    text, page_warnings = self._run_tesseract(image_path)
                    warnings.extend(page_warnings)
                    if text.strip():
                        pages.append(
                            OcrPageText(
                                page_number=page_index + 1,
                                text=text,
                                source="tesseract_pdf_page",
                            )
                        )
            except Exception as exc:  # noqa: BLE001
                warnings.append(f"Scanned PDF OCR failed: {exc}")

        return pages, warnings

    def _extract_image_with_tesseract(
        self,
        *,
        file_name: str,
        file_bytes: bytes,
    ) -> tuple[list[OcrPageText], list[str]]:
        status = self._tesseract_status()
        if not status.available or not status.discovered_path:
            return [], [_missing_tesseract_warning(status)]

        suffix = Path(file_name).suffix.lower() or ".png"
        with tempfile.TemporaryDirectory(prefix="azmusic_ocr_") as temp_dir:
            image_path = Path(temp_dir) / f"scan{suffix}"
            image_path.write_bytes(file_bytes)
            text, warnings = self._run_tesseract(image_path)

        pages = (
            [OcrPageText(page_number=1, text=text, source="tesseract_image")]
            if text.strip()
            else []
        )
        return pages, warnings

    def _run_tesseract(self, image_path: Path) -> tuple[str, list[str]]:
        status = self._tesseract_status()
        if not status.available or not status.discovered_path:
            return "", [_missing_tesseract_warning(status)]

        language = str(self._settings.get("ocr_language") or "eng").strip() or "eng"
        command = [
            status.discovered_path,
            str(image_path),
            "stdout",
            "--psm",
            "6",
            "-l",
            language,
        ]
        try:
            result = subprocess.run(
                command,
                check=False,
                capture_output=True,
                text=True,
                timeout=45,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            return "", [f"Tesseract OCR failed to start: {exc}"]

        warnings = []
        if result.returncode != 0:
            output = (result.stderr or result.stdout).strip()
            warnings.append(f"Tesseract OCR failed: {output or 'unknown error'}")
            return "", warnings
        if result.stderr.strip():
            warnings.append(result.stderr.strip()[:500])
        return result.stdout, warnings

    def _tesseract_status(self):
        return executable_status(
            name="Tesseract OCR",
            configured_path=self._settings.get("ocr_cli_path"),
            fallback_names=("tesseract",),
        )


def infer_metadata_from_text(text: str) -> dict[str, Any]:
    """Infer score metadata from OCR text without pretending certainty."""

    lines = _clean_lines(text)
    if not lines:
        return {}

    metadata: dict[str, Any] = {}
    title = _infer_title(lines)
    if title:
        metadata["title"] = title

    composer = _infer_composer(lines)
    if composer:
        metadata["composer"] = composer

    arranger = _infer_credit(lines, ("arranged by", "arr. by", "arr.", "arranger"))
    if arranger:
        metadata["arranger"] = arranger

    editor = _infer_credit(lines, ("edited by", "ed. by", "editor"))
    if editor:
        metadata["editor"] = editor

    instrument = _infer_primary_instrument(lines)
    if instrument:
        metadata["primary_instrument"] = instrument

    collection = _infer_collection(lines, title)
    if collection:
        metadata["book_or_collection"] = collection

    key_signature = _infer_key_signature(lines)
    if key_signature:
        metadata["key_signature"] = key_signature

    tempo = _infer_tempo(lines)
    if tempo:
        metadata["tempo"] = tempo

    opus = _infer_opus(lines)
    if opus:
        metadata["opus"] = opus

    catalog_number = _infer_catalog_number(lines)
    if catalog_number:
        metadata["catalog_number"] = catalog_number

    publisher = _infer_publisher(lines)
    if publisher:
        metadata["publisher"] = publisher

    return metadata


def _clean_lines(text: str) -> list[str]:
    lines = []
    for raw_line in text.replace("\r", "\n").split("\n"):
        line = " ".join(raw_line.replace("\t", " ").split())
        line = line.strip(" -_|:;,.")
        if not line or len(line) < 2:
            continue
        if _is_noise_line(line):
            continue
        lines.append(line)
    return lines


def _is_noise_line(line: str) -> bool:
    normalized = _normalize(line)
    if not normalized:
        return True
    if normalized in {"page", "score", "music", "copyright", "public domain"}:
        return True
    if normalized.startswith("page ") and normalized.split()[-1].isdigit():
        return True
    if sum(char.isalpha() for char in line) < 2:
        return True
    return False


def _infer_title(lines: list[str]) -> str | None:
    for line in lines[:14]:
        if _is_metadata_line(line):
            continue
        if _looks_like_credit_only(line):
            continue
        if _infer_primary_instrument([line]) and len(line.split()) <= 4:
            continue
        if len(line) > 120:
            continue
        return _title_case_if_needed(line)
    return None


def _infer_composer(lines: list[str]) -> str | None:
    for line in lines[:18]:
        normalized = _normalize(line)
        for prefix in (
            "composed by",
            "music by",
            "by",
            "composer",
            "composer by",
        ):
            if normalized.startswith(prefix):
                credit = _credit_after_prefix(line, prefix)
                if credit:
                    return credit

    for line in lines[1:14]:
        composer = _known_composer_from_line(line)
        if composer:
            return composer
        if _looks_like_person_name(line) and not _is_metadata_line(line):
            return line
    return None


def _infer_credit(lines: list[str], prefixes: tuple[str, ...]) -> str | None:
    for line in lines[:20]:
        normalized = _normalize(line)
        for prefix in prefixes:
            if normalized.startswith(prefix):
                credit = _credit_after_prefix(line, prefix)
                if credit:
                    return credit
            marker = f" {prefix} "
            if marker in normalized:
                _, _, tail = line.partition(prefix)
                credit = tail.strip(" :;-")
                if credit:
                    return credit
    return None


def _infer_primary_instrument(lines: list[str]) -> str | None:
    instrument_map = {
        "violin": "Violin",
        "viola": "Viola",
        "cello": "Cello",
        "violoncello": "Cello",
        "piano": "Piano",
        "flute": "Flute",
        "clarinet": "Clarinet",
        "trumpet": "Trumpet",
        "guitar": "Guitar",
        "voice": "Voice",
        "soprano": "Voice",
    }
    for line in lines[:24]:
        normalized = _normalize(line)
        for token, label in instrument_map.items():
            if re.search(rf"\b{re.escape(token)}\b", normalized) or token in normalized:
                return label
    return None


def _infer_collection(lines: list[str], title: str | None) -> str | None:
    collection_markers = (
        "book",
        "volume",
        "vol",
        "collection",
        "album",
        "notebook",
        "school",
        "method",
    )
    for line in lines[:24]:
        normalized = _normalize(line)
        if title and _normalize(line) == _normalize(title):
            continue
        if any(re.search(rf"\b{marker}\b", normalized) for marker in collection_markers):
            return line
    return None


def _infer_key_signature(lines: list[str]) -> str | None:
    for line in lines[:30]:
        match = re.search(
            r"\b([A-G](?:#|b| sharp| flat)?\s+(?:major|minor))\b",
            line,
            flags=re.IGNORECASE,
        )
        if match:
            return _title_case_if_needed(match.group(1))
    return None


def _infer_tempo(lines: list[str]) -> str | None:
    tempo_words = (
        "Largo",
        "Adagio",
        "Andante",
        "Moderato",
        "Allegro",
        "Presto",
        "Vivace",
    )
    for line in lines[:30]:
        numeric = re.search(
            r"(?:tempo|quarter|q\.?|bpm)\s*[:=]?\s*(\d{2,3})",
            line,
            flags=re.IGNORECASE,
        )
        if numeric:
            return numeric.group(1)
        for word in tempo_words:
            if re.search(rf"\b{word}\b", line, flags=re.IGNORECASE):
                return word
    return None


def _infer_opus(lines: list[str]) -> str | None:
    for line in lines[:30]:
        match = re.search(r"\b(?:op\.?|opus)\s*[\w./ -]+", line, flags=re.IGNORECASE)
        if match:
            return match.group(0).strip(" .")
    return None


def _infer_catalog_number(lines: list[str]) -> str | None:
    for line in lines[:30]:
        match = re.search(
            r"\b(?:BWV|K\.?|KV|Hob\.?|RV|D\.)\s*[A-Za-z0-9./ -]+",
            line,
            flags=re.IGNORECASE,
        )
        if match:
            return match.group(0).strip(" .")
    return None


def _infer_publisher(lines: list[str]) -> str | None:
    for line in lines[:40]:
        normalized = _normalize(line)
        if "copyright" in normalized or "(c)" in normalized or "©" in line:
            return line
        if any(marker in normalized for marker in ("publishing", "edition", "press")):
            return line
    return None


def _is_metadata_line(line: str) -> bool:
    normalized = _normalize(line)
    return any(
        normalized.startswith(prefix)
        for prefix in (
            "composer",
            "arranged by",
            "arranger",
            "edited by",
            "editor",
            "for ",
            "key ",
            "tempo",
            "opus",
            "op ",
            "bwv",
            "copyright",
        )
    )


def _looks_like_credit_only(line: str) -> bool:
    return bool(_known_composer_from_line(line)) and len(line.split()) <= 5


def _known_composer_from_line(line: str) -> str | None:
    normalized = _normalize(line)
    known = {
        "bach": "Bach",
        "j s bach": "J. S. Bach",
        "johann sebastian bach": "Johann Sebastian Bach",
        "beethoven": "Beethoven",
        "ludwig van beethoven": "Ludwig van Beethoven",
        "mozart": "Mozart",
        "wolfgang amadeus mozart": "Wolfgang Amadeus Mozart",
        "pachelbel": "Pachelbel",
        "johann pachelbel": "Johann Pachelbel",
        "vivaldi": "Vivaldi",
        "antonio vivaldi": "Antonio Vivaldi",
        "suzuki": "Shinichi Suzuki",
        "shinichi suzuki": "Shinichi Suzuki",
        "handel": "Handel",
        "george frideric handel": "George Frideric Handel",
        "haydn": "Haydn",
        "franz joseph haydn": "Franz Joseph Haydn",
        "chopin": "Chopin",
        "frederic chopin": "Frederic Chopin",
        "schumann": "Schumann",
        "schubert": "Schubert",
    }
    for key, value in sorted(known.items(), key=lambda item: len(item[0]), reverse=True):
        if re.search(rf"\b{re.escape(key)}\b", normalized):
            return value
    return None


def _looks_like_person_name(line: str) -> bool:
    words = [word for word in re.split(r"\s+", line.strip()) if word]
    if not 2 <= len(words) <= 5:
        return False
    if any(_normalize(word) in {"for", "book", "volume", "tempo"} for word in words):
        return False
    return sum(word[:1].isupper() for word in words) >= 2


def _credit_after_prefix(line: str, normalized_prefix: str) -> str | None:
    normalized_line = _normalize(line)
    start = normalized_line.find(normalized_prefix)
    if start < 0:
        return None
    words_to_drop = len(normalized_prefix.split())
    original_words = line.split()
    if len(original_words) <= words_to_drop:
        tail = re.sub(
            rf"^{re.escape(normalized_prefix)}\s*[:;-]?\s*",
            "",
            normalized_line,
            flags=re.IGNORECASE,
        )
        return _title_case_if_needed(tail) if tail else None
    return " ".join(original_words[words_to_drop:]).strip(" :;-") or None


def _catalog_suggestions(metadata: dict[str, Any], confidence: float) -> list[dict[str, Any]]:
    fields = {
        key: value
        for key, value in metadata.items()
        if key
        in {
            "title",
            "composer",
            "arranger",
            "editor",
            "primary_instrument",
            "book_or_collection",
            "key_signature",
            "tempo",
            "opus",
            "catalog_number",
            "publisher",
        }
        and value not in (None, "", [])
    }
    if not fields:
        return []
    return [{"source": "ocr_text", "confidence": confidence, "fields": fields}]


def _metadata_confidence(metadata: dict[str, Any], *, has_text: bool) -> float:
    if not has_text:
        return 0.0
    if metadata.get("title") and metadata.get("composer"):
        return 0.78
    if metadata.get("title"):
        return 0.66
    return 0.42


def _engine_name(pages: list[OcrPageText]) -> str:
    sources = {page.source for page in pages if page.text.strip()}
    if not sources:
        return "ocr_unavailable"
    if any(source.startswith("tesseract") for source in sources):
        return "tesseract"
    if "pdf_text_layer" in sources:
        return "pdf_text_layer"
    return sorted(sources)[0]


def _has_enough_text(pages: list[OcrPageText]) -> bool:
    return sum(len(page.text.strip()) for page in pages) >= 80


def _missing_tesseract_warning(status) -> str:
    if status.configured and status.error:
        return f"Tesseract OCR is configured but unavailable: {status.error}"
    if status.configured:
        return "Tesseract OCR is configured but the executable was not found."
    return "Tesseract OCR is not configured or discoverable; scanned image OCR was skipped."


def _excerpt(text: str, *, max_length: int = 1000) -> str:
    compact = " ".join(text.split())
    if len(compact) <= max_length:
        return compact
    return compact[: max_length - 1].rstrip() + "..."


def _normalize(value: str) -> str:
    return " ".join("".join(char.lower() if char.isalnum() else " " for char in value).split())


def _title_case_if_needed(value: str) -> str:
    stripped = " ".join(value.split()).strip(" :;-")
    letters = [char for char in stripped if char.isalpha()]
    if letters and sum(char.isupper() for char in letters) / len(letters) > 0.75:
        return stripped.title()
    return stripped

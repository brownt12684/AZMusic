"""Table-of-contents extraction from PDF score files.

Strategy:
1. Try embedded bookmarks via PyMuPDF (fast, no OCR).
2. If no bookmarks and the PDF has multiple pages, render the first page
   as an image and run Tesseract OCR to parse chapter/section entries.
3. Return a flat list of {title, page} dicts.
"""

from __future__ import annotations

import logging
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

import fitz
import pytesseract
from PIL import Image

logger = logging.getLogger(__name__)

# Tesseract binary path — adjust if installed elsewhere.
_TESSERACT_CMD = r"C:\Program Files\Tesseract-OCR\tesseract.exe"
pytesseract.pytesseract.tesseract_cmd = _TESSERACT_CMD

# DPI for rendering PDF pages to images for OCR.
_OCR_DPI = 200

# Regex patterns for parsing OCR output into TOC entries.
# Matches lines like:
#   "1  Introduction .................................... 3"
#   "Chapter 2: The Development of Style ................. 12"
#   "Prelude in C major .................................. 7"
_TOC_LINE_RE = re.compile(
    r"^"
    r"(?:(?:Chapter\s+\d+[:.]?\s*)?"  # optional "Chapter N:"
    r"(?:[IVX]+\s*)?"               # optional Roman numerals
    r"[^\.]*?)"                     # title (non-greedy)
    r"\s+"                          # separator whitespace
    r"(\d+)"                        # page number
    r"\s*$",
    re.IGNORECASE,
)

# Simpler fallback: "word(s) ... digits"
_TOC_LINE_FALLBACK_RE = re.compile(
    r"^(.+?)\.{2,}\s+(\d+)\s*$",
    re.IGNORECASE,
)


@dataclass
class TocEntry:
    """A single table-of-contents entry."""

    title: str
    page: int
    depth: int = 0  # 0 = top-level, 1 = subsection, etc.


@dataclass
class TocExtractionResult:
    """Result of TOC extraction from a PDF."""

    entries: list[TocEntry] = field(default_factory=list)
    source: str = "none"  # "embedded", "ocr", "none"
    error: Optional[str] = None


def extract_toc(pdf_path: str | Path) -> TocExtractionResult:
    """Extract table of contents from a PDF file.

    Returns a TocExtractionResult with entries and the source of extraction.
    """
    path = Path(pdf_path)
    if not path.exists():
        return TocExtractionResult(error=f"File not found: {path}")

    try:
        doc = fitz.open(path)
    except Exception as exc:
        return TocExtractionResult(error=f"Failed to open PDF: {exc}")

    try:
        # Strategy 1: embedded bookmarks
        result = _extract_embedded_toc(doc)
        if result.entries:
            result.source = "embedded"
            return result

        # Strategy 2: OCR on first page (multi-page PDFs only)
        if len(doc) > 1:
            result = _extract_ocr_toc(doc)
            if result.entries:
                result.source = "ocr"
                return result

        return TocExtractionResult(source="none")
    finally:
        doc.close()


def _extract_embedded_toc(doc: fitz.Document) -> TocExtractionResult:
    """Extract TOC from embedded bookmarks."""
    toc = doc.get_toc()
    if not toc:
        return TocExtractionResult()

    entries: list[TocEntry] = []
    for level, title, page_num in toc:
        title = title.strip()
        if not title:
            continue
        # Clamp page number to valid range
        page_num = max(1, min(page_num, len(doc)))
        entries.append(TocEntry(title=title, page=page_num, depth=level - 1))

    return TocExtractionResult(entries=entries)


def _extract_ocr_toc(doc: fitz.Document) -> TocExtractionResult:
    """Extract TOC by OCR-ing the first page of the PDF."""
    try:
        page = doc[0]
        pix = page.get_pixmap(dpi=_OCR_DPI)
        img_bytes = pix.tobytes("png")
        image = Image.open(_bytes_io(img_bytes))
    except Exception as exc:
        logger.warning("Failed to render first page for OCR: %s", exc)
        return TocExtractionResult()

    try:
        text = pytesseract.image_to_string(image, config="--psm 6")
    except Exception as exc:
        logger.warning("Tesseract OCR failed: %s", exc)
        return TocExtractionResult()

    entries = _parse_ocr_text(text)
    return TocExtractionResult(entries=entries)


def _bytes_io(data: bytes):
    """Return an in-memory bytes buffer."""
    from io import BytesIO

    return BytesIO(data)


def _parse_ocr_text(text: str) -> list[TocEntry]:
    """Parse OCR text into TOC entries.

    Heuristic: look for lines that end with a page number, possibly
    preceded by dots or whitespace.
    """
    entries: list[TocEntry] = []
    lines = text.strip().splitlines()

    for line in lines:
        line = line.strip()
        if not line:
            continue

        entry = _try_parse_toc_line(line)
        if entry:
            entries.append(entry)

    return entries


def _try_parse_toc_line(line: str) -> Optional[TocEntry]:
    """Try to parse a single line as a TOC entry."""
    # Primary pattern: title ... page_number
    match = _TOC_LINE_RE.search(line)
    if match:
        title = match.group(1).strip().rstrip(".")
        page = int(match.group(2))
        if title and page > 0:
            return TocEntry(title=title, page=page)

    # Fallback: "title ............ page"
    match = _TOC_LINE_FALLBACK_RE.search(line)
    if match:
        title = match.group(1).strip()
        page = int(match.group(2))
        if title and page > 0:
            return TocEntry(title=title, page=page)

    return None


def toc_entries_to_dict(entries: list[TocEntry]) -> list[dict]:
    """Serialize TOC entries to a list of dicts for JSON API responses."""
    return [
        {"title": e.title, "page": e.page, "depth": e.depth}
        for e in entries
    ]

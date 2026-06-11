"""Render and crop one PDF measure image."""

from __future__ import annotations

from pathlib import Path
from typing import Any


class PdfCropError(RuntimeError):
    """Raised when PDF rendering or crop selection fails."""


def extract_measure_image(
    *,
    pdf_path: Path,
    page_number: int,
    region: dict[str, Any],
    output_path: Path,
    render_scale: float,
) -> Path:
    try:
        import pypdfium2 as pdfium
    except ImportError as exc:  # pragma: no cover - dependency check
        raise PdfCropError("pypdfium2 is required to render the PDF page.") from exc

    if page_number < 1:
        raise PdfCropError("page_number must be 1-based.")

    pdf = pdfium.PdfDocument(str(pdf_path))
    try:
        if page_number > len(pdf):
            raise PdfCropError(f"PDF has {len(pdf)} pages; page {page_number} is unavailable.")
        page = pdf[page_number - 1]
        bitmap = page.render(scale=render_scale)
        image = bitmap.to_pil()
    finally:
        pdf.close()

    box = _crop_box(region, image.width, image.height)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    image.crop(box).save(output_path)
    return output_path


def _crop_box(region: dict[str, Any], width: int, height: int) -> tuple[int, int, int, int]:
    units = str(region.get("units") or "normalized").lower()
    try:
        x = float(region["x"])
        y = float(region["y"])
        crop_width = float(region["width"])
        crop_height = float(region["height"])
    except (KeyError, TypeError, ValueError) as exc:
        raise PdfCropError("Measure region must include numeric x, y, width, and height.") from exc

    if units == "normalized":
        if not all(0 <= value <= 1 for value in (x, y, crop_width, crop_height)):
            raise PdfCropError("Normalized region values must be between 0 and 1.")
        left = round(x * width)
        top = round(y * height)
        right = round((x + crop_width) * width)
        bottom = round((y + crop_height) * height)
    elif units in {"pixels", "pixel", "px"}:
        left = round(x)
        top = round(y)
        right = round(x + crop_width)
        bottom = round(y + crop_height)
    else:
        raise PdfCropError("measure_region.units must be normalized or pixels.")

    left = max(0, min(left, width))
    top = max(0, min(top, height))
    right = max(0, min(right, width))
    bottom = max(0, min(bottom, height))
    if right <= left or bottom <= top:
        raise PdfCropError("Measure crop is empty after clamping to the rendered page.")
    return left, top, right, bottom

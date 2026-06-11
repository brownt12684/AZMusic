"""Lightweight rendered-score visual diff checks."""

from __future__ import annotations

from pathlib import Path
from typing import Any


class ScoreVisualDiffError(RuntimeError):
    """Raised when rendered score images cannot be compared."""


def compare_score_pdfs(
    *,
    before_pdf_path: Path,
    after_pdf_path: Path,
    original_pdf_path: Path | None = None,
    page_limit: int = 1,
) -> dict[str, Any]:
    """Compare rendered score PDFs and report whether notation changed visibly.

    This is intentionally heuristic. The parent still reviews the result, but the
    server should not call an LLM pass a notation correction if the candidate PDF
    did not change at all after the MusicXML tools ran.
    """

    before_images = _render_pdf_pages(before_pdf_path, page_limit=page_limit)
    after_images = _render_pdf_pages(after_pdf_path, page_limit=page_limit)
    page_count = min(len(before_images), len(after_images))
    if page_count <= 0:
        raise ScoreVisualDiffError("No rendered pages were available for visual diff.")

    comparisons = [
        _compare_images(before_images[index], after_images[index])
        for index in range(page_count)
    ]
    changed_pixel_ratio = max(
        comparison["changed_pixel_ratio"] for comparison in comparisons
    )
    changed_bbox = next(
        (
            comparison["changed_bbox"]
            for comparison in comparisons
            if comparison["changed_bbox"] is not None
        ),
        None,
    )
    original_alignment = None
    if original_pdf_path is not None and original_pdf_path.exists():
        try:
            original_images = _render_pdf_pages(original_pdf_path, page_limit=page_count)
            original_page_count = min(len(original_images), len(after_images))
            if original_page_count > 0:
                original_alignment = [
                    _compare_images(original_images[index], after_images[index])
                    for index in range(original_page_count)
                ]
        except ScoreVisualDiffError:
            original_alignment = None

    return {
        "passed": changed_pixel_ratio >= 0.0002,
        "changed_pixel_ratio": changed_pixel_ratio,
        "changed_bbox": changed_bbox,
        "page_count_compared": page_count,
        "original_alignment": original_alignment,
    }


def _render_pdf_pages(path: Path, *, page_limit: int) -> list[Any]:
    try:
        import pypdfium2 as pdfium
        from PIL import Image
    except Exception as exc:  # noqa: BLE001
        raise ScoreVisualDiffError(
            "pypdfium2 and Pillow are required for rendered score visual diff."
        ) from exc

    try:
        document = pdfium.PdfDocument(str(path))
    except Exception as exc:  # noqa: BLE001
        raise ScoreVisualDiffError(f"Could not open PDF for visual diff: {path}") from exc

    images: list[Any] = []
    try:
        for page_index in range(min(len(document), page_limit)):
            page = document[page_index]
            try:
                bitmap = page.render(scale=1.25)
                image = bitmap.to_pil().convert("L")
                image.thumbnail((1400, 1400))
                canvas = Image.new("L", image.size, 255)
                canvas.paste(image)
                images.append(canvas)
            finally:
                close = getattr(page, "close", None)
                if callable(close):
                    close()
    finally:
        close = getattr(document, "close", None)
        if callable(close):
            close()

    if not images:
        raise ScoreVisualDiffError(f"PDF has no pages for visual diff: {path}")
    return images


def _compare_images(before: Any, after: Any) -> dict[str, Any]:
    from PIL import Image, ImageChops

    width = max(before.width, after.width)
    height = max(before.height, after.height)
    before_canvas = Image.new("L", (width, height), 255)
    after_canvas = Image.new("L", (width, height), 255)
    before_canvas.paste(before, (0, 0))
    after_canvas.paste(after, (0, 0))
    diff = ImageChops.difference(before_canvas, after_canvas)
    mask = diff.point(lambda value: 255 if value > 24 else 0)
    histogram = mask.histogram()
    changed_pixels = histogram[255]
    total_pixels = max(1, width * height)
    bbox = mask.getbbox()
    return {
        "changed_pixel_ratio": changed_pixels / total_pixels,
        "changed_bbox": list(bbox) if bbox is not None else None,
    }

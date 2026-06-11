"""CLI for rendering and cropping one measure from a source PDF."""

from __future__ import annotations

import argparse
from pathlib import Path

from ..config import (
    load_config,
    measure_image_path,
    measure_region,
    page_number,
    pdf_path,
    render_scale,
)
from ..pdf_crop import extract_measure_image


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--config",
        default=None,
        help="Path to config.local.json. Defaults to the experiment local config.",
    )
    parser.add_argument("--output", default=None, help="Override output PNG path.")
    args = parser.parse_args(argv)

    config = load_config(args.config)
    output_path = Path(args.output) if args.output else measure_image_path(config)
    if not output_path.is_absolute():
        output_path = Path.cwd() / output_path

    result = extract_measure_image(
        pdf_path=pdf_path(config),
        page_number=page_number(config),
        region=measure_region(config),
        output_path=output_path,
        render_scale=render_scale(config),
    )
    print(result)
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())

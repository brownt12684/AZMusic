"""CLI for asking LM Studio to read one measure image."""

from __future__ import annotations

import argparse
from pathlib import Path

from ..config import (
    load_config,
    measure_facts_path,
    measure_image_path,
    raw_response_path,
    source_payload,
)
from ..vision import analyze_measure_image


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--config",
        default=None,
        help="Path to config.local.json. Defaults to the experiment local config.",
    )
    parser.add_argument("--image", default=None, help="Override cropped measure PNG path.")
    parser.add_argument("--output", default=None, help="Override measure facts JSON path.")
    args = parser.parse_args(argv)

    config = load_config(args.config)
    image_path = Path(args.image) if args.image else measure_image_path(config)
    output_path = Path(args.output) if args.output else measure_facts_path(config)
    if not image_path.is_absolute():
        image_path = Path.cwd() / image_path
    if not output_path.is_absolute():
        output_path = Path.cwd() / output_path

    facts = analyze_measure_image(
        image_path=image_path,
        source=source_payload(config),
        lm_studio_config=config.get("lm_studio", {}),
        raw_response_path=raw_response_path(config),
        output_path=output_path,
    )
    print(output_path)
    print(
        "measure_index="
        f"{facts['measure']['measure_index']} confidence={facts['measure']['confidence']}"
    )
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())

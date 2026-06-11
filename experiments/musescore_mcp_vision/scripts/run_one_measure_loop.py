"""Run the one-measure vision-to-MuseScore experiment loop."""

from __future__ import annotations

import argparse
from pathlib import Path

from ..config import (
    load_config,
    measure_facts_path,
    measure_image_path,
    measure_region,
    page_number,
    pdf_path,
    raw_response_path,
    render_scale,
    source_payload,
)
from ..pdf_crop import extract_measure_image
from ..vision import analyze_measure_image
from .apply_measure_with_mcp import main as apply_main


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--config",
        default=None,
        help="Path to config.local.json. Defaults to the experiment local config.",
    )
    parser.add_argument(
        "--dry-run-mcp",
        action="store_true",
        help="Stop after writing the MuseScore sequence instead of applying it.",
    )
    args = parser.parse_args(argv)

    config = load_config(args.config)
    image_path = extract_measure_image(
        pdf_path=pdf_path(config),
        page_number=page_number(config),
        region=measure_region(config),
        output_path=measure_image_path(config),
        render_scale=render_scale(config),
    )
    print(image_path)

    facts_path = measure_facts_path(config)
    analyze_measure_image(
        image_path=image_path,
        source=source_payload(config),
        lm_studio_config=config.get("lm_studio", {}),
        raw_response_path=raw_response_path(config),
        output_path=facts_path,
    )
    print(facts_path)

    apply_args = ["--config", str(Path(config["_config_path"]))]
    if args.dry_run_mcp:
        apply_args.append("--dry-run")
    return apply_main(apply_args)


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())

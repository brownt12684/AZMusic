"""CLI for converting measure facts into MuseScore MCP commands."""

from __future__ import annotations

import argparse
import asyncio
import json
from pathlib import Path
from typing import Any

from ..config import (
    load_config,
    mcp_result_path,
    measure_facts_path,
    minimum_confidence,
    sequence_path,
)
from ..mcp_stdio import McpStdioClient
from ..measure_schema import MeasureFactsValidationError, load_measure_facts
from ..sequence import SequenceBuildError, build_musescore_sequence


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--config",
        default=None,
        help="Path to config.local.json. Defaults to the experiment local config.",
    )
    parser.add_argument("--facts", default=None, help="Override measure facts JSON path.")
    parser.add_argument("--sequence-output", default=None, help="Override sequence JSON path.")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Write the sequence without starting the MCP server.",
    )
    args = parser.parse_args(argv)

    config = load_config(args.config)
    facts_path = Path(args.facts) if args.facts else measure_facts_path(config)
    output_path = Path(args.sequence_output) if args.sequence_output else sequence_path(config)
    if not facts_path.is_absolute():
        facts_path = Path.cwd() / facts_path
    if not output_path.is_absolute():
        output_path = Path.cwd() / output_path

    try:
        facts = load_measure_facts(facts_path)
        sequence_payload = build_musescore_sequence(
            facts,
            minimum_confidence=minimum_confidence(config),
        )
    except (MeasureFactsValidationError, SequenceBuildError) as exc:
        print(f"Cannot build MuseScore sequence: {exc}")
        return 2
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(sequence_payload, indent=2), encoding="utf-8")
    print(output_path)

    if args.dry_run:
        print("dry_run=true")
        return 0

    result = asyncio.run(_apply_sequence(config, sequence_payload))
    result_path = mcp_result_path(config)
    result_path.parent.mkdir(parents=True, exist_ok=True)
    result_path.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(result_path)
    error = _mcp_apply_error(result)
    if error:
        print(f"MCP apply failed: {error}")
        return 3
    return 0


async def _apply_sequence(
    config: dict[str, Any],
    sequence_payload: dict[str, Any],
) -> dict[str, Any]:
    mcp_config = config.get("mcp", {})
    command = mcp_config.get("server_command")
    if not isinstance(command, list) or not all(isinstance(part, str) for part in command):
        raise RuntimeError("mcp.server_command must be a list of command arguments.")
    tool_names = mcp_config.get("tool_names") or {}
    ping_tool = str(tool_names.get("ping") or "ping_musescore")
    process_sequence_tool = str(tool_names.get("process_sequence") or "processSequence")
    timeout = int(mcp_config.get("request_timeout_seconds") or 30)
    websocket_port = int(mcp_config.get("websocket_port") or 18765)

    async with McpStdioClient(
        command,
        timeout_seconds=timeout,
        env={"MUSESCORE_MCP_PORT": str(websocket_port)},
    ) as client:
        ping = await client.call_tool(ping_tool, {})
        applied = await client.call_tool(
            process_sequence_tool,
            {"sequence": sequence_payload["sequence"]},
        )
    return {
        "ping": ping.result,
        "process_sequence": applied.result,
        "unsupported": sequence_payload.get("unsupported", []),
        "duration_check": sequence_payload.get("duration_check", {}),
    }


def _mcp_apply_error(result: dict[str, Any]) -> str | None:
    for key in ("ping", "process_sequence"):
        message = _tool_result_error(result.get(key))
        if message:
            return f"{key}: {message}"
    return None


def _tool_result_error(value: Any) -> str | None:
    if not isinstance(value, dict):
        return "missing tool result"
    if value.get("isError") is True:
        return "tool marked result as error"
    content = value.get("content")
    if not isinstance(content, list):
        return None
    for item in content:
        if not isinstance(item, dict) or item.get("type") != "text":
            continue
        text = item.get("text")
        if not isinstance(text, str):
            continue
        parsed: Any
        try:
            parsed = json.loads(text)
        except json.JSONDecodeError:
            continue
        if isinstance(parsed, dict):
            if isinstance(parsed.get("error"), str):
                return parsed["error"]
            if parsed.get("success") is False:
                return "tool returned success=false"
            nested = parsed.get("result")
            if isinstance(nested, dict):
                if isinstance(nested.get("error"), str):
                    return nested["error"]
                if nested.get("success") is False:
                    return "tool nested result returned success=false"
    return None


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())

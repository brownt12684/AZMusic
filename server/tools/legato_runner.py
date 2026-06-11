"""AZMusic adapter for the official LEGATO OMR inference script.

The official LEGATO repository exposes `scripts/inference.py`, which writes a
JSON payload containing `abc_transcription`. AZMusic needs a stable runner
contract so the processing engine can treat LEGATO like any other OMR backend.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any

DEFAULT_MODEL_ID = "guangyangmusic/legato"


def main() -> int:
    parser = _build_parser()
    args = parser.parse_args()
    if args.version:
        source_root = _resolve_source_root(args.source_root)
        venv_python = _resolve_venv_python(args.venv_python, source_root)
        if not (source_root / "scripts" / "inference.py").exists():
            print(f"LEGATO inference script was not found under: {source_root}", file=sys.stderr)
            return 2
        if not venv_python.exists():
            print(f"LEGATO Python executable was not found: {venv_python}", file=sys.stderr)
            return 2
        print("AZMusic LEGATO adapter 0.1")
        return 0

    source_root = _resolve_source_root(args.source_root)
    venv_python = _resolve_venv_python(args.venv_python, source_root)
    if not source_root.exists():
        parser.error(f"LEGATO source root was not found: {source_root}")
    if not (source_root / "scripts" / "inference.py").exists():
        parser.error(f"LEGATO inference script was not found under: {source_root}")
    if not venv_python.exists():
        parser.error(f"LEGATO Python executable was not found: {venv_python}")

    input_path = Path(args.input).expanduser().resolve()
    output_abc = Path(args.output_abc).expanduser().resolve()
    metadata_path = Path(args.metadata).expanduser().resolve()
    output_abc.parent.mkdir(parents=True, exist_ok=True)
    metadata_path.parent.mkdir(parents=True, exist_ok=True)

    raw_output_path = metadata_path.with_suffix(".legato-output.json")
    model = _normalize_model_arg(args.model)
    command = [
        str(venv_python),
        str(source_root / "scripts" / "inference.py"),
        "--model_path",
        model,
        "--image_path",
        str(input_path),
        "--output_path",
        str(raw_output_path),
        "--device",
        args.device,
        "--batch_size",
        str(args.batch_size),
        "--beam_size",
        str(args.beam_size),
    ]
    if args.processor:
        command.extend(["--processor_path", _normalize_model_arg(args.processor)])
    if args.fp16:
        command.append("--fp16")

    env = os.environ.copy()
    existing_pythonpath = env.get("PYTHONPATH")
    env["PYTHONPATH"] = (
        str(source_root)
        if not existing_pythonpath
        else f"{source_root}{os.pathsep}{existing_pythonpath}"
    )
    result = subprocess.run(
        command,
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        cwd=str(source_root),
        env=env,
        timeout=args.timeout_seconds,
    )

    metadata: dict[str, Any] = {
        "adapter": "azmusic-legato-runner",
        "adapter_version": "0.1",
        "source_root": str(source_root),
        "venv_python": str(venv_python),
        "model": model,
        "processor": args.processor,
        "device": args.device,
        "batch_size": args.batch_size,
        "beam_size": args.beam_size,
        "fp16": args.fp16,
        "input_path": str(input_path),
        "raw_output_path": str(raw_output_path),
        "command": command,
        "exit_code": result.returncode,
        "stdout_excerpt": (result.stdout or "")[-4000:],
        "stderr_excerpt": (result.stderr or "")[-4000:],
    }

    if result.returncode != 0:
        print(_summarize_failure(result.stderr or result.stdout), file=sys.stderr)
        _write_json(metadata_path, metadata)
        return result.returncode

    abc = _extract_abc(raw_output_path)
    if not abc.strip():
        metadata["error"] = "LEGATO returned no ABC transcription."
        _write_json(metadata_path, metadata)
        print(metadata["error"], file=sys.stderr)
        return 2

    output_abc.write_text(abc.strip() + "\n", encoding="utf-8")
    metadata["abc_path"] = str(output_abc)
    metadata["abc_character_count"] = len(abc)
    _write_json(metadata_path, metadata)
    return 0


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", action="store_true")
    parser.add_argument("--input", help="Rendered score image path")
    parser.add_argument("--output-abc", help="Output ABC notation path")
    parser.add_argument("--metadata", help="Output metadata JSON path")
    parser.add_argument("--model", default=DEFAULT_MODEL_ID)
    parser.add_argument("--processor", default=None)
    parser.add_argument("--source-root", default=None)
    parser.add_argument("--venv-python", default=None)
    parser.add_argument("--device", default="cpu")
    parser.add_argument("--batch-size", type=int, default=1)
    parser.add_argument("--beam-size", type=int, default=5)
    parser.add_argument("--timeout-seconds", type=int, default=900)
    parser.add_argument("--fp16", action="store_true")
    return parser


def _resolve_source_root(configured: str | None) -> Path:
    if configured:
        return Path(configured).expanduser().resolve()
    local_app_data = os.environ.get("LOCALAPPDATA")
    if local_app_data:
        return (
            Path(local_app_data)
            / "AZMusic"
            / "Server"
            / "tools"
            / "legato"
            / "src"
        ).resolve()
    return Path("tools/legato/src").resolve()


def _resolve_venv_python(configured: str | None, source_root: Path) -> Path:
    if configured:
        return Path(configured).expanduser().resolve()
    tool_root = source_root.parent
    candidates = [
        tool_root / ".venv" / "Scripts" / "python.exe",
        tool_root / "venv" / "Scripts" / "python.exe",
        tool_root / ".venv" / "bin" / "python",
        tool_root / "venv" / "bin" / "python",
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate.resolve()
    return candidates[0].resolve()


def _normalize_model_arg(value: str | None) -> str:
    if not value:
        return DEFAULT_MODEL_ID
    raw = value.strip()
    path = Path(raw).expanduser()
    if path.exists():
        return str(path.resolve())
    return raw


def _extract_abc(raw_output_path: Path) -> str:
    payload = json.loads(raw_output_path.read_text(encoding="utf-8"))
    transcriptions = payload.get("abc_transcription")
    if isinstance(transcriptions, list) and transcriptions:
        return str(transcriptions[0])
    if isinstance(transcriptions, str):
        return transcriptions
    return ""


def _write_json(path: Path, payload: dict[str, Any]) -> None:
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def _summarize_failure(output: str | None) -> str:
    details = (output or "").strip()
    lowered_details = details.lower()
    gated_model = _extract_gated_model(details)
    if "gated repo" in lowered_details or (
        "huggingface.co" in lowered_details and "401 client error" in lowered_details
    ) or (
        "huggingface.co" in lowered_details and "403 client error" in lowered_details
    ):
        if gated_model:
            if "awaiting a review" in lowered_details:
                return (
                    "LEGATO model access failed: Hugging Face says access to "
                    f"{gated_model} is awaiting review from the repo authors. "
                    "Wait for approval, then rerun processing, or configure a "
                    "local LEGATO model directory with all required dependencies."
                )
            return (
                "LEGATO model access failed: Hugging Face denied access to "
                f"{gated_model}. Accept/request access for that model with the "
                "same account used by the LEGATO CLI, or configure a local model "
                "directory with all required dependencies."
            )
        return (
            "LEGATO model access failed: the configured Hugging Face model is "
            "gated or private. Log in with an account that has access, or "
            "configure a local LEGATO model directory."
        )
    if not details:
        return "LEGATO inference failed without returning diagnostic output."
    return details[-2000:]


def _extract_gated_model(details: str) -> str | None:
    marker = "huggingface.co/"
    index = details.find(marker)
    if index == -1:
        return None
    remainder = details[index + len(marker) :]
    if "/resolve/" in remainder:
        return remainder.split("/resolve/", 1)[0]
    parts = remainder.replace("\\", "/").split("/")
    if len(parts) >= 2:
        return f"{parts[0]}/{parts[1]}".rstrip(".")
    return None


if __name__ == "__main__":
    raise SystemExit(main())

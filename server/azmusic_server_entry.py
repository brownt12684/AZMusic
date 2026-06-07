"""Packaged Windows entry point for the AZMusic server."""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

import uvicorn


def _default_server_dir() -> Path:
    if getattr(sys, "frozen", False):
        return (Path(sys.executable).resolve().parent / "server").resolve()
    return Path(__file__).resolve().parent


def _configure_runtime_environment() -> None:
    os.environ.setdefault("AZMUSIC_SERVER_DIR", str(_default_server_dir()))


def main() -> int:
    parser = argparse.ArgumentParser(description="Run the AZMusic local server.")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8795)
    parser.add_argument("--version", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    _configure_runtime_environment()

    if args.version:
        print("AZMusic Server 0.2.0")
        return 0

    if args.self_test:
        import server.main  # noqa: PLC0415

        print(f"AZMusic server self-test ok: {server.main.app.title}")
        return 0

    from server.main import app  # noqa: PLC0415

    uvicorn.run(app, host=args.host, port=args.port)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

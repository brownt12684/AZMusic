# AZMusic

Private family music practice system for violin-family students.

## Overview

AZMusic is a greenfield private monorepo with two main parts:

- `client/`: Flutter app for offline score import, reading, annotation, practice media, and LAN sync.
- `server/`: FastAPI service for LAN-only processing, review workflows, and sync coordination.

The product is Windows-first for the client and home-LAN-only in v1. The repo is optimized for maintainability and internal family use rather than public app-store packaging.

## Repository layout

```text
AZMusic/
|-- client/
|   |-- assets/
|   |-- lib/
|   `-- test/
|-- docs/
|   |-- ARCHITECTURE.md
|   |-- REPO_FOUNDATIONS.md
|   `-- SETUP_GUIDE.md
|-- scripts/
|   `-- dev.ps1
|-- server/
|   |-- models/
|   |-- routers/
|   |-- services/
|   |-- tests/
|   |-- .env.example
|   `-- requirements.txt
|-- .editorconfig
|-- .gitignore
|-- Makefile
|-- pyproject.toml
|-- prompt.md
`-- requirements.md
```

## Canonical workflow

Run repo tasks from the root with PowerShell:

```powershell
.\scripts\dev.ps1 -Task bootstrap-server
.\scripts\dev.ps1 -Task run-server
```

```powershell
.\scripts\dev.ps1 -Task bootstrap-client
.\scripts\dev.ps1 -Task run-client
```

```powershell
.\scripts\dev.ps1 -Task run-client-sandbox
```

`bootstrap-client` generates missing Flutter platform folders with `flutter create` before running `flutter pub get`. The root `Makefile` is an optional wrapper for contributors who already have GNU Make installed.

## Build Status

- `Milestone`: Foundations phase is active. The current import-first offline workflow remains the primary target.
- `Windows build`: Green. `.\scripts\dev.ps1 -Task check-client-windows` passes and the Windows debug build produces `client\build\windows\x64\runner\Debug\azmusic.exe`.
- `Client import flow`: Green for the offline-first local library path, including the first-import case that previously failed on an immutable empty library list.
- `Automated coverage`: Green. `check-client` covers the import workflow cancellation path, local image import persistence, the local-library repository, and the core app-shell routes. `check-client-windows` adds the Windows PDF reader smoke path with the sandbox fixture.
- `Prototype loop`: Green. `.\scripts\dev.ps1 -Task run-client-sandbox` launches a seeded local sandbox with a fake import path and direct routing into library, piece-detail, reader, and review-queue surfaces.
- `Next`: Manual Windows QA of the real file-picker import flow versus the sandbox fast path.
- `Next`: Wire real sync/review behavior and reduce reliance on the native file picker for broader automation.

## Toolchain

- Python 3.11+
- Flutter 3.41.9 for client work
- PowerShell 7+ as the canonical local task runner

`scripts/dev.ps1` prefers the repo-local Flutter SDK under `.tooling/flutter` when it exists, so the project can run against a known-good SDK without depending on the machine-wide Flutter install.

## Shared conventions

- Use root-relative commands. Shared automation assumes the current directory is the repo root.
- Server environment state lives in `server/.env`.
- Relative server paths are resolved from `server/`, so database and storage locations stay stable regardless of shell working directory.
- Repo-wide formatting defaults live in `.editorconfig`.
- Python test and lint configuration lives in `pyproject.toml`.

## Verification commands

```powershell
.\scripts\dev.ps1 -Task check-server
.\scripts\dev.ps1 -Task check-client
.\scripts\dev.ps1 -Task check-client-windows
```

`lint-server` runs Python bytecode compilation plus Ruff. `check-server` runs the server smoke path: bytecode compilation plus pytest coverage for `/health` and the documented `/api/v1/pieces`, `/review`, `/jobs`, and `/sync` route groups. `check-client` runs `flutter analyze` plus `flutter test --no-pub --no-test-assets --no-dds -r expanded`.

`check-client-windows` runs `check-client` first, then launches the sandbox reader on Windows, waits for the generated demo PDF to load, and fails on the class of Syncfusion viewer crashes that previously blanked the PDF screen.

## Prototype Loop

Use the sandbox target when iterating on client UI or local-library behavior:

```powershell
.\scripts\dev.ps1 -Task run-client-sandbox
.\scripts\dev.ps1 -Task run-client-sandbox -SandboxSurface reader
.\scripts\dev.ps1 -Task run-client-sandbox -SandboxSurface sandbox -ResetSandboxOnLaunch
```

`run-client-sandbox` skips the native file picker dependency for day-to-day prototyping. It seeds a local demo score on demand, exposes a fake import button, and can route directly into the library, piece detail, reader, or review queue.

## Documentation

- [Setup Guide](docs/SETUP_GUIDE.md)
- [Repository Foundations](docs/REPO_FOUNDATIONS.md)
- [Architecture](docs/ARCHITECTURE.md)

## License

Private - family use only.

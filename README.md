# AZMusic

Private family music practice system for violin-family students.

## Overview

AZMusic is an existing private monorepo being extended in place with two main parts:

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

- `Milestone`: Foundations phase is still active, but the current slice now includes parent intake/review/push, student library alpha-jump browsing, explicit reader write mode, PDF spread layout rules, opportunistic sync status messaging, and server processing configuration.
- `Windows build`: Green. `.\scripts\dev.ps1 -Task check-client-windows` passes and the Windows debug build produces `client\build\windows\x64\runner\Debug\azmusic.exe`.
- `Client import flow`: Green for the offline-first local library path, including the first-import case that previously failed on an immutable empty library list.
- `Automated coverage`: Green. `check-client` covers the import workflow cancellation path, local image import persistence, app-config host and port resolution, library sync banner states, alpha-jump behavior, reader spread layout rules, the local-library repository, and the core app-shell routes. `check-client-windows` adds a Windows empty-sandbox launch smoke path.
- `Prototype loop`: Green. `.\scripts\dev.ps1 -Task run-client-sandbox` launches an empty local sandbox with direct routing into the library and review-queue surfaces. Piece-detail and reader routes require an imported piece.
- `Next`: Manual Windows QA of the real file-picker import flow versus the sandbox fast path.
- `Next`: Install/configure Audiveris and MuseScore for real OMR/rendering, then replace the current development MusicXML fallback with the real processing path during manual QA.
- `Next`: Decide how much of the client banner state should move onto the server `/api/v1/sync` contract and replace JSON client persistence with a stronger local database layer.

## Toolchain

- Python 3.11+
- Flutter 3.41.9 for client work
- PowerShell 7+ as the canonical local task runner

`scripts/dev.ps1` prefers the repo-local Flutter SDK under `.tooling/flutter` when it exists, so the project can run against a known-good SDK without depending on the machine-wide Flutter install.

## Shared conventions

- Use root-relative commands. Shared automation assumes the current directory is the repo root.
- Server environment state lives in `server/.env`.
- Relative server paths are resolved from `server/`, so database and storage locations stay stable regardless of shell working directory.
- `run-client`, `run-client-sandbox`, and `check-client-windows` accept `-ClientServerHost` and `-ClientServerPort` so same-machine testing can override the checked-in LAN target without editing source or saved preferences.
- Repo-wide formatting defaults live in `.editorconfig`.
- Python test and lint configuration lives in `pyproject.toml`.

## Verification commands

```powershell
.\scripts\dev.ps1 -Task check-server
.\scripts\dev.ps1 -Task check-client
.\scripts\dev.ps1 -Task check-client-windows
```

`lint-server` runs Python bytecode compilation plus Ruff. `check-server` runs the server smoke path: bytecode compilation plus pytest coverage for `/health` and the documented `/api/v1/pieces`, `/review`, `/jobs`, `/sync`, and `/processing` route groups, including score-version download metadata, sync-state retry bookkeeping, processing settings/capabilities, device-worker registration, and raw-preserving processing failure behavior. `check-client` runs `flutter analyze` plus `flutter test --no-pub --no-test-assets --no-dds -r expanded`.

`check-client-windows` runs `check-client` first, then launches the sandbox library on Windows to verify the desktop shell starts cleanly.

## Prototype Loop

Use the sandbox target when iterating on client UI or local-library behavior:

```powershell
.\scripts\dev.ps1 -Task run-client-sandbox
.\scripts\dev.ps1 -Task run-client-sandbox -SandboxSurface library
.\scripts\dev.ps1 -Task run-client-sandbox -SandboxSurface sandbox -ResetSandboxOnLaunch
.\scripts\dev.ps1 -Task run-client-sandbox -SandboxSurface review-queue -ClientServerHost 127.0.0.1 -ClientServerPort 8000
```

`run-client-sandbox` starts the app with sandbox routing and can be pointed at a local server session with the host and port override flags. It no longer seeds sample music; import real test files through the library or parent intake flow before opening piece-detail or reader surfaces.

## Documentation

- [Setup Guide](docs/SETUP_GUIDE.md)
- [Repository Foundations](docs/REPO_FOUNDATIONS.md)
- [Architecture](docs/ARCHITECTURE.md)
- [V1 Delta Scope](docs/V1_DELTA_SCOPE.md)
- [V1 Delta Implementation Checklist](docs/V1_DELTA_IMPLEMENTATION_CHECKLIST.md)

## License

Private - family use only.

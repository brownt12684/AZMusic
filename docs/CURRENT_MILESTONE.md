# AZMusic Current Milestone

Snapshot date: 2026-05-18

## Milestone summary

The repository is currently in a foundations phase centered on one reliable user workflow:

- import a score locally,
- keep it usable offline immediately,
- run a local FastAPI server scaffold in parallel for later processing work.

This is not yet a fully integrated client/server product.

## What works now

### Client

- `.\scripts\dev.ps1 -Task bootstrap-client` can generate missing Flutter platform folders and fetch packages.
- `.\scripts\dev.ps1 -Task run-client` launches the Windows target by default; use `-ClientDevice` only when overriding the default device.
- `.\scripts\dev.ps1 -Task run-client-sandbox` launches a sandbox entrypoint with seeded local demo content and direct surface routing for faster prototyping.
- `.\scripts\dev.ps1 -Task check-client` passes with the repo-local Flutter 3.41.9 SDK under `.tooling/flutter`.
- `.\scripts\dev.ps1 -Task test-client` runs the committed widget and repository smoke tests with `--no-dds`.
- `.\scripts\dev.ps1 -Task check-client-windows` runs the full Windows client gate: `check-client` plus a sandbox smoke path that verifies the PDF reader can load the generated demo score without crashing.
- The library screen can import local `pdf` and common image files.
- Imported files are copied into app-managed local storage instead of being referenced in place.
- The reader can open PDF and image scores from that local copy.
- The piece list is persisted locally through `library/library_index.json`.
- The Windows debug build completes and launches from `client/build/windows/x64/runner/Debug/azmusic.exe`.
- The sandbox launcher can fake-import a deterministic demo score, reset the local sandbox library, and jump directly into the library, piece detail, reader, or review-queue surfaces.
- The automated client path now covers import cancellation, image-import persistence, the local-library repository, and the core app-shell routes alongside the Windows PDF smoke path.

### Server

- `.\scripts\dev.ps1 -Task bootstrap-server` creates `server/.venv` and installs dependencies.
- `.\scripts\dev.ps1 -Task run-server` starts the FastAPI app.
- The server initializes its SQLite database and storage directory on startup.
- The documented `/api/v1/pieces`, `/review`, `/jobs`, and `/sync` route groups are mounted and covered by the canonical automated smoke path alongside `/health`.
- Routers for pieces, review items, jobs, and sync state are present for later integration work.

### Shared workflow

- `scripts/dev.ps1` is the canonical automation entry point.
- The repo is Windows-first and root-relative; run shared automation from the monorepo root even though the component roots are `client/` and `server/`.
- The current setup path is documented in `docs/SETUP_GUIDE.md`.

## What is still placeholder or incomplete

- The client does not use Drift yet; current persistence is JSON-backed.
- The client sync manager does not perform real uploads, downloads, or conflict resolution.
- The review queue screen is a placeholder.
- The client does not currently drive the server routers in an end-to-end workflow.
- The primary client import flow still depends on the native `file_picker` dialog, so there is no committed headless client test covering the real import interaction.
- The sandbox fast path avoids the native file picker for iteration, but it is still a prototype aid rather than the real import workflow.
- LAN auth is configured as a placeholder only and is not enforced.
- The current client tests cover the app shell, sandbox launch routing, and local-library repository, but they still do not drive the native file picker or full reader flow end to end.

## Key operating assumptions

- The user must be able to import a raw score and use it immediately with no network connection.
- v1 is LAN-only. No cloud dependency belongs in the core workflow.
- Raw imports should remain available even if processed or approved derivatives are added later.
- Windows Surface Book is the primary target. Android tablets are secondary.
- Generated Flutter platform folders are recoverable; later workers should not assume they are committed.
- Server database and storage paths resolve relative to `server/`.
- The checked-in client network default is `http://192.168.1.100:8000`; same-machine server runs do not automatically retarget the client to `localhost`.

## Handoff notes for later workers

- Preserve the import-first offline workflow while replacing the current JSON storage with a stronger local database layer.
- Keep the server JSON request bodies aligned as more client flows start using the API surface.
- Treat `server/server/tests/test_routers.py` as non-canonical until it is reconciled with the current package layout and route signatures.
- Prefer `run-client-sandbox` for fast local UI iteration; it is the current low-friction path for testing library, piece-detail, reader, and review-queue changes without a manual OS file dialog.
- Update docs under `docs/` whenever you change setup steps, path assumptions, or milestone scope.

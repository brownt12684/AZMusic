# AZMusic Setup Guide

## Current milestone

This repository is currently at a foundations milestone.

- The client can bootstrap, import a PDF or image score locally, persist it offline, and open it in the reader.
- The server can bootstrap, create its SQLite database and storage folders, and serve the current FastAPI scaffold.
- Client/server sync, client review actions, and client-side Drift persistence are not finished yet.

## Prerequisites

| Tool | Minimum Version | Notes |
|------|-----------------|-------|
| Python | 3.11 | Required for server work |
| Flutter | 3.41.9 (stable) | Required for client work when you are not using the repo-local SDK |
| PowerShell | 7 | Canonical task runner shell |
| Visual Studio Build Tools | 2022 | Required for Flutter Windows desktop builds |
| CMake | 3.14+ | Required by the generated Windows runner |
| Windows SDK | Current | Needed for the primary Windows client target |
| Android SDK | Current | Needed only if you run the Android target |

Run all commands from the repo root. The canonical workflow is `.\scripts\dev.ps1`; the `Makefile` only mirrors it for users who already have GNU Make installed.

When present, `scripts/dev.ps1` prefers the repo-local Flutter SDK under `.tooling/flutter`. That keeps the project runnable even if the machine-wide Flutter install is stale or broken.

### Windows client build dependencies

Use this dependency set when building or running the Flutter Windows target:

| Dependency | Required Version | Notes |
|------------|------------------|-------|
| Flutter SDK | 3.41.9 (stable) | Matches the current local SDK recorded in the Windows Flutter toolchain metadata. |
| Visual Studio Build Tools | 2022 | Install the `Desktop development with C++` workload so Flutter can compile the native Windows runner. |
| CMake | 3.14+ | `client/windows/CMakeLists.txt` declares `cmake_minimum_required(VERSION 3.14)`. A compatible CMake is typically installed with Visual Studio 2022. |

## Component roots

- Monorepo root: `C:\Projects\AZMusic`
- Client implementation root: `client/`
- Server implementation root: `server/`

Use the monorepo root for shared automation even when you are validating a single component. `scripts/dev.ps1` handles the required directory changes internally.

## Server setup

Bootstrap the Python environment from the repo root:

```powershell
.\scripts\dev.ps1 -Task bootstrap-server
```

Start the server:

```powershell
.\scripts\dev.ps1 -Task run-server
```

Verify the server:

```powershell
.\scripts\dev.ps1 -Task check-server
curl http://localhost:8000/health
```

Important server paths:

- `server/.venv` is the local Python environment.
- `server/.env` is the canonical runtime config file.
- `server/azmusic_server.db` is the default SQLite database.
- `server/storage/` is the default file storage root.

Key settings in `server/.env`:

| Setting | Default | Notes |
|---------|---------|-------|
| `HOST` | `0.0.0.0` | Uvicorn bind address |
| `PORT` | `8000` | Uvicorn port |
| `DATABASE_URL` | `sqlite+aiosqlite:///./azmusic_server.db` | Relative SQLite paths are normalized against `server/` |
| `STORAGE_PATH` | `./storage` | Relative storage paths are normalized against `server/` |
| `LAN_AUTH_TOKEN` | *(empty)* | Placeholder only; routes do not enforce auth yet |
| `AI_ENABLED` | `true` | Enables processing-related code paths |
| `MAX_CONCURRENT_JOBS` | `2` | Background job concurrency limit |

## Client setup

Bootstrap the Flutter workspace:

```powershell
.\scripts\dev.ps1 -Task bootstrap-client
```

`bootstrap-client` creates missing `client/windows` and `client/android` folders with `flutter create` before running `flutter pub get`. Those generated platform folders are intentionally recoverable and do not need to exist before setup.

Start the primary Windows target:

```powershell
.\scripts\dev.ps1 -Task run-client
```

`run-client` defaults to the Windows target. Override the device only when needed:

`.\scripts\dev.ps1 -Task run-client -ClientDevice <flutter-device-id>`

Start the Android target:

```powershell
.\scripts\dev.ps1 -Task run-client-android
```

Start the sandbox target for fast client iteration:

```powershell
.\scripts\dev.ps1 -Task run-client-sandbox
.\scripts\dev.ps1 -Task run-client-sandbox -SandboxSurface reader
.\scripts\dev.ps1 -Task run-client-sandbox -SandboxSurface sandbox -ResetSandboxOnLaunch
```

Sandbox launch behavior:

- `run-client-sandbox` uses `client/lib/main_sandbox.dart`.
- It can seed a deterministic local demo score without using the native OS file picker.
- `-SandboxSurface` supports `sandbox`, `library`, `piece-detail`, `reader`, and `review-queue`.
- `-ResetSandboxOnLaunch` clears the local sandbox library before seeding or routing.

## Current milestone flow

Use this sequence when you want to validate the current milestone end to end:

1. Bootstrap and run the server.
2. Bootstrap and run the Windows client.
3. In the library screen, choose `Import score`.
4. Select a `pdf`, `png`, `jpg`, `jpeg`, or `webp` file.
5. Confirm the app opens the reader immediately from the local copy.

Current local persistence behavior:

- Imported files are copied into the app documents directory under `library/scores/<piece_id>/`.
- Library metadata is stored as JSON in `library/library_index.json`.
- The client remains usable without the server for this import-and-read flow.

## Fast prototype flow

Use this sequence when you want to iterate on the client without waiting on the native import dialog:

1. Run `.\scripts\dev.ps1 -Task run-client-sandbox`.
2. Use `Fake import score` when you need a deterministic local fixture.
3. Open the library, piece detail, reader, or review queue directly from the sandbox launcher.
4. Use `-SandboxSurface` when you want the app to start directly on one of those surfaces.

## Sandbox validation boundary

The current milestone splits cleanly into a fast sandbox path and one still-manual real-import path.

### Automatable today

- `.\scripts\dev.ps1 -Task check-server` runs the canonical server smoke path from `server/tests/`.
- `.\scripts\dev.ps1 -Task check-client` runs `flutter analyze` and `flutter test` from the correct client root.
- `.\scripts\dev.ps1 -Task check-client-windows` runs the full Windows client gate: `check-client` plus the sandbox PDF reader smoke path.
- `.\scripts\dev.ps1 -Task run-server` and `.\scripts\dev.ps1 -Task run-client` launch each component in isolation through the shared task runner.
- `.\scripts\dev.ps1 -Task run-client-sandbox` gives the client a deterministic local score and direct routes into the main prototype surfaces without a native file picker.

### Manual today

- The real import flow uses `file_picker`, which opens a native OS file chooser.
- There is no committed Flutter integration test or fixture hook that drives `Import score` headlessly.
- The client-side reader-open verification for the real import path therefore still requires an interactive desktop or tablet session.
- The sandbox path is faster, but it validates the local fixture flow rather than the real user file-selection flow.

## Client config notes

- Runtime config is in `client/lib/core/config/app_config.dart`.
- The default server base URL is `http://192.168.1.100:8000`.
- There is no settings UI yet for changing host and port; treat that value as a development default.
- Do not assume a local `run-server` session will be discovered automatically by the client; same-machine testing requires the configured host to match the actual server address.
- The current sync banner and connection status values are placeholder state, not live server telemetry.

## Verification commands

```powershell
.\scripts\dev.ps1 -Task lint-server
.\scripts\dev.ps1 -Task test-server
.\scripts\dev.ps1 -Task check-server
.\scripts\dev.ps1 -Task lint-client
.\scripts\dev.ps1 -Task test-client
.\scripts\dev.ps1 -Task check-client
.\scripts\dev.ps1 -Task check-client-windows
```

Verification caveats:

- `check-server` runs Python bytecode compilation plus `pytest server/tests`, which currently covers the health path and focused smoke coverage for the documented `pieces`, `review`, `jobs`, and `sync` route groups.
- `check-client` runs `flutter analyze` plus `flutter test --no-pub --no-test-assets --no-dds -r expanded`.
- `client/test/` now contains committed smoke coverage for the import workflow cancellation path, local image-import persistence, the local-library repository, sandbox launch routing, and the main app shell. It still does not drive the native OS file picker itself.
- `check-client-windows` runs `check-client` and then launches the sandbox reader to verify that the generated demo PDF loads on Windows, catching the PDF-viewer crash class that would otherwise show up as a blank screen.
- `server/server/tests/test_routers.py` exists but is not part of the canonical verification path and does not match the current package layout or request shapes.

## Shared operating assumptions

- The client is offline-first; importing and reading the raw score must not depend on server availability.
- v1 is LAN-only and private. No cloud or WAN dependency belongs in the core flow.
- Raw imported score files must remain available even if later processing creates reviewed or approved derivatives.
- Windows Surface Book is the primary client target. Android tablets are secondary.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `flutter` is not recognized | Add Flutter to `PATH` and rerun `flutter doctor` |
| Python modules are missing | Rerun `.\scripts\dev.ps1 -Task bootstrap-server` |
| Server data appears in an unexpected directory | Check `server/.env`; server-relative paths are normalized against `server/` |
| `client/windows` or `client/android` is missing | Rerun `.\scripts\dev.ps1 -Task bootstrap-client` |
| You want to iterate without the native file picker | Use `.\scripts\dev.ps1 -Task run-client-sandbox` and optionally `-SandboxSurface` to jump straight into a screen |
| Client cannot reach the intended server | Check the `AppConfig` host/port values and whether the client is still pointed at the checked-in LAN default `192.168.1.100:8000` instead of the server address you actually launched |

## Cleanup

```powershell
.\scripts\dev.ps1 -Task clean
```

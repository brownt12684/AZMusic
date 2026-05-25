# AZMusic Setup Guide

## Current milestone

This repository is currently at a foundations milestone.

- The client can bootstrap, import scores into parent intake, persist them offline immediately, push ready pieces to students, and open stored score versions in the reader.
- The server can bootstrap, create its SQLite database and storage folders, expose the current piece and review routes, and persist richer sync-state bookkeeping.
- The server now exposes processing settings/capabilities for Audiveris, MuseScore, development stub fallback, and experimental device workers.
- Client/server sync is still opportunistic. The local SQLite library remains the source of truth for immediate usability.

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
| `PRODUCTION_MODE` | `false` | When `true`, stub MusicXML is disabled and real processing tools are required |
| `REQUIRE_DEVICE_AUTH` | `false` | When `true`, protected API routes require a QR-paired device token |
| `AI_ENABLED` | `true` | Enables processing-related code paths |
| `MAX_CONCURRENT_JOBS` | `2` | Background job concurrency limit |
| `AUDIVERIS_CLI_PATH` | *(empty)* | Optional real OMR engine path; can also be set from the parent processing settings screen |
| `MUSESCORE_CLI_PATH` | *(empty)* | Optional MusicXML-to-PDF renderer path; can also be set from the parent processing settings screen |
| `OCR_CLI_PATH` | *(empty)* | Optional Tesseract OCR path; required in production mode |
| `PROCESSING_MODE` | `server_only` | Use `server_plus_device_workers` only for experimental device-worker registration |
| `ALLOW_STUB_MUSICXML` | `true` | Allows development imports to produce deterministic placeholder MusicXML when Audiveris is not configured |

Processing settings are persisted at `server/storage/processing_settings.json` after being changed from the parent app or `/api/v1/processing/settings`. Device-worker registrations are persisted at `server/storage/device_workers.json`.

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

For same-machine testing against a local `run-server` session, override the checked-in LAN target at launch time:

```powershell
.\scripts\dev.ps1 -Task run-client -ClientServerHost 127.0.0.1 -ClientServerPort 8000
```

Start the Android target:

```powershell
.\scripts\dev.ps1 -Task run-client-android
```

Build private release packages:

```powershell
.\scripts\dev.ps1 -Task build-client-windows-release
.\scripts\dev.ps1 -Task build-client-android-apk
.\scripts\dev.ps1 -Task build-client-android-aab
.\scripts\dev.ps1 -Task package-release-assets
```

Release build outputs:

- Windows: `client/build/windows/x64/runner/Release/azmusic.exe`
- Android APK: `client/build/app/outputs/flutter-apk/app-release.apk`
- Android app bundle: `client/build/app/outputs/bundle/release/app-release.aab`
- Release assets: `dist/AZMusic-server-windows-v0.1.0-pretesting.zip`, `dist/AZMusic-windows-v0.1.0-pretesting.zip`, `dist/AZMusic-android-v0.1.0-pretesting.apk`, and `dist/SHA256SUMS.txt`

These build tasks pass `AZMUSIC_PRODUCTION=true` into the client. Android release signing reads `client/android/key.properties` when present; otherwise it uses debug signing only for internal development installs.

The Windows server package is a portable ZIP. Extract it on the server PC, run `Setup AZMusic Server.cmd`, then run `Start AZMusic Server.cmd`. The package includes helper scripts for opening Audiveris, MuseScore, and Tesseract installer pages, but those tools remain separately installed and configured.

Start the sandbox target for fast client iteration:

```powershell
.\scripts\dev.ps1 -Task run-client-sandbox
.\scripts\dev.ps1 -Task run-client-sandbox -SandboxSurface library
.\scripts\dev.ps1 -Task run-client-sandbox -SandboxSurface sandbox -ResetSandboxOnLaunch
.\scripts\dev.ps1 -Task run-client-sandbox -SandboxSurface review-queue -ClientServerHost 127.0.0.1 -ClientServerPort 8000
```

Sandbox launch behavior:

- `run-client-sandbox` uses `client/lib/main_sandbox.dart`.
- It starts empty; import real test files through the library or parent intake flow before opening piece-detail or reader surfaces.
- `-SandboxSurface` supports `sandbox`, `library`, `piece-detail`, `reader`, and `review-queue`.
- `-ResetSandboxOnLaunch` clears the local sandbox library before routing.
- `-ClientServerHost` and `-ClientServerPort` are forwarded as compile-time Dart defines and take precedence over the stored host and port for that launch.
- `check-client-windows` and the Windows PDF smoke path forward those same overrides when they are provided on the command line.

## Current milestone flow

Use this sequence when you want to validate the current milestone end to end:

1. Bootstrap and run the server.
2. Bootstrap and run the Windows client. If you launched the server on the same machine, prefer `-ClientServerHost 127.0.0.1 -ClientServerPort 8000`.
3. Sign in as the parent profile and choose `Import music`.
4. Select a `pdf`, `png`, `jpg`, `jpeg`, or `webp` file.
5. Confirm the intake item is written locally immediately. If the import is a PDF and the server is reachable, confirm it also appears in the parent review queue.
6. Approve the candidate and push the ready piece to one or more student profiles when you want to validate the server-backed flow.
7. Switch to a student profile, open the piece from the student library or piece detail, and confirm the reader opens the local score.

For first-time server setup, open `http://<server-address>:8000/setup` on the server or another device on the same network. That page shows the parent/admin QR code used to initialize the parent device. After the parent device is connected, use the parent section in the app to generate separate student-device QR codes for each student. Android clients can scan pairing QR codes from the pairing dialog; Windows clients keep manual QR payload/code entry as the supported fallback.

For real OMR testing, open the parent server-processing settings screen and configure Audiveris before importing the PDF. Without Audiveris, the development fallback can still generate stub MusicXML if `ALLOW_STUB_MUSICXML` remains enabled. Configure MuseScore when you want rendered review PDFs produced from MusicXML instead of raw-PDF fallback copies.

Current local persistence behavior:

- Imported files are copied into the app documents directory under `library/scores/<piece_id>/`.
- Parent intake entries stay in the local library even if the server upload fails.
- Library metadata, notes, and annotation layers are stored in local SQLite at `azmusic.sqlite`.
- Existing `library/library_index.json` files are migrated into SQLite on first load and backed up as `library_index.json.migrated-backup`.
- Approved server PDF versions download as additional local score versions without removing the raw fallback.
- The client remains usable without the server for the local import-and-read flow.

## Fast prototype flow

Use this sequence when you want to iterate on the client without waiting on the native import dialog:

1. Run `.\scripts\dev.ps1 -Task run-client-sandbox`.
2. Import a real local test file through the library or parent intake flow when you need reader content.
3. Open the library or review queue directly from the sandbox launcher.
4. Use `-SandboxSurface` when you want the app to start directly on one of those surfaces.

## Sandbox validation boundary

The current milestone splits cleanly into a fast sandbox path and one still-manual real-import path.

### Automatable today

- `.\scripts\dev.ps1 -Task check-server` runs the canonical server smoke path from `server/tests/`.
- `.\scripts\dev.ps1 -Task check-client` runs `flutter analyze` and `flutter test` from the correct client root.
- `.\scripts\dev.ps1 -Task check-client-windows` runs the full Windows client gate: `check-client` plus the sandbox launch smoke path.
- `.\scripts\dev.ps1 -Task run-server` and `.\scripts\dev.ps1 -Task run-client` launch each component in isolation through the shared task runner.
- `.\scripts\dev.ps1 -Task run-client-sandbox` gives the client direct routes into the main prototype surfaces without seeding sample music.

### Manual today

- The real import flow uses `file_picker` from the parent tools surface, which opens a native OS file chooser.
- There is no committed Flutter integration test or fixture hook that drives the parent import action headlessly.
- The client-side reader-open verification for the real import path therefore still requires an interactive desktop or tablet session.
- The sandbox path is faster, but it validates the local fixture flow rather than the real user file-selection flow.

## Client config notes

- Runtime config is in `client/lib/core/config/app_config.dart`.
- The default server base URL is `http://192.168.1.100:8000`.
- `-ClientServerHost` and `-ClientServerPort` override that value for a single launch by passing `AZMUSIC_SERVER_HOST` and `AZMUSIC_SERVER_PORT` as compile-time Dart defines.
- There is no settings UI yet for changing host and port; treat that value as a development default.
- Do not assume a local `run-server` session will be discovered automatically by the client; same-machine testing requires the configured host to match the actual server address.
- The current sync banner reports real client-side states: `offline-ready`, `syncing`, `synced`, and `failed-usable`.
- The banner is still derived from the client sync flow today, not from direct rendering of the server `/api/v1/sync` response.

## Verification commands

```powershell
.\scripts\dev.ps1 -Task lint-server
.\scripts\dev.ps1 -Task test-server
.\scripts\dev.ps1 -Task check-server
.\scripts\dev.ps1 -Task lint-client
.\scripts\dev.ps1 -Task test-client
.\scripts\dev.ps1 -Task check-client
.\scripts\dev.ps1 -Task check-client-windows
.\scripts\dev.ps1 -Task build-client-windows-release
.\scripts\dev.ps1 -Task build-client-android-apk
```

Verification caveats:

- `check-server` runs Python bytecode compilation plus `pytest server/tests`, which currently covers the health path, piece import and detail smoke flows, score-version download metadata, review and job routes, and sync-state retry bookkeeping.
- `lint-server` adds Ruff on top of bytecode compilation.
- The server smoke path now also covers `/api/v1/processing` settings, executable validation, QR-paired device-token enforcement, production processing gates, metadata refresh into pending MusicXML candidates, device-worker registration, processing metadata on review candidates, and the raw-preservation failure path when required processing is unavailable.
- `check-client` runs `flutter analyze` plus `flutter test --no-pub --no-test-assets --no-dds -r expanded`.
- `client/test/` now contains committed coverage for import workflow cancellation, local image-import persistence, app-config host and port resolution, library sync banner states, alpha-jump lookup, reader spread layout rules, the local-library repository, sandbox launch routing, and the main app shell. It still does not drive the native OS file picker itself.
- `check-client-windows` runs `check-client` and then launches the sandbox library on Windows to verify that the desktop shell starts cleanly.
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
| Client cannot reach the intended server | Check the `AppConfig` host/port values and whether the client is still pointed at the checked-in LAN default `192.168.1.100:8000`. For same-machine testing, launch with `-ClientServerHost 127.0.0.1 -ClientServerPort 8000`. |

## Cleanup

```powershell
.\scripts\dev.ps1 -Task clean
```

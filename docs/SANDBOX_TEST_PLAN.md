# AZMusic Sandbox Test Plan

Snapshot date: 2026-05-17

## Purpose

Validate the current foundations milestone in a sandbox using the correct component roots, canonical task runner, and the real boundary between automated checks and manual UI interaction.

## Component roots and launch points

- Monorepo root: `C:\Projects\AZMusic`
- Shared automation entry point: `.\scripts\dev.ps1`
- Server implementation root: `server/`
- Server entry point: `server/main.py`
- Server tests: `server/tests/`
- Client implementation root: `client/`
- Client entry point: `client/lib/main.dart`
- Client tests: `client/test/`

Run all automation from the monorepo root. The component roots above describe code ownership and runtime layout, not separate shell starting points.

## Canonical commands

### Server

```powershell
.\scripts\dev.ps1 -Task bootstrap-server
.\scripts\dev.ps1 -Task lint-server
.\scripts\dev.ps1 -Task test-server
.\scripts\dev.ps1 -Task check-server
.\scripts\dev.ps1 -Task run-server
```

### Client

```powershell
.\scripts\dev.ps1 -Task bootstrap-client
.\scripts\dev.ps1 -Task lint-client
.\scripts\dev.ps1 -Task test-client
.\scripts\dev.ps1 -Task check-client
.\scripts\dev.ps1 -Task run-client
```

`run-client` defaults to the Windows target. Use `-ClientDevice <flutter-device-id>` only when overriding that default, or `-Task run-client-android` for the Android shortcut.

## Current milestone flows

### Automated server smoke flow

The canonical server smoke coverage under `server/tests/` currently exercises:

1. `/health`
2. `/api/v1/pieces/`
3. `/api/v1/pieces/{id}/history_drafts`
4. `/api/v1/pieces/{id}/media`
5. `/api/v1/review/` and `/api/v1/review/{id}`
6. `/api/v1/jobs/trigger` and `/api/v1/jobs/{id}`
7. `/api/v1/sync/{client_id}`

### Interactive client milestone flow

1. Launch the client app.
2. Use `Import score` on the library screen.
3. Select a `pdf`, `png`, `jpg`, `jpeg`, or `webp` file through the native picker.
4. Confirm the file is copied into app-managed storage.
5. Confirm `library/library_index.json` is updated.
6. Confirm the reader opens the imported score immediately from the local copy.

### Not yet a real cross-component E2E flow

- The client does not yet drive the server review, job, or sync routes end to end.
- Server smoke coverage is real and useful, but it is still API-level validation rather than a client-driven integrated flow.

## Recommended sandbox order

1. Bootstrap and verify the server in isolation.
2. Bootstrap and verify the client in isolation.
3. Launch the server only if you are validating server availability separately from the client.
4. Launch the client and perform the interactive offline import flow.
5. Treat any server-backed client workflow beyond launch as non-canonical for this milestone.

## Current automation blockers

- `file_picker` opens a native OS dialog, so the real import flow is not headless yet.
- `client/test/` currently contains scaffold directories but no committed test files, so `flutter test` is mostly a toolchain-health signal.
- The checked-in client server default is `http://192.168.1.100:8000`, not `localhost`.
- There is no client settings UI yet for changing host and port during manual validation.

## Pass conditions for this milestone

- `check-server` passes against `server/tests/test_health.py` and `server/tests/test_api_smoke.py`.
- `check-client` passes, meaning Flutter analyze succeeds and the current test command completes.
- The client launches on Windows.
- A manual import from the library screen opens the reader immediately from the copied local score.

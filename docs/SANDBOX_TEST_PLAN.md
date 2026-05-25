# AZMusic Sandbox Test Plan

Snapshot date: 2026-05-23

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

For same-machine validation against a local server session, prefer:

```powershell
.\scripts\dev.ps1 -Task run-client -ClientServerHost 127.0.0.1 -ClientServerPort 8000
.\scripts\dev.ps1 -Task run-client-sandbox -ClientServerHost 127.0.0.1 -ClientServerPort 8000
```

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
8. Parent MuseScore correction endpoints for accepting an edited MusicXML/MXL upload and rerendering it into the review PDF
9. The score-review coming-soon path for AI-assisted metadata and notation correction

### Interactive client milestone flow

1. Launch the client app.
2. Sign in as the parent profile and use `Import music` from the parent tools surface.
3. Select a `pdf`, `png`, `jpg`, `jpeg`, or `webp` file through the native picker.
4. Confirm the intake item is copied into app-managed storage and `library/library_index.json` is updated.
5. If the import is a PDF and the server is reachable, confirm the piece can appear in the parent review queue.
6. On a score-candidate review item, use `Edit MusicXML in MuseScore`, save/export a visible edit on the parent device, then use `Upload edited MusicXML` before approving the candidate.
7. Push a ready piece to a student profile when you are validating the server-backed path.
8. Switch to a student profile and confirm the reader opens the imported score from the local copy.

### Not yet a real cross-component E2E flow

- The client now drives part of the server review and sync surface, but there is still no single automated end-to-end client flow covering import, review, push, and student reading.
- Server smoke coverage is real and useful, but it is still API-level validation rather than a client-driven integrated flow.

## Recommended sandbox order

1. Bootstrap and verify the server in isolation.
2. Bootstrap and verify the client in isolation.
3. Launch the server only if you are validating server availability separately from the client.
4. Launch the client and perform the interactive parent-import flow.
5. Treat the server-backed review and push path as valid manual coverage, but not yet as a committed automated E2E gate.

## Current automation blockers

- `file_picker` opens a native OS dialog, so the real import flow is not headless yet.
- `client/test/` has useful committed coverage, but it still does not drive the native picker or the full parent-to-student workflow.
- The checked-in client server default is `http://192.168.1.100:8000`, not `localhost`.
- There is no client settings UI yet for changing host and port during manual validation.

## Pass conditions for this milestone

- `check-server` passes against `server/tests/test_health.py` and `server/tests/test_api_smoke.py`.
- `check-client` passes, meaning Flutter analyze succeeds and the current test command completes.
- The client launches on Windows.
- A manual parent import can be pushed through to a student-readable piece, and the reader opens the copied local score.
- For processed score candidates, the parent can round-trip the generated MusicXML/MXL through a parent-device MusicXML editor and refresh the rendered review PDF before approval.
- The `Send back for AI score review` action is visible as coming soon and must not enqueue fake LLM correction.

# AZMusic Current Milestone

Snapshot date: 2026-06-11

## Milestone summary

The repository is still in a foundations phase, but the active slice now spans two connected workflows:

- parent intake, server review, and push,
- student-ready library browsing, local reading, and opportunistic LAN sync.

This is now a V1 package candidate, but it still needs a real-device E2E pass before distribution to students.

## What works now

### Client

- `.\scripts\dev.ps1 -Task bootstrap-client` can generate missing Flutter platform folders and fetch packages.
- `.\scripts\dev.ps1 -Task run-client` launches the Windows target by default; use `-ClientDevice` only when overriding the default device, and use `-ClientServerHost` and `-ClientServerPort` when you need to point the client at a local or non-default server target.
- `.\scripts\dev.ps1 -Task run-client-sandbox` launches an empty sandbox entrypoint with direct surface routing for faster prototyping.
- `.\scripts\dev.ps1 -Task check-client` passes with the repo-local Flutter 3.41.9 SDK under `.tooling/flutter`.
- `.\scripts\dev.ps1 -Task test-client` runs the committed widget and repository smoke tests with `--no-dds`.
- `.\scripts\dev.ps1 -Task check-client-windows` runs the full Windows client gate: `check-client` plus a sandbox smoke path that verifies the Windows shell starts cleanly.
- `.\scripts\dev.ps1 -Task build-client-windows-release` builds the production-flagged Windows release app.
- `.\scripts\dev.ps1 -Task build-client-android-apk` builds the production-flagged Android APK.
- `.\scripts\dev.ps1 -Task package-release-assets` creates the Windows server installer EXE, Windows client installer EXE, Android APK copy, and `SHA256SUMS.txt`.
- Parent tools can import local `pdf` and common image files into intake, keep the raw local copy immediately, and best-effort upload PDFs to the server.
- The parent intake workflow is split into Import, Processing, Review, and Push sections. Import now isolates stale local-upload problems with explicit retry/reupload/remove actions instead of leaving old "waiting to upload" rows mixed into the active server workflow.
- The client blocks duplicate imports of the same source path while an upload is active, and server piece identity fields are preserved on synced remote summaries so duplicate/book attempts can be surfaced cleanly.
- The parent review queue and review-compare screen load server review items and submit approve or reject actions.
- The parent review-compare screen is now PDF-first for V1. Metadata review approves the cleaned student PDF for push; MusicXML/MuseScore work is optional and lives behind the Advanced Notation Lab path.
- The parent review-compare screen can still download generated MusicXML/MXL candidates after Advanced Notation Lab processing, open them in a local MusicXML-capable app such as MuseScore, upload an edited file, and refresh the rendered review PDF through the server renderer.
- The parent review-compare screen treats deterministic Audiveris/MuseScore output as the human-edit baseline. Parents can accept it as-is, or edit externally in MuseScore, upload the corrected MusicXML, rerender, and accept the result.
- The parent review UI no longer exposes Audiveris/HOMR/LEGATO OMR comparison controls. Side-by-side remains the default review mode, overlay remains available, and experimental OMR engines are treated as backend-only evidence.
- Parent tools now include a renamed Advanced surface for server health, parent-owned sync status, Audiveris, MuseScore, development stub fallback, and experimental device-worker mode.
- Server setup now hosts the first parent/admin QR code at `/setup`; local setup-page launches encode a detected LAN URL instead of `localhost`, and `PUBLIC_SERVER_URL` can override detection. Parent tools then generate separate student-device QR codes that are tied to a specific student profile. Android and Windows clients can scan these QR codes, manual payload/code entry remains available, and a server-host override no longer counts as pairing unless an explicit pairing token is also supplied.
- Parent push marks student visibility locally immediately and retries the server push later if the server is unreachable.
- The student library supports search plus a left-side drag alpha rail for `Title`, `Composer`, and `Book`.
- Imported files are copied into app-managed local storage instead of being referenced in place.
- Piece detail lists all stored score versions for a piece.
- The reader can open PDF and image scores from the local copy, distinguish read mode from write mode, preserve page-specific markup and notes, and render two-page PDF spreads in wide landscape when write mode is off.
- The piece list, notes, and annotation layers are persisted locally through SQLite at `azmusic.sqlite`; legacy `library/library_index.json` files migrate on first load.
- The library banner now reports real `offline-ready`, `syncing`, `synced`, and `failed-usable` states from the current opportunistic sync flow.
- The Windows release build completes at `client/build/windows/x64/runner/Release/azmusic.exe`.
- The Android release APK builds at `client/build/app/outputs/flutter-apk/app-release.apk`.
- The preferred end-user server installer is `dist/AZMusic.Server.Setup.exe`, which embeds the internal bundled-server package and creates shortcuts.
- The preferred Windows client installer is `dist/AZMusic.Windows.Client.Setup.exe`, which embeds the Windows client package and creates shortcuts for `azmusic.exe`.
- The sandbox launcher can reset the local sandbox library and jump directly into the library or review-queue surfaces. Piece detail and reader routing use the first local entry when one exists.
- Parent debug mode now exposes test-only controls for clearing local/server workflow data, refreshing jobs, canceling jobs, and retrying failed jobs with the piece title visible when the server provides it.
- The automated client path now covers import cancellation, image-import persistence, app-config host and port resolution, sync banner state transitions, duplicate active-import blocking, stale local upload retry/removal, alpha-jump logic, reader spread layout rules, the local-library repository, PDF-first parent workflow labels, and the core app-shell routes alongside the Windows sandbox smoke path.

### Server

- `.\scripts\dev.ps1 -Task bootstrap-server` creates `server/.venv` and installs dependencies.
- `.\scripts\dev.ps1 -Task run-server` starts the FastAPI app.
- The server initializes its SQLite database and storage directory on startup.
- Piece detail responses now expose per-score-version download metadata, including `file_url`, `content_type`, `file_size_bytes`, and `content_sha256`.
- `/api/v1/sync/{client_id}` now reports `offline-ready`, `syncing`, `synced`, and `sync-failed-usable` state, plus retry and error metadata through `GET` and `PATCH`.
- `/api/v1/cloud`, `/api/v1/notes`, and `/api/v1/annotations` now provide parent/teacher-owned sync scaffolding. GitHub is the interim provider model, exported today as a restorable local family manifest under `server/storage/cloud_sync/`; this is not yet a remote GitHub push implementation.
- Sync retry metadata is persisted under `server/storage/sync_state/` alongside the main SQLite-backed sync counters.
- The documented `/api/v1/pieces`, `/review`, `/jobs`, and `/sync` route groups are mounted and covered by the canonical automated smoke path alongside `/health`.
- Routers for pieces, review items, jobs, and sync state are present for later integration work.
- `/api/v1/processing` now exposes durable processing settings, executable validation, capability reporting, and experimental device-worker registration.
- `/api/v1/pairing` now exposes short-lived pairing-code creation, QR PNG generation, and one-time device claim. Pairing codes carry their purpose: parent setup or student-device assignment.
- `REQUIRE_DEVICE_AUTH=true` enforces QR-paired device tokens on protected API groups while keeping setup, pairing, and health available.
- PDF import now creates a raw score version plus a cleaned student PDF score version immediately. Parent metadata approval makes the cleaned PDF pushable without requiring Audiveris, MuseScore, or MusicXML generation.
- Advanced Notation Lab processing now runs explicitly through MusicXML and PDF-render engine adapters after the parent chooses to start it. Audiveris is the current default OMR engine, HOMR and LEGATO are optional backend-only experimental OMR signals, MuseScore is the intended PDF renderer, and the deterministic MusicXML path remains only as a development fallback when enabled.
- Score-version API endpoints support parent-driven MuseScore correction by preserving the original OMR baseline, accepting an uploaded edited MusicXML/MXL candidate, and rerendering it back into the review PDF.
- Human-approved notation candidates are cataloged under server storage as retraining samples containing the original source, OMR baseline, final MusicXML, final rendered PDF, metadata, and provenance.
- Legacy Gemini and local LLM score-correction endpoints still exist in the server code, but they are dormant/experimental and are not part of the active parent-facing notation workflow.
- Processed MusicXML metadata is now extracted for title, composer, instrument/parts, key, time signature, tempo when present, measure count, software provenance, and MusicXML version. The metadata is attached to review items, job results, piece detail responses, and local client piece records during sync.
- Failed optional notation processing keeps the raw and cleaned student PDFs stored, marks the notation job failed, and records the last processing error in server settings.
- `PRODUCTION_MODE=true` disables stub MusicXML and requires Audiveris, MuseScore, and Tesseract OCR before Advanced Notation Lab jobs can produce notation candidates. PDF-first import and metadata review remain available.

### Shared workflow

- `scripts/dev.ps1` is the canonical automation entry point.
- The repo is Windows-first and root-relative; run shared automation from the monorepo root even though the component roots are `client/` and `server/`.
- Use `-ClientServerHost` and `-ClientServerPort` on `run-client`, `run-client-sandbox`, or `check-client-windows` when same-machine testing should target `127.0.0.1:8795` instead of the checked-in LAN default.
- The current setup path is documented in `docs/SETUP_GUIDE.md`.

## What is still placeholder or incomplete

- The client does not use Drift yet; current persistence is direct SQLite with serialized domain payloads.
- The client banner state is still client-owned; the server `/api/v1/sync` surface exists for bookkeeping, but the UI does not yet treat it as the sole source of truth.
- The current sync flow is opportunistic rather than a full durable conflict-resolution system. Parent-owned cloud manifest export exists, but remote GitHub/Google upload and conflict resolution are still future work.
- The primary client import flow still depends on the native `file_picker` dialog, so there is no committed headless client test covering the real import interaction.
- The sandbox fast path avoids the native file picker for iteration, but it is still a prototype aid rather than the real import workflow.
- The current server processing path still accepts PDFs only. Image imports remain local-only.
- Real OMR requires installing/configuring Audiveris through the parent Advanced settings surface or server settings API. HOMR, LEGATO, local LLM, and cloud lanes are hidden unless experimental features are explicitly enabled. Without a real OMR engine, V1 still pushes the cleaned PDF; notation prototypes can use stub MusicXML only when `allow_stub_musicxml` is enabled.
- Real reconstructed PDF rendering after parent MuseScore edits requires installing/configuring MuseScore on the server. The parent device only needs an app that can open/edit MusicXML/MXL.
- Score-level LLM correction remains dormant/experimental. The active score workflow queues deterministic OMR output for human edit, with ready samples cataloged for retraining.
- Parent-triggered LLM metadata reprocessing has been removed from the active workflow. Parents edit metadata directly during student-PDF review.
- Experimental device-worker registration exists, but no dispatch queue sends processing work packages to devices yet.
- Device pairing supports generated QR payloads, manual payload/code entry, Android camera scanning, and Windows tablet camera scanning.
- Piece research metadata beyond MusicXML extraction, such as composer biography, work catalog numbers, publisher/source history, and pedagogical notes, is not implemented yet.
- LAN auth now has an enforced paired-device-token mode, but production deployments still need a final decision on LAN HTTP versus HTTPS.
- The current client and server tests cover targeted behavior, and `scripts/run-release-smoke.ps1` covers packaged first-run pairing surfaces, but the final real-device parent-import to student-reader flow still needs a manual E2E gate.

## Key operating assumptions

- The user must be able to import a raw score and use it immediately with no network connection.
- v1 is LAN-first for core import/read/review/push. Parent-owned cloud sync is allowed as an optional restore/sync layer, but the core student reading path must not require it.
- Raw imports should remain available even if processed or approved derivatives are added later.
- Windows Surface Book is the primary target. Android tablets are secondary.
- Flutter Windows and Android platform folders now exist and are part of the packaging path; they can still be regenerated, but release edits under `client/android` should be preserved.
- Server database and storage paths resolve relative to `server/`.
- The checked-in client network fallback is `http://192.168.1.100:8795`, but first-run pairing starts blank and should be populated by the QR payload.

## Handoff notes for later workers

- Treat `docs/V1_DELTA_SCOPE.md` as the contract for the next library, reader, write-mode, two-page, and sync slice.
- Preserve the import-first offline workflow and keep future storage changes behind the existing repository boundaries.
- Treat `docs/V1_PRODUCTION_READINESS.md` as the current release packaging checklist.
- Keep the server JSON request bodies aligned as more client flows start using the API surface.
- Preserve the new score-version download metadata fields and richer sync-state contract when evolving client/server sync.
- Treat `server/server/tests/test_routers.py` as non-canonical until it is reconciled with the current package layout and route signatures.
- Prefer `run-client-sandbox` for fast local UI iteration; it is the current low-friction path for testing library, piece-detail, reader, and review-queue changes without a manual OS file dialog.
- Prefer launch-time host and port overrides over source edits when you need to retarget the client to a local server session.
- Update docs under `docs/` whenever you change setup steps, path assumptions, or milestone scope.

# AZMusic Architecture

## Purpose

This document records the current implementation shape of AZMusic for the present foundations milestone. It is intentionally conservative: when code and older assumptions disagree, trust the code in `client/`, `server/`, and `scripts/dev.ps1`.

## System overview

AZMusic is a two-part private monorepo:

- `client/`: Flutter app for local score import, reading, and later review/sync workflows.
- `server/`: FastAPI service for LAN-only processing, review coordination, and sync state.

Current high-level state:

- The client already supports the offline import-and-read loop without requiring the server.
- The server already boots and persists state locally.
- The client now drives part of the review and sync surface, but the overall workflow is still local-first and only partially backed by the server.

## Client architecture today

### App structure

The active client surface is organized under `client/lib/`:

- `main.dart` initializes orientation, application documents storage, and `AppConfig`.
- `app/` contains the Material app shell, routing, and theme.
- `presentation/screens/` contains the active login, library, piece detail, reader, parent, review-compare, and sandbox surfaces.
- `presentation/providers/` uses Riverpod to expose local library state.
- `data/repositories/local_library_repository.dart` is the main local persistence boundary used today.
- `data/database/database.dart` owns the current SQLite schema for library entries, notes, and annotation layers.
- `core/network/` contains the current reachability probe and API client plumbing, while `core/sync/` still contains future integration scaffolding.

### What the client actually does now

- Parent tools import `pdf`, `png`, `jpg`, `jpeg`, and `webp` files with `file_picker`, create a local intake entry immediately, and best-effort upload PDFs to the server.
- The student library supports search plus a left-side drag alpha rail for `Title`, `Composer`, and `Book` browse modes.
- `LocalLibraryRepository` copies the selected file into the app documents directory under `library/scores/<piece_id>/`.
- The repository stores library metadata in `azmusic.sqlite` and migrates the previous `library/library_index.json` file on first load.
- Piece detail shows every stored score version for a piece and launches the reader from any stored version.
- The reader opens PDFs with `syncfusion_flutter_pdfviewer` and images with `InteractiveViewer`, keeps utility modules in-route, supports explicit read versus write mode, and enables PDF-only spread layout in wide landscape.
- Parent review surfaces load the server review queue and allow approve or reject actions against candidate items.
- Parent processing settings load `/api/v1/processing` capability data and let the parent configure Audiveris, MuseScore, development stub fallback, and experimental device-worker mode.
- Piece loading performs opportunistic sync: pending uploads bind a `serverPieceId`, assigned pieces are fetched for the active student, and approved PDF versions can download as additional local score versions without removing the raw fallback.

### Current persistence boundary

The client now uses SQLite directly through `AppDatabase`.

- `library_entries` stores serialized local library entries keyed by local and server piece IDs.
- `annotation_layers` stores page-specific markup layers by profile, score version, and page.
- `notes` stores notebook entries by profile, piece, and score version.
- Legacy `library/library_index.json` files are migrated into SQLite on first load.

This boundary is important for later workers: keep UI code behind repository contracts instead of binding screens directly to the database.

### Config and sync scaffolding

- `AppConfig` loads from `SharedPreferences` and optional compile-time overrides.
- The legacy default server base URL is `http://192.168.1.100:8795`, but first-run pairing should come from the QR payload rather than that fallback.
- `scripts/dev.ps1` can override that target for development launches with `-ClientServerHost` and `-ClientServerPort`, which become `AZMUSIC_SERVER_HOST` and `AZMUSIC_SERVER_PORT` Dart defines.
- A server-host override no longer counts as pairing. Release builds start unpaired and must claim a real server QR token.
- `ApiClient` and `NetworkInfo` are active today; `NetworkInfo` probes the currently configured server host for reachability.
- `SyncManager.sync()` is still a TODO, but `PieceListNotifier` already runs opportunistic sync on app load, refresh, post-import, parent push, and connectivity return.
- `LibrarySyncBannerState`, `syncStatusProvider`, and `connectionStatusProvider` expose real `offline-ready`, `syncing`, `synced`, and `failed-usable` states for the library banner.
- The current banner state is still client-derived; it is not yet a direct rendering of the server `/api/v1/sync` response.

## Planned client direction

The intended next steps are:

- Normalize the SQLite schema further, or move to Drift if generated typed queries become worth the migration cost.
- Keep imported raw scores available immediately and offline.
- Add real sync, review actions, annotation persistence, and richer media handling without breaking the import-first workflow.

## Server architecture today

### Runtime shape

- `server/main.py` creates the FastAPI app and registers routers.
- Startup initializes database tables through `server.database.init_db()`.
- Shutdown disposes the shared async SQLAlchemy engine.
- Settings are loaded from `server/.env` via `pydantic-settings`.

### Storage and configuration

- Default database: `server/azmusic_server.db`
- Default storage root: `server/storage/`
- Relative database and storage paths are normalized against `server/`, not against the shell working directory.
- `REQUIRE_DEVICE_AUTH=true` enforces QR-paired device tokens on protected API route groups.
- Pairing, setup, and health endpoints remain open so new devices can be paired and health can be checked.
- `PUBLIC_SERVER_URL` can force the server URL encoded into QR payloads; otherwise local `/setup` requests use best-effort LAN IPv4 detection instead of `localhost`.

### Domain model currently implemented on the server

The ORM models in `server/models/orm.py` currently cover:

- `Profile`
- `Piece`
- `ScoreVersion`
- `AnnotationLayer`
- `MediaAsset`
- `PieceHistoryDraft`
- `ReviewItem`
- `BackgroundJob`
- `SyncState`

This is broader than the current runnable client experience. Some of these entities exist as server-side scaffolding for later milestones.

### Router surface

Current route groups:

- `/health`
- `/api/v1/pieces`
- `/api/v1/review`
- `/api/v1/jobs`
- `/api/v1/sync`
- `/api/v1/processing`
- `/api/v1/pairing`
- `/setup`

Important notes about the current API shape:

- The API should be treated as internal scaffolding, not a stable public contract.
- The active non-file create and update handlers use JSON request bodies; media upload remains multipart because it carries files.
- Piece detail responses now include per-score-version download metadata: `file_url`, `content_type`, `file_size_bytes`, and `content_sha256`.
- The sync router now supports `GET`, `PATCH`, and upload/download counter updates, with retry and error metadata persisted under `server/storage/sync_state/`.
- The processing router supports durable server settings, executable validation, server capability reporting, and experimental device-worker registration.
- The pairing router creates short-lived parent/admin and student-device QR payloads. Android clients scan with `mobile_scanner`; Windows clients scan by capturing camera snapshots through `camera_windows` and decoding them with the Dart QR decoder. Manual payload/code entry remains available on all platforms.
- Piece history draft routes currently use `history_drafts` with an underscore in the path.

### Processing boundary

Server processing is now separated into orchestration and engine adapters:

- `ScoreProcessingService` owns raw import preservation, job state, score-version rows, review item creation, and failure recording.
- `MusicXmlEngine` chooses the configured OMR strategy: Audiveris default/sweep, HOMR experimental, or experimental bakeoff. The deterministic stub is only allowed when development fallback is explicitly enabled.
- `MuseScoreRenderEngine` renders MusicXML to PDF when configured, or copies the raw PDF as a development review fallback when no renderer is configured.
- `PRODUCTION_MODE=true` disables stub MusicXML and requires Audiveris, MuseScore, and Tesseract OCR to be available. HOMR remains optional and experimental.
- `ProcessingSettingsStore` persists parent-managed settings under `server/storage/processing_settings.json`.
- `DeviceWorkerRegistry` persists experimental device-worker registrations under `server/storage/device_workers.json`.

HOMR is integrated as a server-side experimental OMR engine. It is installed separately into a Python 3.10-3.12 virtual environment and produces MusicXML from rendered page images. Approved MusicXML remains the canonical future playback artifact, while the MuseScore-rendered PDF remains the student-readable display artifact.

The frontend should treat these as server-owned concerns. Client code may import, read, show status, configure settings, and approve review candidates, but it should not embed OMR or rendering decisions in end-user UI code.

## Current end-to-end data flow

### Parent intake, review, and push

1. A parent imports music from the parent tools surface.
2. The client copies the source file into app-managed local storage and writes intake metadata into `azmusic.sqlite`.
3. If the import is a PDF and the server is reachable, the client best-effort uploads it to `/api/v1/pieces/import`.
4. The parent review queue loads candidate review items from `/api/v1/review`.
5. Once a piece is ready, the parent pushes it to one or more student profiles. The local library updates immediately, and the server push retries opportunistically if it fails.

### Student library and reading

1. The student library loads from local storage first.
2. If the configured server host is reachable, the client attempts opportunistic sync for pending uploads, assigned pieces, and approved PDF score versions.
3. The library banner reports `offline-ready`, `syncing`, `synced`, or `failed-usable` based on that work.
4. Opening a piece routes through piece detail, where the user can pick any stored score version before opening the reader.
5. The reader keeps raw local access available even after newer approved versions are downloaded.

### Server-backed work

The server already persists pieces, score versions, media assets, review items, background jobs, and sync-state bookkeeping in SQLite plus storage-side JSON metadata. The client uses part of that surface today, but the server is still additive to the local-first flow rather than required for baseline reading.

## Operating constraints

- Windows Surface Book is the primary client target.
- Android tablets are the secondary client target.
- v1 is LAN-only and private; do not add cloud assumptions to the core workflow.
- The client must remain useful with no network connection.
- Raw imported scores should stay available even after later review or processing steps create derived versions.
- Run repo automation from the repo root through `scripts/dev.ps1`.

## Known gaps and cautions

- Client persistence is SQLite-backed, but it still stores serialized domain payloads rather than a fully normalized relational model.
- The client banner state is still owned locally; `/api/v1/sync` exists for durable bookkeeping but is not yet the sole source of truth for UI state.
- Same-machine testing still requires either saved host settings or launch-time `-ClientServerHost` and `-ClientServerPort` overrides because the checked-in default points at a LAN IP.
- Non-PDF imports remain local-only. The current server processing path only accepts PDFs.
- There is committed client test coverage, but there is still no single end-to-end integration test that drives parent import, server review, push, and student reading through the native file picker flow.
- The canonical server verification path covers `server/tests/test_health.py` plus focused API smoke coverage for the documented router groups.
- `server/server/tests/test_routers.py` appears to be legacy or experimental coverage and is not part of the canonical `check-server` workflow.

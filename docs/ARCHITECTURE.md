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
- The end-to-end sync and review workflow between them is still scaffold-level, not complete.

## Client architecture today

### App structure

The active client surface is organized under `client/lib/`:

- `main.dart` initializes orientation, application documents storage, and `AppConfig`.
- `app/` contains the Material app shell, routing, and theme.
- `presentation/screens/` contains the current screens: library, piece detail, reader, and a placeholder review queue.
- `presentation/providers/` uses Riverpod to expose local library state.
- `data/repositories/local_library_repository.dart` is the real persistence boundary used today.
- `core/network/` and `core/sync/` contain future integration scaffolding.

### What the client actually does now

- The library screen imports `pdf`, `png`, `jpg`, `jpeg`, and `webp` files with `file_picker`.
- `LocalLibraryRepository` copies the selected file into the app documents directory under `library/scores/<piece_id>/`.
- The repository stores metadata in `library/library_index.json`.
- The reader screen opens PDFs with `syncfusion_flutter_pdfviewer` and images with `InteractiveViewer`.
- The review queue screen is present as navigation scaffolding only.

### Current persistence boundary

The client is not on Drift yet.

- `client/lib/data/database/database.dart` contains a placeholder `AppDatabase`.
- `client/lib/data/database/tables.dart` names planned storage tables but does not define a working SQLite schema.
- Real client persistence today is JSON-backed file storage behind `LocalLibraryRepository`.

This boundary is important for later workers: if client persistence changes, prefer swapping the implementation behind the repository contract instead of rewriting the UI flow first.

### Config and sync scaffolding

- `AppConfig` loads from `SharedPreferences`.
- The default server base URL is `http://192.168.1.100:8000`.
- `ApiClient`, `NetworkInfo`, and `SyncManager` exist, but `SyncManager.sync()` is still a TODO.
- `syncStatusProvider` and `connectionStatusProvider` currently expose placeholder values used by the library banner.

## Planned client direction

The intended next steps are:

- Replace JSON-backed storage with Drift or another real local database layer.
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
- `LAN_AUTH_TOKEN` exists in config as a placeholder, but the current routes do not enforce it.

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

Important notes about the current API shape:

- The API should be treated as internal scaffolding, not a stable public contract.
- The active non-file create and update handlers use JSON request bodies; media upload remains multipart because it carries files.
- Piece history draft routes currently use `history_drafts` with an underscore in the path.

## Current end-to-end data flow

### Import and read

1. The user imports a score from the library screen.
2. The client copies the source file into app-managed local storage.
3. The client writes library metadata into `library/library_index.json`.
4. The client immediately opens the reader from the local copy.

This flow is the most reliable user-visible milestone implemented today.

### Server-backed work

The server can already:

- expose health metadata,
- persist pieces and related records in SQLite,
- upload media into `server/storage/`,
- track review items,
- track background job state,
- track simple sync counters by client ID.

The client does not yet drive these server workflows end to end.

## Operating constraints

- Windows Surface Book is the primary client target.
- Android tablets are the secondary client target.
- v1 is LAN-only and private; do not add cloud assumptions to the core workflow.
- The client must remain useful with no network connection.
- Raw imported scores should stay available even after later review or processing steps create derived versions.
- Run repo automation from the repo root through `scripts/dev.ps1`.

## Known gaps and cautions

- Client/server sync is not wired through the app yet.
- Client persistence is still file-and-JSON based, not SQLite-based.
- The review queue UI is placeholder-only on the client.
- `client/test/` currently has scaffold directories but no committed test files.
- The canonical server verification path covers `server/tests/test_health.py` plus focused API smoke coverage for the documented router groups.
- `server/server/tests/test_routers.py` appears to be legacy or experimental coverage and is not part of the canonical `check-server` workflow.

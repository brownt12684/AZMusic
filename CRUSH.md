# AZMusic — Agent Guidance

## Essential Commands

All commands route through the Makefile, which calls `scripts/dev.ps1`. Use `make <target>` — never invoke Flutter or Python tooling directly.

| Target | What it does |
|--------|-------------|
| `make bootstrap` | Set up server venv + Flutter SDK |
| `make server/run` | Start FastAPI server (port 8795 by default) |
| `make server/lint` | Run ruff on server code |
| `make server/test` | Run pytest on `server/tests/` |
| `make server/check` | Lint + test combined |
| `make client/run` | Run Flutter app (Windows or Android) |
| `make client/run-sandbox` | Run Flutter with sandbox surface |
| `make client/smoke-windows-pdf` | Smoke test PDF rendering on Windows |
| `make client/run-android` | Run Flutter on Android device/emulator |
| `make client/lint` | Flutter analyze |
| `make client/test` | Flutter test |
| `make client/check` | Lint + test combined |
| `make client/check-windows` | Windows-specific client checks |
| `make check` | Server + client check |
| `make test` | Server + client test |
| `make lint` | Server + client lint |
| `make clean` | Clean build artifacts |

### Client launch flags (passed via dev.ps1)

- `-ClientServerHost <host>` — override server base URL
- `-ClientServerPort <port>` — override server port
- `-SandboxSurface <surface>` — sandbox surface: `sandbox`, `library`, `piece-detail`, `reader`, `review-queue`
- `-ResetSandboxOnLaunch` — clear sandbox state on startup
- `AZMUSIC_PRODUCTION=true` — run in production mode (unpaired, no dev overrides)

## Architecture

**Two-part monorepo**: Python FastAPI server + Flutter client.

```
server/          # FastAPI backend
  main.py        # App entry, lifespan, router registration
  config.py      # Pydantic Settings (.env backed)
  models/        # ORM (SQLAlchemy) + schemas (Pydantic)
  routers/       # API endpoints
  services/      # Business logic (OMR, AI, PDF, etc.)
  jobs/          # Background job dispatcher
  database.py    # DB init
  tests/         # pytest suite

client/          # Flutter app (Android + Windows)
  lib/           # Dart source — Riverpod state, SQLite persistence
  pubspec.yaml   # Dependencies
```

**Data flow**: Parent uploads score (PDF) → server processes via OMR engines → generates review items → parent reviews → pushes to paired student devices.

**Operating constraints**:
- Primary dev machine: Windows Surface Book
- Student devices: Android tablets
- Client is **local-first**: works fully offline; server is additive for sync/review

## Code Organization

### Server

- **`main.py`** — FastAPI app with lifespan management. Registers routers, health endpoint, LAN-only auth via `require_paired_device`.
- **`config.py`** — Pydantic `Settings` class reading from `.env`. Defaults: port 8795, SQLite DB, `server/storage/` for files. Paths are normalized against `server/`, not shell CWD.
- **`models/orm.py`** — SQLAlchemy models: `Profile`, `Piece`, `ScoreVersion`, `AnnotationLayer`, `MediaAsset`, `PieceHistoryDraft`, `ReviewItem`, `BackgroundJob`, `SyncState`.
- **`models/schemas.py`** — Pydantic request/response models: `PieceStatus`, `ScoreVersionType`, `JobStatus`, `ReviewItem`, etc.
- **`database.py`** — Async SQLite engine setup via `aiosqlite`.

### Client

- Uses **Riverpod** for state management.
- **SQLite** local persistence via `AppDatabase`.
- **syncfusion** PDF viewer for score rendering.
- First-run pairing reads QR token from server; default base URL is `http://192.168.1.100:8795`.

## Testing

- **Server**: `pytest` on `server/tests/`. Run via `make server/test`.
- **Client**: `flutter test` on `client/test/`. Run via `make client/test`.
- **No E2E integration tests** exist between client and server.

## Naming, Style & Conventions

- **Python**: 3.10+
- **Linting**: ruff with rules `E`, `F`, `I`, `UP`
- **Line length**: 100 characters
- **Config**: `pyproject.toml` (server root) defines ruff settings and pytest config
- **Flutter**: Standard Dart conventions; use `flutter analyze` for lint

## Gotchas & Non-Obvious Details

1. **Never call Flutter or Python tooling directly** — always go through `make` / `dev.ps1`. The script handles venv paths, Flutter SDK location (`.tooling/flutter/`), and Dart defines.

2. **Client banner state is locally owned** — not server-driven. The client decides what to show without server coordination.

3. **Non-PDF imports are local-only** — the server only accepts PDFs. Non-PDF scores never reach the server.

4. **Same-machine testing** requires saved host settings in the client, or launch-time `-ClientServerHost` and `-ClientServerPort` overrides.

5. **Release builds start unpaired** — they must claim a real server QR token. Dev builds may use sandbox surfaces.

6. **Legacy test file**: `server/server/tests/test_routers.py` exists but is **not** part of the canonical `check-server` workflow. Ignore it.

7. **Server database and storage paths** are normalized against `server/` directory, not the shell working directory.

8. **LAN-only auth**: Server uses QR-paired device tokens. No username/password. First-run pairing comes from QR payload.

9. **Job dispatcher** handles OMR (optical music recognition) and notation work asynchronously. Services may queue background jobs.

10. **Flutter SDK** is repo-local at `.tooling/flutter/` — not system-installed. The Makefile and `dev.ps1` handle this.

## Environment

- **Server port**: 8795 (default, from `.env`)
- **Server DB**: `azmusic_server.db` (SQLite)
- **Client DB**: `azmusic.sqlite` (SQLite, app documents dir)
- **Storage**: `server/storage/`
- **Server venv**: `server/.venv/Scripts/python.exe`
- **Flutter SDK**: `.tooling/flutter/bin/flutter.bat`

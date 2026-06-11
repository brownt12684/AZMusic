# V1 Production Readiness

Snapshot date: 2026-06-11

## Status

AZMusic now has a verified private-package path for the current V1 candidate:

- Windows release build: `client/build/windows/x64/runner/Release/azmusic.exe`
- Android release APK: `client/build/app/outputs/flutter-apk/app-release.apk`
- Windows server installer: `dist/AZMusic.Server.Setup.exe`
- Windows client installer: `dist/AZMusic.Windows.Client.Setup.exe`
- Android APK package: `dist/AZMusic.Android.apk`
- The Windows server package includes bundled `azmusic-server.exe`; Python remains an implementation detail and should not be manually installed by end users.
- The Windows server installer is the end-user setup path for the server PC.
- The Windows client installer is the end-user setup path for Windows tablets.
- Release client builds use `--dart-define=AZMUSIC_PRODUCTION=true` through `scripts/dev.ps1`.
- `scripts/dev.ps1 -Task package-release-assets` creates the three end-user release assets and `dist/SHA256SUMS.txt`.
- The client uses SQLite local persistence for library entries, notes, and annotation layers, with migration from the previous JSON library index.
- The server can run in production mode. PDF-first imports and metadata review remain available without OMR; stub MusicXML is disabled and Audiveris, MuseScore, and Tesseract OCR are required before optional Advanced Notation Lab jobs can produce notation candidates. HOMR and LEGATO remain optional backend-only experimental OMR evidence.
- Score-level LLM correction is dormant/experimental. The active notation workflow lets parents accept Audiveris/MuseScore output as-is or upload a human-edited MusicXML; final acceptance catalogs the sample for retraining.
- Parent-owned sync scaffolding exists through local family manifest export for GitHub-shaped restore data. Remote GitHub/Google push-pull remains a later release gate.
- Protected server API groups can require QR-paired device tokens with `REQUIRE_DEVICE_AUTH=true`.
- The server setup page creates the first parent/admin QR code. Paired parent devices create student-device QR codes from the parent section.
- Release clients start unpaired. A server-host override no longer counts as pairing unless an explicit development pairing token is supplied.
- Local server setup pages encode a detected LAN URL instead of `localhost`; `PUBLIC_SERVER_URL` is available when the detected address must be overridden.
- Android and Windows QR camera scanning are supported through the client pairing dialog. Manual QR payload/code entry remains available as a fallback.
- Parent PIN setup is now parent-managed on first parent login. The client stores a salted PIN hash, does not use a `0000` fallback, and the release smoke path includes first-run PIN coverage.
- Experimental notation, cloud, and local-LLM controls are hidden from normal release builds unless `AZMUSIC_SHOW_EXPERIMENTAL=true` is explicitly supplied.

## Verified Commands

Run from the repository root:

```powershell
.\scripts\dev.ps1 -Task check-server
.\scripts\dev.ps1 -Task check-client-windows
.\scripts\dev.ps1 -Task lint-client
.\scripts\dev.ps1 -Task test-client
.\scripts\dev.ps1 -Task build-client-android-apk
.\scripts\dev.ps1 -Task build-client-windows-release
.\scripts\dev.ps1 -Task package-release-assets
```

Last verified results:

- Server: `104 passed`
- Client tests: `68 passed`
- Client analyzer: no issues
- Windows client smoke gate: passed
- Android release APK: built successfully
- Windows release app: built successfully
- Release asset packaging: server installer EXE, Windows client installer EXE, Android APK copy, and `SHA256SUMS.txt`

## Server Production Settings

Set these in `server/.env` for a production-like server:

```env
PRODUCTION_MODE=true
REQUIRE_DEVICE_AUTH=true
ALLOW_STUB_MUSICXML=false
AUDIVERIS_CLI_PATH=C:\path\to\audiveris.bat
MUSESCORE_CLI_PATH=C:\path\to\MuseScore4.exe
OCR_CLI_PATH=C:\path\to\tesseract.exe
HOMR_CLI_PATH=C:\path\to\homr.exe
LEGATO_CLI_PATH=C:\path\to\legato_runner.py
LEGATO_MODEL_PATH=guangyangmusic/legato
LOCAL_LLM_PROVIDER=lmstudio
LOCAL_LLM_BASE_URL=http://127.0.0.1:1234/v1
LOCAL_LLM_MODEL=
```

In production mode, saved parent processing settings cannot re-enable stub MusicXML. Validation fails for optional notation work unless Audiveris, MuseScore, and Tesseract are available. HOMR and LEGATO do not block production processing unless a backend/dev workflow explicitly selects their experimental strategies. Local LLM settings are optional and can also be set from the parent Advanced processing screen.

The release package does not bundle Audiveris, MuseScore Studio, Tesseract OCR, HOMR, or LEGATO. Setup keeps those tools as separately installed applications and includes `PROCESSING_TOOL_NOTICES.md`, `PYTHON_RUNTIME_LICENSE.txt`, and `PYTHON_DEPENDENCY_LICENSES.md` for license visibility. The processing helper can install optional HOMR and LEGATO virtual environments; LEGATO's official `guangyangmusic/legato` model requires Hugging Face access unless a local model directory is configured.

## Android Signing

The generated Android project supports `client/android/key.properties` for release signing:

```properties
storeFile=C:\\path\\to\\azmusic-release.jks
storePassword=...
keyAlias=...
keyPassword=...
```

If that file is missing, the release APK build falls back to the debug signing config so internal development installs remain possible. That fallback is not suitable for a final student distribution package.

## Release Asset Replacement

The `v0.2.0` GitHub release should contain all required runtime pieces:

- `AZMusic.Server.Setup.exe`
- `AZMusic.Windows.Client.Setup.exe`
- `AZMusic.Android.apk`
- `SHA256SUMS.txt`

If an older milestone release only contains the clients, delete the release and tag before recreating it from the updated commit.

## Remaining Release Gates

- Run a real-device E2E pass: parent import, server cleaned-PDF review, push to student, student offline open, note/markup persistence, reconnect sync, and optional Advanced Notation Lab processing.
- Install and validate the Android APK on the target tablet hardware.
- Decide whether V1 distribution should require HTTPS or continue LAN HTTP with paired device tokens.

## Release Candidate Acceptance Checklist

Use only the release assets under `dist/` for this pass:

1. Install `AZMusic.Server.Setup.exe`; verify Start Menu and desktop shortcuts launch without requiring manual Python setup.
2. Open the server setup page and confirm it shows only parent/admin QR pairing instructions.
3. Install `AZMusic.Windows.Client.Setup.exe`; pair it as the parent device using the server setup QR.
4. Create a parent PIN on first parent login; restart the client and verify only the chosen PIN unlocks parent tools.
5. Create a student profile and generate that student's device QR from the parent client.
6. Install `AZMusic.Android.apk`; pair the device by scanning the student QR and verify it lands in the student library.
7. Import a single-piece PDF from the parent client, review/edit metadata, approve the cleaned student PDF, push to the student, and open it on Android.
8. Import a book PDF, verify processing tracker counts, approve metadata in bulk, push selected pieces, and close completed workflow items.
9. Toggle Android offline or stop the server, reopen a synced piece, and confirm the cleaned PDF remains readable.
10. Reconnect, refresh sync, and confirm no stale "waiting to upload" or duplicate book entries remain in the active workflow.

# V1 Production Readiness

Snapshot date: 2026-05-25

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
- The server can run in production mode, where stub MusicXML is disabled and Audiveris, MuseScore, and Tesseract OCR are required before processing imports. HOMR remains optional experimental OMR for bakeoff testing.
- Protected server API groups can require QR-paired device tokens with `REQUIRE_DEVICE_AUTH=true`.
- The server setup page creates the first parent/admin QR code. Paired parent devices create student-device QR codes from the parent section.
- Release clients start unpaired. A server-host override no longer counts as pairing unless an explicit development pairing token is supplied.
- Local server setup pages encode a detected LAN URL instead of `localhost`; `PUBLIC_SERVER_URL` is available when the detected address must be overridden.
- Android and Windows QR camera scanning are supported through the client pairing dialog. Manual QR payload/code entry remains available as a fallback.

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

- Server: `41 passed`
- Client tests: `46 passed`
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
```

In production mode, saved parent processing settings cannot re-enable stub MusicXML. Validation fails unless Audiveris, MuseScore, and Tesseract are available. HOMR validation is only required when the parent selects a HOMR strategy.

The release package does not bundle Audiveris, MuseScore Studio, Tesseract OCR, or HOMR. Setup keeps those tools as separately installed applications and includes `PROCESSING_TOOL_NOTICES.md`, `PYTHON_RUNTIME_LICENSE.txt`, and `PYTHON_DEPENDENCY_LICENSES.md` for license visibility.

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

- Run a real-device E2E pass: parent import, server processing, parent review/edit, push to student, student offline open, note/markup persistence, reconnect sync.
- Install and validate the Android APK on the target tablet hardware.
- Replace hardcoded development PIN defaults with the final parent-managed setup flow.
- Decide whether V1 distribution should require HTTPS or continue LAN HTTP with paired device tokens.

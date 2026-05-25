# V1 Production Readiness

Snapshot date: 2026-05-24

## Status

AZMusic now has a verified private-package path for the current V1 candidate:

- Windows release build: `client/build/windows/x64/runner/Release/azmusic.exe`
- Android release APK: `client/build/app/outputs/flutter-apk/app-release.apk`
- Release client builds use `--dart-define=AZMUSIC_PRODUCTION=true` through `scripts/dev.ps1`.
- The client uses SQLite local persistence for library entries, notes, and annotation layers, with migration from the previous JSON library index.
- The server can run in production mode, where stub MusicXML is disabled and Audiveris, MuseScore, and Tesseract OCR are required before processing imports.
- Protected server API groups can require QR-paired device tokens with `REQUIRE_DEVICE_AUTH=true`.

## Verified Commands

Run from the repository root:

```powershell
.\scripts\dev.ps1 -Task check-server
.\scripts\dev.ps1 -Task check-client-windows
.\scripts\dev.ps1 -Task lint-client
.\scripts\dev.ps1 -Task test-client
.\scripts\dev.ps1 -Task build-client-android-apk
.\scripts\dev.ps1 -Task build-client-windows-release
```

Last verified results:

- Server: `35 passed`
- Client tests: `34 passed`
- Client analyzer: no issues
- Windows client smoke gate: passed
- Android release APK: built successfully
- Windows release app: built successfully

## Server Production Settings

Set these in `server/.env` for a production-like server:

```env
PRODUCTION_MODE=true
REQUIRE_DEVICE_AUTH=true
ALLOW_STUB_MUSICXML=false
AUDIVERIS_CLI_PATH=C:\path\to\audiveris.bat
MUSESCORE_CLI_PATH=C:\path\to\MuseScore4.exe
OCR_CLI_PATH=C:\path\to\tesseract.exe
```

In production mode, saved parent processing settings cannot re-enable stub MusicXML. Validation fails unless Audiveris, MuseScore, and Tesseract are available.

## Android Signing

The generated Android project supports `client/android/key.properties` for release signing:

```properties
storeFile=C:\\path\\to\\azmusic-release.jks
storePassword=...
keyAlias=...
keyPassword=...
```

If that file is missing, the release APK build falls back to the debug signing config so internal development installs remain possible. That fallback is not suitable for a final student distribution package.

## Remaining Release Gates

- Run a real-device E2E pass: parent import, server processing, parent review/edit, push to student, student offline open, note/markup persistence, reconnect sync.
- Install and validate the Android APK on the target tablet hardware.
- Package the Windows release folder with a private installer or scripted zip installer.
- Replace hardcoded development PIN defaults with the final parent-managed setup flow.
- Decide whether V1 distribution should require HTTPS or continue LAN HTTP with paired device tokens.

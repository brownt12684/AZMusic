# V1 Production Readiness

Snapshot date: 2026-05-25

## Status

AZMusic now has a verified private-package path for the current V1 candidate:

- Windows release build: `client/build/windows/x64/runner/Release/azmusic.exe`
- Android release APK: `client/build/app/outputs/flutter-apk/app-release.apk`
- Windows server package: `dist/AZMusic-server-windows-v0.1.0-pretesting.zip`
- Windows client package: `dist/AZMusic-windows-v0.1.0-pretesting.zip`
- Android APK package: `dist/AZMusic-android-v0.1.0-pretesting.apk`
- Release client builds use `--dart-define=AZMUSIC_PRODUCTION=true` through `scripts/dev.ps1`.
- `scripts/dev.ps1 -Task package-release-assets` creates all release assets and `dist/SHA256SUMS.txt`.
- The client uses SQLite local persistence for library entries, notes, and annotation layers, with migration from the previous JSON library index.
- The server can run in production mode, where stub MusicXML is disabled and Audiveris, MuseScore, and Tesseract OCR are required before processing imports.
- Protected server API groups can require QR-paired device tokens with `REQUIRE_DEVICE_AUTH=true`.
- The server setup page creates the first parent/admin QR code. Paired parent devices create student-device QR codes from the parent section.
- Android QR camera scanning is supported through the client pairing dialog. Windows keeps manual QR payload/code entry because the selected scanner plugin does not ship a Windows camera backend.

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

- Server: `35 passed`
- Client tests: `34 passed`
- Client analyzer: no issues
- Windows client smoke gate: passed
- Android release APK: built successfully
- Windows release app: built successfully
- Release asset packaging: server ZIP, Windows client ZIP, Android APK copy, and `SHA256SUMS.txt`

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

## Release Asset Replacement

The `v0.1.0-pretesting` GitHub prerelease should contain all required runtime pieces:

- `AZMusic-server-windows-v0.1.0-pretesting.zip`
- `AZMusic-windows-v0.1.0-pretesting.zip`
- `AZMusic-android-v0.1.0-pretesting.apk`
- `SHA256SUMS.txt`

If an older milestone release only contains the clients, delete the release and tag before recreating it from the updated commit.

## Remaining Release Gates

- Run a real-device E2E pass: parent import, server processing, parent review/edit, push to student, student offline open, note/markup persistence, reconnect sync.
- Install and validate the Android APK on the target tablet hardware.
- Replace hardcoded development PIN defaults with the final parent-managed setup flow.
- Decide whether V1 distribution should require HTTPS or continue LAN HTTP with paired device tokens.

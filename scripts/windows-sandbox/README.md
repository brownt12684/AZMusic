# AZMusic Windows Sandbox

This folder configures Microsoft Windows Sandbox for clean release-package validation.

## Host Setup

Windows Sandbox is currently a Windows optional feature. Enable it once, reboot, then launch the AZMusic sandbox:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows-sandbox\enable-windows-sandbox.ps1
```

After reboot:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows-sandbox\launch-windows-sandbox.ps1
```

The launcher refreshes the server package by default so setup-script changes are included. Use `-UseExistingPackages` to skip package refresh. Use `-RefreshClientPackage` if the Windows client package should also be regenerated from the current build output.

## What The Sandbox Tests

The generated `.wsb` mounts:

- `dist` as `C:\AZMusicDist` read-only for end-user release installers.
- `scripts\windows-sandbox` as `C:\AZMusicSandbox` read-only.
- `sandbox-results\windows-sandbox` as `C:\AZMusicSandboxResults` writable.

On logon, the sandbox creates desktop shortcuts and runs the package smoke by default. The smoke runs the end-user server and Windows client installer EXEs, installs the Microsoft Visual C++ runtime only if the bundled server self-test requires it, starts the server, claims parent and student pairing codes, and verifies protected processing settings.

Smoke transcripts and server logs are written back to `sandbox-results\windows-sandbox`. To read the latest result from the host:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows-sandbox\read-latest-results.ps1
```

Processing import is skipped unless Audiveris, MuseScore, and Tesseract are installed inside the sandbox. Missing tools should produce setup/capability warnings, not connection timeouts.

## Important Limitations

Windows Sandbox is disposable. Installed tools, app data, and server state disappear when the sandbox closes.

Windows Sandbox validates the Windows server and Windows client packages. It does not validate Android installation; use a physical Android device or emulator for that path.

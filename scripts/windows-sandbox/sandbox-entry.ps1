param(
    [string]$ReleaseVersion = "v0.2.0",
    [string]$ResultsDir = "C:\AZMusicSandboxResults",
    [switch]$NoAutoSmoke
)

$ErrorActionPreference = "Stop"

function Write-EntryLog {
    param([string]$Message)
    "$(Get-Date -Format o) $Message" | Add-Content -LiteralPath $EntryLogPath -Encoding utf8
}

function Disable-SmartAppControlForSandboxSession {
    Write-EntryLog "disabling Smart App Control for this disposable sandbox session"

    $commands = @(
        @(
            "reg.exe",
            @(
                "add",
                "HKLM\SYSTEM\CurrentControlSet\Control\CI\Policy",
                "/v",
                "VerifiedAndReputablePolicyState",
                "/t",
                "REG_DWORD",
                "/d",
                "0",
                "/f"
            )
        ),
        @(
            "reg.exe",
            @(
                "add",
                "HKLM\SYSTEM\CurrentControlSet\Control\CI\Protected",
                "/v",
                "VerifiedAndReputablePolicyStateMinValueSeen",
                "/t",
                "REG_DWORD",
                "/d",
                "0",
                "/f"
            )
        ),
        @(
            "reg.exe",
            @(
                "add",
                "HKLM\SOFTWARE\Microsoft\Windows Defender",
                "/v",
                "SacLearningModeSwitch",
                "/t",
                "REG_DWORD",
                "/d",
                "0",
                "/f"
            )
        )
    )

    foreach ($command in $commands) {
        $exe = $command[0]
        $arguments = $command[1]
        try {
            $output = & $exe @arguments 2>&1
            Write-EntryLog "$exe $($arguments -join ' ') exit=$LASTEXITCODE output=$($output -join ' ')"
        }
        catch {
            Write-EntryLog "$exe $($arguments -join ' ') failed: $($_.Exception.Message)"
        }
    }

    $ciTool = Join-Path $env:SystemRoot "System32\CiTool.exe"
    if (Test-Path $ciTool) {
        try {
            $refreshOutput = & $ciTool -r 2>&1
            Write-EntryLog "CiTool.exe -r exit=$LASTEXITCODE output=$($refreshOutput -join ' ')"
        }
        catch {
            Write-EntryLog "CiTool.exe -r failed: $($_.Exception.Message)"
        }

        try {
            $policyOutput = & $ciTool -lp 2>&1
            Write-EntryLog "CiTool.exe -lp exit=$LASTEXITCODE output=$($policyOutput -join ' | ')"
        }
        catch {
            Write-EntryLog "CiTool.exe -lp failed: $($_.Exception.Message)"
        }
    } else {
        Write-EntryLog "CiTool.exe not found; SAC registry values were written without policy refresh"
    }
}

$Desktop = [Environment]::GetFolderPath("Desktop")
if ([string]::IsNullOrWhiteSpace($Desktop)) {
    $Desktop = Join-Path $env:USERPROFILE "Desktop"
}
$ReadmePath = Join-Path $Desktop "AZMusic Sandbox Instructions.txt"
$SmokeCmd = Join-Path $Desktop "Run AZMusic Package Smoke.cmd"
$ClientCmd = Join-Path $Desktop "AZMusic Windows Client.cmd"
$DistCmd = Join-Path $Desktop "Open AZMusic Dist Folder.cmd"
$ResultsCmd = Join-Path $Desktop "Open AZMusic Smoke Results.cmd"
$EntryLogPath = Join-Path $ResultsDir "entry.log"

New-Item -ItemType Directory -Path $ResultsDir -Force | Out-Null
"$(Get-Date -Format o) sandbox-entry started; release=$ReleaseVersion; results=$ResultsDir; no_auto_smoke=$($NoAutoSmoke.IsPresent)" | Set-Content -LiteralPath $EntryLogPath -Encoding utf8
Write-EntryLog "desktop=$Desktop"

try {
Disable-SmartAppControlForSandboxSession
New-Item -ItemType Directory -Path $Desktop -Force | Out-Null
Write-EntryLog "writing instructions and shortcuts"

@"
AZMusic Windows Sandbox

This is a clean Microsoft Windows Sandbox session. It is disposable; closing
the sandbox deletes anything installed inside it.

Mapped folders:
- C:\AZMusicDist: release installer files from the host repo's dist folder.
- C:\AZMusicSandbox: smoke-test helper scripts from the host repo.
- C:\AZMusicSandboxResults: writable smoke-test logs visible on the host.

Recommended checks:
1. Run "Run AZMusic Package Smoke.cmd" to install the server and Windows client
   from the end-user installer EXEs, start the server, pair through the API,
   and verify protected processing settings.
2. Run "AZMusic Windows Client.cmd" to launch the installed Windows client.
3. Use the server setup page shown by the smoke script for manual QR pairing.
4. Run "Open AZMusic Smoke Results.cmd" to view logs written by the smoke run.

Processing tools:
- Audiveris, MuseScore, and Tesseract are not installed by Windows Sandbox.
- Missing tools should produce setup guidance and processing warnings, not
  pairing timeouts.
- Pairing or Dio connection failures are still network/firewall/server URL
  issues.
- Python is bundled into azmusic-server.exe for release packages; the sandbox
  smoke should not install Python.
"@ | Set-Content -LiteralPath $ReadmePath -Encoding utf8

@"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\AZMusicSandbox\run-package-smoke.ps1" -ReleaseVersion "$ReleaseVersion" -ResultsDir "$ResultsDir"
pause
"@ | Set-Content -LiteralPath $SmokeCmd -Encoding ascii

@"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -Command "if (Test-Path 'C:\AZMusicReleaseSmoke\client\azmusic.exe') { Start-Process 'C:\AZMusicReleaseSmoke\client\azmusic.exe' } else { Write-Host 'Run package smoke first to expand the client package.'; pause }"
"@ | Set-Content -LiteralPath $ClientCmd -Encoding ascii

@"
@echo off
explorer C:\AZMusicDist
"@ | Set-Content -LiteralPath $DistCmd -Encoding ascii

@"
@echo off
explorer "$ResultsDir"
"@ | Set-Content -LiteralPath $ResultsCmd -Encoding ascii

Write-EntryLog "shortcuts written"
Write-EntryLog "instructions written to $ReadmePath"

if (-not $NoAutoSmoke.IsPresent) {
    Write-EntryLog "starting automatic package smoke"
    Start-Process powershell.exe `
        -ArgumentList @(
            "-NoProfile",
            "-NoExit",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            "C:\AZMusicSandbox\run-package-smoke.ps1",
            "-ReleaseVersion",
            $ReleaseVersion,
            "-ResultsDir",
            $ResultsDir
        )
    Write-EntryLog "automatic package smoke process started"
} else {
    Write-EntryLog "automatic package smoke disabled"
}
}
catch {
    Write-EntryLog "sandbox-entry failed: $($_.Exception.Message)"
    throw
}

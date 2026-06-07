<#
.SYNOPSIS
    Run a packaged AZMusic server/client smoke test inside Windows Sandbox.
#>
param(
    [string]$ReleaseVersion = "v0.2.0",
    [string]$ResultsDir = "C:\AZMusicSandboxResults"
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$DistDir = "C:\AZMusicDist"
$WorkRoot = "C:\AZMusicReleaseSmoke"
$ServerInstaller = Join-Path $DistDir "AZMusic.Server.Setup.exe"
$ClientInstaller = Join-Path $DistDir "AZMusic.Windows.Client.Setup.exe"
$ServerInstallRoot = Join-Path $WorkRoot "server"
$ClientInstallRoot = Join-Path $WorkRoot "client"
$BaseUrl = "http://127.0.0.1:8795"
$Script:ServerProcess = $null
$Script:ServerStdout = $null
$Script:ServerStderr = $null
$Script:SmokeSucceeded = $false
$Script:RunId = Get-Date -Format "yyyyMMdd-HHmmss"
$Script:RunDir = Join-Path $ResultsDir $Script:RunId
$Script:TranscriptPath = Join-Path $Script:RunDir "transcript.log"
$Script:StatusPath = Join-Path $Script:RunDir "status.json"
$Script:LatestPath = Join-Path $ResultsDir "latest.json"

New-Item -ItemType Directory -Path $Script:RunDir -Force | Out-Null
Start-Transcript -LiteralPath $Script:TranscriptPath -Force | Out-Null

function Write-Status {
    param(
        [string]$Status,
        [string]$Step,
        [string]$Message,
        [hashtable]$Details
    )

    $payload = [ordered]@{
        status = $Status
        step = $Step
        message = $Message
        run_id = $Script:RunId
        updated_at = (Get-Date).ToString("o")
        transcript = $Script:TranscriptPath
        run_dir = $Script:RunDir
    }
    if ($Details) {
        $payload.details = $Details
    }

    $json = $payload | ConvertTo-Json -Depth 8
    Set-Content -LiteralPath $Script:StatusPath -Value $json -Encoding utf8
    Set-Content -LiteralPath $Script:LatestPath -Value $json -Encoding utf8
}

function Copy-LogToResults {
    param(
        [string]$SourcePath,
        [string]$DestinationName
    )

    if ([string]::IsNullOrWhiteSpace($SourcePath) -or -not (Test-Path $SourcePath)) {
        return
    }
    Copy-Item -LiteralPath $SourcePath -Destination (Join-Path $Script:RunDir $DestinationName) -Force
}

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "--- $Message ---" -ForegroundColor Cyan
    Write-Status -Status "running" -Step $Message -Message $Message
}

function Reset-WorkRoot {
    $resolved = [System.IO.Path]::GetFullPath($WorkRoot)
    if ($resolved -ne "C:\AZMusicReleaseSmoke") {
        throw "Refusing to reset unexpected path: $resolved"
    }
    if (Test-Path $resolved) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
    New-Item -ItemType Directory -Path $resolved -Force | Out-Null
}

function Wait-ServerHealthy {
    $deadline = (Get-Date).AddSeconds(60)
    while ((Get-Date) -lt $deadline) {
        if ($null -ne $Script:ServerProcess -and $Script:ServerProcess.HasExited) {
            Show-ServerLogs
            throw "AZMusic server process exited with code $($Script:ServerProcess.ExitCode) before becoming healthy."
        }
        try {
            $health = Invoke-RestMethod -Uri "$BaseUrl/health" -TimeoutSec 2
            if ($health.status -eq "ok") {
                return
            }
        } catch {
            Start-Sleep -Seconds 2
        }
    }
    Show-ServerLogs
    throw "AZMusic server did not become healthy at $BaseUrl."
}

function Show-LogFile {
    param(
        [string]$Label,
        [string]$Path
    )

    Write-Host ""
    Write-Host "--- $Label ---" -ForegroundColor Yellow
    if (-not (Test-Path $Path)) {
        Write-Host "Missing log file: $Path"
        return
    }

    $lines = Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue
    if ($null -eq $lines -or $lines.Count -eq 0) {
        Write-Host "(empty)"
        return
    }
    $lines | Select-Object -Last 80
}

function Show-ServerLogs {
    if ($null -ne $Script:ServerProcess) {
        Write-Host ""
        Write-Host "Server process id: $($Script:ServerProcess.Id)"
        Write-Host "Server process exited: $($Script:ServerProcess.HasExited)"
        if ($Script:ServerProcess.HasExited) {
            Write-Host "Server process exit code: $($Script:ServerProcess.ExitCode)"
        }
    }
    if ($Script:ServerStdout) {
        Show-LogFile -Label "server stdout" -Path $Script:ServerStdout
        Copy-LogToResults -SourcePath $Script:ServerStdout -DestinationName "server_stdout.log"
    }
    if ($Script:ServerStderr) {
        Show-LogFile -Label "server stderr" -Path $Script:ServerStderr
        Copy-LogToResults -SourcePath $Script:ServerStderr -DestinationName "server_stderr.log"
    }
}

function Invoke-PackageInstaller {
    param(
        [string]$Label,
        [string]$FilePath,
        [string[]]$Arguments,
        [int]$TimeoutSeconds = 240
    )

    $safeLabel = ($Label -replace '[^A-Za-z0-9_-]', '_').ToLowerInvariant()
    $stdout = Join-Path $Script:RunDir "$safeLabel.stdout.log"
    $stderr = Join-Path $Script:RunDir "$safeLabel.stderr.log"

    $process = Start-Process -FilePath $FilePath `
        -ArgumentList $Arguments `
        -RedirectStandardOutput $stdout `
        -RedirectStandardError $stderr `
        -WindowStyle Hidden `
        -PassThru

    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        Show-LogFile -Label "$Label stdout" -Path $stdout
        Show-LogFile -Label "$Label stderr" -Path $stderr
        throw "$Label timed out after $TimeoutSeconds seconds."
    }
    $process.WaitForExit()
    $process.Refresh()

    Show-LogFile -Label "$Label stdout" -Path $stdout
    Show-LogFile -Label "$Label stderr" -Path $stderr

    $exitCode = $process.ExitCode
    if ($null -eq $exitCode) {
        $stdoutText = if (Test-Path $stdout) { Get-Content -LiteralPath $stdout -Raw } else { "" }
        if ($stdoutText.Contains("Installation complete.")) {
            Write-Host "$Label completed; PowerShell did not report an exit code."
            return
        }
        throw "$Label exited without reporting an exit code."
    }

    if ($exitCode -ne 0) {
        throw "$Label exited with code $exitCode."
    }
}

function Stop-PackagedServer {
    if ($null -ne $Script:ServerProcess -and -not $Script:ServerProcess.HasExited) {
        Stop-Process -Id $Script:ServerProcess.Id -Force -ErrorAction SilentlyContinue
    }

    Get-Process -Name "azmusic-server" -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -like "$WorkRoot*" } |
        Stop-Process -Force -ErrorAction SilentlyContinue
}

try {

function Invoke-JsonPost {
    param(
        [string]$Uri,
        [object]$Body,
        [hashtable]$Headers
    )
    $json = $Body | ConvertTo-Json -Depth 8
    if ($Headers) {
        return Invoke-RestMethod -Method Post -Uri $Uri -ContentType "application/json" -Body $json -Headers $Headers
    }
    return Invoke-RestMethod -Method Post -Uri $Uri -ContentType "application/json" -Body $json
}

Write-Step "Checking release installers"
if (-not (Test-Path $ServerInstaller)) {
    throw "Missing server installer: $ServerInstaller"
}
if (-not (Test-Path $ClientInstaller)) {
    throw "Missing Windows client installer: $ClientInstaller"
}

Reset-WorkRoot

Write-Step "Installing server from end-user installer"
Invoke-PackageInstaller `
    -Label "server installer" `
    -FilePath $ServerInstaller `
    -Arguments @(
        "--install-dir",
        $ServerInstallRoot,
        "--setup-skip-processing-tool-prompt",
        "--quiet"
    )

Write-Step "Installing Windows client from end-user installer"
Invoke-PackageInstaller `
    -Label "windows client installer" `
    -FilePath $ClientInstaller `
    -Arguments @(
        "--install-dir",
        $ClientInstallRoot,
        "--quiet"
    ) `
    -TimeoutSeconds 240

Write-Step "Starting installed server"
$stdout = Join-Path $WorkRoot "server_stdout.log"
$stderr = Join-Path $WorkRoot "server_stderr.log"
$Script:ServerStdout = $stdout
$Script:ServerStderr = $stderr
$Script:ServerProcess = Start-Process powershell.exe `
    -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        "`"$(Join-Path $ServerInstallRoot "start-azmusic-server.ps1")`""
    ) `
    -RedirectStandardOutput $stdout `
    -RedirectStandardError $stderr `
    -PassThru `
    -WindowStyle Hidden

Wait-ServerHealthy
Write-Host "Server healthy at $BaseUrl"

Write-Step "Pairing parent device through packaged API"
$pairingCode = Invoke-RestMethod `
    -Uri "$BaseUrl/api/v1/pairing/code?purpose=parent_setup&profile_id=parent-main&profile_name=Parent&role=parent"
$claim = Invoke-JsonPost `
    -Uri "$BaseUrl/api/v1/pairing/claim" `
    -Body @{
        pairing_code = $pairingCode.pairing_code
        device_id = "windows-sandbox-parent"
        device_name = "Windows Sandbox Parent"
        platform = "windows-sandbox"
    }
$headers = @{ "X-AZMusic-Device-Token" = $claim.device_token }
Write-Host "Parent pairing token issued for server $($claim.server_name)."

Write-Step "Checking protected processing settings"
$settings = Invoke-RestMethod -Uri "$BaseUrl/api/v1/processing/settings" -Headers $headers
Write-Host "Processing mode: $($settings.processing_mode)"
Write-Host "Production mode: $($settings.production_mode)"

$capabilities = Invoke-RestMethod -Uri "$BaseUrl/api/v1/processing/capabilities" -Headers $headers
Write-Host "Audiveris available: $($capabilities.audiveris.available)"
Write-Host "MuseScore available: $($capabilities.musescore.available)"
Write-Host "Tesseract available: $($capabilities.ocr.available)"
if ($capabilities.warnings.Count -gt 0) {
    Write-Host "Warnings:"
    foreach ($warning in $capabilities.warnings) {
        Write-Host " - $warning"
    }
}

Write-Step "Pairing student device through packaged API"
$studentCode = Invoke-RestMethod `
    -Uri "$BaseUrl/api/v1/pairing/code?purpose=student_device&profile_id=student-sandbox&profile_name=Sandbox%20Student&role=student" `
    -Headers $headers
$studentClaim = Invoke-JsonPost `
    -Uri "$BaseUrl/api/v1/pairing/claim" `
    -Body @{
        pairing_code = $studentCode.pairing_code
        device_id = "windows-sandbox-student"
        device_name = "Windows Sandbox Student"
        platform = "windows-sandbox"
    }
Write-Host "Student pairing role: $($studentClaim.role), profile: $($studentClaim.profile_id)"

Write-Step "Windows client install"
$clientExe = Join-Path $ClientInstallRoot "azmusic.exe"
if (-not (Test-Path $clientExe)) {
    throw "azmusic.exe was not found after Windows client installer ran."
}
Write-Host "Client executable: $clientExe"
$desktop = [Environment]::GetFolderPath("Desktop")
if ([string]::IsNullOrWhiteSpace($desktop)) {
    $desktop = Join-Path $env:USERPROFILE "Desktop"
}
$clientLaunchCmd = Join-Path $desktop "AZMusic Windows Client.cmd"
@"
@echo off
start "" "$clientExe"
"@ | Set-Content -LiteralPath $clientLaunchCmd -Encoding ascii
Write-Host "Use the desktop shortcut 'AZMusic Windows Client.cmd' to launch it."

Write-Step "Smoke result"
Write-Host "Installer smoke, server start, parent pairing, processing settings, and student pairing passed." -ForegroundColor Green
if (-not ($capabilities.audiveris.available -and $capabilities.musescore.available -and $capabilities.ocr.available)) {
    Write-Host "Processing import smoke was intentionally skipped because this clean sandbox lacks one or more processing tools." -ForegroundColor Yellow
    Write-Host "That is expected unless you install Audiveris, MuseScore, and Tesseract inside the sandbox."
}

Write-Host ""
Write-Host "Setup page: $BaseUrl/setup"
Write-Host "Server stdout: $stdout"
Write-Host "Server stderr: $stderr"
Write-Host "The installed server is left running for manual sandbox testing."
Copy-LogToResults -SourcePath $stdout -DestinationName "server_stdout.log"
Copy-LogToResults -SourcePath $stderr -DestinationName "server_stderr.log"
$Script:SmokeSucceeded = $true
Write-Status `
    -Status "passed" `
    -Step "complete" `
    -Message "Installer smoke, server start, parent pairing, processing settings, and student pairing passed. Server left running for manual testing." `
    -Details @{
        setup_page = "$BaseUrl/setup"
        audiveris_available = $capabilities.audiveris.available
        musescore_available = $capabilities.musescore.available
        tesseract_available = $capabilities.ocr.available
    }
}
catch {
    Show-ServerLogs
    Write-Status `
        -Status "failed" `
        -Step "failed" `
        -Message $_.Exception.Message `
        -Details @{
            error = $_.ToString()
        }
    throw
}
finally {
    if (-not $Script:SmokeSucceeded) {
        Stop-PackagedServer
    }
    Stop-Transcript | Out-Null
}

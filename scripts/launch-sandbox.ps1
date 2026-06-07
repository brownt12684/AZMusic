param(
    [ValidateSet("sandbox", "library", "piece-detail", "reader", "review-queue")]
    [string]$SandboxSurface = "sandbox",

    [switch]$ResetSandboxOnLaunch
)

$ErrorActionPreference = "Stop"

$RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$DevScript = Join-Path $RepoRoot "scripts\dev.ps1"
$ServerStdout = Join-Path $RepoRoot "server\dev_server_stdout.log"
$ServerStderr = Join-Path $RepoRoot "server\dev_server_stderr.log"

function Test-LocalServer {
    try {
        $response = Invoke-RestMethod -Uri "http://127.0.0.1:8795/health" -TimeoutSec 2
        return $response.status -eq "ok"
    }
    catch {
        return $false
    }
}

function Start-LocalServer {
    if (Test-LocalServer) {
        return
    }

    Start-Process -FilePath powershell `
        -ArgumentList @(
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            $DevScript,
            "-Task",
            "run-server"
        ) `
        -RedirectStandardOutput $ServerStdout `
        -RedirectStandardError $ServerStderr `
        -WindowStyle Hidden

    $deadline = (Get-Date).AddSeconds(25)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 1
        if (Test-LocalServer) {
            return
        }
    }

    throw "AZMusic server did not become healthy on 127.0.0.1:8795."
}

function Stop-ExistingSandboxClient {
    Get-Process -Name azmusic -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue

    Get-CimInstance Win32_Process |
        Where-Object {
            $_.Name -in @("dart.exe", "dartvm.exe", "dartaotruntime.exe") -and
            $_.CommandLine -like "*AZMusic*"
        } |
        ForEach-Object {
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        }
}

Start-LocalServer
Stop-ExistingSandboxClient

$clientArgs = @{
    Task = "run-client-sandbox"
    SandboxSurface = $SandboxSurface
    ClientServerHost = "127.0.0.1"
    ClientServerPort = "8795"
}

if ($ResetSandboxOnLaunch.IsPresent) {
    $clientArgs["ResetSandboxOnLaunch"] = $true
}

& $DevScript @clientArgs

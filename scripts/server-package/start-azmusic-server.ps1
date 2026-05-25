param(
    [int]$Port = 8000,
    [string]$HostAddress = "0.0.0.0"
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$PackageRoot = $PSScriptRoot
$ServerDir = Join-Path $PackageRoot "server"
$VenvPython = Join-Path $ServerDir ".venv\Scripts\python.exe"
$EnvFile = Join-Path $ServerDir ".env"

if (-not (Test-Path $VenvPython)) {
    & (Join-Path $PackageRoot "setup-azmusic-server.ps1")
}

if (-not (Test-Path $EnvFile)) {
    & (Join-Path $PackageRoot "setup-azmusic-server.ps1") -SkipDependencyInstall
}

Write-Host "Starting AZMusic server on http://localhost:$Port"
Write-Host "Open http://localhost:$Port/setup to pair the parent/admin device."
Write-Host "Keep this window open while clients are using the server."

Push-Location $PackageRoot
try {
    & $VenvPython -m uvicorn server.main:app --host $HostAddress --port $Port --app-dir $PackageRoot
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
finally {
    Pop-Location
}


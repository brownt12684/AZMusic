param(
    [switch]$SkipDependencyInstall
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$PackageRoot = $PSScriptRoot
$ServerDir = Join-Path $PackageRoot "server"
$VenvPython = Join-Path $ServerDir ".venv\Scripts\python.exe"
$Requirements = Join-Path $ServerDir "requirements.txt"
$EnvFile = Join-Path $ServerDir ".env"
$EnvExample = Join-Path $ServerDir ".env.example"

if (-not (Test-Path $ServerDir)) {
    throw "Missing server folder at $ServerDir."
}

if (-not (Test-Path $Requirements)) {
    throw "Missing server requirements at $Requirements."
}

if (-not (Test-Path $EnvFile)) {
    if (-not (Test-Path $EnvExample)) {
        throw "Missing environment template at $EnvExample."
    }
    Copy-Item -LiteralPath $EnvExample -Destination $EnvFile
    Write-Host "Created server\.env from the packaged production template."
}

if (-not (Test-Path $VenvPython)) {
    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($null -eq $python) {
        throw "Python was not found. Install Python 3.11 or newer, then run setup again."
    }

    Push-Location $ServerDir
    try {
        & $python.Source -m venv .venv
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    }
    finally {
        Pop-Location
    }
}

if (-not $SkipDependencyInstall.IsPresent) {
    & $VenvPython -m pip install --upgrade pip
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    & $VenvPython -m pip install -r $Requirements
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

& (Join-Path $PackageRoot "check-azmusic-server.ps1")

Write-Host ""
Write-Host "Server setup complete. Run 'Start AZMusic Server.cmd', then open the setup page to pair the parent device."


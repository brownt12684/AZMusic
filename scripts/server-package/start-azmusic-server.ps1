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

& (Join-Path $PackageRoot "enable-azmusic-firewall.ps1") -Port $Port

Write-Host "Starting AZMusic server on http://localhost:$Port"
Write-Host "Open http://localhost:$Port/setup to pair the parent/admin device."
try {
    $addresses = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
        Where-Object {
            $_.IPAddress -notlike "127.*" -and
            $_.IPAddress -notlike "169.254.*" -and
            $_.PrefixOrigin -ne "WellKnown"
        } |
        Sort-Object InterfaceMetric |
        Select-Object -ExpandProperty IPAddress -Unique
    foreach ($address in $addresses) {
        Write-Host "LAN setup URL: http://${address}:$Port/setup"
    }
}
catch {
    Write-Host "LAN setup URLs will also be shown on the setup page."
}
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

param(
    [int]$Port = 8000
)

$ErrorActionPreference = "Stop"
$PackageRoot = $PSScriptRoot
$ServerDir = Join-Path $PackageRoot "server"
$VenvPython = Join-Path $ServerDir ".venv\Scripts\python.exe"
$EnvFile = Join-Path $ServerDir ".env"

function Get-EnvValue {
    param([string]$Name)

    if (-not (Test-Path $EnvFile)) {
        return $null
    }

    $line = Get-Content -LiteralPath $EnvFile |
        Where-Object { $_ -match "^\s*$([regex]::Escape($Name))\s*=" } |
        Select-Object -First 1
    if ($null -eq $line) {
        return $null
    }

    return ($line -split "=", 2)[1].Trim().Trim('"')
}

function Test-ConfiguredTool {
    param(
        [string]$Label,
        [string]$EnvName
    )

    $value = Get-EnvValue -Name $EnvName
    if ([string]::IsNullOrWhiteSpace($value)) {
        Write-Host "${Label}: not configured"
        return
    }

    if (Test-Path $value) {
        Write-Host "${Label}: configured at $value"
    } else {
        Write-Host "${Label}: configured path was not found: $value"
    }
}

Write-Host "AZMusic server package check"
Write-Host "Package: $PackageRoot"
Write-Host "Python venv: $(if (Test-Path $VenvPython) { 'ready' } else { 'missing; run setup' })"
Write-Host "Environment: $(if (Test-Path $EnvFile) { 'server\.env exists' } else { 'missing; run setup' })"

Test-ConfiguredTool -Label "Audiveris" -EnvName "AUDIVERIS_CLI_PATH"
Test-ConfiguredTool -Label "MuseScore" -EnvName "MUSESCORE_CLI_PATH"
Test-ConfiguredTool -Label "Tesseract OCR" -EnvName "OCR_CLI_PATH"

try {
    $health = Invoke-RestMethod -Uri "http://localhost:$Port/health" -TimeoutSec 2
    Write-Host "Running server health: $($health.status)"
}
catch {
    Write-Host "Running server health: not reachable on http://localhost:$Port"
}

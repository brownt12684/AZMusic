<#
.SYNOPSIS
    Run a deterministic AZMusic release smoke loop.
.DESCRIPTION
    Exercises the install-to-first-piece path with isolated test state:
    parent pairing, protected processing settings, student pairing, import,
    processing, review approval, push, and student assignment fetch. Also runs
    the client widget/provider coverage for parent PIN setup and student setup.
#>
param(
    [string]$RepoRoot
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

if (-not $RepoRoot) {
    $RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
}

$ServerDir = Join-Path $RepoRoot "server"
$ClientDir = Join-Path $RepoRoot "client"
$Python = Join-Path $ServerDir ".venv\Scripts\python.exe"
$Flutter = Join-Path $RepoRoot ".tooling\flutter\bin\flutter.bat"

if (-not (Test-Path $Python)) {
    $Python = "python"
}

if (-not (Test-Path $Flutter)) {
    $Flutter = "flutter"
}

Write-Host ""
Write-Host "--- Server release smoke loop ---" -ForegroundColor Cyan
& $Python -m pytest `
    "$ServerDir\tests\test_api_smoke.py::test_protected_processing_settings_require_parent_pairing_token" `
    "$ServerDir\tests\test_api_smoke.py::test_server_setup_page_hosts_pairing_qr" `
    "$ServerDir\tests\test_api_smoke.py::test_release_install_pair_import_review_push_smoke_loop" `
    -q
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "--- Client first-run smoke coverage ---" -ForegroundColor Cyan
Push-Location $ClientDir
try {
    & $Flutter test `
        test\core\app_config_test.dart `
        test\widget_test.dart `
        test\presentation\providers\piece_providers_test.dart `
        --no-dds
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host "Release smoke loop passed." -ForegroundColor Green

# AZMusic Production APK Build Script
# =====================================
# Builds the release APK with AZMUSIC_PRODUCTION=true so that:
#   - Hardcoded dev profile stubs (Zora, Alyse) are suppressed
#   - The app uses only QR-paired student profiles
#   - Sandbox/dev-only UI surfaces are hidden
#
# Usage:
#   .\scripts\build-release.ps1              # Build only
#   .\scripts\build-release.ps1 -Install     # Build and install to connected device

param(
    [switch]$Install
)

$clientDir = Join-Path $PSScriptRoot ".." "client"
$clientDir = Resolve-Path $clientDir

Write-Host "AZMusic Production Build" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan
Write-Host "Client directory: $clientDir"
Write-Host ""

# Build the release APK with production flag
Write-Host "Building release APK (AZMUSIC_PRODUCTION=true)..." -ForegroundColor Yellow
Push-Location $clientDir
try {
    flutter build apk --release `
        --dart-define=AZMUSIC_PRODUCTION=true `
        --dart-define=AZMUSIC_SHOW_EXPERIMENTAL=false

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Build failed!" -ForegroundColor Red
        exit 1
    }
} finally {
    Pop-Location
}

$apkPath = Join-Path $clientDir "build" "app" "outputs" "flutter-apk" "app-release.apk"
Write-Host ""
Write-Host "Build succeeded!" -ForegroundColor Green
Write-Host "APK: $apkPath"
Write-Host ""

if ($Install) {
    Write-Host "Installing to connected device..." -ForegroundColor Yellow
    $devices = adb devices 2>&1 | Select-String "device$"
    if (-not $devices) {
        Write-Host "No authorized device found. Connect a device and ensure USB debugging is enabled." -ForegroundColor Red
        exit 1
    }
    adb install -r $apkPath
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Installed successfully!" -ForegroundColor Green
    } else {
        Write-Host "Install failed. Check device connection." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "To install on a connected device, run:" -ForegroundColor Gray
    Write-Host "  .\scripts\build-release.ps1 -Install" -ForegroundColor Gray
    Write-Host "Or manually:" -ForegroundColor Gray
    Write-Host "  adb install -r `"$apkPath`"" -ForegroundColor Gray
}

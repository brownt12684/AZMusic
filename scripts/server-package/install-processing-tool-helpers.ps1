param(
    [switch]$UseWinget
)

$ErrorActionPreference = "Stop"

$toolPages = @(
    "https://musescore.org/en/download",
    "https://github.com/Audiveris/audiveris/releases",
    "https://github.com/UB-Mannheim/tesseract/wiki"
)

if ($UseWinget.IsPresent) {
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($null -eq $winget) {
        throw "winget was not found. Opening installer pages instead."
    }

    winget install --id MuseScore.MuseScore --source winget
    winget install --id UB-Mannheim.TesseractOCR --source winget
    Write-Host "Audiveris is not consistently available through winget. Opening the Audiveris releases page."
    Start-Process "https://github.com/Audiveris/audiveris/releases"
    return
}

Write-Host "Opening installer/download pages for AZMusic processing tools."
foreach ($page in $toolPages) {
    Start-Process $page
}

Write-Host ""
Write-Host "After installing tools, configure their paths from the parent processing settings screen or server\.env."


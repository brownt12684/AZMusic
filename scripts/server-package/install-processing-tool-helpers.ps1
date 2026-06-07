param(
    [switch]$UseWinget
)

$ErrorActionPreference = "Stop"

$licenseNotes = @(
    "Audiveris: AGPL-3.0, installed separately from https://github.com/Audiveris/audiveris/releases",
    "MuseScore Studio: GPL-3.0, installed separately from https://musescore.org/en/download or winget",
    "Tesseract OCR: Apache-2.0, installed separately from https://github.com/UB-Mannheim/tesseract/wiki or winget",
    "HOMR: AGPL-3.0, optional experimental Python OMR installed into a separate virtual environment from https://pypi.org/project/homr/"
)

$toolPages = @(
    "https://musescore.org/en/download",
    "https://github.com/Audiveris/audiveris/releases",
    "https://github.com/UB-Mannheim/tesseract/wiki",
    "https://pypi.org/project/homr/"
)

function Find-HomrPython {
    $candidates = @(
        @("py", "-3.12"),
        @("py", "-3.11"),
        @("py", "-3.10"),
        @("python", "")
    )
    foreach ($candidate in $candidates) {
        $command = $candidate[0]
        $arg = $candidate[1]
        $resolved = Get-Command $command -ErrorAction SilentlyContinue
        if ($null -eq $resolved) {
            continue
        }
        $versionArgs = @()
        if (-not [string]::IsNullOrWhiteSpace($arg)) {
            $versionArgs += $arg
        }
        $versionArgs += "-c"
        $versionArgs += "import sys; raise SystemExit(0 if (3,10) <= sys.version_info[:2] <= (3,12) else 1)"
        try {
            & $command @versionArgs | Out-Null
            if ($LASTEXITCODE -eq 0) {
                return @($command, $arg)
            }
        } catch {
            continue
        }
    }
    return $null
}

function Install-HomrExperimental {
    $python = Find-HomrPython
    if ($null -eq $python) {
        Write-Host "HOMR requires Python 3.10-3.12. Install compatible Python, then rerun this helper."
        Start-Process "https://www.python.org/downloads/windows/"
        return
    }

    $toolRoot = Join-Path $PSScriptRoot "tools\homr"
    $venvPath = Join-Path $toolRoot ".venv"
    $homrExe = Join-Path $venvPath "Scripts\homr.exe"
    New-Item -ItemType Directory -Force -Path $toolRoot | Out-Null

    $pythonCommand = $python[0]
    $pythonVersionArg = $python[1]
    $pythonArgs = @()
    if (-not [string]::IsNullOrWhiteSpace($pythonVersionArg)) {
        $pythonArgs += $pythonVersionArg
    }
    if (-not (Test-Path $venvPath)) {
        Write-Host "Creating HOMR virtual environment at $venvPath"
        & $pythonCommand @pythonArgs -m venv $venvPath
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Unable to create HOMR virtual environment."
            return
        }
    }

    $venvPython = Join-Path $venvPath "Scripts\python.exe"
    Write-Host "Installing HOMR into isolated virtual environment. This may download model dependencies."
    & $venvPython -m pip install --upgrade pip
    & $venvPython -m pip install homr
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $homrExe)) {
        Write-Host "HOMR installation did not complete. AZMusic will continue using Audiveris."
        return
    }

    Write-Host "HOMR installed at $homrExe"
    Write-Host "Set HOMR_CLI_PATH to this path in server\.env or refresh Server processing settings."
}

Write-Host "AZMusic processing tool helper"
Write-Host "AZMusic does not bundle these tools. They remain separately installed command-line applications."
foreach ($note in $licenseNotes) {
    Write-Host "- $note"
}
Write-Host ""

if ($UseWinget.IsPresent) {
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($null -eq $winget) {
        throw "winget was not found. Opening installer pages instead."
    }

    Write-Host "Installing MuseScore Studio through winget..."
    winget install --id MuseScore.MuseScore --source winget --accept-source-agreements --accept-package-agreements
    winget install --id UB-Mannheim.TesseractOCR --source winget --accept-source-agreements --accept-package-agreements
    Write-Host "Audiveris is not consistently available through winget. Opening the Audiveris releases page."
    Start-Process "https://github.com/Audiveris/audiveris/releases"
    $homrAnswer = Read-Host "Install optional experimental HOMR OMR into a local Python virtual environment? [y/N]"
    if ($homrAnswer.Trim().ToLowerInvariant() -in @("y", "yes")) {
        Install-HomrExperimental
    }
    return
}

$winget = Get-Command winget -ErrorAction SilentlyContinue
if ($null -ne $winget) {
    $answer = Read-Host "Install MuseScore Studio and Tesseract with winget, then open Audiveris releases? [Y/n]"
    if ([string]::IsNullOrWhiteSpace($answer) -or $answer.Trim().ToLowerInvariant() -in @("y", "yes")) {
        & $PSCommandPath -UseWinget
        return
    }
}

Write-Host "Opening installer/download pages for AZMusic processing tools."
foreach ($page in $toolPages) {
    Start-Process $page
}

Write-Host ""
Write-Host "After installing tools, configure their paths from the parent processing settings screen or server\.env."

$homrAnswer = Read-Host "Install optional experimental HOMR OMR into a local Python virtual environment? [y/N]"
if ($homrAnswer.Trim().ToLowerInvariant() -in @("y", "yes")) {
    Install-HomrExperimental
}

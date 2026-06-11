param(
    [switch]$UseWinget
)

$ErrorActionPreference = "Stop"

$licenseNotes = @(
    "Audiveris: AGPL-3.0, installed separately from https://github.com/Audiveris/audiveris/releases",
    "MuseScore Studio: GPL-3.0, installed separately from https://musescore.org/en/download or winget",
    "Tesseract OCR: Apache-2.0, installed separately from https://github.com/UB-Mannheim/tesseract/wiki or winget",
    "HOMR: AGPL-3.0, optional experimental Python OMR installed into a separate virtual environment from https://pypi.org/project/homr/",
    "LEGATO: MIT, optional experimental Python OMR installed from https://github.com/guang-yng/legato with the guangyangmusic/legato Hugging Face model"
)

$toolPages = @(
    "https://musescore.org/en/download",
    "https://github.com/Audiveris/audiveris/releases",
    "https://github.com/UB-Mannheim/tesseract/wiki",
    "https://pypi.org/project/homr/",
    "https://github.com/guang-yng/legato"
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

function Find-LegatoPython {
    $candidates = @(
        @("py", "-3.11"),
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
        $versionArgs += "import sys; raise SystemExit(0 if sys.version_info[:2] == (3,11) else 1)"
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

function Get-LegatoAdapterPath {
    $candidates = @(
        (Join-Path $PSScriptRoot "server\tools\legato_runner.py"),
        (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "server\tools\legato_runner.py")
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return (Resolve-Path $candidate).Path
        }
    }
    return $null
}

function Set-ServerEnvValue {
    param(
        [string]$Name,
        [string]$Value
    )

    $serverDir = Join-Path $PSScriptRoot "server"
    if (-not (Test-Path $serverDir)) {
        return
    }
    $envFile = Join-Path $serverDir ".env"
    if (-not (Test-Path $envFile)) {
        $exampleFile = Join-Path $serverDir ".env.example"
        if (Test-Path $exampleFile) {
            Copy-Item -LiteralPath $exampleFile -Destination $envFile
        } else {
            New-Item -ItemType File -Force -Path $envFile | Out-Null
        }
    }

    $escapedName = [regex]::Escape($Name)
    $line = "$Name=$Value"
    $content = @(Get-Content -LiteralPath $envFile -ErrorAction SilentlyContinue)
    $matched = $false
    $updated = foreach ($entry in $content) {
        if ($entry -match "^\s*$escapedName\s*=") {
            $matched = $true
            $line
        } else {
            $entry
        }
    }
    if (-not $matched) {
        $updated += $line
    }
    Set-Content -LiteralPath $envFile -Value $updated -Encoding UTF8
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

function Install-LegatoExperimental {
    $adapterPath = Get-LegatoAdapterPath
    if ([string]::IsNullOrWhiteSpace($adapterPath)) {
        Write-Host "LEGATO adapter was not found in this AZMusic package. Recreate the server package first."
        return
    }

    $python = Find-LegatoPython
    if ($null -eq $python) {
        Write-Host "LEGATO currently requires Python 3.11 for the tested PyTorch inference environment. Install Python 3.11, then rerun this helper."
        Start-Process "https://www.python.org/downloads/release/python-3119/"
        return
    }

    $toolRoot = Join-Path $env:LOCALAPPDATA "AZMusic\Server\tools\legato"
    $sourceRoot = Join-Path $toolRoot "src"
    $venvPath = Join-Path $toolRoot ".venv"
    New-Item -ItemType Directory -Force -Path $toolRoot | Out-Null

    if (-not (Test-Path (Join-Path $sourceRoot "scripts\inference.py"))) {
        $archive = Join-Path $toolRoot "legato-main.zip"
        $expandedRoot = Join-Path $toolRoot "legato-main"
        Write-Host "Downloading official LEGATO source into $toolRoot"
        Invoke-WebRequest `
            -Uri "https://github.com/guang-yng/legato/archive/refs/heads/main.zip" `
            -OutFile $archive `
            -UseBasicParsing
        if (Test-Path $expandedRoot) {
            Remove-Item -LiteralPath $expandedRoot -Recurse -Force
        }
        Expand-Archive -LiteralPath $archive -DestinationPath $toolRoot -Force
        if (Test-Path $sourceRoot) {
            Remove-Item -LiteralPath $sourceRoot -Recurse -Force
        }
        Move-Item -LiteralPath $expandedRoot -Destination $sourceRoot
    }

    $pythonCommand = $python[0]
    $pythonVersionArg = $python[1]
    $pythonArgs = @()
    if (-not [string]::IsNullOrWhiteSpace($pythonVersionArg)) {
        $pythonArgs += $pythonVersionArg
    }
    if (-not (Test-Path $venvPath)) {
        Write-Host "Creating LEGATO virtual environment at $venvPath"
        & $pythonCommand @pythonArgs -m venv $venvPath
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Unable to create LEGATO virtual environment."
            return
        }
    }

    $venvPython = Join-Path $venvPath "Scripts\python.exe"
    Write-Host "Installing LEGATO inference dependencies. This is a large PyTorch/Transformers download."
    & $venvPython -m pip install --upgrade pip setuptools wheel
    & $venvPython -m pip install accelerate==1.8.0 datasets==3.2.0 fire==0.7.0 transformers==4.54.0 torch==2.6.0 pillow==11.1.0 numpy==1.26.4 Levenshtein tqdm pyparsing
    if ($LASTEXITCODE -ne 0) {
        Write-Host "LEGATO dependency installation did not complete."
        return
    }

    Set-ServerEnvValue -Name "LEGATO_CLI_PATH" -Value $adapterPath
    Set-ServerEnvValue -Name "LEGATO_MODEL_PATH" -Value "guangyangmusic/legato"

    Write-Host "LEGATO adapter configured at $adapterPath"
    Write-Host "LEGATO source installed at $sourceRoot"
    Write-Host "The guangyangmusic/legato model is gated and requires Hugging Face login plus approved model access."
    $hfAnswer = Read-Host "Connect Hugging Face for LEGATO now? [Y/n]"
    if ([string]::IsNullOrWhiteSpace($hfAnswer) -or $hfAnswer.Trim().ToLowerInvariant() -in @("y", "yes")) {
        & (Join-Path $PSScriptRoot "connect-legato-huggingface.ps1")
    }
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
    $legatoAnswer = Read-Host "Install optional experimental LEGATO OMR into a local Python virtual environment? [y/N]"
    if ($legatoAnswer.Trim().ToLowerInvariant() -in @("y", "yes")) {
        Install-LegatoExperimental
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

$legatoAnswer = Read-Host "Install optional experimental LEGATO OMR into a local Python virtual environment? [y/N]"
if ($legatoAnswer.Trim().ToLowerInvariant() -in @("y", "yes")) {
    Install-LegatoExperimental
}

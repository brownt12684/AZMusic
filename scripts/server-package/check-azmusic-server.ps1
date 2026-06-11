param(
    [int]$Port = 8795
)

$ErrorActionPreference = "Stop"
$PackageRoot = $PSScriptRoot
$ServerDir = Join-Path $PackageRoot "server"
$ServerExe = Join-Path $PackageRoot "azmusic-server.exe"
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

function Find-ToolPath {
    param(
        [string]$EnvName,
        [string[]]$CommandNames,
        [string[]]$CommonPaths
    )

    $value = Get-EnvValue -Name $EnvName
    if (-not [string]::IsNullOrWhiteSpace($value)) {
        if (Test-Path $value) {
            return @{
                Source = "configured"
                Path = $value
            }
        }
        $command = Get-Command $value -ErrorAction SilentlyContinue
        if ($null -ne $command) {
            return @{
                Source = "configured command"
                Path = $command.Source
            }
        }
        return @{
            Source = "missing configured"
            Path = $value
        }
    }

    foreach ($commandName in $CommandNames) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($null -ne $command) {
            return @{
                Source = "PATH"
                Path = $command.Source
            }
        }
    }

    foreach ($commonPath in $CommonPaths) {
        if (Test-Path $commonPath) {
            return @{
                Source = "auto-detected"
                Path = $commonPath
            }
        }
    }

    return $null
}

function Test-ConfiguredTool {
    param(
        [string]$Label,
        [string]$EnvName,
        [string[]]$CommandNames,
        [string[]]$CommonPaths = @()
    )

    $tool = Find-ToolPath `
        -EnvName $EnvName `
        -CommandNames $CommandNames `
        -CommonPaths $CommonPaths
    if ($null -eq $tool) {
        Write-Host "${Label}: not configured or detected"
        return
    }

    if ($tool.Source -eq "missing configured") {
        Write-Host "${Label}: configured path was not found: $($tool.Path)"
    } else {
        Write-Host "${Label}: $($tool.Source) at $($tool.Path)"
    }
}

function Test-MuseHubInstalled {
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Muse Hub\Muse Hub.exe",
        "$env:ProgramFiles\Muse Hub\Muse Hub.exe",
        "${env:ProgramFiles(x86)}\Muse Hub\Muse Hub.exe"
    )
    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path $candidate)) {
            return $true
        }
    }
    return $false
}

function Test-HuggingFaceToken {
    $tokenPath = Join-Path $HOME ".cache\huggingface\token"
    if (Test-Path $tokenPath) {
        $token = (Get-Content -LiteralPath $tokenPath -Raw -ErrorAction SilentlyContinue).Trim()
        return -not [string]::IsNullOrWhiteSpace($token)
    }
    return $false
}

Write-Host "AZMusic server package check"
Write-Host "Package: $PackageRoot"
Write-Host "Bundled server executable: $(if (Test-Path $ServerExe) { 'ready' } else { 'missing; recreate package' })"
Write-Host "Environment: $(if (Test-Path $EnvFile) { 'server\.env exists' } else { 'missing; run setup' })"

Test-ConfiguredTool `
    -Label "Audiveris" `
    -EnvName "AUDIVERIS_CLI_PATH" `
    -CommandNames @("audiveris") `
    -CommonPaths @("$env:ProgramFiles\Audiveris\Audiveris.exe", "${env:ProgramFiles(x86)}\Audiveris\Audiveris.exe")
Test-ConfiguredTool `
    -Label "MuseScore Studio" `
    -EnvName "MUSESCORE_CLI_PATH" `
    -CommandNames @("musescore", "mscore", "MuseScore4") `
    -CommonPaths @("$env:ProgramFiles\MuseScore 4\bin\MuseScore4.exe", "${env:ProgramFiles(x86)}\MuseScore 4\bin\MuseScore4.exe", "$env:LOCALAPPDATA\Programs\MuseScore 4\bin\MuseScore4.exe")
if (Test-MuseHubInstalled) {
    Write-Host "Muse Hub detected. If MuseScore Studio is missing above, install MuseScore Studio inside Muse Hub."
}
Test-ConfiguredTool `
    -Label "Tesseract OCR" `
    -EnvName "OCR_CLI_PATH" `
    -CommandNames @("tesseract") `
    -CommonPaths @("$env:ProgramFiles\Tesseract-OCR\tesseract.exe", "${env:ProgramFiles(x86)}\Tesseract-OCR\tesseract.exe")
Test-ConfiguredTool `
    -Label "HOMR (experimental)" `
    -EnvName "HOMR_CLI_PATH" `
    -CommandNames @("homr") `
    -CommonPaths @("$PackageRoot\tools\homr\.venv\Scripts\homr.exe", "$env:LOCALAPPDATA\AZMusic\Server\tools\homr\.venv\Scripts\homr.exe")
Test-ConfiguredTool `
    -Label "LEGATO (experimental)" `
    -EnvName "LEGATO_CLI_PATH" `
    -CommandNames @("legato-runner", "legato") `
    -CommonPaths @("$PackageRoot\server\tools\legato_runner.py", "$env:LOCALAPPDATA\AZMusic\Server\tools\legato\legato-runner.py", "$env:LOCALAPPDATA\AZMusic\Server\tools\legato\legato-runner.cmd")
Write-Host "LEGATO Hugging Face token: $(if (Test-HuggingFaceToken) { 'found' } else { 'not found; run Connect LEGATO Hugging Face.cmd if using guangyangmusic/legato' })"

try {
    $health = Invoke-RestMethod -Uri "http://localhost:$Port/health" -TimeoutSec 2
    Write-Host "Running server health: $($health.status)"
}
catch {
    Write-Host "Running server health: not reachable on http://localhost:$Port"
}

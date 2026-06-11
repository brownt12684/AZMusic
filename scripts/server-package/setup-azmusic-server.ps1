param(
    [switch]$SkipDependencyInstall,
    [switch]$SkipProcessingToolPrompt,
    [switch]$InstallPythonIfMissing,
    [switch]$SkipPythonPrompt
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$PackageRoot = $PSScriptRoot
$ServerDir = Join-Path $PackageRoot "server"
$ServerExe = Join-Path $PackageRoot "azmusic-server.exe"
$EnvFile = Join-Path $ServerDir ".env"
$EnvExample = Join-Path $ServerDir ".env.example"

function Install-VcRuntime {
    $installerUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
    $installerPath = Join-Path $env:TEMP "vc_redist.x64.exe"

    Write-Host "Installing Microsoft Visual C++ runtime required by bundled native components..."
    try {
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
    }
    catch {
        Write-Warning "Unable to download Microsoft Visual C++ runtime installer: $_"
        return $false
    }

    $process = Start-Process `
        -FilePath $installerPath `
        -ArgumentList @(
            "/install",
            "/quiet",
            "/norestart"
        ) `
        -Wait `
        -PassThru

    return $process.ExitCode -in @(0, 1638, 3010)
}

function Test-ServerExecutable {
    if (-not (Test-Path $ServerExe)) {
        return $false
    }

    $logPath = Join-Path $PackageRoot "azmusic-server-self-test.log"
    & $ServerExe --self-test *> $logPath
    if ($LASTEXITCODE -eq 0) {
        return $true
    }

    Write-Warning "AZMusic server executable self-test failed. See $logPath"
    return $false
}

function Ensure-ServerExecutable {
    if (-not (Test-Path $ServerExe)) {
        throw "Missing bundled server executable at $ServerExe. Recreate the AZMusic server package."
    }

    if (Test-ServerExecutable) {
        Write-Host "Bundled AZMusic server executable is ready."
        return
    }

    Write-Host ""
    Write-Host "The bundled server could not start. This is usually a missing Microsoft Visual C++ runtime."
    if (-not (Install-VcRuntime)) {
        throw "Unable to install Microsoft Visual C++ runtime. Install the x64 Visual C++ Redistributable, then rerun setup."
    }

    if (-not (Test-ServerExecutable)) {
        throw "AZMusic server executable still failed self-test after installing the Visual C++ runtime. Reboot Windows and rerun setup."
    }

    Write-Host "Bundled AZMusic server executable is ready after Visual C++ runtime setup."
}

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

function Set-EnvValue {
    param(
        [string]$Name,
        [string]$Value
    )

    $escapedName = [regex]::Escape($Name)
    $line = "$Name=$Value"
    $content = @()
    if (Test-Path $EnvFile) {
        $content = @(Get-Content -LiteralPath $EnvFile)
    }

    $updated = $false
    $next = foreach ($existingLine in $content) {
        if ($existingLine -match "^\s*$escapedName\s*=") {
            $updated = $true
            $line
        } else {
            $existingLine
        }
    }

    if (-not $updated) {
        $next += $line
    }

    Set-Content -LiteralPath $EnvFile -Value $next -Encoding utf8
}

function Find-ToolPath {
    param(
        [string]$EnvName,
        [string[]]$CommandNames,
        [string[]]$CommonPaths
    )

    $configuredPath = Get-EnvValue -Name $EnvName
    if (-not [string]::IsNullOrWhiteSpace($configuredPath)) {
        if (Test-Path $configuredPath) {
            return $configuredPath
        }
        $configuredCommand = Get-Command $configuredPath -ErrorAction SilentlyContinue
        if ($null -ne $configuredCommand) {
            return $configuredCommand.Source
        }
    }

    foreach ($commandName in $CommandNames) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($null -ne $command) {
            return $command.Source
        }
    }

    foreach ($commonPath in $CommonPaths) {
        if (Test-Path $commonPath) {
            return $commonPath
        }
    }

    return $null
}

function Test-ToolAvailable {
    param(
        [string]$EnvName,
        [string[]]$CommandNames,
        [string[]]$CommonPaths = @()
    )

    return -not [string]::IsNullOrWhiteSpace(
        (Find-ToolPath -EnvName $EnvName -CommandNames $CommandNames -CommonPaths $CommonPaths)
    )
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

function Ensure-DetectedProcessingToolPaths {
    $tools = @(
        @{
            Label = "Audiveris"
            EnvName = "AUDIVERIS_CLI_PATH"
            CommandNames = @("audiveris")
            CommonPaths = @(
                "$env:ProgramFiles\Audiveris\Audiveris.exe",
                "${env:ProgramFiles(x86)}\Audiveris\Audiveris.exe"
            )
        },
        @{
            Label = "MuseScore Studio"
            EnvName = "MUSESCORE_CLI_PATH"
            CommandNames = @("musescore", "mscore", "MuseScore4")
            CommonPaths = @(
                "$env:ProgramFiles\MuseScore 4\bin\MuseScore4.exe",
                "${env:ProgramFiles(x86)}\MuseScore 4\bin\MuseScore4.exe",
                "$env:LOCALAPPDATA\Programs\MuseScore 4\bin\MuseScore4.exe"
            )
        },
        @{
            Label = "Tesseract OCR"
            EnvName = "OCR_CLI_PATH"
            CommandNames = @("tesseract")
            CommonPaths = @(
                "$env:ProgramFiles\Tesseract-OCR\tesseract.exe",
                "${env:ProgramFiles(x86)}\Tesseract-OCR\tesseract.exe"
            )
        },
        @{
            Label = "HOMR"
            EnvName = "HOMR_CLI_PATH"
            CommandNames = @("homr")
            CommonPaths = @(
                "$PackageRoot\tools\homr\.venv\Scripts\homr.exe",
                "$env:LOCALAPPDATA\AZMusic\Server\tools\homr\.venv\Scripts\homr.exe"
            )
        },
        @{
            Label = "LEGATO"
            EnvName = "LEGATO_CLI_PATH"
            CommandNames = @("legato-runner", "legato")
            CommonPaths = @(
                "$PackageRoot\server\tools\legato_runner.py",
                "$env:LOCALAPPDATA\AZMusic\Server\tools\legato\legato-runner.py",
                "$env:LOCALAPPDATA\AZMusic\Server\tools\legato\legato-runner.cmd"
            )
        }
    )

    foreach ($tool in $tools) {
        $existingValue = Get-EnvValue -Name $tool.EnvName
        $detectedPath = Find-ToolPath `
            -EnvName $tool.EnvName `
            -CommandNames $tool.CommandNames `
            -CommonPaths $tool.CommonPaths
        if ([string]::IsNullOrWhiteSpace($existingValue) -and -not [string]::IsNullOrWhiteSpace($detectedPath)) {
            Set-EnvValue -Name $tool.EnvName -Value $detectedPath
            Write-Host "$($tool.Label) detected at $detectedPath"
        }
    }
}

function Get-MissingProcessingTools {
    $missing = @()
    if (-not (Test-ToolAvailable -EnvName "AUDIVERIS_CLI_PATH" -CommandNames @("audiveris") -CommonPaths @("$env:ProgramFiles\Audiveris\Audiveris.exe", "${env:ProgramFiles(x86)}\Audiveris\Audiveris.exe"))) {
        $missing += "Audiveris"
    }
    if (-not (Test-ToolAvailable -EnvName "MUSESCORE_CLI_PATH" -CommandNames @("musescore", "mscore", "MuseScore4") -CommonPaths @("$env:ProgramFiles\MuseScore 4\bin\MuseScore4.exe", "${env:ProgramFiles(x86)}\MuseScore 4\bin\MuseScore4.exe", "$env:LOCALAPPDATA\Programs\MuseScore 4\bin\MuseScore4.exe"))) {
        $missing += "MuseScore Studio"
    }
    if (-not (Test-ToolAvailable -EnvName "OCR_CLI_PATH" -CommandNames @("tesseract") -CommonPaths @("$env:ProgramFiles\Tesseract-OCR\tesseract.exe", "${env:ProgramFiles(x86)}\Tesseract-OCR\tesseract.exe"))) {
        $missing += "Tesseract OCR"
    }
    return $missing
}

function Show-ProcessingToolGuidance {
    if ($SkipProcessingToolPrompt.IsPresent) {
        return
    }

    $missingTools = Get-MissingProcessingTools
    if ($missingTools.Count -eq 0) {
        Write-Host ""
        Write-Host "Processing tools detected: Audiveris, MuseScore Studio, and Tesseract OCR."
        return
    }

    Write-Host ""
    Write-Host "AZMusic can start without all processing tools, but production processing will be limited."
    Write-Host "Missing processing tools: $($missingTools -join ', ')"
    Write-Host ""
    if (($missingTools -contains "MuseScore Studio") -and (Test-MuseHubInstalled)) {
        Write-Host "Muse Hub was detected, but MuseScore Studio was not. Open Muse Hub and install MuseScore Studio, or use the MuseScore download page."
        Write-Host ""
    }
    Write-Host "Audiveris and MuseScore Studio are copyleft-licensed tools installed separately from AZMusic. Tesseract OCR is Apache-2.0 licensed."
    Write-Host "HOMR is optional experimental AGPL-3.0 OMR and can be installed into a separate Python virtual environment by the helper."
    Write-Host "LEGATO is optional experimental MIT-licensed OMR and can be installed into a separate Python virtual environment by the helper."
    Write-Host "The helper opens official download pages or uses winget; AZMusic does not silently bundle those tools."
    Write-Host ""
    $answer = Read-Host "Open the processing tool installer helper now? [Y/n]"
    if ([string]::IsNullOrWhiteSpace($answer) -or $answer.Trim().ToLowerInvariant() -in @("y", "yes")) {
        & (Join-Path $PackageRoot "install-processing-tool-helpers.ps1")
        Write-Host ""
        Write-Host "After installing tools, pair the parent device and confirm paths in Server processing settings."
    } else {
        Write-Host "Skipping processing tool helper. You can run 'Install Processing Tool Helpers.cmd' later."
    }
}

if ($InstallPythonIfMissing.IsPresent -or $SkipPythonPrompt.IsPresent) {
    Write-Host "Python install flags are ignored; this package contains a bundled AZMusic server executable."
}

if (-not (Test-Path $ServerDir)) {
    throw "Missing server runtime folder at $ServerDir."
}

if (-not (Test-Path $EnvFile)) {
    if (-not (Test-Path $EnvExample)) {
        throw "Missing environment template at $EnvExample."
    }
    Copy-Item -LiteralPath $EnvExample -Destination $EnvFile
    Write-Host "Created server\.env from the packaged production template."
}

Ensure-DetectedProcessingToolPaths
Ensure-ServerExecutable

& (Join-Path $PackageRoot "check-azmusic-server.ps1")
& (Join-Path $PackageRoot "enable-azmusic-firewall.ps1") -Port 8795
Show-ProcessingToolGuidance

Write-Host ""
Write-Host "Server setup complete. Run 'Start AZMusic Server.cmd', then open the setup page to pair the parent device."

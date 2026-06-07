param(
    [Parameter(Mandatory = $true)]
    [ValidateSet(
        "bootstrap",
        "bootstrap-server",
        "bootstrap-client",
        "run-server",
        "lint-server",
        "test-server",
        "check-server",
        "run-client",
        "run-client-sandbox",
        "smoke-client-windows-pdf",
        "run-client-android",
        "lint-client",
        "test-client",
        "check-client",
        "check-client-windows",
        "build-client-windows-release",
        "build-client-android-apk",
        "build-client-android-aab",
        "package-server-windows-release",
        "package-server-windows-installer",
        "package-client-windows-release",
        "package-client-windows-installer",
        "package-client-android-apk",
        "package-release-assets",
        "check",
        "clean"
    )]
    [string]$Task,

    [string]$ClientDevice,

    [string]$ClientServerHost,

    [string]$ClientServerPort,

    [string]$ReleaseVersion = "v0.2.0",

    [ValidateSet("sandbox", "library", "piece-detail", "reader", "review-queue")]
    [string]$SandboxSurface = "sandbox",

    [switch]$ResetSandboxOnLaunch
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$ClientDir = Join-Path $RepoRoot "client"
$ServerDir = Join-Path $RepoRoot "server"
$DistDir = Join-Path $RepoRoot "dist"
$LocalFlutter = Join-Path $RepoRoot ".tooling\\flutter\\bin\\flutter.bat"
$ClientHooksDir = Join-Path $ClientDir ".dart_tool\\hooks_runner"
$ClientBuildDir = Join-Path $ClientDir "build"
$ServerVenvPython = Join-Path $ServerDir ".venv\\Scripts\\python.exe"
$BrandIcon = Join-Path $ClientDir "windows\\runner\\resources\\app_icon.ico"

function Get-FlutterCommand {
    if (Test-Path $LocalFlutter) {
        return $LocalFlutter
    }

    $command = Get-Command flutter -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        throw "Flutter was not found. Bootstrap the repo-local SDK under .tooling/flutter or add Flutter to PATH."
    }

    return $command.Source
}

function Get-ServerPython {
    if (-not (Test-Path $ServerVenvPython)) {
        throw "Missing server virtual environment at server/.venv. Run '.\\scripts\\dev.ps1 -Task bootstrap-server' first."
    }

    return $ServerVenvPython
}

function Get-ClientRuntimeDartDefines {
    $dartDefines = @()

    if (-not [string]::IsNullOrWhiteSpace($ClientServerHost)) {
        $dartDefines += "--dart-define=AZMUSIC_SERVER_HOST=$ClientServerHost"
    }

    if (-not [string]::IsNullOrWhiteSpace($ClientServerPort)) {
        $dartDefines += "--dart-define=AZMUSIC_SERVER_PORT=$ClientServerPort"
    }

    return $dartDefines
}

function Get-ClientProductionDartDefines {
    return @("--dart-define=AZMUSIC_PRODUCTION=true")
}

function Invoke-Flutter {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments
    )

    $flutter = Get-FlutterCommand
    $previousAnalytics = $env:FLUTTER_SUPPRESS_ANALYTICS
    $env:FLUTTER_SUPPRESS_ANALYTICS = "true"

    Push-Location $ClientDir
    try {
        & $flutter @Arguments
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    }
    finally {
        Pop-Location
        $env:FLUTTER_SUPPRESS_ANALYTICS = $previousAnalytics
    }
}

function Invoke-ServerPython {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments
    )

    $python = Get-ServerPython
    Push-Location $RepoRoot
    try {
        & $python @Arguments
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    }
    finally {
        Pop-Location
    }
}

function Invoke-ServerCompile {
    $targets = @(
        (Join-Path $ServerDir "main.py"),
        (Join-Path $ServerDir "config.py"),
        (Join-Path $ServerDir "database.py"),
        (Join-Path $ServerDir "jobs"),
        (Join-Path $ServerDir "models"),
        (Join-Path $ServerDir "providers"),
        (Join-Path $ServerDir "repositories"),
        (Join-Path $ServerDir "routers"),
        (Join-Path $ServerDir "services"),
        (Join-Path $ServerDir "tests")
    )

    Invoke-ServerPython -m compileall @targets
}

function Ensure-ServerEnvFile {
    $envFile = Join-Path $ServerDir ".env"
    $exampleFile = Join-Path $ServerDir ".env.example"

    if (-not (Test-Path $envFile) -and (Test-Path $exampleFile)) {
        Copy-Item -LiteralPath $exampleFile -Destination $envFile
    }
}

function Bootstrap-Server {
    Ensure-ServerEnvFile

    if (-not (Test-Path $ServerVenvPython)) {
        Push-Location $ServerDir
        try {
            python -m venv .venv
            if ($LASTEXITCODE -ne 0) {
                exit $LASTEXITCODE
            }
        }
        finally {
            Pop-Location
        }
    }

    Invoke-ServerPython -m pip install --upgrade pip
    Invoke-ServerPython -m pip install -r (Join-Path $ServerDir "requirements-dev.txt")
}

function Bootstrap-Client {
    $flutter = Get-FlutterCommand
    $missingPlatforms = @()

    if (-not (Test-Path (Join-Path $ClientDir "windows"))) {
        $missingPlatforms += "windows"
    }
    if (-not (Test-Path (Join-Path $ClientDir "android"))) {
        $missingPlatforms += "android"
    }

    $previousAnalytics = $env:FLUTTER_SUPPRESS_ANALYTICS
    $env:FLUTTER_SUPPRESS_ANALYTICS = "true"
    Push-Location $ClientDir
    try {
        if ($missingPlatforms.Count -gt 0) {
            & $flutter create --org com.azmusic . "--platforms=$($missingPlatforms -join ',')"
            if ($LASTEXITCODE -ne 0) {
                exit $LASTEXITCODE
            }
        }

        & $flutter pub get
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    }
    finally {
        Pop-Location
        $env:FLUTTER_SUPPRESS_ANALYTICS = $previousAnalytics
    }
}

function Clean-ClientBuildState {
    Get-Process | Where-Object { $_.ProcessName -in @('dart', 'dartvm', 'dartaotruntime') } | Stop-Process -Force -ErrorAction SilentlyContinue

    foreach ($path in @($ClientHooksDir, $ClientBuildDir)) {
        if (Test-Path $path) {
            Remove-Item -LiteralPath $path -Recurse -Force
        }
    }
}

function Get-ClientRuntimeProcesses {
    Get-Process | Where-Object {
        $_.ProcessName -in @('azmusic', 'dart', 'dartvm', 'dartaotruntime')
    }
}

function Stop-ClientRuntimeProcesses {
    param(
        [int[]]$ExcludeIds = @()
    )

    Get-ClientRuntimeProcesses |
        Where-Object { $ExcludeIds -notcontains $_.Id } |
        Stop-Process -Force -ErrorAction SilentlyContinue
}

function Invoke-ClientWindowsPdfSmoke {
    Stop-ClientRuntimeProcesses
    Start-Sleep -Milliseconds 500

    $runId = [guid]::NewGuid().ToString("N")
    $stdoutPath = Join-Path $ClientDir "smoke_client_windows_pdf_stdout_$runId.log"
    $stderrPath = Join-Path $ClientDir "smoke_client_windows_pdf_stderr_$runId.log"
    $windowsDebugDir = Join-Path $ClientBuildDir "windows\\x64\\runner\\Debug"
    $windowsConfigDir = Join-Path $ClientDir "windows\\flutter\\ephemeral"
    $generatedConfigPath = Join-Path $windowsConfigDir "generated_config.cmake"
    $preservedDebugDir = Join-Path $ClientBuildDir "windows_standard_debug_preserved"
    $preservedConfigPath = Join-Path $ClientBuildDir "windows_standard_generated_config.cmake"
    $beforeIds = @(Get-ClientRuntimeProcesses | Select-Object -ExpandProperty Id)
    $runner = $null
    $result = "timeout"
    $logs = ""
    $restoredStandardBuild = $false

    foreach ($path in @($preservedConfigPath)) {
        if (Test-Path $path) {
            Remove-Item -LiteralPath $path -Force
        }
    }

    if (Test-Path $preservedDebugDir) {
        Remove-Item -LiteralPath $preservedDebugDir -Recurse -Force
    }

    if ((Test-Path $windowsDebugDir) -and (Test-Path $generatedConfigPath)) {
        $generatedConfig = Get-Content $generatedConfigPath -Raw
        if ($generatedConfig.Contains('FLUTTER_TARGET=C:\\Projects\\AZMusic\\client\\lib/main.dart')) {
            Copy-Item -LiteralPath $windowsDebugDir -Destination $preservedDebugDir -Recurse
            Copy-Item -LiteralPath $generatedConfigPath -Destination $preservedConfigPath
        }
    }

    try {
        $runnerArguments = @(
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            $PSCommandPath,
            '-Task',
            'run-client-sandbox',
            '-SandboxSurface',
            'library',
            '-ResetSandboxOnLaunch'
        )

        if (-not [string]::IsNullOrWhiteSpace($ClientServerHost)) {
            $runnerArguments += @('-ClientServerHost', $ClientServerHost)
        }

        if (-not [string]::IsNullOrWhiteSpace($ClientServerPort)) {
            $runnerArguments += @('-ClientServerPort', $ClientServerPort)
        }

        $runner = Start-Process -FilePath powershell `
            -ArgumentList $runnerArguments `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath `
            -WindowStyle Hidden `
            -PassThru

        $successPatterns = @(
            'AZMUSIC_PDF_LOAD_OK:',
            'A Dart VM Service on Windows is available at:'
        )
        $failurePatterns = @(
            'AZMUSIC_PDF_LOAD_FAILED:',
            'Unhandled Exception',
            'getImage() has not been implemented.'
        )
        $deadline = (Get-Date).AddMinutes(3)

        while ((Get-Date) -lt $deadline) {
            Start-Sleep -Seconds 5

            $stdout = if (Test-Path $stdoutPath) {
                Get-Content $stdoutPath -Raw
            } else {
                ''
            }
            $stderr = if (Test-Path $stderrPath) {
                Get-Content $stderrPath -Raw
            } else {
                ''
            }
            $logs = "$stdout`n$stderr"

            foreach ($pattern in $successPatterns) {
                if ($logs.Contains($pattern)) {
                    $result = "success"
                    break
                }
            }

            if ($result -eq "success") {
                break
            }

            foreach ($pattern in $failurePatterns) {
                if ($logs.Contains($pattern)) {
                    $result = "failure"
                    break
                }
            }

            if ($result -eq "failure") {
                break
            }
        }
    }
    finally {
        if ($runner -and -not $runner.HasExited) {
            Stop-Process -Id $runner.Id -Force -ErrorAction SilentlyContinue
        }

        $newIds = @(
            Get-ClientRuntimeProcesses |
                Where-Object { $beforeIds -notcontains $_.Id } |
                Select-Object -ExpandProperty Id
        )
        Stop-ClientRuntimeProcesses -ExcludeIds $beforeIds

        if (Test-Path $preservedDebugDir) {
            if (Test-Path $windowsDebugDir) {
                Remove-Item -LiteralPath $windowsDebugDir -Recurse -Force
            }
            Copy-Item -LiteralPath $preservedDebugDir -Destination $windowsDebugDir -Recurse
            Remove-Item -LiteralPath $preservedDebugDir -Recurse -Force

            if (Test-Path $preservedConfigPath) {
                Copy-Item -LiteralPath $preservedConfigPath -Destination $generatedConfigPath -Force
                Remove-Item -LiteralPath $preservedConfigPath -Force
            }

            $restoredStandardBuild = $true
        }
    }

    if ($result -ne "success") {
        if ([string]::IsNullOrWhiteSpace($logs)) {
            $stdout = if (Test-Path $stdoutPath) {
                Get-Content $stdoutPath -Raw
            } else {
                ''
            }
            $stderr = if (Test-Path $stderrPath) {
                Get-Content $stderrPath -Raw
            } else {
                ''
            }
            $logs = "$stdout`n$stderr"
        }

        if (-not [string]::IsNullOrWhiteSpace($logs)) {
            Write-Host $logs
        }

        throw "Windows sandbox smoke test failed while launching the empty library."
    }

    if ($restoredStandardBuild) {
        Write-Host "Restored the preserved standard Windows debug build after the PDF smoke run."
    }
}

function Invoke-ClientCheck {
    Invoke-Flutter analyze
    Invoke-Flutter test --no-pub --no-test-assets --no-dds -r expanded
}

function Invoke-ClientWindowsCheck {
    Invoke-ClientCheck
    Invoke-ClientWindowsPdfSmoke
}

function Invoke-ClientWindowsReleaseBuild {
    Bootstrap-Client
    $clientArguments = @("build", "windows", "--release") + (Get-ClientProductionDartDefines)
    Invoke-Flutter -Arguments $clientArguments
}

function Invoke-ClientAndroidApkBuild {
    Bootstrap-Client
    $clientArguments = @("build", "apk", "--release") + (Get-ClientProductionDartDefines)
    Invoke-Flutter -Arguments $clientArguments
}

function Invoke-ClientAndroidAppBundleBuild {
    Bootstrap-Client
    $clientArguments = @("build", "appbundle", "--release") + (Get-ClientProductionDartDefines)
    Invoke-Flutter -Arguments $clientArguments
}

function Reset-Directory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $resolvedParent = [System.IO.Path]::GetFullPath((Split-Path -Parent $Path))
    $resolvedRepo = [System.IO.Path]::GetFullPath($RepoRoot)
    if (-not $resolvedParent.StartsWith($resolvedRepo, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to reset a directory outside the repository: $Path"
    }

    if (Test-Path $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Compress-ReleaseFolder {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceFolder,

        [Parameter(Mandatory = $true)]
        [string]$DestinationZip
    )

    if (Test-Path $DestinationZip) {
        Remove-Item -LiteralPath $DestinationZip -Force
    }

    Compress-Archive -Path $SourceFolder -DestinationPath $DestinationZip -CompressionLevel Optimal
    Write-Host "Created $DestinationZip"
}

function Ensure-ClientVcRuntimeInstaller {
    $vendorRoot = Join-Path $DistDir "vendor"
    $vcRedist = Join-Path $vendorRoot "vc_redist.x64.exe"
    if (Test-Path $vcRedist) {
        return $vcRedist
    }

    New-Item -ItemType Directory -Path $vendorRoot -Force | Out-Null
    $url = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
    Write-Host "Downloading Microsoft Visual C++ runtime installer for Windows client package..."
    Invoke-WebRequest -Uri $url -OutFile $vcRedist -UseBasicParsing -TimeoutSec 60
    if (-not (Test-Path $vcRedist)) {
        throw "Failed to download Microsoft Visual C++ runtime installer."
    }
    return $vcRedist
}

function Find-VisualCppRuntimeRedistDir {
    $programFilesX86 = ${env:ProgramFiles(x86)}
    if ([string]::IsNullOrWhiteSpace($programFilesX86)) {
        return $null
    }

    $redistRoot = Join-Path $programFilesX86 "Microsoft Visual Studio\2022\BuildTools\VC\Redist\MSVC"
    if (-not (Test-Path $redistRoot)) {
        return $null
    }

    $candidates = Get-ChildItem -LiteralPath $redistRoot -Directory |
        Sort-Object Name -Descending |
        ForEach-Object { Join-Path $_.FullName "x64\Microsoft.VC143.CRT" } |
        Where-Object { Test-Path (Join-Path $_ "msvcp140.dll") }

    return $candidates | Select-Object -First 1
}

function Copy-ClientVcRuntimeDlls {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageRoot
    )

    $runtimeDir = Find-VisualCppRuntimeRedistDir
    if ([string]::IsNullOrWhiteSpace($runtimeDir)) {
        Write-Warning "Visual C++ runtime DLLs were not found in the local Visual Studio redist folder. The client installer will fall back to the VC++ redistributable installer."
        return
    }

    foreach ($dllName in @(
        "msvcp140.dll",
        "vcruntime140.dll",
        "vcruntime140_1.dll"
    )) {
        $source = Join-Path $runtimeDir $dllName
        if (-not (Test-Path $source)) {
            throw "Missing Visual C++ runtime DLL: $source"
        }
        Copy-Item -LiteralPath $source -Destination (Join-Path $PackageRoot $dllName) -Force
    }

    Write-Host "Bundled Visual C++ runtime DLLs from $runtimeDir"
}

function Get-ReleaseEnvTemplate {
    $template = Get-Content (Join-Path $ServerDir ".env.example") -Raw
    $template = $template.Replace("PRODUCTION_MODE=false", "PRODUCTION_MODE=true")
    $template = $template.Replace("REQUIRE_DEVICE_AUTH=false", "REQUIRE_DEVICE_AUTH=true")
    $template = $template.Replace("ALLOW_STUB_MUSICXML=true", "ALLOW_STUB_MUSICXML=false")
    return $template
}

function Invoke-ServerWindowsExecutableBuild {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputDir
    )

    Bootstrap-Server

    $buildRoot = Join-Path $DistDir "pyinstaller-server"
    $workRoot = Join-Path $buildRoot "work"
    $specRoot = Join-Path $buildRoot "spec"
    Reset-Directory -Path $buildRoot
    New-Item -ItemType Directory -Path $workRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $specRoot -Force | Out-Null

    $pyInstallerArguments = @(
        "-m",
        "PyInstaller",
        "--noconfirm",
        "--clean",
        "--name",
        "azmusic-server",
        "--onefile",
        "--console",
        "--icon",
        $BrandIcon,
        "--distpath",
        $OutputDir,
        "--workpath",
        $workRoot,
        "--specpath",
        $specRoot,
        "--paths",
        $RepoRoot,
        "--hidden-import",
        "aiosqlite",
        "--hidden-import",
        "greenlet",
        "--hidden-import",
        "sqlalchemy.dialects.sqlite.aiosqlite",
        "--collect-all",
        "pypdfium2",
        (Join-Path $ServerDir "azmusic_server_entry.py")
    )
    Invoke-ServerPython -Arguments $pyInstallerArguments

    $serverExe = Join-Path $OutputDir "azmusic-server.exe"
    if (-not (Test-Path $serverExe)) {
        throw "PyInstaller completed without producing $serverExe"
    }
}

function Copy-PythonRuntimeNotice {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageRoot
    )

    $licensePath = & $ServerVenvPython -c "import pathlib, sys; print(pathlib.Path(sys.base_prefix) / 'LICENSE.txt')"
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($licensePath) -and (Test-Path $licensePath)) {
        Copy-Item -LiteralPath $licensePath -Destination (Join-Path $PackageRoot "PYTHON_RUNTIME_LICENSE.txt") -Force
    }
}

function Write-PythonDependencyNotices {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageRoot
    )

    $outputPath = Join-Path $PackageRoot "PYTHON_DEPENDENCY_LICENSES.md"
    & $ServerVenvPython -m piplicenses `
        --from=mixed `
        --format=markdown `
        --with-license-file `
        --output-file $outputPath

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Unable to generate Python dependency license report."
    }
}

function Write-ProcessingToolNotices {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageRoot
    )

    $notice = @"
# AZMusic Processing Tool Notices

AZMusic can call external processing tools, but this Windows server package does not bundle Audiveris, MuseScore Studio, Tesseract OCR, or HOMR.

The setup helper opens official download pages or uses Windows Package Manager (`winget`) so those tools remain separately installed applications with their own installers, licenses, and update channels.

## External Tools

| Tool | Purpose | License | Install Source |
| --- | --- | --- | --- |
| Audiveris | Optical music recognition / MusicXML generation | AGPL-3.0 | https://github.com/Audiveris/audiveris/releases |
| MuseScore Studio | MusicXML editing and PDF rendering | GPL-3.0 | https://musescore.org/en/download |
| Tesseract OCR | OCR text extraction | Apache-2.0 | https://tesseract-ocr.github.io/tessdoc/Installation.html |
| HOMR | Experimental optical music recognition / MusicXML generation | AGPL-3.0 | https://pypi.org/project/homr/ |

Before commercial or public distribution, review each upstream license and installer redistribution policy with project counsel. This package currently avoids redistributing the copyleft processing applications.
"@

    Set-Content -LiteralPath (Join-Path $PackageRoot "PROCESSING_TOOL_NOTICES.md") -Value $notice -Encoding utf8
}

function Invoke-ServerWindowsReleasePackage {
    $packageName = "AZMusic-server-windows-$ReleaseVersion"
    $stagingRoot = Join-Path $DistDir "staging"
    $packageRoot = Join-Path $stagingRoot $packageName
    $packageServerDir = Join-Path $packageRoot "server"
    $destinationZip = Join-Path $DistDir "$packageName.zip"
    $templateDir = Join-Path $RepoRoot "scripts\server-package"

    Reset-Directory -Path $packageRoot
    New-Item -ItemType Directory -Path $packageServerDir | Out-Null

    Copy-Item -Path (Join-Path $templateDir "*") -Destination $packageRoot -Recurse -Force
    Invoke-ServerWindowsExecutableBuild -OutputDir $packageRoot

    Copy-Item -LiteralPath (Join-Path $ServerDir "requirements.txt") -Destination $packageServerDir -Force
    Set-Content -LiteralPath (Join-Path $packageServerDir ".env.example") -Value (Get-ReleaseEnvTemplate) -Encoding utf8
    Copy-PythonRuntimeNotice -PackageRoot $packageRoot
    Write-PythonDependencyNotices -PackageRoot $packageRoot
    Write-ProcessingToolNotices -PackageRoot $packageRoot
    Compress-ReleaseFolder -SourceFolder $packageRoot -DestinationZip $destinationZip
}

function Invoke-ServerWindowsInstallerPackage {
    $serverZip = Join-Path $DistDir "AZMusic-server-windows-$ReleaseVersion.zip"
    if (-not (Test-Path $serverZip)) {
        Invoke-ServerWindowsReleasePackage
    }

    Bootstrap-Server

    $installerScript = Join-Path $RepoRoot "scripts\server-installer\azmusic_server_installer.py"
    if (-not (Test-Path $installerScript)) {
        throw "Missing server installer script: $installerScript"
    }

    $installerName = "AZMusic Server Setup"
    $installerExe = Join-Path $DistDir "$installerName.exe"
    $buildRoot = Join-Path $DistDir "pyinstaller-server-installer"
    $workRoot = Join-Path $buildRoot "work"
    $specRoot = Join-Path $buildRoot "spec"
    $outputRoot = Join-Path $buildRoot "out"
    Reset-Directory -Path $buildRoot
    New-Item -ItemType Directory -Path $workRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $specRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null

    if (Test-Path $installerExe) {
        Remove-Item -LiteralPath $installerExe -Force
    }

    $addData = "$serverZip;."
    $installerArguments = @(
        "-m",
        "PyInstaller",
        "--noconfirm",
        "--clean",
        "--name",
        $installerName,
        "--onefile",
        "--console",
        "--icon",
        $BrandIcon,
        "--distpath",
        $outputRoot,
        "--workpath",
        $workRoot,
        "--specpath",
        $specRoot,
        "--add-data",
        $addData,
        $installerScript
    )
    Invoke-ServerPython -Arguments $installerArguments

    $builtInstallerExe = Join-Path $outputRoot "$installerName.exe"
    if (-not (Test-Path $builtInstallerExe)) {
        throw "PyInstaller completed without producing $builtInstallerExe"
    }

    Copy-Item -LiteralPath $builtInstallerExe -Destination $installerExe -Force
    Write-Host "Created $installerExe"
}

function Invoke-ClientWindowsReleasePackage {
    $releaseDir = Join-Path $ClientBuildDir "windows\x64\runner\Release"
    if (-not (Test-Path (Join-Path $releaseDir "azmusic.exe"))) {
        Invoke-ClientWindowsReleaseBuild
    }

    $packageName = "AZMusic-windows-$ReleaseVersion"
    $stagingRoot = Join-Path $DistDir "staging"
    $packageRoot = Join-Path $stagingRoot $packageName
    $destinationZip = Join-Path $DistDir "$packageName.zip"

    Reset-Directory -Path $packageRoot
    Copy-Item -Path (Join-Path $releaseDir "*") -Destination $packageRoot -Recurse -Force
    Copy-ClientVcRuntimeDlls -PackageRoot $packageRoot
    Compress-ReleaseFolder -SourceFolder $packageRoot -DestinationZip $destinationZip
}

function Invoke-ClientWindowsInstallerPackage {
    $clientZip = Join-Path $DistDir "AZMusic-windows-$ReleaseVersion.zip"
    if (-not (Test-Path $clientZip)) {
        Invoke-ClientWindowsReleasePackage
    }

    Bootstrap-Server

    $installerScript = Join-Path $RepoRoot "scripts\client-installer\azmusic_client_installer.py"
    if (-not (Test-Path $installerScript)) {
        throw "Missing client installer script: $installerScript"
    }

    $installerName = "AZMusic Windows Client Setup"
    $installerExe = Join-Path $DistDir "$installerName.exe"
    $buildRoot = Join-Path $DistDir "pyinstaller-client-installer"
    $workRoot = Join-Path $buildRoot "work"
    $specRoot = Join-Path $buildRoot "spec"
    $outputRoot = Join-Path $buildRoot "out"
    Reset-Directory -Path $buildRoot
    New-Item -ItemType Directory -Path $workRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $specRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null

    if (Test-Path $installerExe) {
        Remove-Item -LiteralPath $installerExe -Force
    }

    $addData = "$clientZip;."
    $vcRedist = Ensure-ClientVcRuntimeInstaller
    $vcRedistAddData = "$vcRedist;."
    $installerArguments = @(
        "-m",
        "PyInstaller",
        "--noconfirm",
        "--clean",
        "--name",
        $installerName,
        "--onefile",
        "--console",
        "--icon",
        $BrandIcon,
        "--distpath",
        $outputRoot,
        "--workpath",
        $workRoot,
        "--specpath",
        $specRoot,
        "--add-data",
        $addData,
        "--add-data",
        $vcRedistAddData,
        $installerScript
    )
    Invoke-ServerPython -Arguments $installerArguments

    $builtInstallerExe = Join-Path $outputRoot "$installerName.exe"
    if (-not (Test-Path $builtInstallerExe)) {
        throw "PyInstaller completed without producing $builtInstallerExe"
    }

    Copy-Item -LiteralPath $builtInstallerExe -Destination $installerExe -Force
    Write-Host "Created $installerExe"
}

function Invoke-ClientAndroidApkPackage {
    $apkPath = Join-Path $ClientBuildDir "app\outputs\flutter-apk\app-release.apk"
    if (-not (Test-Path $apkPath)) {
        Invoke-ClientAndroidApkBuild
    }

    if (-not (Test-Path $DistDir)) {
        New-Item -ItemType Directory -Path $DistDir | Out-Null
    }

    $destinationApk = Join-Path $DistDir "AZMusic Android.apk"
    Copy-Item -LiteralPath $apkPath -Destination $destinationApk -Force
    Write-Host "Created $destinationApk"
}

function Invoke-ReleaseChecksums {
    if (-not (Test-Path $DistDir)) {
        throw "Missing dist directory. Package release assets first."
    }

    $assetNames = @(
        "AZMusic Android.apk",
        "AZMusic Server Setup.exe",
        "AZMusic Windows Client Setup.exe"
    )
    $assets = foreach ($assetName in $assetNames) {
        $assetPath = Join-Path $DistDir $assetName
        if (-not (Test-Path $assetPath)) {
            throw "Missing end-user release asset: $assetPath"
        }
        Get-Item -LiteralPath $assetPath
    }

    if ($assets.Count -eq 0) {
        throw "No release assets found for $ReleaseVersion."
    }

    $lines = foreach ($asset in $assets) {
        $hash = Get-FileHash -Algorithm SHA256 -LiteralPath $asset.FullName
        "{0}  {1}" -f $hash.Hash.ToLowerInvariant(), $asset.Name
    }

    $checksumPath = Join-Path $DistDir "SHA256SUMS.txt"
    Set-Content -LiteralPath $checksumPath -Value $lines -Encoding utf8
    Write-Host "Created $checksumPath"
}

function Remove-InternalReleaseArtifacts {
    foreach ($fileName in @(
        "AZMusic-server-windows-$ReleaseVersion.zip",
        "AZMusic-windows-$ReleaseVersion.zip",
        "AZMusic-server-installer-windows-$ReleaseVersion.exe",
        "AZMusic-client-installer-windows-$ReleaseVersion.exe",
        "AZMusic-android-$ReleaseVersion.apk"
    )) {
        $path = Join-Path $DistDir $fileName
        if (Test-Path $path) {
            Remove-Item -LiteralPath $path -Force
        }
    }

    foreach ($directoryName in @(
        "pyinstaller-client-installer",
        "pyinstaller-server",
        "pyinstaller-server-installer",
        "staging",
        "windows-sandbox"
    )) {
        $path = Join-Path $DistDir $directoryName
        if (Test-Path $path) {
            Remove-Item -LiteralPath $path -Recurse -Force
        }
    }
}

function Invoke-ReleaseAssetPackage {
    Invoke-ClientWindowsReleaseBuild
    Invoke-ClientAndroidApkBuild
    Invoke-ServerWindowsReleasePackage
    Invoke-ServerWindowsInstallerPackage
    Invoke-ClientWindowsReleasePackage
    Invoke-ClientWindowsInstallerPackage
    Invoke-ClientAndroidApkPackage
    Remove-InternalReleaseArtifacts
    Invoke-ReleaseChecksums
}

switch ($Task) {
    "bootstrap" {
        Bootstrap-Server
        Bootstrap-Client
    }

    "bootstrap-server" {
        Bootstrap-Server
    }

    "bootstrap-client" {
        Bootstrap-Client
    }

    "run-server" {
        Ensure-ServerEnvFile
        Invoke-ServerPython -m uvicorn server.main:app --host 0.0.0.0 --port 8795 --app-dir $RepoRoot
    }

    "lint-server" {
        Invoke-ServerCompile
        Invoke-ServerPython -m ruff check server
    }

    "test-server" {
        Invoke-ServerPython -m pytest
    }

    "check-server" {
        Invoke-ServerCompile
        Invoke-ServerPython -m pytest
    }

    "run-client" {
        $device = if ([string]::IsNullOrWhiteSpace($ClientDevice)) { "windows" } else { $ClientDevice }
        $clientArguments = @("run", "-d", $device) + (Get-ClientRuntimeDartDefines)
        Invoke-Flutter -Arguments $clientArguments
    }

    "run-client-sandbox" {
        $device = if ([string]::IsNullOrWhiteSpace($ClientDevice)) { "windows" } else { $ClientDevice }
        $resetFlag = if ($ResetSandboxOnLaunch.IsPresent) { "true" } else { "false" }
        $clientArguments = @(
            "run",
            "-d",
            $device,
            "-t",
            "lib/main_sandbox.dart",
            "--dart-define=AZMUSIC_SANDBOX_SURFACE=$SandboxSurface",
            "--dart-define=AZMUSIC_RESET_SANDBOX_ON_LAUNCH=$resetFlag"
        ) + (Get-ClientRuntimeDartDefines)
        Invoke-Flutter -Arguments $clientArguments
    }

    "smoke-client-windows-pdf" {
        Invoke-ClientWindowsPdfSmoke
    }

    "run-client-android" {
        $device = if ([string]::IsNullOrWhiteSpace($ClientDevice)) { "android" } else { $ClientDevice }
        Invoke-Flutter -Arguments @("run", "-d", $device)
    }

    "lint-client" {
        Invoke-Flutter analyze
    }

    "test-client" {
        Invoke-Flutter test --no-pub --no-test-assets --no-dds -r expanded
    }

    "check-client" {
        Invoke-ClientCheck
    }

    "check-client-windows" {
        Invoke-ClientWindowsCheck
    }

    "build-client-windows-release" {
        Invoke-ClientWindowsReleaseBuild
    }

    "build-client-android-apk" {
        Invoke-ClientAndroidApkBuild
    }

    "build-client-android-aab" {
        Invoke-ClientAndroidAppBundleBuild
    }

    "package-server-windows-release" {
        Invoke-ServerWindowsReleasePackage
    }

    "package-server-windows-installer" {
        Invoke-ServerWindowsInstallerPackage
    }

    "package-client-windows-release" {
        Invoke-ClientWindowsReleasePackage
    }

    "package-client-windows-installer" {
        Invoke-ClientWindowsInstallerPackage
    }

    "package-client-android-apk" {
        Invoke-ClientAndroidApkPackage
    }

    "package-release-assets" {
        Invoke-ReleaseAssetPackage
    }

    "check" {
        Invoke-ServerCompile
        Invoke-ServerPython -m pytest
        Invoke-ClientWindowsCheck
    }

    "clean" {
        Clean-ClientBuildState
        Invoke-Flutter clean
    }
}

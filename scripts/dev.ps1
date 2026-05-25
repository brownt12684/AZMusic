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
        "check",
        "clean"
    )]
    [string]$Task,

    [string]$ClientDevice,

    [string]$ClientServerHost,

    [string]$ClientServerPort,

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
$LocalFlutter = Join-Path $RepoRoot ".tooling\\flutter\\bin\\flutter.bat"
$ClientHooksDir = Join-Path $ClientDir ".dart_tool\\hooks_runner"
$ClientBuildDir = Join-Path $ClientDir "build"
$ServerVenvPython = Join-Path $ServerDir ".venv\\Scripts\\python.exe"

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
    return @("--dart-define=AZMUSIC_PRODUCTION=true") + (Get-ClientRuntimeDartDefines)
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
        Invoke-ServerPython -m uvicorn server.main:app --host 0.0.0.0 --port 8000 --app-dir $RepoRoot
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

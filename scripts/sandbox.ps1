param(
    [ValidateSet(
        "bootstrap",
        "server-e2e",
        "fixtures",
        "client-check",
        "full"
    )]
    [string]$Mode = "full",
    [switch]$Clean
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $true
}

$ScriptDir = $PSScriptRoot
$RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $ScriptDir ".."))
$ServerDir = Join-Path $RepoRoot "server"
$ClientDir = Join-Path $RepoRoot "client"
$SandboxDir = Join-Path $RepoRoot "sandbox"
$FixtureDir = Join-Path $SandboxDir "fixtures"

$PASS = "[PASS]"
$FAIL = "[FAIL]"
$INFO = "[INFO]"

function Write-Step {
    param([string]$Message)
    Write-Host "`n=== $Message ===" -ForegroundColor Cyan
}

function Write-Result {
    param(
        [string]$Name,
        [bool]$Success,
        [string]$Detail = ""
    )
    $color = if ($Success) { "Green" } else { "Red" }
    $tag = if ($Success) { $PASS } else { $FAIL }
    Write-Host "$tag $Name" -ForegroundColor $color
    if ($Detail) {
        Write-Host "       $Detail" -ForegroundColor DarkGray
    }
}

function Invoke-SandboxBootstrap {
    Write-Step "Bootstrap Sandbox"

    if (-not (Test-Path $ScriptDir\dev.ps1)) {
        Write-Result "dev.ps1 entry point" $false "Not found at $ScriptDir\dev.ps1"
        return $false
    }

    if (-not (Test-Path $RepoRoot\server\main.py)) {
        Write-Result "server entry point" $false "Not found at $RepoRoot\server\main.py"
        return $false
    }

    if (-not (Test-Path $RepoRoot\client\lib\main.dart)) {
        Write-Result "client entry point" $false "Not found at $RepoRoot\client\lib\main.dart"
        return $false
    }

    Write-Host "$INFO Repository structure verified at $RepoRoot" -ForegroundColor Gray
    return $true
}

function Invoke-ServerE2E {
    Write-Step "Server E2E Tests"

    $result = & $ScriptDir\run-server-e2e.ps1 -RepoRoot $RepoRoot -ErrorAction SilentlyContinue
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-Result "Server e2e suite" $true "All server tests passed"
        return $true
    } else {
        Write-Result "Server e2e suite" $false "Exit code $exitCode"
        return $false
    }
}

function Invoke-FixtureGeneration {
    Write-Step "Generate Test Fixtures"

    if (-not (Test-Path $ScriptDir\create-test-fixture.ps1)) {
        Write-Result "create-test-fixture.ps1" $false "Script not found"
        return $false
    }

    $result = & $ScriptDir\create-test-fixture.ps1 -OutputDir $FixtureDir -ErrorAction SilentlyContinue
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-Result "Fixture generation" $true "Fixtures written to $FixtureDir"
        return $true
    } else {
        Write-Result "Fixture generation" $false "Exit code $exitCode"
        return $false
    }
}

function Invoke-ClientCheck {
    Write-Step "Client Check (lint + test)"

    $pythonPath = if (Test-Path (Join-Path $ServerDir ".venv\Scripts\python.exe")) {
        Join-Path $ServerDir ".venv\Scripts\python.exe"
    } else {
        "python"
    }

    $compileResult = & $pythonPath -m compileall -q $ServerDir 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Result "Server compile" $false "compileall failed"
        return $false
    }
    Write-Result "Server compile" $true ""

    $testResult = & $pythonPath -m pytest $ServerDir\tests -v --tb=short 2>&1
    $testExit = $LASTEXITCODE

    if ($testExit -eq 0) {
        Write-Result "Server pytest" $true "All tests passed"
    } else {
        Write-Result "Server pytest" $false "Exit code $testExit"
        return $false
    }

    if (Test-Path $ScriptDir\dev.ps1) {
        $stdoutPath = [System.IO.Path]::GetTempFileName()
        $stderrPath = [System.IO.Path]::GetTempFileName()
        try {
            $devProcess = Start-Process -FilePath powershell `
                -ArgumentList @(
                    '-NoProfile',
                    '-ExecutionPolicy',
                    'Bypass',
                    '-File',
                    (Join-Path $ScriptDir 'dev.ps1'),
                    '-Task',
                    'check-client'
                ) `
                -Wait `
                -PassThru `
                -RedirectStandardOutput $stdoutPath `
                -RedirectStandardError $stderrPath

            if ($devProcess.ExitCode -eq 0) {
                Write-Result "Client check (lint+test)" $true ""
            } else {
                $stdout = if (Test-Path $stdoutPath) { Get-Content $stdoutPath -Raw } else { '' }
                $stderr = if (Test-Path $stderrPath) { Get-Content $stderrPath -Raw } else { '' }
                if ($stdout) {
                    Write-Host $stdout
                }
                if ($stderr) {
                    Write-Host $stderr
                }
                Write-Result "Client check (lint+test)" $false "Exit code $($devProcess.ExitCode)"
            }
        }
        finally {
            foreach ($path in @($stdoutPath, $stderrPath)) {
                if (Test-Path $path) {
                    Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
                }
            }
        }
    } else {
        Write-Result "Client check (lint+test)" $false "dev.ps1 not available"
    }

    return $testExit -eq 0
}

function Invoke-FullSandbox {
    $results = @{
        bootstrap     = $false
        serverE2E     = $false
        fixtures      = $false
        clientCheck   = $false
    }

    $results.bootstrap = Invoke-SandboxBootstrap
    if (-not $results.bootstrap) {
        Write-Host "`n$FAIL Bootstrap failed. Aborting sandbox." -ForegroundColor Red
        return $results
    }

    $results.serverE2E = Invoke-ServerE2E
    $results.fixtures  = Invoke-FixtureGeneration
    $results.clientCheck = Invoke-ClientCheck

    return $results
}

function Write-Summary {
    param([hashtable]$Results)

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  Sandbox Summary" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    $allPassed = $true
    foreach ($key in $Results.Keys) {
        $label = $key -replace "^([a-z])", { $args[0].Groups[1].Value.ToUpper() }
        $label = $label -replace "([A-Z])", " $1" -replace "^ "
        $status = if ($Results[$key]) { "PASS" } else { "FAIL" }
        $color = if ($Results[$key]) { "Green" } else { "Red" }
        if (-not $Results[$key]) { $allPassed = $false }
        Write-Host "  $label : $status" -ForegroundColor $color
    }

    Write-Host "========================================" -ForegroundColor Cyan
    $overall = if ($allPassed) { "ALL PASSED" } else { "SOME FAILED" }
    $overallColor = if ($allPassed) { "Green" } else { "Red" }
    Write-Host "  Overall: $overall" -ForegroundColor $overallColor
    Write-Host "========================================`n" -ForegroundColor Cyan

    return $allPassed
}

# Clean mode
if ($Clean) {
    Write-Step "Clean Sandbox Artifacts"
    function Remove-IfPresent {
        param([string]$p)
        if (Test-Path $p) { Remove-Item -LiteralPath $p -Recurse -Force }
    }
    if (Test-Path $SandboxDir) {
        Remove-Item -LiteralPath $SandboxDir -Recurse -Force
        Write-Host "$INFO Removed sandbox directory" -ForegroundColor Gray
    }
    if (Test-Path (Join-Path $ServerDir "storage")) {
        Remove-Item -LiteralPath (Join-Path $ServerDir "storage") -Recurse -Force
        Write-Host "$INFO Removed server storage" -ForegroundColor Gray
    }
    exit 0
}

# Main execution
$success = switch ($Mode) {
    "bootstrap" { Invoke-SandboxBootstrap }
    "server-e2e" { Invoke-ServerE2E }
    "fixtures" { Invoke-FixtureGeneration }
    "client-check" { Invoke-ClientCheck }
    "full" {
        $results = Invoke-FullSandbox
        Write-Summary -Results $results
        $all = $results.Values | Where-Object { $_ }
        return ($all.Count -eq $results.Count)
    }
    default {
        Write-Host "Unknown mode: $Mode" -ForegroundColor Red
        exit 1
    }
}

if ($success -eq $false -and $Mode -ne "full") {
    exit 1
}

<#
.SYNOPSIS
    Run the AZMusic server e2e test suite with structured output.
.DESCRIPTION
    Invokes pytest against the server test suite with an in-memory database
    override, captures pass/fail counts, and returns a structured JSON
    summary to stdout for the sandbox orchestrator.
.PARAMETER RepoRoot
    Absolute path to the AZMusic monorepo root.
.PARAMETER Verbose
    Emit per-test detail lines to stderr.
#>
param(
    [string]$RepoRoot,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $true
}

if (-not $RepoRoot) {
    $RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
}

$ServerDir = Join-Path $RepoRoot "server"
$TestDir = Join-Path $ServerDir "tests"

$PASS = "[PASS]"
$FAIL = "[FAIL]"
$INFO = "[INFO]"

function Write-Step {
    param([string]$Message)
    Write-Host "`n--- $Message ---" -ForegroundColor Cyan
}

function Get-ServerPython {
    $venvPython = Join-Path $ServerDir ".venv\Scripts\python.exe"
    if (Test-Path $venvPython) {
        return $venvPython
    }
    Assert-Command "python" "Install Python 3.11+ and add it to PATH."
    return "python"
}

function Assert-Command {
    param([string]$Name, [string]$InstallHint)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Missing required command '$Name'. $InstallHint"
    }
}

# Pre-flight checks
Write-Step "Pre-flight checks"

if (-not (Test-Path $TestDir)) {
    Write-Host "$FAIL Test directory not found: $TestDir" -ForegroundColor Red
    exit 1
}

$python = Get-ServerPython
Write-Host "$INFO Using Python: $python" -ForegroundColor Gray

# Verify required test files exist
$requiredTests = @("test_health.py", "test_api_smoke.py")
$missingTests = @()
foreach ($t in $requiredTests) {
    if (-not (Test-Path (Join-Path $TestDir $t))) {
        $missingTests += $t
    }
}

if ($missingTests.Count -gt 0) {
    Write-Host "$FAIL Missing required test files: $($missingTests -join ', ')" -ForegroundColor Red
    exit 1
}

Write-Host "$INFO All required test files present" -ForegroundColor Gray

# Run pytest with structured output
Write-Step "Running server e2e tests"

$envVars = @{
    "AZMUSIC_DATABASE_URL" = "sqlite+aiosqlite:///:memory:"
}

$pytestArgs = @(
    "-m", "pytest",
    $TestDir,
    "-v",
    "--tb=short",
    "--no-header",
    "--disable-warnings"
)

$fullOutput = & $python @pytestArgs 2>&1
$exitCode = $LASTEXITCODE

# Parse results
$passedCount = 0
$failedCount = 0
$skippedCount = 0
$testLines = @()

foreach ($line in $fullOutput) {
    if ($Verbose) {
        Write-Host $line -ForegroundColor DarkGray
    }
    if ($line -match "(\d+) passed") {
        $passedCount = [int]$Matches[1]
    }
    if ($line -match "(\d+) failed") {
        $failedCount = [int]$Matches[1]
    }
    if ($line -match "(\d+) skipped") {
        $skippedCount = [int]$Matches[1]
    }
    if ($line -match "^.*::test_.* (PASSED|FAILED|SKIPPED)") {
        $testLines += $line.Trim()
    }
}

# If pytest regex didn't capture counts, count from output directly
if ($passedCount -eq 0 -and $failedCount -eq 0) {
    foreach ($line in $fullOutput) {
        if ($line -match "PASSED") { $passedCount++ }
        if ($line -match "FAILED") { $failedCount++ }
        if ($line -match "SKIPPED") { $skippedCount++ }
    }
}

# Write structured summary to stdout
$summary = @{
    status     = if ($exitCode -eq 0) { "passed" } else { "failed" }
    passed     = $passedCount
    failed     = $failedCount
    skipped    = $skippedCount
    total      = $passedCount + $failedCount + $skippedCount
    test_files = $requiredTests
    python     = $python
    repo_root  = $RepoRoot
}

Write-Host "`n--- Results ---" -ForegroundColor Cyan
foreach ($t in $testLines) {
    if ($t -match "PASSED") {
        Write-Host "$PASS $t" -ForegroundColor Green
    } elseif ($t -match "FAILED") {
        Write-Host "$FAIL $t" -ForegroundColor Red
    } else {
        Write-Host "SKIP $t" -ForegroundColor Yellow
    }
}

Write-Host "`n  Total: $($summary.total)  Passed: $($summary.passed)  Failed: $($summary.failed)  Skipped: $($summary.skipped)" -ForegroundColor White
Write-Host "  Status: $($summary.status)" -ForegroundColor $(if ($summary.status -eq "passed") { "Green" } else { "Red" })

# Output JSON summary for orchestrator consumption
Write-Host "`n$(ConvertTo-Json $summary -Depth 4)" -ForegroundColor DarkGray

exit $exitCode

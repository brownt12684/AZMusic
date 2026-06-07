param(
    [string]$ResultsDir = (Join-Path $PSScriptRoot "..\..\sandbox-results\windows-sandbox"),
    [int]$Tail = 80
)

$ErrorActionPreference = "Stop"

if ([System.IO.Path]::IsPathRooted($ResultsDir)) {
    $resolvedResultsDir = [System.IO.Path]::GetFullPath($ResultsDir)
} else {
    $resolvedResultsDir = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $ResultsDir))
}
$latestPath = Join-Path $resolvedResultsDir "latest.json"

if (-not (Test-Path -LiteralPath $latestPath)) {
    Write-Host "No sandbox result has been written yet."
    Write-Host "Expected: $latestPath"
    exit 1
}

$latest = Get-Content -LiteralPath $latestPath -Raw | ConvertFrom-Json
$runDir = $latest.run_dir
if ($runDir -like "C:\AZMusicSandboxResults*") {
    $relativeRunDir = $runDir.Substring("C:\AZMusicSandboxResults".Length).TrimStart("\")
    $runDir = Join-Path $resolvedResultsDir $relativeRunDir
}

Write-Host "Run: $($latest.run_id)"
Write-Host "Status: $($latest.status)"
Write-Host "Step: $($latest.step)"
Write-Host "Updated: $($latest.updated_at)"

if ($latest.error) {
    Write-Host ""
    Write-Host "Error:"
    Write-Host $latest.error
}

if ($latest.details) {
    Write-Host ""
    Write-Host "Details:"
    $latest.details.PSObject.Properties | ForEach-Object {
        Write-Host ("- {0}: {1}" -f $_.Name, ($_.Value | ConvertTo-Json -Compress))
    }
}

$transcript = Join-Path $runDir "transcript.log"
if (Test-Path -LiteralPath $transcript) {
    Write-Host ""
    Write-Host "Transcript tail ($Tail lines):"
    Get-Content -LiteralPath $transcript -Tail $Tail
}

foreach ($logName in @("server_stderr.log", "server_stdout.log")) {
    $logPath = Join-Path $runDir $logName
    if (Test-Path -LiteralPath $logPath) {
        Write-Host ""
        Write-Host "$logName tail ($Tail lines):"
        Get-Content -LiteralPath $logPath -Tail $Tail
    }
}

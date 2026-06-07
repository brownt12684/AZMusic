param(
    [string]$BaseUrl = "http://127.0.0.1:8795",
    [string]$StoragePath = "server\storage",
    [int]$IntervalSeconds = 3,
    [string]$LogPath = "server\processing-watch.log",
    [switch]$Once
)

$ErrorActionPreference = "Continue"

function Write-WatchLog {
    param([string]$Message)

    $timestamp = (Get-Date).ToString("s")
    $line = "[$timestamp] $Message"
    Write-Host $line
    $logDirectory = Split-Path -Parent $LogPath
    if (-not [string]::IsNullOrWhiteSpace($logDirectory)) {
        New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
    }
    Add-Content -LiteralPath $LogPath -Value $line
}

function Invoke-Json {
    param([string]$Uri)

    try {
        return Invoke-RestMethod -Uri $Uri -TimeoutSec 4
    }
    catch {
        return @{
            error = $_.Exception.Message
        }
    }
}

function Get-ReviewPdfSnapshot {
    if (-not (Test-Path $StoragePath)) {
        return @()
    }

    Get-ChildItem -LiteralPath $StoragePath -Recurse -Filter "candidate_review.pdf" |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 20 |
        ForEach-Object {
            $header = ""
            try {
                $stream = [System.IO.File]::OpenRead($_.FullName)
                try {
                    $buffer = New-Object byte[] ([Math]::Min(5, $stream.Length))
                    [void]$stream.Read($buffer, 0, $buffer.Length)
                    $header = [System.Text.Encoding]::ASCII.GetString($buffer)
                }
                finally {
                    $stream.Dispose()
                }
            }
            catch {
                $header = "unreadable"
            }

            [pscustomobject]@{
                path = $_.FullName
                bytes = $_.Length
                last_write_utc = $_.LastWriteTimeUtc.ToString("s")
                looks_like_pdf = $header.StartsWith("%PDF-")
            }
        }
}

function Get-WatchSnapshot {
    $jobs = Invoke-Json "$BaseUrl/api/v1/jobs/"
    $reviews = Invoke-Json "$BaseUrl/api/v1/review/"
    $capabilities = Invoke-Json "$BaseUrl/api/v1/processing/capabilities"
    $health = Invoke-Json "$BaseUrl/health"

    return [pscustomobject]@{
        health = $health
        capabilities = $capabilities
        jobs = $jobs
        reviews = $reviews
        review_pdfs = @(Get-ReviewPdfSnapshot)
    }
}

Write-WatchLog "Starting AZMusic processing watcher for $BaseUrl"
$resolvedStoragePath = Resolve-Path -LiteralPath $StoragePath -ErrorAction SilentlyContinue
if ($null -eq $resolvedStoragePath) {
    Write-WatchLog "Storage: $StoragePath"
} else {
    Write-WatchLog "Storage: $resolvedStoragePath"
}

$lastSnapshotJson = ""
do {
    $snapshot = Get-WatchSnapshot
    $snapshotJson = $snapshot | ConvertTo-Json -Depth 10 -Compress
    if ($snapshotJson -ne $lastSnapshotJson) {
        Write-WatchLog $snapshotJson
        $lastSnapshotJson = $snapshotJson
    }

    if (-not $Once.IsPresent) {
        Start-Sleep -Seconds $IntervalSeconds
    }
} while (-not $Once.IsPresent)

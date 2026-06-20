# Kill all Python processes
$pyProcesses = Get-Process -Name python -ErrorAction SilentlyContinue
if ($pyProcesses) {
    foreach ($p in $pyProcesses) {
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
        Write-Host "Killed PID $($p.Id)"
    }
} else {
    Write-Host "No Python processes found"
}

# Wait for file locks to release
Start-Sleep -Seconds 3

# Delete database files
$dbFiles = @(
    'C:/Projects/AZMusic/server/azmusic_server.db',
    'C:/Projects/AZMusic/server/azmusic_server.db-wal',
    'C:/Projects/AZMusic/server/azmusic_server.db-shm'
)

foreach ($f in $dbFiles) {
    if (Test-Path $f) {
        Remove-Item $f -Force -ErrorAction SilentlyContinue
        Write-Host "Deleted: $f"
    } else {
        Write-Host "Not found: $f"
    }
}

# Verify
if (Test-Path 'C:/Projects/AZMusic/server/azmusic_server.db') {
    Write-Host "`nDB still exists - check for file locks"
} else {
    Write-Host "`nDB deleted successfully"
}

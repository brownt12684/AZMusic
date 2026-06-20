$connections = Get-NetTCPConnection -LocalPort 8795 -State Listen -ErrorAction SilentlyContinue
if ($connections) {
    $pids = $connections | Select-Object -ExpandProperty OwningProcess | Sort-Object -Unique
    foreach ($p in $pids) {
        Stop-Process -Id $p -Force -ErrorAction SilentlyContinue
        Write-Host "Killed PID $p"
    }
} else {
    Write-Host "No server process found on port 8795"
}

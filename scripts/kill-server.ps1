$port = 8795
$lines = netstat -ano | Select-String ":${port} "
Write-Host "Connections on port ${port}:"
$lines | ForEach-Object { Write-Host $_ }

if ($lines) {
    $targetPids = @()
    foreach ($line in $lines) {
        $parts = $line -split '\s+'
        if ($parts.Count -ge 5) {
            $procId = $parts[$($parts.Count - 1)]
            if ($procId -match '^\d+$') {
                $targetPids += $procId
            }
        }
    }
    $uniqueIds = $targetPids | Sort-Object -Unique
    Write-Host "`nKilling PIDs: $($uniqueIds -join ', ')"
    foreach ($id in $uniqueIds) {
        taskkill //F //PID $id 2>$null
    }
}

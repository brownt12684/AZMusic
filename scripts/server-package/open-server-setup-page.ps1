param(
    [int]$Port = 8795,
    [string]$HostName = "localhost"
)

$setupUrl = "http://${HostName}:$Port/setup"
Write-Host "Opening $setupUrl"
Start-Process $setupUrl

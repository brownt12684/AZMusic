param(
    [int]$Port = 8795,
    [string]$HostAddress = "0.0.0.0"
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$PackageRoot = $PSScriptRoot
$ServerDir = Join-Path $PackageRoot "server"
$ServerExe = Join-Path $PackageRoot "azmusic-server.exe"
$EnvFile = Join-Path $ServerDir ".env"

function Get-PortOwner {
    param([int]$CandidatePort)

    try {
        $connection = Get-NetTCPConnection -LocalPort $CandidatePort -State Listen -ErrorAction Stop |
            Select-Object -First 1
        if ($null -eq $connection) {
            return $null
        }
        $process = Get-Process -Id $connection.OwningProcess -ErrorAction SilentlyContinue
        if ($null -eq $process) {
            return "PID $($connection.OwningProcess)"
        }
        if ($process.Path) {
            return "$($process.ProcessName) ($($process.Path))"
        }
        return "$($process.ProcessName) (PID $($connection.OwningProcess))"
    }
    catch {
        return $null
    }
}

function Select-ServerPort {
    param([int]$PreferredPort)

    for ($candidate = $PreferredPort; $candidate -le ($PreferredPort + 20); $candidate++) {
        $owner = Get-PortOwner -CandidatePort $candidate
        if (-not $owner) {
            if ($candidate -ne $PreferredPort) {
                Write-Host "Port $PreferredPort is already in use. Starting AZMusic Server on port $candidate instead." -ForegroundColor Yellow
            }
            return $candidate
        }
        if ($candidate -eq $PreferredPort) {
            Write-Host "Port $PreferredPort is already in use by $owner." -ForegroundColor Yellow
        }
    }

    throw "No available AZMusic server port was found from $PreferredPort through $($PreferredPort + 20). Close the app using port $PreferredPort or run this script with -Port <open port>."
}

if (-not (Test-Path $ServerExe)) {
    & (Join-Path $PackageRoot "setup-azmusic-server.ps1")
}

if (-not (Test-Path $EnvFile)) {
    & (Join-Path $PackageRoot "setup-azmusic-server.ps1") -SkipDependencyInstall
}

$Port = Select-ServerPort -PreferredPort $Port
& (Join-Path $PackageRoot "enable-azmusic-firewall.ps1") -Port $Port

Write-Host "Starting AZMusic server on http://localhost:$Port"
Write-Host "Open http://localhost:$Port/setup to pair the parent/admin device."
try {
    $addresses = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
        Where-Object {
            $_.IPAddress -notlike "127.*" -and
            $_.IPAddress -notlike "169.254.*" -and
            $_.PrefixOrigin -ne "WellKnown"
        } |
        Sort-Object InterfaceMetric |
        Select-Object -ExpandProperty IPAddress -Unique
    foreach ($address in $addresses) {
        Write-Host "LAN setup URL: http://${address}:$Port/setup"
    }
}
catch {
    Write-Host "LAN setup URLs will also be shown on the setup page."
}
Write-Host "Keep this window open while clients are using the server."

Push-Location $PackageRoot
try {
    & $ServerExe --host $HostAddress --port $Port
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
finally {
    Pop-Location
}

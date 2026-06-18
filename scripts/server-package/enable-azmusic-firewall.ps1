param(
    [int]$Port = 8795
)

$ErrorActionPreference = "Stop"

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Get-Command New-NetFirewallRule -ErrorAction SilentlyContinue)) {
    Write-Warning "Windows firewall cmdlets are unavailable. If pairing times out, allow inbound TCP port $Port manually."
    return
}

if (-not (Test-Administrator)) {
    Write-Warning "Run setup/start as Administrator to add the AZMusic firewall rule automatically. If pairing times out, allow inbound TCP port $Port manually."
    return
}

$displayName = "AZMusic Server (TCP $Port)"
try {
    $existing = Get-NetFirewallRule -DisplayName $displayName -ErrorAction SilentlyContinue
    if ($existing) {
        Set-NetFirewallRule -DisplayName $displayName -Enabled True -Action Allow | Out-Null
        Write-Host "Verified Windows Firewall rule: $displayName"
        return
    }

    New-NetFirewallRule `
        -DisplayName $displayName `
        -Direction Inbound `
        -Action Allow `
        -Protocol TCP `
        -LocalPort $Port `
        -Profile Domain,Private `
        | Out-Null

    Write-Host "Added Windows Firewall rule: $displayName"
}
catch {
    Write-Warning "Unable to configure the Windows Firewall rule automatically: $($_.Exception.Message)"
    Write-Warning "If pairing times out from another device, allow inbound TCP port $Port manually."
}

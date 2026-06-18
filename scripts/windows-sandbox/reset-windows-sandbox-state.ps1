<#
.SYNOPSIS
    Reset stuck Windows Sandbox/Hyper-V worker state before release smoke tests.
.DESCRIPTION
    Windows Sandbox can leave vmwp.exe workers behind after host crashes or
    interrupted sandbox sessions. Those workers can prevent a fresh .wsb launch
    from producing a new smoke-test result. This script requires an elevated
    shell because Host Compute Service and Hyper-V worker control are admin-only.
#>
param(
    [switch]$RestartServices,
    [string]$LogPath
)

$ErrorActionPreference = "Stop"

if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
    $logDirectory = Split-Path -Parent $LogPath
    if (-not [string]::IsNullOrWhiteSpace($logDirectory)) {
        New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    }
    Start-Transcript -LiteralPath $LogPath -Force | Out-Null
}

try {

function Assert-Elevated {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Run this script from an elevated PowerShell session."
    }
}

function Stop-ProcessByName {
    param([string[]]$Names)

    foreach ($name in $Names) {
        Get-Process -Name $name -ErrorAction SilentlyContinue |
            ForEach-Object {
                Write-Host "Stopping $($_.ProcessName) pid=$($_.Id)"
                Stop-Process -Id $_.Id -Force -ErrorAction Stop
            }
    }
}

Assert-Elevated

Stop-ProcessByName -Names @("WindowsSandbox", "WindowsSandboxClient", "WindowsSandboxRemoteSession")
Stop-ProcessByName -Names @("vmwp")

if ($RestartServices.IsPresent) {
    foreach ($serviceName in @("vmcompute", "hns")) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($null -eq $service) {
            continue
        }

        Write-Host "Restarting service $serviceName"
        Restart-Service -Name $serviceName -Force -ErrorAction Stop
    }
}

$remaining = Get-Process -Name "WindowsSandbox", "WindowsSandboxClient", "vmwp" -ErrorAction SilentlyContinue
if ($remaining) {
    $summary = ($remaining | ForEach-Object { "$($_.ProcessName):$($_.Id)" }) -join ", "
    throw "Sandbox reset incomplete. Remaining processes: $summary"
}

Write-Host "Windows Sandbox state reset complete."
}
finally {
    if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
        Stop-Transcript | Out-Null
    }
}

<#
.SYNOPSIS
    Enable Microsoft Windows Sandbox on this machine.
.DESCRIPTION
    Windows Sandbox is an optional Windows feature. Enabling it requires
    Administrator privileges and usually requires a reboot before .wsb files
    can launch.
#>

$ErrorActionPreference = "Stop"

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Start-Process powershell.exe `
        -Verb RunAs `
        -ArgumentList @(
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            "`"$PSCommandPath`""
        )
    return
}

$feature = Get-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM
if ($feature.State -eq "Enabled") {
    Write-Host "Windows Sandbox is already enabled."
    return
}

Enable-WindowsOptionalFeature `
    -Online `
    -FeatureName Containers-DisposableClientVM `
    -All `
    -NoRestart

Write-Host ""
Write-Host "Windows Sandbox has been enabled. Reboot Windows before launching the AZMusic sandbox."

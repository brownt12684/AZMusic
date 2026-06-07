<#
.SYNOPSIS
    Launch a clean Microsoft Windows Sandbox for AZMusic release validation.
.DESCRIPTION
    Generates a .wsb file that mounts the current dist folder and the
    sandbox-side helper scripts. The sandbox starts with shortcuts for running
    an installer-based smoke test and opening the installed Windows client.
#>
param(
    [string]$ReleaseVersion = "v0.2.0",
    [switch]$RefreshServerPackage,
    [switch]$RefreshClientPackage,
    [switch]$UseExistingPackages,
    [switch]$NoAutoSmoke
)

$ErrorActionPreference = "Stop"

$RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$DistDir = Join-Path $RepoRoot "dist"
$DevScript = Join-Path $RepoRoot "scripts\dev.ps1"
$SandboxScriptsDir = Join-Path $RepoRoot "scripts\windows-sandbox"
$GeneratedDir = Join-Path $DistDir "windows-sandbox"
$ResultsDir = Join-Path $RepoRoot "sandbox-results\windows-sandbox"
$WsbPath = Join-Path $GeneratedDir ("AZMusicReleaseSandbox-{0}.wsb" -f (Get-Date -Format "yyyyMMdd-HHmmss"))

function Escape-Xml {
    param([string]$Value)
    return [System.Security.SecurityElement]::Escape($Value)
}

function Assert-WindowsSandboxEnabled {
    $sandboxCommand = Get-Command WindowsSandbox.exe -ErrorAction SilentlyContinue
    if ($null -ne $sandboxCommand) {
        return
    }

    try {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM
        $featureState = $feature.State
    }
    catch {
        $featureState = "unknown; feature query requires elevation"
    }

    Write-Host "Windows Sandbox is not enabled on this machine." -ForegroundColor Yellow
    Write-Host "Run this once, then reboot:" -ForegroundColor Yellow
    Write-Host "  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows-sandbox\enable-windows-sandbox.ps1" -ForegroundColor White
    throw "Windows Sandbox feature state is $featureState."
}

function Ensure-WindowsSandboxFileAssociation {
    $extensionKey = "HKCU:\Software\Classes\.wsb"
    $classKey = "HKCU:\Software\Classes\Windows.Sandbox\shell\open\command"
    $sandboxExe = (Get-Command WindowsSandbox.exe).Source

    New-Item -Path $extensionKey -Force | Out-Null
    Set-ItemProperty -Path $extensionKey -Name "(default)" -Value "Windows.Sandbox"

    New-Item -Path $classKey -Force | Out-Null
    Set-ItemProperty -Path $classKey -Name "(default)" -Value "`"$sandboxExe`" `"%1`""
}

function Assert-ReleaseAssets {
    $serverInstaller = Join-Path $DistDir "AZMusic Server Setup.exe"
    $clientInstaller = Join-Path $DistDir "AZMusic Windows Client Setup.exe"

    if ($RefreshServerPackage.IsPresent -or -not $UseExistingPackages.IsPresent -or -not (Test-Path $serverInstaller)) {
        & powershell.exe `
            -NoProfile `
            -ExecutionPolicy Bypass `
            -File $DevScript `
            -Task package-server-windows-installer `
            -ReleaseVersion $ReleaseVersion
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    }

    if ($RefreshClientPackage.IsPresent -or -not (Test-Path $clientInstaller)) {
        & powershell.exe `
            -NoProfile `
            -ExecutionPolicy Bypass `
            -File $DevScript `
            -Task package-client-windows-installer `
            -ReleaseVersion $ReleaseVersion
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    }

    if (-not (Test-Path $serverInstaller)) {
        throw "Missing server installer: $serverInstaller"
    }
    if (-not (Test-Path $clientInstaller)) {
        throw "Missing Windows client installer: $clientInstaller"
    }
}

Assert-WindowsSandboxEnabled
Ensure-WindowsSandboxFileAssociation
Assert-ReleaseAssets

New-Item -ItemType Directory -Path $GeneratedDir -Force | Out-Null
New-Item -ItemType Directory -Path $ResultsDir -Force | Out-Null
& icacls $ResultsDir /grant "*S-1-1-0:(OI)(CI)M" | Out-Null

$noAutoSmokeArgument = if ($NoAutoSmoke.IsPresent) { " -NoAutoSmoke" } else { "" }
$entryCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\AZMusicSandbox\sandbox-entry.ps1 -ReleaseVersion $ReleaseVersion -ResultsDir C:\AZMusicSandboxResults$noAutoSmokeArgument"

$wsb = @"
<Configuration>
  <vGPU>Disable</vGPU>
  <Networking>Default</Networking>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>$(Escape-Xml $DistDir)</HostFolder>
      <SandboxFolder>C:\AZMusicDist</SandboxFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
    <MappedFolder>
      <HostFolder>$(Escape-Xml $SandboxScriptsDir)</HostFolder>
      <SandboxFolder>C:\AZMusicSandbox</SandboxFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
    <MappedFolder>
      <HostFolder>$(Escape-Xml $ResultsDir)</HostFolder>
      <SandboxFolder>C:\AZMusicSandboxResults</SandboxFolder>
      <ReadOnly>false</ReadOnly>
    </MappedFolder>
  </MappedFolders>
  <LogonCommand>
    <Command>$(Escape-Xml $entryCommand)</Command>
  </LogonCommand>
</Configuration>
"@

Set-Content -LiteralPath $WsbPath -Value $wsb -Encoding utf8

Write-Host "Generated $WsbPath"
Start-Process -FilePath $WsbPath

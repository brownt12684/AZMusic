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
    [switch]$NoAutoSmoke,
    [switch]$Wait,
    [int]$TimeoutMinutes = 10
)

$ErrorActionPreference = "Stop"

$RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$DistDir = Join-Path $RepoRoot "dist"
$DevScript = Join-Path $RepoRoot "scripts\dev.ps1"
$SandboxScriptsDir = Join-Path $RepoRoot "scripts\windows-sandbox"
$GeneratedDir = Join-Path $DistDir "windows-sandbox"
$ResultsDir = Join-Path $RepoRoot "sandbox-results\windows-sandbox"
$LaunchId = Get-Date -Format "yyyyMMdd-HHmmss"
$WsbPath = Join-Path $GeneratedDir ("AZMusicReleaseSandbox-{0}.wsb" -f $LaunchId)

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
    $serverInstaller = Join-Path $DistDir "AZMusic.Server.Setup.exe"
    $clientInstaller = Join-Path $DistDir "AZMusic.Windows.Client.Setup.exe"

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

function Get-StatusPayload {
    $latestPath = Join-Path $ResultsDir "latest.json"
    if (-not (Test-Path $latestPath)) {
        return $null
    }

    try {
        return Get-Content -LiteralPath $latestPath -Raw | ConvertFrom-Json
    }
    catch {
        Write-Warning "Unable to parse sandbox latest.json: $($_.Exception.Message)"
        return $null
    }
}

function Assert-FreshSandboxResult {
    $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
    $lastLine = $null

    while ((Get-Date) -lt $deadline) {
        $status = Get-StatusPayload
        if ($null -ne $status -and $status.run_id -ge $LaunchId) {
            $line = "Sandbox run $($status.run_id): $($status.status) / $($status.step) - $($status.message)"
            if ($line -ne $lastLine) {
                Write-Host $line
                $lastLine = $line
            }

            if ($status.status -eq "passed") {
                return
            }
            if ($status.status -eq "failed") {
                throw "Windows Sandbox release smoke failed: $($status.message). Logs: $($status.run_dir)"
            }
        }

        Start-Sleep -Seconds 5
    }

    $sandboxProcesses = Get-Process -Name "WindowsSandbox", "WindowsSandboxClient", "vmwp" -ErrorAction SilentlyContinue
    if ($sandboxProcesses.Count -eq 0) {
        throw "Windows Sandbox did not start a fresh smoke run for launch $LaunchId."
    }

    $processSummary = ($sandboxProcesses | ForEach-Object { "$($_.ProcessName):$($_.Id)" }) -join ", "
    throw "Windows Sandbox did not publish a fresh smoke result for launch $LaunchId before timeout. Active sandbox-related processes: $processSummary"
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
$sandboxExe = (Get-Command WindowsSandbox.exe).Source
Start-Process -FilePath $sandboxExe -ArgumentList @($WsbPath) | Out-Null

if ($Wait.IsPresent) {
    Assert-FreshSandboxResult
}

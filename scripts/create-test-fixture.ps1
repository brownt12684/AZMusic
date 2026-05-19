<#
.SYNOPSIS
    Generate dummy score files for client import validation.
.DESCRIPTION
    Creates realistic binary stub files (PDF, PNG, JPG) with proper magic
    bytes so the server does not reject them as corrupted during import.
    Files are written to sandbox/fixtures for the sandbox orchestrator.
.PARAMETER OutputDir
    Directory where fixture files are written. Defaults to sandbox/fixtures
    relative to the AZMusic monorepo root.
.PARAMETER Count
    Number of files to generate per type (default: 2).
#>
param(
    [string]$OutputDir,
    [int]$Count = 2
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $true
}

$ScriptDir = $PSScriptRoot
$RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $ScriptDir ".."))

if (-not $OutputDir) {
    $OutputDir = Join-Path $RepoRoot "sandbox/fixtures"
}

$PASS = "[PASS]"
$FAIL = "[FAIL]"
$INFO = "[INFO]"

function Write-Step {
    param([string]$Message)
    Write-Host "`n--- $Message ---" -ForegroundColor Cyan
}

# PDF 1.4 stub (realistic header + minimal body)
function New-PdfFixture {
    param([string]$Path)
    $bytes = [System.Text.Encoding]::ASCII.GetBytes(
        "%PDF-1.4`n1 0 obj`n<< /Type /Catalog /Pages 2 0 R >>`nendobj`n" +
        "2 0 obj`n<< /Type /Pages /Kids [] /Count 0 >>`nendobj`n" +
        "xref`n0 3`ntrailer`n<< /Size 3 /Root 1 0 R >>`nstartxref`n0`n%%EOF"
    )
    [System.IO.File]::WriteAllBytes($Path, $bytes)
}

# PNG stub (valid IHDR chunk, 1x1 pixel)
function New-PngFixture {
    param([string]$Path)
    $png = @(
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,  # signature
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,  # IHDR length + type
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,  # 1x1
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,  # bit depth, color type
        0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,  # CRC + IDAT length + type
        0x54, 0x08, 0xD7, 0x63, 0xF8, 0xFF, 0xFF, 0xFF,  # IDAT data
        0x00, 0x00, 0x00, 0x02, 0x00, 0x01, 0x8E, 0xA4,  # CRC
        0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,  # IEND
        0xAE, 0x42, 0x60, 0x82                            # CRC
    )
    [System.IO.File]::WriteAllBytes($Path, $png)
}

# JPG stub (SOI + APP0 + minimal DQT + SOF0 + EOI)
function New-JpgFixture {
    param([string]$Path)
    $dqt = [byte[]](0x08) + [byte[]](0x00) * 64
    $dht_lut = [byte[]](0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B) + [byte[]](1) * 12
    $jpg = [byte[]]@(
        0xFF, 0xD8,                                          # SOI
        0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46,    # APP0 + "JFIF"
        0x00, 0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01,
        0x00, 0x00,
        0xFF, 0xDB, 0x00, 0x43, 0x00
    ) + $dqt + [byte[]]@(
        0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01, 0x00,    # SOF0 1x1
        0x01, 0x01, 0x11, 0x00,
        0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00                 # DHT
    ) + $dht_lut + [byte[]]@(
        0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00,    # SOS
        0x00, 0x00, 0x3F, 0x00,
        0xFF, 0xD9                                          # EOI
    )
    [System.IO.File]::WriteAllBytes($Path, $jpg)
}

Write-Step "Generate test fixtures"

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Host "$INFO Created $OutputDir" -ForegroundColor Gray
}

$types = @(
    @{ Ext = "pdf"; Func = ${function:New-PdfFixture} },
    @{ Ext = "png"; Func = ${function:New-PngFixture} },
    @{ Ext = "jpg"; Func = ${function:New-JpgFixture} }
)

$generated = 0

foreach ($t in $types) {
    for ($i = 1; $i -le $Count; $i++) {
        $name = "score_{0:D2}.{1}" -f $i, $t.Ext
        $path = Join-Path $OutputDir $name
        & $t.Func -Path $path
        $generated++
        $data = [System.IO.File]::ReadAllBytes($path)
        Write-Host "$INFO Generated $name ($($data.Length) bytes)" -ForegroundColor Gray
    }
}

Write-Host "`n$PASS Generated $generated fixture files in $OutputDir" -ForegroundColor Green
exit 0

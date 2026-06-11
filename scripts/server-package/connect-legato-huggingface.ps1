$ErrorActionPreference = "Stop"

$env:PYTHONIOENCODING = "utf-8"
$toolRoot = Join-Path $env:LOCALAPPDATA "AZMusic\Server\tools\legato"
$venvPython = Join-Path $toolRoot ".venv\Scripts\python.exe"
$tokenPage = "https://huggingface.co/settings/tokens"
$modelPage = "https://huggingface.co/guangyangmusic/legato"
$llamaVisionPage = "https://huggingface.co/meta-llama/Llama-3.2-11B-Vision"

Write-Host "AZMusic LEGATO Hugging Face connection"
Write-Host ""
Write-Host "LEGATO uses the official guangyangmusic/legato model by default."
Write-Host "That model is gated and depends on the gated Meta Llama 3.2 Vision model."
Write-Host "Browser terms acceptance is required for both models, and this server machine"
Write-Host "also needs a Hugging Face token saved for command-line downloads."
Write-Host ""

if (-not (Test-Path $venvPython)) {
    throw "LEGATO virtual environment was not found at $venvPython. Run Install Processing Tool Helpers first and choose LEGATO."
}

Write-Host "Opening model page and token settings page..."
Start-Process $modelPage
Start-Process $llamaVisionPage
Start-Process $tokenPage
Write-Host ""
Write-Host "Create or copy a Hugging Face token with read access, then paste it into the login prompt below."
Write-Host "The token is stored by Hugging Face tooling under your Windows user profile; AZMusic does not write it into server .env."
Write-Host ""

& $venvPython -m huggingface_hub.commands.huggingface_cli login
if ($LASTEXITCODE -ne 0) {
    throw "Hugging Face login did not complete."
}

Write-Host ""
Write-Host "Checking Hugging Face login..."
& $venvPython -m huggingface_hub.commands.huggingface_cli whoami
if ($LASTEXITCODE -ne 0) {
    throw "Hugging Face login check failed."
}

Write-Host ""
Write-Host "Hugging Face is connected for the LEGATO environment."

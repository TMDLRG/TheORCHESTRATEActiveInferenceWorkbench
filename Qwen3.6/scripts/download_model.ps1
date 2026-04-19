# Resumable download of the Qwen 3.6-35B-A3B Q8_0 GGUF from the canonical ggml-org HF repo.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Test-Path venv)) { uv venv --python 3.12 venv }
. "$root\venv\Scripts\Activate.ps1"
uv pip install -q huggingface_hub openai hf_transfer

$env:HF_HUB_ENABLE_HF_TRANSFER = "1"
hf download ggml-org/Qwen3.6-35B-A3B-GGUF Qwen3.6-35B-A3B-Q8_0.gguf --local-dir ./models
Write-Host "Model ready at ./models/Qwen3.6-35B-A3B-Q8_0.gguf"

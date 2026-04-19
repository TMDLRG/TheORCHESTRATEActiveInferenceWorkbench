# One-shot: stop everything, re-start the model server, bring LibreChat up.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host "== Stopping any existing llama-server =="
. "$root\scripts\stop_qwen.ps1"

Write-Host "== Stopping LibreChat if running =="
docker compose -f "$root\librechat\docker-compose.yml" -f "$root\librechat\docker-compose.override.yml" -p librechat down 2>&1 | Out-Host

Write-Host "== Starting llama-server =="
. "$root\scripts\start_qwen.ps1"

Write-Host "== Starting LibreChat =="
docker compose -f "$root\librechat\docker-compose.yml" -f "$root\librechat\docker-compose.override.yml" -p librechat up -d 2>&1 | Out-Host

Write-Host ""
Write-Host "== LibreChat should be reachable at http://localhost:3080 =="
Write-Host "   llama-server on port: $(Get-Content .qwen_port)"

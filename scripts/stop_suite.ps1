#Requires -Version 5.1
<#
  Stop every service started by start_suite.ps1.
#>
$ErrorActionPreference = "SilentlyContinue"
$root  = Resolve-Path (Join-Path $PSScriptRoot "..")
$state = Join-Path $PSScriptRoot ".suite"

function Stop-Pidfile($name, $file) {
  if (Test-Path $file) {
    $pid = Get-Content $file | Select-Object -First 1
    if ($pid -and (Get-Process -Id $pid -ErrorAction SilentlyContinue)) {
      Stop-Process -Id $pid -Force
      Write-Host "  stopped $name (pid=$pid)"
    }
    Remove-Item $file -Force
  }
}

function Stop-Port($port, $name) {
  Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess |
    ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }
  Write-Host "  freed :$port for $name"
}

Stop-Pidfile "Phoenix"     (Join-Path $state "phoenix.pid")
Stop-Pidfile "Speech HTTP" (Join-Path $state "speech_http.pid")
Stop-Pidfile "Speech MCP"  (Join-Path $state "speech_mcp.pid")
Stop-Pidfile "ClaudeSpeak" (Join-Path $state "claudespeak.pid")  # legacy
Stop-Pidfile "Qwen"        (Join-Path $state "qwen.pid")

Stop-Port 4000 "Phoenix"
Stop-Port 7712 "Speech HTTP"
Stop-Port 7711 "Speech MCP"
Stop-Port 8090 "Qwen"

$libreDir = Join-Path $root "Qwen3.6\librechat"
if ((Test-Path (Join-Path $libreDir "docker-compose.yml")) -and (Get-Command docker -ErrorAction SilentlyContinue)) {
  Push-Location $libreDir
  docker compose stop 2>&1 | Out-Null
  Pop-Location
  Write-Host "  stopped LibreChat Docker stack"
}

Write-Host "Suite stopped."

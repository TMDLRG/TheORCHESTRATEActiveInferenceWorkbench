#Requires -Version 5.1
<#
.SYNOPSIS
  Active Inference Masterclass — unified Windows launcher.
  Mirrors scripts/start_suite.sh in PowerShell.

.DESCRIPTION
  Boots Qwen, ClaudeSpeak HTTP, LibreChat Docker, and Phoenix Workbench in
  sequence with readiness checks.  Idempotent — skips anything already up.

  Run from the repo root:
      ./scripts/start_suite.ps1

  Stop everything:
      ./scripts/stop_suite.ps1
#>
param(
  [int]$PhoenixPort = 4000,
  [int]$SpeakPort   = 7712,
  [int]$SpeechMcpPort = 7711,
  [int]$LibrechatPort = 3080,
  [int]$QwenPort    = 8090
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$state = Join-Path $PSScriptRoot ".suite"
$logs  = Join-Path $state "logs"
New-Item -ItemType Directory -Force -Path $state, $logs | Out-Null

function Write-Cyan($m)   { Write-Host $m -ForegroundColor Cyan }
function Write-Green($m)  { Write-Host $m -ForegroundColor Green }
function Write-Yellow($m) { Write-Host $m -ForegroundColor Yellow }
function Write-Red($m)    { Write-Host $m -ForegroundColor Red }

function Test-Http($url, [int]$timeout=3) {
  try {
    $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec $timeout -ErrorAction Stop
    return [int]$r.StatusCode
  } catch {
    return 0
  }
}

function Wait-Up($name, $url, [int]$maxSec, [int]$ok=200) {
  $t = 0
  while ($t -lt $maxSec) {
    $code = Test-Http $url 3
    if ($code -eq $ok) { Write-Green "  + $name ready at $url (${t}s)"; return $true }
    Start-Sleep -Seconds 5
    $t += 5
  }
  Write-Red "  x $name did not come up within ${maxSec}s"
  return $false
}

# [1/3] Qwen
Write-Cyan ">> [1/4] Starting Qwen 3.6..."
if ((Test-Http "http://127.0.0.1:$QwenPort/v1/models") -eq 200) {
  Write-Green "  + Qwen already running on :$QwenPort"
} else {
  $qwenScript = Join-Path $root "Qwen3.6\scripts\start_qwen.ps1"
  if (Test-Path $qwenScript) {
    Start-Process powershell -ArgumentList "-NoProfile","-File",$qwenScript -WorkingDirectory (Join-Path $root "Qwen3.6") -RedirectStandardOutput (Join-Path $logs "qwen.log") -RedirectStandardError (Join-Path $logs "qwen.err") -PassThru | ForEach-Object { $_.Id } | Out-File (Join-Path $state "qwen.pid")
    Write-Yellow "  ... loading 36 GB weights may take up to 2 minutes"
    Wait-Up "Qwen" "http://127.0.0.1:$QwenPort/v1/models" 240 | Out-Null
  } else {
    Write-Yellow "  skipped — Qwen3.6\scripts\start_qwen.ps1 missing"
  }
}

# [2/3] (removed) — the voice service now lives inside the LibreChat Docker
# stack as the `voice` container. docker compose up brings it online alongside
# LibreChat, MongoDB, etc.  No standalone PowerShell speech processes.

# [2/4] LibreChat Docker (includes voice container exposing 7711/7712)
Write-Cyan ">> [2/4] Starting LibreChat Docker stack (includes voice service)..."
if ((Test-Http "http://127.0.0.1:$LibrechatPort/") -eq 200) {
  Write-Green "  + LibreChat already running on :$LibrechatPort"
} else {
  $libreDir = Join-Path $root "Qwen3.6\librechat"
  if ((Test-Path (Join-Path $libreDir "docker-compose.yml")) -and (Get-Command docker -ErrorAction SilentlyContinue)) {
    Push-Location $libreDir
    docker compose up -d | Out-File (Join-Path $logs "librechat.log")
    Pop-Location
    Wait-Up "LibreChat" "http://127.0.0.1:$LibrechatPort/" 120 | Out-Null
    Wait-Up "Speech HTTP (voice)" "http://127.0.0.1:$SpeakPort/healthz" 30 | Out-Null
    Wait-Up "Speech MCP  (voice)" "http://127.0.0.1:$SpeechMcpPort/sse" 30 | Out-Null
  } else {
    Write-Yellow "  skipped — Docker or compose file missing"
  }
}

# [3/4] LibreChat bootstrap + seed (requires Python)
$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) { $py = Get-Command python3 -ErrorAction SilentlyContinue }
if ((Test-Http "http://127.0.0.1:$LibrechatPort/") -eq 200 -and $py) {
  Write-Cyan ">> [3/4] LibreChat bootstrap + API seeding (idempotent)..."
  $env:LC_BASE_URL = "http://127.0.0.1:$LibrechatPort"
  $bootLog = Join-Path $logs "librechat_bootstrap.log"
  $seedLog = Join-Path $logs "librechat_seed.log"
  & $py.Source (Join-Path $root "scripts\librechat_bootstrap.py") 2>&1 | Out-File -FilePath $bootLog -Encoding utf8
  if ($LASTEXITCODE -eq 0) { Write-Green "  + librechat_bootstrap.py" }
  else { Write-Yellow "  ! librechat_bootstrap.py failed — see $bootLog" }
  & $py.Source (Join-Path $root "tools\librechat_seed\seed.py") 2>&1 | Out-File -FilePath $seedLog -Encoding utf8
  if ($LASTEXITCODE -eq 0) { Write-Green "  + tools/librechat_seed/seed.py" }
  else { Write-Yellow "  ! librechat_seed/seed.py failed — see $seedLog" }
}
elseif ((Test-Http "http://127.0.0.1:$LibrechatPort/") -eq 200) {
  Write-Yellow "  python not found — skipping LibreChat bootstrap/seed"
}

# [4/4] Phoenix
Write-Cyan ">> [4/4] Starting Phoenix Workbench..."
if ((Test-Http "http://127.0.0.1:$PhoenixPort/") -eq 200) {
  Write-Green "  + Phoenix already running on :$PhoenixPort"
} else {
  $phxDir = Join-Path $root "active_inference"
  $env:MIX_ENV = "dev"
  $env:PORT = $PhoenixPort
  Start-Process cmd -ArgumentList "/c","mix phx.server" -WorkingDirectory $phxDir -RedirectStandardOutput (Join-Path $logs "phoenix.log") -RedirectStandardError (Join-Path $logs "phoenix.err") -PassThru | ForEach-Object { $_.Id } | Out-File (Join-Path $state "phoenix.pid")
  if (-not (Wait-Up "Phoenix" "http://127.0.0.1:$PhoenixPort/" 60)) {
    Write-Red "  Phoenix failed. See $logs\phoenix.log"
    exit 1
  }
}

Write-Host ""
Write-Green "================================================="
Write-Green " Active Inference Masterclass is live."
Write-Green "================================================="
Write-Cyan  "  Learn hub  : http://127.0.0.1:$PhoenixPort/learn"
Write-Cyan  "  Workbench  : http://127.0.0.1:$PhoenixPort/"
Write-Cyan  "  Full chat  : http://127.0.0.1:$LibrechatPort/"
Write-Cyan  "  Qwen API   : http://127.0.0.1:$QwenPort/v1/models"
Write-Cyan  "  Speech TTS : http://127.0.0.1:$SpeakPort/healthz"
Write-Cyan  "  Speech MCP : http://127.0.0.1:$SpeechMcpPort/sse"
Write-Host ""
Write-Cyan  "  Logs       : $logs\"
Write-Cyan  "  Stop       : $(Join-Path $PSScriptRoot 'stop_suite.ps1')"
Write-Host ""

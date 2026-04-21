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
# Immediate banner so the window is never mistaken for "hung" before first HTTP check.
Write-Host "Active Inference suite launcher (logs under scripts\.suite\logs)" -ForegroundColor DarkGray
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$state = Join-Path $PSScriptRoot ".suite"
$logs  = Join-Path $state "logs"
New-Item -ItemType Directory -Force -Path $state, $logs | Out-Null

function Write-Cyan($m)   { Write-Host $m -ForegroundColor Cyan }
function Write-Green($m)  { Write-Host $m -ForegroundColor Green }
function Write-Yellow($m) { Write-Host $m -ForegroundColor Yellow }
function Write-Red($m)    { Write-Host $m -ForegroundColor Red }

function Ensure-ComposeUidGid {
  if ([string]::IsNullOrWhiteSpace($env:UID)) { $env:UID = '1000' }
  if ([string]::IsNullOrWhiteSpace($env:GID)) { $env:GID = '1000' }
}

function Write-LogTail([string]$path, [int]$lines = 25) {
  if (Test-Path $path) {
    Write-Host "--- last $lines lines: $path ---" -ForegroundColor DarkGray
    Get-Content $path -Tail $lines -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "  $_" }
  } else {
    Write-Host "(log not found: $path)" -ForegroundColor DarkGray
  }
}

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
    Write-Host "  ... waiting for $name (${t}s / ${maxSec}s)..." -ForegroundColor DarkGray
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
    $qwenLog = Join-Path $logs "qwen.log"
    $qwenErr = Join-Path $logs "qwen.err"
    try {
      # Hidden: stdout/stderr go to log files; a visible window would look blank.
      Start-Process powershell -WindowStyle Hidden -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File",$qwenScript -WorkingDirectory (Join-Path $root "Qwen3.6") -RedirectStandardOutput $qwenLog -RedirectStandardError $qwenErr -PassThru | ForEach-Object { $_.Id } | Out-File (Join-Path $state "qwen.pid")
    } catch {
      Write-Red "  x could not start Qwen helper process: $($_.Exception.Message)"
      exit 1
    }
    Write-Yellow "  ... loading 36 GB weights may take up to 2 minutes (detail: $qwenLog)"
    if (-not (Wait-Up "Qwen" "http://127.0.0.1:$QwenPort/v1/models" 240)) {
      Write-Red "  x Qwen startup timed out; suite continues but local LLM tab may be offline."
      Write-LogTail $qwenErr
      Write-LogTail $qwenLog
    }
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
    $libreLog = Join-Path $logs "librechat.log"
    Push-Location $libreDir
    Ensure-ComposeUidGid
    docker compose up -d *>&1 | Out-File -FilePath $libreLog -Encoding utf8
    $dc = $LASTEXITCODE
    Pop-Location
    if ($dc -ne 0) {
      Write-Red "  x docker compose up failed (exit $dc). Full chat / voice stack did not start."
      Write-LogTail $libreLog
      exit 1
    }
    if (-not (Wait-Up "LibreChat" "http://127.0.0.1:$LibrechatPort/" 120)) {
      Write-Red "  x LibreChat startup timed out; full chat tab may show an offline page. See $libreLog"
      Write-LogTail $libreLog
    }
    if (-not (Wait-Up "Speech HTTP (voice)" "http://127.0.0.1:$SpeakPort/healthz" 30)) {
      Write-Yellow "  ! voice HTTP slow — narrator may fall back to Web Speech until :$SpeakPort answers."
    }
    if (-not (Wait-Up "Speech MCP  (voice)" "http://127.0.0.1:$SpeechMcpPort/sse" 30)) {
      Write-Yellow "  ! voice MCP slow — LibreChat speak~voice tool may attach late."
    }
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
  if (-not (Get-Command mix -ErrorAction SilentlyContinue)) {
    Write-Red "  x mix (Elixir) is not on PATH — Phoenix cannot start."
    Write-Host "    Install Elixir, ensure mix is on your user PATH, then open a new PowerShell in the repo and run:" -ForegroundColor Yellow
    Write-Host "      .\scripts\start_suite.ps1" -ForegroundColor Yellow
    Write-Host "    (Double-clicking often uses a minimal PATH; VS Code / Windows Terminal inherit your dev PATH.)" -ForegroundColor Yellow
    exit 1
  }
  $phxDir = Join-Path $root "active_inference"
  if (-not (Test-Path $phxDir)) {
    Write-Red "  x Phoenix app directory missing: $phxDir"
    exit 1
  }
  $phxOut = Join-Path $logs "phoenix.log"
  $phxErr = Join-Path $logs "phoenix.err"
  $env:MIX_ENV = "dev"
  $env:PORT = "$PhoenixPort"
  try {
    Start-Process cmd -WindowStyle Hidden -ArgumentList "/c","mix phx.server" -WorkingDirectory $phxDir -RedirectStandardOutput $phxOut -RedirectStandardError $phxErr -PassThru | ForEach-Object { $_.Id } | Out-File (Join-Path $state "phoenix.pid")
  } catch {
    Write-Red "  x could not start Phoenix: $($_.Exception.Message)"
    exit 1
  }
  if (-not (Wait-Up "Phoenix" "http://127.0.0.1:$PhoenixPort/" 60)) {
    Write-Red "  x Phoenix failed to listen on :$PhoenixPort. See logs:"
    Write-LogTail $phxErr
    Write-LogTail $phxOut
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
Write-Cyan ("  Logs       : " + $logs + '\')
Write-Cyan  "  Stop       : $(Join-Path $PSScriptRoot 'stop_suite.ps1')"
Write-Host ""

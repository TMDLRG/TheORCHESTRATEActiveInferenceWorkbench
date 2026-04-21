#Requires -Version 5.1
<#
  Stop every service started by start_suite.ps1.

  IMPORTANT: Do not use $pid as a variable name — it aliases the read-only
  automatic variable $PID (this process). The old script never read pidfiles.
#>
param(
  [int]$PhoenixPort = 4000,
  [int]$SpeakPort   = 7712,
  [int]$SpeechMcpPort = 7711,
  [int]$LibrechatPort = 3080,
  [int]$QwenPort    = 8090
)

$ErrorActionPreference = "Continue"
$root  = Resolve-Path (Join-Path $PSScriptRoot "..")
$state = Join-Path $PSScriptRoot ".suite"
$qwenRoot = Join-Path $root "Qwen3.6"

Write-Host "Stopping Active Inference suite..." -ForegroundColor Cyan

# docker-compose.yml uses user: "${UID}:${GID}"; unset vars make Compose warn on Windows.
function Ensure-ComposeUidGid {
  if ([string]::IsNullOrWhiteSpace($env:UID)) { $env:UID = '1000' }
  if ([string]::IsNullOrWhiteSpace($env:GID)) { $env:GID = '1000' }
}

function Stop-ProcessTree([int]$processId) {
  if ($processId -le 0) { return }
  # /T = kill children (mix -> beam, cmd -> mix, etc.)
  # Cannot combine -WindowStyle with -NoNewWindow on Start-Process (Windows PowerShell 5.1).
  $p = Start-Process -FilePath "$env:SystemRoot\System32\taskkill.exe" `
    -ArgumentList @("/F", "/T", "/PID", "$processId") `
    -WindowStyle Hidden -Wait -PassThru
  if ($p.ExitCode -ne 0 -and (Get-Process -Id $processId -ErrorAction SilentlyContinue)) {
    Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
  }
}

function Stop-Pidfile([string]$label, [string]$file) {
  if (-not (Test-Path $file)) { return }
  $raw = (Get-Content $file -Raw -ErrorAction SilentlyContinue).Trim()
  $targetId = 0
  [void][int]::TryParse($raw, [ref]$targetId)
  Remove-Item $file -Force -ErrorAction SilentlyContinue
  if ($targetId -le 0) { return }
  if (Get-Process -Id $targetId -ErrorAction SilentlyContinue) {
    Stop-ProcessTree $targetId
    Write-Host "  stopped $label (pid=$targetId)" -ForegroundColor Green
  }
}

function Get-PidsListeningOnPort([int]$port) {
  $ids = [System.Collections.Generic.HashSet[int]]::new()
  try {
    Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue |
      ForEach-Object { [void]$ids.Add($_.OwningProcess) }
  } catch { }
  if ($ids.Count -eq 0) {
    # Fallback when NetTCPIP is unavailable (same class of issue as start_qwen).
    $netstat = & "$env:SystemRoot\System32\netstat.exe" -ano 2>$null
    foreach ($line in $netstat) {
      if ($line -notmatch "LISTENING") { continue }
      if ($line -notmatch ":$port\s") { continue }
      if ($line -match "\s+(\d+)\s*$") {
        [void]$ids.Add([int]$Matches[1])
      }
    }
  }
  return @($ids)
}

function Stop-Port([int]$port, [string]$name) {
  foreach ($procId in (Get-PidsListeningOnPort $port)) {
    if ($procId -le 4) { continue }
    Stop-ProcessTree $procId
  }
  Write-Host "  freed :$port ($name)" -ForegroundColor DarkGray
}

# llama-server PID lives in Qwen3.6 (written by start_qwen.ps1), not scripts/.suite/qwen.pid
$qwenPidFile = Join-Path $qwenRoot ".qwen_pid"
if (Test-Path $qwenPidFile) {
  $raw = (Get-Content $qwenPidFile -Raw -ErrorAction SilentlyContinue).Trim()
  $llamaId = 0
  [void][int]::TryParse($raw, [ref]$llamaId)
  if ($llamaId -gt 0 -and (Get-Process -Id $llamaId -ErrorAction SilentlyContinue)) {
    Stop-ProcessTree $llamaId
    Write-Host "  stopped Qwen llama-server (pid=$llamaId)" -ForegroundColor Green
  }
  Remove-Item $qwenPidFile -Force -ErrorAction SilentlyContinue
}

Stop-Pidfile "Phoenix helper"     (Join-Path $state "phoenix.pid")
Stop-Pidfile "Qwen helper shell" (Join-Path $state "qwen.pid")
Stop-Pidfile "Speech HTTP"       (Join-Path $state "speech_http.pid")
Stop-Pidfile "Speech MCP"        (Join-Path $state "speech_mcp.pid")
Stop-Pidfile "ClaudeSpeak"       (Join-Path $state "claudespeak.pid")

# Stop Docker-published services first; killing :3080 on the host can hit Docker's proxy before containers stop.
$libreDir = Join-Path $root "Qwen3.6\librechat"
if ((Test-Path (Join-Path $libreDir "docker-compose.yml")) -and (Get-Command docker -ErrorAction SilentlyContinue)) {
  Push-Location $libreDir
  try {
    Ensure-ComposeUidGid
    & docker compose stop
    if ($LASTEXITCODE -ne 0) {
      Write-Host "  docker compose stop returned $LASTEXITCODE (trying down...)" -ForegroundColor Yellow
      & docker compose down
    }
    Write-Host "  stopped LibreChat Docker stack" -ForegroundColor Green
  } catch {
    Write-Host "  docker error: $($_.Exception.Message)" -ForegroundColor Red
  } finally {
    Pop-Location
  }
}

Stop-Port $PhoenixPort    "Phoenix"
Stop-Port $SpeakPort     "Speech HTTP"
Stop-Port $SpeechMcpPort "Speech MCP"
Stop-Port $QwenPort      "Qwen API"

if ((Test-Path (Join-Path $root "docker-compose.yml")) -and (Get-Command docker -ErrorAction SilentlyContinue)) {
  Push-Location $root
  try {
    Ensure-ComposeUidGid
    & docker compose stop 2>&1 | Out-Null
  } finally {
    Pop-Location
  }
}

Get-Process -Name 'beam','beam.smp','erl','erlsrv','werl','epmd' -ErrorAction SilentlyContinue |
  ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
Write-Host "  swept any lingering BEAM/erl/epmd processes" -ForegroundColor DarkGray

Write-Host "Suite stopped." -ForegroundColor Green

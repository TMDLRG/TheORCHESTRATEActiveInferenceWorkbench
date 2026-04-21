# Start the local Qwen 3.6-35B-A3B llama-server on a free port.
# - Auto-resolves port conflicts (scans upward from $StartPort).
# - Binds 0.0.0.0 so the Docker-hosted LibreChat can reach us via host.docker.internal:host-gateway.
# - Writes chosen port to .qwen_port and regenerates librechat/librechat.yaml from the template.
# - Runs llama-server in the background; PID captured in .qwen_pid.

param(
    [int]$StartPort = 8090,
    [int]$CtxSize  = 524288,
    [int]$NGPULayers = 20,
    [int]$NCpuMoE  = 999,
    [string]$Quant = "Q8_0",
    [string]$KvCacheType = "q8_0",   # q8_0 halves KV-cache RAM vs default fp16
    [switch]$NoYarn,                  # pass -NoYarn to disable YaRN (for ctx <= 262144)
    [int]$YarnOrigCtx = 262144,       # Qwen 3.6-35B-A3B native context
    [switch]$KvOffload                # pass -KvOffload to let KV cache use GPU (default: CPU-only KV)
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$model = Join-Path $root "models\Qwen3.6-35B-A3B-$Quant.gguf"
if (-not (Test-Path $model)) { throw "Model missing: $model. Run scripts/download_model.ps1." }

$bin = Join-Path $root "llama.cpp-bin\llama-server.exe"
if (-not (Test-Path $bin)) { throw "llama-server.exe missing at $bin." }

function Test-PortFree([int]$p) {
    # .NET API only — avoids NetTCPIP / Get-NetTCPConnection (missing or restricted on some Windows setups).
    $props = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
    foreach ($l in $props.GetActiveTcpListeners()) {
        if ($l.Port -eq $p) { return $false }
    }
    return $true
}

$port = $StartPort
while (-not (Test-PortFree $port)) {
    Write-Host "Port $port is in use; trying $($port + 1)"
    $port++
    if ($port -gt ($StartPort + 50)) { throw "No free port found in range." }
}
Set-Content -Path ".qwen_port" -Value $port -NoNewline
Write-Host "Selected port: $port"

$tpl = Join-Path $root "librechat\librechat.yaml.template"
$yaml = Join-Path $root "librechat\librechat.yaml"
if (Test-Path $tpl) {
    (Get-Content $tpl -Raw).Replace("__PORT__", "$port") | Set-Content -Path $yaml -NoNewline
    Write-Host "Regenerated $yaml with port $port"
}

$logDir = Join-Path $root "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$stdout = Join-Path $logDir "llama-server.stdout.log"
$stderr = Join-Path $logDir "llama-server.stderr.log"

$args = @(
    "-m", $model,
    "--host", "0.0.0.0",
    "--port", "$port",
    "--ctx-size", "$CtxSize",
    "--parallel", "1",
    "--n-cpu-moe", "$NCpuMoE",
    "-ngl", "$NGPULayers",
    "--jinja",
    "--alias", "Qwen3.6-35B-A3B-Q8_0",
    "--cache-type-k", "$KvCacheType",
    "--cache-type-v", "$KvCacheType",
    "--flash-attn", "on",
    "--log-file", (Join-Path $logDir "llama-server.log"),
    "--metrics"
)

if (-not $KvOffload) {
    # Keep the full KV cache in system RAM. At 500K ctx it would blow through the T1000's 4 GB.
    $args += @("--no-kv-offload")
}

if (-not $NoYarn -and $CtxSize -gt $YarnOrigCtx) {
    # Model is native-262K. For longer windows, apply YaRN extension.
    $scale = [math]::Round($CtxSize / $YarnOrigCtx, 4)
    $args += @(
        "--rope-scaling", "yarn",
        "--rope-scale",   "$scale",
        "--yarn-orig-ctx", "$YarnOrigCtx"
    )
    Write-Host "YaRN enabled: rope-scale=$scale (orig-ctx=$YarnOrigCtx, target=$CtxSize)"
}

Write-Host "Launching: $bin $($args -join ' ')"
$proc = Start-Process -FilePath $bin -ArgumentList $args -NoNewWindow -PassThru `
    -RedirectStandardOutput $stdout -RedirectStandardError $stderr
Set-Content -Path ".qwen_pid" -Value $proc.Id -NoNewline
Write-Host "llama-server started (PID $($proc.Id)). Waiting for /v1/models..."

$deadline = (Get-Date).AddMinutes(10)
while ((Get-Date) -lt $deadline) {
    try {
        $r = Invoke-WebRequest -Uri "http://127.0.0.1:$port/v1/models" -UseBasicParsing -TimeoutSec 5
        if ($r.StatusCode -eq 200) {
            Write-Host "llama-server is healthy on http://127.0.0.1:$port"
            Write-Host ($r.Content)
            exit 0
        }
    } catch { Start-Sleep -Seconds 5 }
}
throw "llama-server did not become healthy within 10 minutes. Check logs/llama-server.stderr.log"

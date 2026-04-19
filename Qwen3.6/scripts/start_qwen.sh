#!/usr/bin/env bash
# Bash/WSL equivalent of start_qwen.ps1. Prefer the PowerShell version on Windows.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

START_PORT="${START_PORT:-8090}"
CTX_SIZE="${CTX_SIZE:-524288}"
NGL="${NGL:-20}"
NCPUMOE="${NCPUMOE:-999}"
QUANT="${QUANT:-Q8_0}"
KV_CACHE_TYPE="${KV_CACHE_TYPE:-q8_0}"
YARN_ORIG_CTX="${YARN_ORIG_CTX:-262144}"
NO_YARN="${NO_YARN:-0}"
KV_OFFLOAD="${KV_OFFLOAD:-0}"

MODEL="$ROOT/models/Qwen3.6-35B-A3B-${QUANT}.gguf"
BIN="$ROOT/llama.cpp-bin/llama-server.exe"
[[ -f "$MODEL" ]] || { echo "Missing model: $MODEL"; exit 1; }
[[ -f "$BIN"   ]] || { echo "Missing llama-server.exe: $BIN"; exit 1; }

port="$START_PORT"
while :; do
    # Windows PowerShell port probe (works from Git Bash too).
    if powershell.exe -Command "if (Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }" >/dev/null 2>&1; then
        echo "Port $port busy; trying $((port+1))"
        port=$((port+1))
        [[ $port -gt $((START_PORT+50)) ]] && { echo "No free port found"; exit 1; }
    else
        break
    fi
done
echo -n "$port" > .qwen_port
echo "Selected port: $port"

TPL="$ROOT/librechat/librechat.yaml.template"
YAML="$ROOT/librechat/librechat.yaml"
[[ -f "$TPL" ]] && sed "s/__PORT__/$port/g" "$TPL" > "$YAML" && echo "Regenerated $YAML"

mkdir -p "$ROOT/logs"

args=(
  -m "$MODEL"
  --host 0.0.0.0
  --port "$port"
  --ctx-size "$CTX_SIZE"
  --parallel 1
  --n-cpu-moe "$NCPUMOE"
  -ngl "$NGL"
  --jinja
  --alias "Qwen3.6-35B-A3B-${QUANT}"
  --cache-type-k "$KV_CACHE_TYPE"
  --cache-type-v "$KV_CACHE_TYPE"
  --flash-attn on
  --log-file "$ROOT/logs/llama-server.log"
  --metrics
)

[[ "$KV_OFFLOAD" == "0" ]] && args+=(--no-kv-offload)

if [[ "$NO_YARN" == "0" && "$CTX_SIZE" -gt "$YARN_ORIG_CTX" ]]; then
  scale=$(awk -v a="$CTX_SIZE" -v b="$YARN_ORIG_CTX" 'BEGIN { printf "%.4f", a/b }')
  args+=(--rope-scaling yarn --rope-scale "$scale" --yarn-orig-ctx "$YARN_ORIG_CTX")
  echo "YaRN enabled: rope-scale=$scale (orig-ctx=$YARN_ORIG_CTX, target=$CTX_SIZE)"
fi

nohup "$BIN" "${args[@]}" \
  > "$ROOT/logs/llama-server.stdout.log" \
  2> "$ROOT/logs/llama-server.stderr.log" &

echo "$!" > .qwen_pid
echo "llama-server PID $(cat .qwen_pid); waiting for /v1/models..."

for _ in $(seq 1 120); do
    if curl -sf "http://127.0.0.1:$port/v1/models" >/dev/null 2>&1; then
        echo "llama-server is healthy on http://127.0.0.1:$port"
        curl -s "http://127.0.0.1:$port/v1/models"
        exit 0
    fi
    sleep 5
done
echo "llama-server did not become healthy. See logs/llama-server.stderr.log"
exit 1

#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -f .qwen_pid ]]; then
    target="$(cat .qwen_pid)"
    echo "Stopping llama-server PID $target"
    powershell.exe -Command "Stop-Process -Id $target -Force" 2>/dev/null || true
    rm -f .qwen_pid
fi

powershell.exe -Command "Get-Process llama-server -ErrorAction SilentlyContinue | Stop-Process -Force" 2>/dev/null || true
rm -f .qwen_port
echo "Stopped."

#!/usr/bin/env bash
# Stop every service started by start_suite.sh.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATE_DIR="$ROOT/scripts/.suite"

stop_pid() {
  local name="$1" file="$2"
  if [[ -f "$file" ]]; then
    local pid
    pid=$(cat "$file")
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      sleep 1
      kill -9 "$pid" 2>/dev/null || true
      echo "  stopped $name (pid=$pid)"
    fi
    rm -f "$file"
  fi
}

# Also kill anything bound to our ports via PowerShell (Windows-friendly).
kill_port() {
  local port="$1" name="$2"
  if command -v powershell >/dev/null 2>&1; then
    powershell -Command "Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess | ForEach-Object { Stop-Process -Id \$_ -Force -ErrorAction SilentlyContinue }" 2>/dev/null || true
    echo "  ensured :$port free for $name"
  fi
}

stop_pid "Phoenix"     "$STATE_DIR/phoenix.pid"
stop_pid "Speech HTTP" "$STATE_DIR/speech_http.pid"
stop_pid "Speech MCP"  "$STATE_DIR/speech_mcp.pid"
stop_pid "ClaudeSpeak" "$STATE_DIR/claudespeak.pid"   # legacy
stop_pid "Qwen"        "$STATE_DIR/qwen.pid"

kill_port 4000 "Phoenix"
kill_port 7712 "Speech HTTP"
kill_port 7711 "Speech MCP"
kill_port 8090 "Qwen"

if [[ -f "$ROOT/Qwen3.6/librechat/docker-compose.yml" ]] && command -v docker >/dev/null 2>&1; then
  ( cd "$ROOT/Qwen3.6/librechat" && docker compose stop 2>/dev/null || true )
  echo "  stopped LibreChat Docker stack"
fi

# Also kill any orcworkbench Docker container from the root compose (prod release).
if command -v docker >/dev/null 2>&1 && [[ -f "$ROOT/docker-compose.yml" ]]; then
  ( cd "$ROOT" && docker compose stop 2>/dev/null || true )
fi

# Nuclear: sweep any lingering BEAM / Elixir / epmd processes. The port
# kills above usually cover this, but a BEAM node that never opened :4000
# (e.g. a stalled `mix phx.server` during boot, or an iex left open) can
# hang around and hold Mnesia locks for the next run.
if command -v powershell >/dev/null 2>&1; then
  powershell -Command "Get-Process -Name 'beam','beam.smp','erl','erlsrv','werl','epmd' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue" 2>/dev/null || true
  echo "  swept any lingering BEAM/erl/epmd processes"
elif command -v pkill >/dev/null 2>&1; then
  pkill -f "beam.smp" 2>/dev/null || true
  pkill -x "erl" 2>/dev/null || true
  pkill -x "epmd" 2>/dev/null || true
  echo "  swept any lingering BEAM/erl/epmd processes"
fi

echo "Suite stopped."

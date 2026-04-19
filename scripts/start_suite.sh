#!/usr/bin/env bash
# ============================================================================
# Active Inference Masterclass — unified suite launcher.
#
# Starts, in order, with readiness checks between each:
#   1. Qwen 3.6 llama-server          → http://127.0.0.1:8090
#   2. LibreChat Docker Compose stack → http://127.0.0.1:3080 (includes voice :7711/:7712)
#   3. LibreChat admin + API seeding  → scripts/librechat_bootstrap.py + tools/librechat_seed/seed.py
#   4. Phoenix Workbench              → http://127.0.0.1:4000
#
# Run from the repo root:
#   ./scripts/start_suite.sh
#
# Stop everything:
#   ./scripts/stop_suite.sh
#
# Each backend's PID / container is tracked so we can tear down cleanly.
# The script is idempotent: if a service is already up, it won't be restarted.
# ============================================================================
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATE_DIR="$ROOT/scripts/.suite"
LOG_DIR="$ROOT/scripts/.suite/logs"
mkdir -p "$STATE_DIR" "$LOG_DIR"

PHOENIX_PORT=${PHOENIX_PORT:-4000}
SPEAK_PORT=${SPEAK_PORT:-7712}
SPEECH_MCP_PORT=${SPEECH_MCP_PORT:-7711}
LIBRECHAT_PORT=${LIBRECHAT_PORT:-3080}
QWEN_PORT=${QWEN_PORT:-8090}

cyan()   { printf "\e[1;36m%s\e[0m\n" "$*"; }
green()  { printf "\e[1;32m%s\e[0m\n" "$*"; }
yellow() { printf "\e[1;33m%s\e[0m\n" "$*"; }
red()    { printf "\e[1;31m%s\e[0m\n" "$*"; }

up_http() {
  local url="$1" timeout_s="${2:-3}"
  curl -s --max-time "$timeout_s" -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000"
}

wait_until_up() {
  local name="$1" url="$2" max_s="$3" check_code="${4:-200}"
  local t=0
  while (( t < max_s )); do
    local code
    code=$(up_http "$url" 3)
    if [[ "$code" == "$check_code" ]]; then
      green "  ✓ $name ready at $url ($(( t ))s)"
      return 0
    fi
    sleep 5
    t=$(( t + 5 ))
  done
  red "  ✗ $name did not come up within ${max_s}s"
  return 1
}

# ---------------------------------------------------------------------------
# 1. Qwen 3.6 (llama-server).  Loading 36 GB Q8 weights takes ~2 minutes.
# ---------------------------------------------------------------------------
cyan ">> [1/4] Starting Qwen 3.6…"
if [[ "$(up_http "http://127.0.0.1:$QWEN_PORT/v1/models")" == "200" ]]; then
  green "  ✓ Qwen already running on :$QWEN_PORT"
else
  if [[ -f "$ROOT/Qwen3.6/scripts/start_qwen.sh" ]]; then
    ( cd "$ROOT/Qwen3.6" && bash scripts/start_qwen.sh > "$LOG_DIR/qwen.log" 2>&1 & echo $! > "$STATE_DIR/qwen.pid" )
    yellow "  … Qwen starting (see $LOG_DIR/qwen.log). Loading 36 GB weights may take ~2 minutes."
    wait_until_up "Qwen" "http://127.0.0.1:$QWEN_PORT/v1/models" 240 || red "  Qwen startup timed out; suite will still run but uber-help will be offline."
  else
    yellow "  Qwen start script not found at Qwen3.6/scripts/start_qwen.sh — skipping."
  fi
fi

# ---------------------------------------------------------------------------
# 2. (removed) — the voice service now lives inside the LibreChat Docker stack
#    as the `voice` container (Dockerfile in ClaudeSpeak/claude-voice-connector-http/).
#    docker compose up brings it online alongside LibreChat, MongoDB, etc.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# 3. LibreChat Docker stack: LibreChat + MongoDB + pgvector + Meilisearch +
#    rag_api + voice (Piper TTS over HTTP :7712 + MCP SSE :7711).
# ---------------------------------------------------------------------------
cyan ">> [2/4] Starting LibreChat Docker stack (includes voice service)…"
if [[ "$(up_http "http://127.0.0.1:$LIBRECHAT_PORT/")" == "200" ]]; then
  green "  ✓ LibreChat already running on :$LIBRECHAT_PORT"
else
  if command -v docker >/dev/null 2>&1 && [[ -f "$ROOT/Qwen3.6/librechat/docker-compose.yml" ]]; then
    ( cd "$ROOT/Qwen3.6/librechat" && docker compose up -d > "$LOG_DIR/librechat.log" 2>&1 )
    wait_until_up "LibreChat" "http://127.0.0.1:$LIBRECHAT_PORT/" 120 || red "  LibreChat startup timed out; full chat tab will show offline page."
    wait_until_up "Speech HTTP (voice container)" "http://127.0.0.1:$SPEAK_PORT/healthz" 30 || yellow "  voice HTTP slow to start — Phoenix Narrator falls back to Web Speech."
    wait_until_up "Speech MCP  (voice container)" "http://127.0.0.1:$SPEECH_MCP_PORT/sse" 30 || yellow "  voice MCP slow to start — LibreChat speak~voice tool will attach late."
  else
    yellow "  Docker or compose file missing — skipping LibreChat."
  fi
fi

# ---------------------------------------------------------------------------
# 3b. LibreChat admin JWT + Mongo content (agents, prompts, RAG, memories, agents.json).
# ---------------------------------------------------------------------------
if [[ "$(up_http "http://127.0.0.1:$LIBRECHAT_PORT/")" == "200" ]] && command -v python3 >/dev/null 2>&1; then
  cyan ">> [2b/4] LibreChat bootstrap + API seeding (idempotent)…"
  export LC_BASE_URL="http://127.0.0.1:$LIBRECHAT_PORT"
  if ( cd "$ROOT" && python3 scripts/librechat_bootstrap.py >> "$LOG_DIR/librechat_bootstrap.log" 2>&1 ); then
    green "  ✓ librechat_bootstrap.py"
  else
    yellow "  ⚠ librechat_bootstrap.py failed — see $LOG_DIR/librechat_bootstrap.log"
  fi
  if ( cd "$ROOT" && python3 tools/librechat_seed/seed.py >> "$LOG_DIR/librechat_seed.log" 2>&1 ); then
    green "  ✓ tools/librechat_seed/seed.py"
  else
    yellow "  ⚠ tools/librechat_seed/seed.py failed — see $LOG_DIR/librechat_seed.log"
  fi
elif [[ "$(up_http "http://127.0.0.1:$LIBRECHAT_PORT/")" == "200" ]]; then
  yellow "  python3 not found — skipping LibreChat bootstrap/seed (install Python 3.11+)"
fi

# ---------------------------------------------------------------------------
# 4. Phoenix Workbench.  Mix boots in ~5 seconds.
# ---------------------------------------------------------------------------
cyan ">> [4/4] Starting Phoenix Workbench…"
if [[ "$(up_http "http://127.0.0.1:$PHOENIX_PORT/")" == "200" ]]; then
  green "  ✓ Phoenix already running on :$PHOENIX_PORT"
else
  ( cd "$ROOT/active_inference" && MIX_ENV=dev PORT=$PHOENIX_PORT mix phx.server > "$LOG_DIR/phoenix.log" 2>&1 & echo $! > "$STATE_DIR/phoenix.pid" )
  wait_until_up "Phoenix" "http://127.0.0.1:$PHOENIX_PORT/" 60 || { red "  Phoenix failed to start. Check $LOG_DIR/phoenix.log"; exit 1; }
fi

echo
green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
green " Active Inference Masterclass is live."
green "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cyan "  Learn hub         : http://127.0.0.1:$PHOENIX_PORT/learn"
cyan "  Workbench         : http://127.0.0.1:$PHOENIX_PORT/"
cyan "  Full chat         : http://127.0.0.1:$LIBRECHAT_PORT/"
cyan "  Qwen API          : http://127.0.0.1:$QWEN_PORT/v1/models"
cyan "  Speech TTS (HTTP) : http://127.0.0.1:$SPEAK_PORT/healthz"
cyan "  Speech MCP (SSE)  : http://127.0.0.1:$SPEECH_MCP_PORT/sse"
echo
cyan "  Logs              : $LOG_DIR/"
cyan "  Stop              : $ROOT/scripts/stop_suite.sh"
echo

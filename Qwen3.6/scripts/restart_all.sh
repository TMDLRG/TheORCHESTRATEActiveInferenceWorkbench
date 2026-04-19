#!/usr/bin/env bash
# One-shot: stop everything, re-start the model server, bring LibreChat up.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "== Stopping any existing llama-server =="
bash "$ROOT/scripts/stop_qwen.sh" || true

echo "== Stopping LibreChat if running =="
(cd "$ROOT/librechat" && docker compose -p librechat down) || true

echo "== Starting llama-server =="
bash "$ROOT/scripts/start_qwen.sh"

echo "== Starting LibreChat =="
(cd "$ROOT/librechat" && docker compose -p librechat up -d)

echo ""
echo "== LibreChat should be reachable at http://localhost:3080 =="
echo "   llama-server on port: $(cat "$ROOT/.qwen_port")"

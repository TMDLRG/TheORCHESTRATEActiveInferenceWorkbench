#!/usr/bin/env bash
# Smoke tests for the local Qwen server via curl.
# Proves: /v1/models, reasoning mode (<think>), direct mode (no <think>).
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PORT="${PORT:-$(cat .qwen_port 2>/dev/null || echo 8090)}"
HOST="${HOST:-http://127.0.0.1:$PORT}"
OUT="$ROOT/logs/api-proof.txt"
mkdir -p "$ROOT/logs"

echo "=== $(date -Iseconds) — Direct API proof against $HOST ===" | tee "$OUT"

echo ""                                         | tee -a "$OUT"
echo "--- GET /v1/models ---"                   | tee -a "$OUT"
curl -s "$HOST/v1/models" | tee -a "$OUT"
echo ""                                         | tee -a "$OUT"

# Reasoning (enable_thinking=true) — expect <think>...</think> block.
echo ""                                         | tee -a "$OUT"
echo "--- POST /v1/chat/completions (REASONING ON) ---" | tee -a "$OUT"
curl -s "$HOST/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
        "model": "Qwen3.6-35B-A3B-Q8_0",
        "messages": [{"role":"user","content":"What is 17 * 23? Think step by step, then give ONLY the final number."}],
        "max_tokens": 2048,
        "temperature": 1.0,
        "top_p": 0.95,
        "chat_template_kwargs": {"enable_thinking": true}
      }' | tee -a "$OUT"
echo ""                                         | tee -a "$OUT"

# Direct (enable_thinking=false) — expect no <think> block.
echo ""                                         | tee -a "$OUT"
echo "--- POST /v1/chat/completions (REASONING OFF) ---" | tee -a "$OUT"
curl -s "$HOST/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
        "model": "Qwen3.6-35B-A3B-Q8_0",
        "messages": [{"role":"user","content":"What is the capital of France? Answer in one word."}],
        "max_tokens": 64,
        "temperature": 0.7,
        "top_p": 0.8,
        "chat_template_kwargs": {"enable_thinking": false}
      }' | tee -a "$OUT"
echo ""                                         | tee -a "$OUT"

echo ""                                         | tee -a "$OUT"
echo "--- Pass/fail check ---"                  | tee -a "$OUT"
# llama-server's Qwen3 reasoning parser extracts <think>...</think> into reasoning_content.
# Either form (raw <think> OR reasoning_content) proves reasoning mode.
if grep -q -E '"reasoning_content"\s*:\s*"[^"]' "$OUT"; then
    echo "PASS: reasoning response populated reasoning_content" | tee -a "$OUT"
elif grep -q "<think>" "$OUT"; then
    echo "PASS: reasoning response contained raw <think>" | tee -a "$OUT"
else
    echo "FAIL: reasoning response missing both reasoning_content and <think>" | tee -a "$OUT"
fi

# Direct mode must NOT have a reasoning_content field (other than empty).
if grep -A2 "REASONING OFF" "$OUT" | tail -2 | grep -q "Paris"; then
    echo "PASS: direct mode returned 'Paris'" | tee -a "$OUT"
else
    echo "FAIL: direct mode did not return 'Paris'" | tee -a "$OUT"
fi

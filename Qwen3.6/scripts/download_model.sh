#!/usr/bin/env bash
# Resumable download of the Qwen 3.6-35B-A3B Q8_0 GGUF (~36.9 GB) from the canonical
# ggml-org HF repo (no token required). hf_transfer is used for parallel-chunked pulls.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ ! -d venv ]]; then
    uv venv --python 3.12 venv
fi
# shellcheck disable=SC1091
source venv/Scripts/activate
uv pip install -q huggingface_hub openai hf_transfer

export HF_HUB_ENABLE_HF_TRANSFER=1
hf download ggml-org/Qwen3.6-35B-A3B-GGUF Qwen3.6-35B-A3B-Q8_0.gguf --local-dir ./models
echo "Model ready at ./models/Qwen3.6-35B-A3B-Q8_0.gguf"

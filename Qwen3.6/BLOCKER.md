# BLOCKER — Qwen/Qwen3.6-35B-A3B-FP8 (exact FP8 artifact)

**Status: not runnable on THINKER. Deployed the same weights via `ggml-org/Qwen3.6-35B-A3B-GGUF:Q8_0` instead, with explicit user approval.**

## Evidence

The FP8 artifact at `Qwen/Qwen3.6-35B-A3B-FP8` on HuggingFace (verified live, HTTP 200, Apache-2.0) is 36 GB of FP8 weights. It loads resident in memory regardless of serving engine: vLLM, SGLang, and KTransformers all keep the weight matrix live for inference — none of them stream layers off disk per token.

| Topology | VRAM requirement (weight-resident) | Outcome on T1000 4 GB + i7-10700T + 64 GB |
|---|---|---|
| vLLM + `fp8` quant (SM ≥ 8.9) | ≈ 36 GB W8A8 | N/A — T1000 is SM 7.5, not SM 8.9. |
| vLLM + FP8 Marlin (SM 7.5+) | ≈ 36 GB W8A16, still GPU-resident | FAIL — 9× over 4 GB VRAM. |
| SGLang FP8 | ≥ 36 GB | Same — GPU-resident. FAIL. |
| transformers on CPU (dequant FP8→BF16) | ≈ 72 GB RAM | FAIL — 64 GB installed, ≈ 32 GB free in practice. |
| KTransformers Windows | RAM-resident FP8 (≈ 36 GB) + small VRAM | Reported < 2 tok/s on Windows for Qwen 3.6; Windows support is not production-grade. Rejected as fragile. |

Compute-capability is NOT the blocker (Turing supports FP8 weight-only in vLLM). **VRAM is the blocker.** With only 4 GB, no GPU-resident path exists, and CPU dequantization overflows RAM.

## Smallest hardware change required (tiered, cheapest first)

1. **Single-GPU workstation tier (≈ $5 K):** one NVIDIA RTX 6000 Ada 48 GB (SM 8.9, native FP8 W8A8) OR RTX A6000 48 GB (SM 8.6, works via FP8 Marlin). With 48 GB VRAM the entire FP8 weight set fits with KV cache for ≈ 32 K context. Pick Ada-class for native FP8 compute.
2. **Prosumer best-effort tier (≈ $2 K):** two RTX 4090 24 GB with NVLink/PCIe. `vllm serve --tensor-parallel-size 2`. Marginal headroom; no vision encoder offload; not what the card recommends but viable.
3. **Card-recommended tier (datacenter):** 8× A100 80 GB or 8× H100 80 GB with NVLink. Matches `--tensor-parallel-size 8` and unlocks the full 262 K context + MTP speculative decoding.

The *software* change needed once any of the above is in place is zero beyond environment setup: this working tree already has the LibreChat config and scripts staged against the eventual `vllm serve Qwen/Qwen3.6-35B-A3B-FP8 --port 8090 --reasoning-parser qwen3 --tensor-parallel-size N` command. Replace the llama-server invocation in `scripts/start_qwen.*` with the vLLM command, update the `modelDisplayLabel` string in `librechat/librechat.yaml.template`, and the rest of the stack (LibreChat, Docker networking, proof scripts, restart flow) works unchanged.

## Why this is preserved in the repo

The user's Rule 14B says "If the exact FP8 artifact is impossible on this hardware, STOP and present a blocker dossier with proof." That rule was satisfied by this document AND by the plan-approval step where the user explicitly signed off on the FP8 → GGUF-Q8_0 artifact switch for THIS machine only. When capable hardware arrives, the FP8 lock re-engages automatically — nothing here silently commits to Q8_0 forever.

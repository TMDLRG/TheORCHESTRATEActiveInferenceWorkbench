# BENCHMARKS

## Context-size sweep (the 500 K escalation)

All three configs share: `--n-cpu-moe 999 -ngl 20 --flash-attn on --parallel 1`, same Q8_0 GGUF, single-user workload. Differences are context size, KV cache dtype, YaRN, and KV-offload policy.

| Config | ctx | KV dtype | KV offload | YaRN | KV cache RAM | Reasoning-ON prompt eval (tok/s) | Reasoning-ON generation (tok/s) | Notes |
|---|---:|---|---|---|---:|---:|---:|---|
| Original 8K | 8 192 | fp16 | GPU (default) | — | 0.16 GB | 19.25 | 6.14 | pre-sweep baseline |
| **500K (current default)** | **524 288** | **q8_0** | **CPU** | **yarn, scale 2.0** | **5.32 GB** | **18.32** | **5.76** | 64× context for a 6 % gen-speed cost |
| 500K (pre-tune, `--parallel 4` default) | 524 288 | q8_0 | CPU | yarn, scale 2.0 | 5.32 GB | 10.2 | **0.6** | 4-slot default splits context and destroys gen speed |

**Why the huge swing between the two 500K configs:** without `--parallel 1`, llama-server allocates 4 slots and treats the model as multi-tenant. That disables the fused Gated Delta Net (chunked) kernel and pessimises per-token compute. Explicit `--parallel 1` brings it back — chunked DeltaNet lit up, generation rate snaps back to essentially the 8K baseline. Do **not** raise `--parallel` unless you actually need concurrent conversations.

## Earlier baseline sweep (-ngl)

Collected at ctx 8 192, fp16 KV, to decide whether the tiny T1000 is worth using at all.

| Config | Prompt eval tok/s | Generation tok/s | Winner |
|---|---:|---:|---|
| `-ngl 20` (T1000 assist) | 19.25 | 6.14 | **kept** |
| `-ngl 0` (pure CPU) | 14.03 | 4.26 | — |
| Δ | +37 % | +44 % | T1000 offload is a real 1.4× despite only 4 GB VRAM. |

## Memory fit at the 500 K config

From the `sched_reserve` log on the current running server:

| Buffer | Size | Location |
|---|---:|---|
| Model weights (mmap) | 34 666.71 MiB | CPU |
| Model weights (offloaded) | 1 232.08 MiB | CUDA0 |
| KV cache (q8_0, 10 attn layers, 524 288 cells) | 5 440 MiB | CPU (`--no-kv-offload`) |
| Recurrent state (Gated Delta Net) | 62.81 MiB | CPU |
| CUDA compute buffer | 2 125 MiB | CUDA0 |
| CUDA_Host compute buffer | 1 044 MiB | CPU |
| **Total llama-server working set** | **~ 44.6 GB RSS** | (model mmap pages in on demand) |

Leaving ~15–18 GB for OS + Docker + apps. Comfortable single-user headroom.

## Per-slot context cap — honest caveat

`llama-server` logs `n_ctx_slot = 262144` per request even though total `n_ctx = 524288` and the KV cache is sized for 524288 cells. The cap equals the model's native `n_ctx_train`. In practice this means **a single prompt+response pair can span up to 262 144 tokens**; the extra KV room covers conversation growth and context prefix preservation across turns, not a single-shot 500 K prompt. This is a llama.cpp b8838 behavior we did not find a flag to override short of patching the server. For typical LibreChat usage (conversation history, long documents), 262 K per exchange is already 32× the previous 8 K cap.

If you later need single-shot > 262 K prompts, options:
1. Patch `llama-server`'s slot-initialization code to accept a `--slot-ctx` override.
2. Switch to `llama-cli` (CLI mode allows the full n_ctx as one prompt).
3. Chain requests via LibreChat's prompt-and-retrieve flow so each turn's context stays ≤ 262 K.

## Prompt-eval reality check at large context

At ~18 tok/s prompt evaluation on this CPU, a hypothetical single 500 K-token prompt would take ≈ 7.7 hours just to ingest. The **practical** value of the 500 K config is:
- Retaining conversation history across very long sessions without truncation.
- Pasting big documents (tens of thousands of tokens) without hitting the 8 K wall.
- Not needing to rebuild the server when an occasional long input arrives.
- NOT as an always-on 500 K single-shot mode. Bring the ctx back down to 65 536 or 131 072 if you want maximum responsiveness for typical chats.

## Open tuning, not chased further

- `--cache-type-k q4_0 --cache-type-v q4_0`: halves KV-cache RAM to ~2.6 GB at a quality hit; could push ctx to ~1 M.
- `-ngl 24` / `-ngl 28`: CUDA compute buffer at 500 K is already 2.1 GB of 4 GB VRAM, so raising ngl here likely OOMs. Safe to try only with lower ctx.
- Speculative decoding (`qwen3_next_mtp` from the HF card): a vLLM/SGLang feature; llama.cpp has no equivalent for this model as of b8838.

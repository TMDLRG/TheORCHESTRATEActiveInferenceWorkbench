# RUNTIME_DECISION

## Candidates considered

Four serving paths were evaluated against the target model (`Qwen/Qwen3.6-35B-A3B-FP8`, a ~36 GB FP8 MoE with 3 B active params) and this machine (4 GB VRAM on a Turing T1000, 64 GB RAM, i7-10700T).

| Runtime | Exact FP8 artifact? | VRAM needed | Fit on this box | Verdict |
|---|---|---|---|---|
| **vLLM** | Yes, W8A16 Marlin on SM 7.5 | ≥ 36 GB weight-resident | 9× VRAM shortfall; vLLM does not do mid-inference CPU offload | REJECT |
| **SGLang** | Yes, FP8 support via torchao | ≥ 36 GB | Same shortfall as vLLM | REJECT |
| **KTransformers** | Partial FP8 support; MoE-aware CPU+GPU split | RAM for FP8-resident weights (≈ 36 GB) + small VRAM for attention | Fits in RAM but FP8 pathway for Qwen 3.6 Thinking specifically is immature; Windows support weaker than Linux | REJECT (fragile on Windows; benchmarks report <2 tok/s) |
| **llama.cpp / llama-server** | No (FP8 safetensors not consumed; reads GGUF of same weights) | GGUF resident in RAM; any VRAM bonus via `-ngl` + `--n-cpu-moe` | Clean fit at Q8_0 (34.4 GB) with ≈ 30 GB RAM headroom; warmed up cleanly on CUDA 12.4 build | **CHOSEN** |

## FP8 artifact is not viable on this hardware

- vLLM FP8 support on Turing is **weight-only W8A16 via FP8 Marlin** (verified against the vLLM FP8 docs). Compute capability is not the blocker — memory is.
- 36 GB of FP8 weights vs 4 GB of VRAM is a 9× shortfall; no serving engine streams weights from CPU per-layer during active inference.
- CPU fallback via transformers dequantizes FP8 → BF16 at load, doubling footprint to ≈ 72 GB, which overruns the 64 GB installed (and ≈ 32 GB currently free) RAM budget.
- KTransformers does MoE-aware CPU+GPU split specifically for this regime, but its Qwen 3.6 FP8 pathway on Windows is not production-ready; published community benchmarks show < 2 tok/s with OOM risk under load.

See `BLOCKER.md` for the smallest hardware change that unlocks each tier.

## llama.cpp / llama-server was the only viable path

Same underlying Qwen 3.6-35B-A3B weights, different quantization format (GGUF). Canonical build: **`ggml-org/Qwen3.6-35B-A3B-GGUF`** — the llama.cpp maintainers' own conversion. Only Q8_0 (34.4 GB) and BF16 (64.6 GB) are published there; no Q4_K_M. **Q8_0 was selected** because:
- 34.4 GB comfortably fits in 64 GB RAM with ≈ 30 GB headroom for KV cache + OS + Docker.
- Q8_0 preserves ~99 % of the FP16 quality (within 0.1–0.2 MMLU points for most models), a better fidelity-vs-speed tradeoff than Q4_K_M at the same footprint class.
- Canonical source = no trust-in-quantizer risk.
- BF16 (64.6 GB) was ruled out: it fits on disk but requires the full RAM budget to be allocatable simultaneously and would thrash with LibreChat's Mongo/Meili/Vector containers co-resident.

## Runtime configuration choices

| Flag | Value | Why |
|---|---|---|
| `--jinja` | on | Enables Qwen 3.6's Jinja chat template so `chat_template_kwargs` can toggle `enable_thinking` per-request. Without this, thinking mode cannot be toggled via the API. |
| `--n-cpu-moe 999` | 999 | Keep all MoE expert tensors on CPU (total experts: 256; active per token: 8+1). 3 B active params means per-token bandwidth ≈ 3 GB, comfortable on DDR4. |
| `-ngl 20` | 20 of 40 | Offload the non-expert portion (attention, norms, routing) of the first 20 layers to the T1000. Sized empirically so CUDA buffer stays ≤ 1.3 GB, leaving VRAM headroom for KV + compute buffers. |
| `--ctx-size 524288` | 524 288 | 500 K+ context. Paired with YaRN extension (see below) and q8_0 KV cache on CPU to fit ~5.3 GB of KV in RAM instead of 10.7 GB. `llama-server` still caps a single prompt/response at `n_ctx_slot = 262144` (native train length) — 32× the original 8 K. See BENCHMARKS.md. |
| `--parallel 1` | 1 | Single-slot server. Required for the fused Gated Delta Net (chunked) kernel to activate, which is what keeps generation at ~5.8 tok/s even with 500 K KV allocated. Default 4-slot mode destroys gen speed (0.6 tok/s). |
| `--cache-type-k q8_0 --cache-type-v q8_0` | q8_0 | Halves KV-cache memory vs default fp16. Quality loss is negligible for K/V; this is the standard long-context trick. |
| `--flash-attn on` | explicit | Required for q8_0 KV cache; also enables chunked-path optimizations. |
| `--no-kv-offload` | — | KV cache stays entirely in system RAM. 5.3 GB of KV would otherwise try to sit on the 4 GB T1000 and OOM. |
| `--rope-scaling yarn --rope-scale 2.0 --yarn-orig-ctx 262144` | — | YaRN extension to double the native 262 144 context up to the 524 288 target. Matches the config.json override suggested in the HF model card. |
| `--host 0.0.0.0` | — | Docker-hosted LibreChat reaches us via `host.docker.internal:host-gateway`, which requires the service to bind the host's routable interfaces, not just 127.0.0.1. Windows Defender Firewall blocks external access by default on this LAN profile; no separate ACL change was made. |
| `--alias Qwen3.6-35B-A3B-Q8_0` | — | Stable model ID exposed to LibreChat via `/v1/models`. |
| `--metrics` | on | `/metrics` Prometheus endpoint for later benchmarking. |

## Binary selection

llama.cpp ships four Windows flavors: cpu-x64, cuda-12.4, cuda-13.1, vulkan. Three were tested:

| Build | Outcome |
|---|---|
| `cuda-13.1` | **FAIL** — `CUDA error: the provided PTX was compiled with an unsupported toolchain`. The driver (581.42) bundles CUDA runtime 13.0; the cuda-13.1 build's PTX needs 13.1+. |
| `cuda-12.4` | **PASS** — loads, detects T1000 at compute 7.5, runs warmup. Chosen. |
| `vulkan-x64` | Not tested — kept in reserve as fallback for when CUDA compatibility breaks on driver updates. Also works on the Intel UHD 630. |

The chosen `llama.cpp-bin\llama-server.exe` reports: `version: 8838 (23b8cc499), built with Clang 19.1.5 for Windows x86_64`.

## Alternatives I will NOT silently substitute

- **Qwen 3.5** (ruled out by user at job start).
- **Any community-quantized GGUF** (`bombman/`, `mradermacher/`, `bartowski/`, `unsloth/` etc.) — the `ggml-org/` build is canonical; community quants were not needed.
- **A different base model** (e.g. Qwen 3-Thinking, Qwen 3-Coder) — explicit no-go.
- **Cloud inference** (vertex, runpod, modal) — explicit out-of-scope.

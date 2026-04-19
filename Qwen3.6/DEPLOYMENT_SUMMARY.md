# DEPLOYMENT_SUMMARY

Local deployment of **Qwen 3.6-35B-A3B** (Q8_0 GGUF conversion of the same underlying weights as the user-requested `Qwen/Qwen3.6-35B-A3B-FP8`) wired into **LibreChat v0.8.5-rc1**, with reasoning mode and direct mode both proven end-to-end through the UI and the OpenAI-compatible API.

See `BLOCKER.md` for why the FP8 artifact itself can't run on this hardware and what it would take to re-enable the FP8 lock.

## Installed components

| Component | Version | Path |
|---|---|---|
| llama.cpp (pre-built Windows CUDA 12.4) | b8838 (commit `23b8cc499`, Clang 19.1.5) | `llama.cpp-bin/llama-server.exe` |
| cudart 12.4 runtime DLLs | shipped by ggml-org | `llama.cpp-bin/cudart64_12.dll` + cublas |
| Qwen 3.6-35B-A3B Q8_0 GGUF | from `ggml-org/Qwen3.6-35B-A3B-GGUF` | `models/Qwen3.6-35B-A3B-Q8_0.gguf` (36.90 GB) |
| Python venv (uv) | Python 3.12.10 | `venv/` |
| `huggingface_hub[cli]` | 1.11.0 | venv |
| `hf_transfer` | latest | venv (enabled via `HF_HUB_ENABLE_HF_TRANSFER=1`) |
| `openai` (SDK) | 2.32.0 | venv |
| LibreChat | v0.8.5-rc1 (shallow clone, `main`) | `librechat/` |
| Docker images | LibreChat v0.8.5-rc1, MongoDB 8.0.20, Meilisearch 1.35.1, pgvector 0.8.0, rag_api | pulled via `docker compose pull` |

## Runtime topology

```
┌──────────────────────────────┐        ┌───────────────────────────────────┐
│ Windows host                 │        │ Docker containers (LibreChat net) │
│                              │        │                                   │
│  llama-server.exe            │◀──┐    │   LibreChat  (api, port 3080)     │
│    -m models/...Q8_0.gguf    │   │    │   chat-mongodb                    │
│    --port 8090 (dynamic)     │   │    │   chat-meilisearch                │
│    --n-cpu-moe 999           │   └────│   vectordb                        │
│    -ngl 20 (T1000 assist)    │  host.docker.internal:host-gateway         │
│    --jinja --alias Qwen3.6…  │        │   rag_api                         │
└──────────────────────────────┘        └───────────────────────────────────┘
  ^                                        ^
  │  direct /v1 API                        │  browser / UI
  │                                        │
  └─ scripts/test_qwen_api.*               └─ http://localhost:3080
```

## Deployment steps (in the order they were executed)

1. Hardware/OS audit (read-only, see `HARDWARE_AUDIT.md`).
2. Downloaded llama.cpp b8838 CUDA 13.1 zips → **rejected** (PTX incompatible with driver 581.42 / CUDA 13.0 runtime).
3. Downloaded llama.cpp b8838 CUDA 12.4 zips → loaded, CUDA backend initialized, T1000 detected at SM 7.5.
4. `uv venv --python 3.12 venv`, installed `huggingface_hub`, `hf_transfer`, `openai`.
5. `hf download ggml-org/Qwen3.6-35B-A3B-GGUF Qwen3.6-35B-A3B-Q8_0.gguf --local-dir ./models` — 36.9 GB, resumable, no HF token required.
6. `scripts/start_qwen.ps1` — dynamic port scan (picked 8090), launched llama-server, regenerated `librechat/librechat.yaml` from template with live port, waited for `/v1/models` to respond.
7. Smoke tests: `scripts/test_qwen_api.sh` (curl) and `scripts/test_qwen_api.py` (OpenAI SDK). Both PASS:
   - `GET /v1/models` returns `Qwen3.6-35B-A3B-Q8_0`.
   - Reasoning mode (`chat_template_kwargs.enable_thinking: true`) populates `reasoning_content` with chain-of-thought; final `content` has answer `391`.
   - Direct mode (`enable_thinking: false`) returns `Paris` with no reasoning content.
8. `git clone https://github.com/danny-avila/LibreChat librechat`, seeded `.env` (JWT / CREDS / MEILI secrets regenerated, `ENDPOINTS=custom`), wrote `docker-compose.override.yml` (mounts `librechat.yaml`, adds `host.docker.internal:host-gateway`).
9. `docker compose -p librechat pull` + `up -d` — all 5 containers (api, mongodb, meilisearch, vectordb, rag_api) healthy.
10. Verified `/api/endpoints` returns "Qwen 3.6 Reasoning" + "Qwen 3.6 Direct"; `/api/models` returns `["Qwen3.6-35B-A3B-Q8_0"]` under each; confirms LibreChat's container reached the host llama-server via `host.docker.internal:8090`.
11. Direct container-to-host proof: `docker exec LibreChat curl host.docker.internal:8090/v1/chat/completions` returned a normal completion.
12. **UI proof** (Chrome-in-Claude browser automation):
    - Direct preset → "What is the capital of France?" → **"Paris"** rendered; llama-server logged `POST /v1/chat/completions 127.0.0.1 200`.
    - Reasoning preset → "What is 17 × 23?" → UI shows **"Thinking..." collapsible with chain-of-thought**, final answer **"391"**; llama-server logged another 200.
    - LibreChat natively renders `reasoning_content` as a collapsible "Thinking..." block with a "Copy thoughts to clipboard" button.
13. Benchmarked baseline vs `-ngl 0` variant (see `BENCHMARKS.md`); baseline wins, kept.

## Config files actually written / changed

- `librechat/.env` — 30 358 bytes, from `.env.example`, with regenerated `CREDS_KEY`/`CREDS_IV`/`JWT_SECRET`/`JWT_REFRESH_SECRET`/`MEILI_MASTER_KEY` and `ENDPOINTS=custom`, `DEBUG_CONSOLE=true`, `DEBUG_OPENAI=true` appended.
- `librechat/librechat.yaml.template` — authoritative template with `__PORT__` placeholder; two custom endpoints + two modelSpecs.
- `librechat/librechat.yaml` — generated from the template on every `start_qwen.*`; points at whichever port llama-server bound to.
- `librechat/docker-compose.override.yml` — mounts the yaml into the api container, ensures `extra_hosts: host.docker.internal:host-gateway`.
- `scripts/*.ps1` (PowerShell) and `scripts/*.sh` (bash) — dynamic port, start/stop/restart/download/test.

## Validation captured

- `logs/api-proof.txt` — full curl response bodies for /v1/models + both chat modes.
- `logs/api-proof.py.txt` — Python SDK proof summary.
- `logs/librechat-server.log` — llama-server's main log.
- `logs/llama-server.stderr.log` — CUDA init + model load details.
- LibreChat docker logs show "Qwen 3.6 Reasoning" + "Qwen 3.6 Direct" endpoints loaded and both modelSpecs registered.
- llama-server `/v1/chat/completions` access log shows 200 OK from `127.0.0.1` (Docker-NAT'd LibreChat) for both the direct-mode "Paris" test and the reasoning-mode "391" test.

## Known limitations on this hardware

- ~5.8 tok/s generation at **524 288** ctx (current default, q8_0 KV, YaRN-extended) — essentially matches the 8 K baseline thanks to the fused Gated Delta Net (chunked) kernel. Drop ctx to 65 536–131 072 if you want the very last tenth of a tok/s for short chats.
- `llama-server` caps a single prompt+response exchange at `n_ctx_slot = 262 144` even with `n_ctx = 524 288` allocated. Multi-turn conversations can keep adding history up to the full 524 288. See BENCHMARKS.md for detail.
- Speculative decoding (`qwen3_next_mtp`) not available in llama.cpp for this model as of b8838.
- Port 8000 is held by another Docker service (`orchestrate-agile-mcp-app`); dynamic port scan picked 8090. If you free 8000 and prefer it, edit `START_PORT` in the start scripts.

## Next-run experience

```powershell
# From scratch (machine rebooted, nothing running)
cd C:\Users\mpolz\Documents\Qwen3.6
.\scripts\restart_all.ps1
# Browser → http://localhost:3080
```

or piecewise:

```powershell
.\scripts\start_qwen.ps1                              # start model server
.\scripts\test_qwen_api.sh                             # direct API proof (bash)
docker compose -p librechat -f librechat\docker-compose.yml -f librechat\docker-compose.override.yml up -d
```

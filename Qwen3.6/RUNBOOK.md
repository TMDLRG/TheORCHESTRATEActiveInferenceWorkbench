# RUNBOOK

## One-command restart

```powershell
cd C:\Users\mpolz\Documents\Qwen3.6
.\scripts\restart_all.ps1
```

This stops any running llama-server + LibreChat stack, starts llama-server on the first free port ≥ 8090, regenerates `librechat/librechat.yaml` with that port, and `docker compose up -d`'s LibreChat.

Open `http://localhost:3080` in your browser. Two presets in the picker: **Qwen 3.6 · Direct** and **Qwen 3.6 · Reasoning**.

## Manual start

```powershell
# default: ctx 524288 (YaRN-extended), q8_0 KV on CPU, -ngl 20, scan from 8090
.\scripts\start_qwen.ps1

# smaller context for maximum responsiveness
.\scripts\start_qwen.ps1 -CtxSize 65536 -NoYarn      # 64 K, no YaRN needed
.\scripts\start_qwen.ps1 -CtxSize 131072 -NoYarn     # 128 K
.\scripts\start_qwen.ps1 -CtxSize 262144 -NoYarn     # 256 K, native limit

# even longer, at a quality cost
.\scripts\start_qwen.ps1 -CtxSize 1048576 -KvCacheType q4_0     # 1 M ctx, q4 KV

# port override
.\scripts\start_qwen.ps1 -StartPort 8200

cd librechat
docker compose -p librechat up -d
```

**Context size reality check.** The default 524 288-ctx config allocates 5.3 GB of KV cache so sessions can grow huge — but `llama-server` caps a *single* prompt/response pair at `n_ctx_slot = 262144` (the model's native train length). That's still 32× the original 8 K wall. See BENCHMARKS.md for the detail.

**Output-length caps (max_tokens).** The modelSpec presets ship with:
- `Qwen 3.6 · Reasoning`: `max_tokens: 81920` (Qwen card's recommendation for complex math/code)
- `Qwen 3.6 · Direct`: `max_tokens: 32768`

Both are also mirrored in the endpoint-level `addParams` so they apply even when the user doesn't pick a preset. Lower them via the Parameters panel in the UI if you want shorter responses or faster aborts. Raising them beyond `n_ctx_slot` (262 144) has no effect — the slot cap wins.

bash/WSL equivalent:

```bash
bash scripts/start_qwen.sh
(cd librechat && docker compose -p librechat up -d)
```

## Stop

```powershell
.\scripts\stop_qwen.ps1
cd librechat
docker compose -p librechat down
```

## Smoke tests

```bash
# Direct API (curl): /v1/models + reasoning + direct
bash scripts/test_qwen_api.sh

# Direct API (Python SDK): asserts both modes
source venv/Scripts/activate
python scripts/test_qwen_api.py
```

Expected PASS lines:
```
PASS: reasoning response populated reasoning_content
PASS: direct mode returned 'Paris'
```

Python SDK version:
```
PASS: reasoning produced reasoning_content + answer 391
PASS: direct mode with no reasoning_content, answered Paris
```

## LibreChat login

First-time: click **Register**, create a user. The first registered user becomes an ADMIN.

If you get a stale "temporarily banned" message after mucking with the API during development, clear it:

```bash
docker exec chat-mongodb mongosh LibreChat --quiet --eval 'db.users.deleteMany({}); db.sessions.deleteMany({}); db.logs.deleteMany({})'
docker restart LibreChat
```

## Tail logs

```powershell
Get-Content -Wait logs\llama-server.log           # model server
docker compose -p librechat logs -f api           # LibreChat application log
docker compose -p librechat logs -f meilisearch   # search
```

The llama-server log reports per-request timing in its response JSON. Look at `timings.prompt_per_second` (how fast the prompt is eaten) and `timings.predicted_per_second` (generation rate).

## Port management

- Default: llama-server scans upward from `8090`.
- If 8090 is busy (common when you re-run `start_qwen` before `stop_qwen` releases the socket), the script auto-picks 8091, 8092, etc.
- The selected port is written to `.qwen_port` at repo root and substituted into `librechat/librechat.yaml` by replacing `__PORT__` in `librechat.yaml.template`.
- If the port changes, restart LibreChat so it reloads the yaml: `docker restart LibreChat`.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `CUDA error: the provided PTX was compiled with an unsupported toolchain` | Wrong llama.cpp binary (cuda-13.x built for a newer driver than installed) | Use the CUDA 12.4 build currently installed. Confirm with `llama.cpp-bin\llama-server.exe --version`. |
| Server warmup takes > 5 min | First load is cold OS cache; mmap'ing 36 GB off disk takes time. | Wait. Subsequent loads are seconds. |
| LibreChat shows "Endpoint not found" | `librechat.yaml` not mounted, or `docker compose up` was run without the override | Check `librechat/docker-compose.override.yml` is next to `docker-compose.yml` and compose picks it up. |
| LibreChat chats show no response | Port mismatch between `librechat.yaml` and the currently-running llama-server | `cat .qwen_port` and `grep baseURL librechat/librechat.yaml` should match. If not: `.\scripts\stop_qwen.ps1; .\scripts\start_qwen.ps1; docker restart LibreChat`. |
| "Your account has been temporarily banned" | LibreChat's in-memory violation tracker got triggered by a malformed request | Delete the user row + restart LibreChat (see "LibreChat login" above). |
| Out-of-memory during inference | Context too high for 64 GB host or `-ngl` pushed too many layers into 4 GB VRAM | Lower `--ctx-size` to 4096, or `-ngl` to 10. |

## Adding an MCP server

Local-address SSRF allowlist is already configured — `localhost`, `127.0.0.1`, `host.docker.internal`, `172.17.0.1` (Docker bridge), `10.0.0.39` (this machine's current LAN IP), plus wildcard `*.local` / `*.internal` / `*.lan` / `*.home.arpa`. Matcher is exact-hostname or `*.suffix`; CIDR is NOT supported — add extra private IPs explicitly in `librechat/librechat.yaml.template` under `mcpSettings.allowedDomains`.

### Wire up a remote-transport MCP server (SSE / WS / HTTP)

Two ways:

1. **Static config (recommended for a always-on server).** Uncomment and edit the `mcpServers` block in `librechat/librechat.yaml.template`, then re-run `.\scripts\start_qwen.ps1` (regenerates the yaml) and `docker restart LibreChat`. Example:
   ```yaml
   mcpServers:
     local-fs:
       type: sse
       url: http://host.docker.internal:3100/sse
       timeout: 60000
   ```

2. **UI-based (per-user).** Open LibreChat → sidebar → MCP Settings → add server. Enter a URL using any host on the allowlist (`http://host.docker.internal:<port>/...`). The SSRF check is enforced server-side before the connection opens.

### Wire up a stdio MCP server (e.g. npx-launched)

Stdio servers don't traverse the SSRF allowlist — they're spawned as child processes of the LibreChat container. Caveat: the LibreChat container's node image is Alpine, without npx/python pre-installed globally. Either:
- Run the stdio server on the host and wrap it as an SSE server (then add via the allowlist above), or
- Use a docker-in-docker pattern (not covered here).

### Troubleshooting the allowlist

If an MCP connect fails with `Domain not in allowlist`, grep the LibreChat logs for the exact hostname it tried to resolve and add that literal string to `mcpSettings.allowedDomains`. Do NOT attempt CIDR — the matcher ignores it.

### Orchestrate MCP server — blocked by server-side JSON-RPC bug

Configured in `librechat/librechat.yaml.template` under `mcpServers.orchestrate`, pointing at `http://host.docker.internal:9001/sse` with `Authorization: Bearer ${ORCHESTRATE_MCP_API_KEY}` (key in `librechat/.env`). Connectivity is good (auth accepted, SSE opens, POST /messages?sessionId returns 202, JSON-RPC response delivered over SSE), but the Orchestrate server's `initialize` response is missing the required JSON-RPC `id` field — so LibreChat's MCP SDK rejects it with `invalid_union` and refuses to register the server.

Repro against the running server:
```bash
bash scripts/test_orchestrate_mcp.sh
```
Exits 2 with `FAIL: response is missing the JSON-RPC id (bug)` until the server fix lands. Once every response echoes the request id, the script exits 0 and LibreChat will finish the MCP handshake on its next restart.

Fix needed on the Orchestrate side (applies to every request-type RPC — `initialize`, `tools/list`, `tools/call`, `resources/list`, `prompts/list`, etc. — notifications are the only exception):
```json
{"jsonrpc": "2.0", "id": <request_id>, "result": {...}}
```

### Verifying the allowlist is live

```bash
bash scripts/verify_mcp_allowlist.sh
```

Calls the same `isMCPDomainAllowed` function the running LibreChat uses, inside the running container, against the allowlist parsed from the mounted `/app/librechat.yaml`. Exits non-zero if any assertion fails. Re-run after any config change.

## Upgrading

- **llama.cpp**: replace `llama.cpp-bin/` with a newer release zip. Stick to `cuda-12.4` until the NVIDIA driver is refreshed. `.\scripts\stop_qwen.ps1; unzip …; .\scripts\start_qwen.ps1`.
- **LibreChat**: `cd librechat; git pull; docker compose -p librechat pull; docker compose -p librechat up -d --force-recreate`.
- **Qwen 3.6 model**: if Qwen adds a new quant to `ggml-org/Qwen3.6-35B-A3B-GGUF`, run `.\scripts\download_model.ps1` (it calls `hf download` on the specific file). To switch quants, update `Quant` parameter and the `models.default` entry in `librechat.yaml.template`.

## Reference

- Model card (FP8 target): https://huggingface.co/Qwen/Qwen3.6-35B-A3B-FP8
- GGUF repo used: https://huggingface.co/ggml-org/Qwen3.6-35B-A3B-GGUF
- LibreChat: https://github.com/danny-avila/LibreChat
- llama.cpp: https://github.com/ggml-org/llama.cpp

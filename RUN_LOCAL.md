# Active Inference Masterclass — Run Local

One script spins up every service the suite needs.  No barriers — if something fails, the UI degrades gracefully and tells you the exact command to fix it.

## Quick start

```bash
# from repo root
./scripts/start_suite.sh      # macOS / Linux / Git-Bash
./scripts/start_suite.ps1     # Windows PowerShell
```

The launcher boots four services in order, with a readiness check between each:

| Step | Service | Port | Health URL |
|------|---------|------|------------|
| 1/4 | **Qwen 3.6** (llama.cpp) | 8090 | `http://127.0.0.1:8090/v1/models` |
| 2a/4 | **Speech HTTP TTS** (browser narration) | 7712 | `http://127.0.0.1:7712/healthz` |
| 2b/4 | **Speech MCP** (SSE transport for LibreChat) | 7711 | `http://127.0.0.1:7711/sse` |
| 3/4 | **LibreChat Docker stack** (+ MongoDB, pgvector, Meilisearch, rag_api) | 3080 | `http://127.0.0.1:3080/` |
| 4/4 | **Phoenix Workbench** | 4000 | `http://127.0.0.1:4000/` |

When everything is live, the launcher prints:

```
=================================================
 Active Inference Masterclass is live.
=================================================
  Learn hub         : http://127.0.0.1:4000/learn
  Workbench         : http://127.0.0.1:4000/
  Full chat         : http://127.0.0.1:3080/
  Qwen API          : http://127.0.0.1:8090/v1/models
  Speech TTS (HTTP) : http://127.0.0.1:7712/healthz
  Speech MCP (SSE)  : http://127.0.0.1:7711/sse

  Logs              : scripts/.suite/logs/
  Stop              : ./scripts/stop_suite.sh
```

## Stop

```bash
./scripts/stop_suite.sh
./scripts/stop_suite.ps1
```

## What each service does

### Qwen 3.6 — `Qwen3.6/`
Local 36 GB model served by `llama.cpp`'s OpenAI-compatible API on port 8090.  Used by:
- The embedded **Ask Qwen** uber-help drawer (bottom-right on every page).
- **LibreChat** as the default endpoint (`Qwen 3.6 · Direct` and `Qwen 3.6 · Reasoning`).

Cold start: first boot loads the Q8 weights (~2 minutes).  Subsequent starts are instant because the launcher notices Qwen is already up.

### Speech HTTP TTS — `ClaudeSpeak/claude-voice-connector-http/server.py`
FastAPI wrapper over Piper TTS.  `POST /speak → audio/wav` bytes.  Used by the **Narrator** button on every session page (browser plays the returned WAV).  Falls back to the browser's Web Speech API if offline.

### Speech MCP (SSE) — `ClaudeSpeak/claude-voice-connector-http/mcp_sse_server.py`
Pure ASGI MCP server exposing `speak`, `stop_speaking`, and `list_voices` over SSE at `/sse`.  LibreChat (running inside Docker) reaches it via `host.docker.internal:7711`.  Registered in `librechat.yaml` under `mcpServers.claude_speak`.

### LibreChat — `Qwen3.6/librechat/`
Docker Compose stack: LibreChat Express app + MongoDB + pgvector + Meilisearch + rag_api.  Connected to Qwen as a custom OpenAI-compatible endpoint; MCP servers (orchestrate + claude_speak) are registered and tool-calling works end-to-end.

### Phoenix Workbench — `active_inference/apps/workbench_web/`
The learning-suite Phoenix app.  Hosts the 10-chapter curriculum, 39 sessions, 7 Learning Labs, progress tracker, and the embedded Qwen uber-help drawer.

## Suite URLs

| Surface | URL | Notes |
|---------|-----|-------|
| **Learn hub** | `/learn` | 11-chapter grid + path picker + Labs index |
| **Chapter page** | `/learn/chapter/:num` | Session list + full-chapter podcast + narrate button |
| **Session page** | `/learn/session/:num/:slug` | Path-specific narration, excerpt, figures, podcast segment, labs, Workbench, concepts, quiz, Qwen button |
| **Chat bridge** | `/learn/chat-bridge/session/:num/:slug` | Builds a rich starter prompt and opens LibreChat in a new tab with `?prompt=` pre-filled |
| **Progress** | `/learn/progress` | Heatmap of completed sessions |
| **Learning Labs** | `/learninglabs/:file.html?path=…&beat=…` | 7 standalone sim labs with path + beat URL params honored by the Shell |
| **Chat proxy** | `/chat` | Bounces to LibreChat in a new tab and returns you to `/learn` |
| **Speech** | `/speech/speak` (POST), `/speech/voices`, `/speech/healthz`, `/speech/narrate/chapter/:num` | Reverse-proxies the HTTP TTS; graceful 503 when offline |
| **Uber-help** | `/api/uber-help` (POST) | Context-aware tutor; includes session excerpt + glossary + chapter metadata in every request |
| **Workbench** | `/`, `/equations`, `/models`, `/world`, `/builder/new`, `/guide`, `/glass`, `/labs` | Existing Jido-agent IDE surfaces |

## Graceful degradation

The launcher is tolerant — if a service isn't available, the UI still works:

- **Qwen offline** → uber-help drawer shows a “Start Qwen: …” message.
- **Speech HTTP offline** → Narrator falls back to browser Web Speech API.
- **Speech MCP offline** → LibreChat shows `claude_speak` as disconnected; voice tools unavailable in the chat.
- **LibreChat offline** → Full-chat link shows a styled offline page with a copy-paste `docker compose up` command.
- **LibreChat without Docker** → launcher prints a yellow warning and continues.

## First-run setup (one-time)

1. Clone the repo and the sub-repos at `Qwen3.6/` and `ClaudeSpeak/`.
2. Install the Qwen model weights per `Qwen3.6/README.md`.
3. Install ClaudeSpeak's venv:
   ```bash
   cd ClaudeSpeak/claude-voice-connector-stdio
   python -m venv venv && venv/Scripts/python.exe -m pip install -e .
   venv/Scripts/python.exe -m pip install fastapi "uvicorn[standard]" pydantic "mcp>=1.9"
   ```
4. Build the Phoenix deps:
   ```bash
   cd active_inference
   mix deps.get
   mix compile
   mix workbench_web.sync_labs
   mix workbench_web.sync_audio
   mix workbench_web.chunk_book
   python apps/workbench_web/priv/book/extract_figures.py
   ```
5. Start Docker Desktop (for LibreChat).
6. `./scripts/start_suite.sh`.

## Updating content

- Edit a session's narration: `active_inference/apps/workbench_web/lib/workbench_web/book/sessions.ex`, then `mix compile` (Phoenix hot-reloads in dev).
- Edit a lab: `learninglabs/*.html`, then `mix workbench_web.sync_labs` copies it into `priv/static/learninglabs/`.
- Add/update a figure: `python apps/workbench_web/priv/book/extract_figures.py` rebuilds every PNG.
- Refresh book chunks (after supplying `book_9780262369978 (1).txt` per [BOOK_SOURCES.md](BOOK_SOURCES.md)): `mix workbench_web.chunk_book`.
- **Cookbook recipes** — author JSON under `active_inference/apps/workbench_web/priv/cookbook/*.json` per [the schema](active_inference/apps/workbench_web/priv/cookbook/_schema.yaml); validate with `mix cookbook.validate`.
- **LibreChat prompts** — ORCHESTRATE-shaped YAML in `tools/librechat_seed/`; re-seed a running LibreChat with `python tools/librechat_seed/seed.py` (see [PROMPT_DESIGN.md](tools/librechat_seed/PROMPT_DESIGN.md)).
- **Screenshots** — capture checklist in [scripts/capture_screenshots.md](scripts/capture_screenshots.md); output under `priv/static/guide/screenshots/`.

## New URLs after the ORCHESTRATE uplift

| Route | Purpose |
|---|---|
| `/guide/creator` | About Michael Polzin (ORCHESTRATE + Level Up author) |
| `/guide/orchestrate` | Primer on the 11-letter framework |
| `/guide/level-up` | Primer on the AI-UMM 6-level model |
| `/guide/features` | Honest state (works / partial / scaffold) for every feature |
| `/guide/learning` | Learning flow guide (paths, chapters, sessions, quizzes, progress) |
| `/guide/workbench` | Workbench surfaces guide (builder, world, labs, glass, equations, models) |
| `/guide/labs` | 7 learning labs with launch params + coach agents |
| `/guide/voice` | Piper / XTTS-v2 / narrator / autoplay shim |
| `/guide/chat` | LibreChat integration, all 27 agents |
| `/guide/jido` | Jido primer + curated knowledgebase (27 topics) |
| `/guide/jido/:topic` | Any knowledgebase/jido/NN-*.md rendered in-place |
| `/guide/jido/docs` | Upstream `jido/guides/*.md` rendered in-place |
| `/guide/credits` | Consolidated credits and attributions |
| `/guide/cookbook` | How to read a recipe card |
| `/cookbook` | 50 runnable Active Inference recipes |
| `/cookbook/:slug` | Recipe detail + Run in Builder + Run in Labs + Run in Studio |
| `/studio` | **Studio dashboard** -- live/stopped/archived agents + trash count |
| `/studio/new` | New run picker: Attach existing / Instantiate from spec / Build from recipe |
| `/studio/run/:session_id` | Live attached-episode view (Detach or Stop agent controls) |
| `/studio/agents/:agent_id` | Per-agent lifecycle panel: Stop / Archive / Trash / Restore / Restart |
| `/studio/trash` | Trashed agents -- Restore / Permanent delete / Empty trash (confirm-guarded) |
| `/guide/studio` | How-to: Studio vs. Labs, the 3-flow picker, lifecycle model |

## Studio vs. Labs

- **`/labs`** is the stable "fresh agent + fresh world per click" runner.  Unchanged.
- **`/studio`** is the flexible workshop: attach an existing agent, manage its lifecycle, soft-delete to trash, restore, empty trash.  Forward-compatible with the future custom-world builder via the `WorldPlane.WorldBehaviour` contract.
- Both paths run real native Jido on the BEAM; the agent is a real `Jido.AgentServer` in each case.  See [STUDIO_PLAN.md](STUDIO_PLAN.md) for the full design.

## Production-ready checklist

- [x] Every route returns 200 under normal conditions (37/37 swept).
- [x] Every chat link opens in a new tab; current tab is never navigated away.
- [x] Uber-help injects the on-page book excerpt + glossary + chapter context.
- [x] LibreChat "Full chat" link pre-fills the conversation input with the session's starter prompt via `?prompt=…`.
- [x] Speech MCP reachable from inside Docker via SSE.
- [x] Graceful degradation documented above for every backend outage.
- [x] Launcher is idempotent (safe to run twice).
- [x] Stop script leaves no orphan processes or Docker containers.
- [x] Progress cookie survives navigation + is correctly URL-decoded.
- [x] Lab deep-links honor `?path=…&beat=…` query parameters.

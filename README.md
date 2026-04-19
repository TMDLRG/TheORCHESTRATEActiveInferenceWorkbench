# The ORCHESTRATE Active Inference Learning Workbench

> *Built with wisdom from [THE ORCHESTRATE METHOD™](https://www.amazon.com/ORCHESTRATE-Prompting-Professional-AI-Outputs-ebook/dp/B0G2B9LG6V) and [LEVEL UP](https://www.amazon.com/Level-Usage-Maturity-Model-Excellence-ebook/dp/B0GS4WDVFZ) by [Michael Polzin](https://www.linkedin.com/in/mpolzin/) — running on pure [Jido](https://github.com/agentjido/jido) on the BEAM, teaching Active Inference from Parr, Pezzulo & Friston (2022, MIT Press, CC BY-NC-ND).*

A full **Active Inference learning suite** with a BEAM-native agent workbench, a 10-chapter curriculum with 39 sessions, 7 browser-based Learning Labs, a 50-recipe cookbook, and an integrated chat UI with 27 custom tutors. Every agent is a real `Jido.AgentServer` running on Elixir/OTP — no external agent runtimes, no Python orchestration.

---

## What the suite is

Five cooperating services, launched by one script:

| # | Service | Role | Port |
|---|---------|------|------|
| 1 | **Phoenix Workbench** (Elixir) | Learn hub, curriculum, builder, labs, studio, glass, cookbook, equations, models | `4000` |
| 2 | **LibreChat** (Docker) | Chat UI with 27 custom tutor agents, MCP-enabled, OpenAI-compatible backend | `3080` |
| 3 | **Local LLM** (Qwen 3.6 via llama.cpp) — *optional* | OpenAI-compatible local inference | `8090` |
| 4 | **Speech HTTP TTS** (Piper) — *optional* | Narrator audio on every session page | `7712` |
| 5 | **Speech MCP (SSE)** — *optional* | Voice tools inside LibreChat | `7711` |

Pick any combination. The Phoenix Workbench runs standalone. LibreChat is independent of the Workbench and can talk to **any** OpenAI/Anthropic/OpenAI-compatible endpoint. Voice and local LLM are progressive enhancements — missing services degrade gracefully with friendly messages.

---

## Full feature set

### Active Inference Workbench (Phoenix LiveView)

- **Equation registry** — every equation from Parr/Pezzulo/Friston (2022) with source trace, verification status (verified / scaffolded / uncertain), cross-references.
- **Model taxonomy** — filterable registry of generative-model archetypes.
- **Builder** (`/builder/new`) — Lego-style composition canvas with a schema-bound Inspector. Nodes, ports, and type checking come from the topology registry.
- **Labs** (`/labs`) — stable "fresh agent + fresh world per click" runner. Pick any saved spec × any registered world; compiles, boots a supervised episode, renders live maze + belief heatmap + policy-posterior + predicted-trajectory overlay.
- **Studio** (`/studio`) — flexible workshop. Attach an already-running agent to any world. Full lifecycle: **live / stopped / archived / trashed**. Soft-delete + restore + empty-trash. Forward-compatible with the custom world builder via the `WorldPlane.WorldBehaviour` contract.
- **Glass Engine** (`/glass`) — every signal traced back to the book equation that produced it; per-agent history with Mnesia-backed event log.
- **Cookbook** (`/cookbook`) — 50 runnable recipes, each with a "Run in Builder / Labs / Studio" button. Validated by `mix cookbook.validate` so every recipe compiles against real Jido actions + skills.
- **Running sessions chip** — global nav indicator that lists every live episode and lets you return to any in-progress run from anywhere in the app.

### Learning Suite

- **Learn hub** (`/learn`) — 11-chapter grid + four learning paths (`kid`, `real`, `equation`, `derivation` — mapped to AI-UMM levels 0–5 from *LEVEL UP*).
- **Sessions** (`/learn/session/:num/:slug`) — path-specific narration, attributed book excerpt, figures, podcast segment, linked labs and Workbench deep-links, concept list, quiz.
- **Learning Labs** (`/learninglabs/*.html`) — 7 standalone interactive simulations (BayesChips, POMDP Machine, Free-Energy Forge, Laplace Tower, Jumping Frog, Atlas, Anatomy). Launch params `?path=...&beat=...` are honored by the Shell.
- **Progress** (`/learn/progress`) — heatmap of completed sessions, cookie-persisted.
- **Uber-help** — context-aware tutor drawer in the bottom-right corner of every page; injects the on-page book excerpt + glossary + chapter metadata into every request.
- **Narrator** — Piper-backed WAV generation per session, with browser Web Speech API fallback.

### Chat (LibreChat + 27 custom agents)

- Every agent is seeded with an ORCHESTRATE-shaped system prompt (O-R-C foundation + per-letter sub-structures). See [tools/librechat_seed/PROMPT_DESIGN.md](tools/librechat_seed/PROMPT_DESIGN.md).
- **Global agents** shared with every LibreChat user (no auth juggling): path coaches, chapter specialists, quiz writers, explainers, code reviewers.
- **Chat bridge** — a session page's starter prompt is URL-encoded and pre-filled into the LibreChat composer via `?prompt=...`.
- **MCP integration** — `claude_speak` (voice) + `orchestrate` MCP servers registered in `librechat.yaml`; tool-calling works end-to-end.
- **BYO LLM** — wire any OpenAI, Anthropic, Google, Groq, Bedrock, or OpenAI-compatible endpoint in LibreChat's admin UI; no code changes.

---

## Prerequisites

| Requirement | Version | Required for |
|-------------|---------|--------------|
| **Elixir** | `~> 1.18` (tested 1.19.5) | Phoenix Workbench |
| **Erlang/OTP** | `27+` (tested 28) | Phoenix Workbench |
| **Git** | any recent | submodule clone |
| **Docker Desktop** | any recent | LibreChat, MongoDB, pgvector, Meilisearch |
| **Python** | `3.11+` | Speech TTS, LibreChat seed scripts |
| **GPU** (optional) | CUDA 12.4 + ≥24 GB VRAM | Local Qwen 3.6 (Q8_0 quant, ~36 GB on disk) |

No Node.js / esbuild / Tailwind pipeline — the Workbench UI is inline CSS over Bandit.

---

## Installation

### 1. Clone

```bash
git clone --recurse-submodules https://github.com/TMDLRG/ORCWorkbench.git
cd ORCWorkbench
```

If you already cloned without `--recurse-submodules`:

```bash
git submodule update --init
```

### 2. Environment

```bash
cp .env.example .env
# edit .env — generate SECRET_KEY_BASE with:
#   cd active_inference && mix phx.gen.secret
#   openssl rand -base64 48
```

### 3. Phoenix dependencies + content

```bash
cd active_inference
mix deps.get
mix compile
mix workbench_web.sync_labs     # copy labs into /priv/static
mix workbench_web.sync_audio    # register session audio
mix workbench_web.chunk_book    # optional: requires the Parr/Pezzulo/Friston TXT (see below)
python apps/workbench_web/priv/book/extract_figures.py   # optional: extracts figure PNGs
cd ..
```

### 4. LibreChat voice (optional)

```bash
cd ClaudeSpeak/claude-voice-connector-stdio
python -m venv venv
venv/Scripts/python.exe -m pip install -e .
venv/Scripts/python.exe -m pip install fastapi "uvicorn[standard]" pydantic "mcp>=1.9"
cd ../..
```

### 5. Local LLM weights (optional — only if you plan to use Qwen 3.6 locally)

Follow [`Qwen3.6/RUNBOOK.md`](Qwen3.6/RUNBOOK.md) to download the `ggml-org/Qwen3.6-35B-A3B-GGUF` Q8_0 quant (~36 GB). If you prefer OpenAI/Anthropic keys, **skip this step entirely** — see the LLM-setup section below.

### 6. Active Inference book text (optional, copyright-safe)

*Active Inference* (Parr, Pezzulo, Friston; MIT Press 2022) is CC BY-NC-ND. If you own a copy and want the full-text search/chunking features, follow [`BOOK_SOURCES.md`](BOOK_SOURCES.md) — the file is gitignored and must stay local-only. The pre-committed derivative extracts in `active_inference/apps/workbench_web/priv/book/` are enough for the curriculum without the full text.

---

## Running

### Start the whole suite (recommended)

```bash
./scripts/start_suite.sh      # macOS / Linux / Git-Bash
./scripts/start_suite.ps1     # Windows PowerShell
```

The launcher is idempotent (safe to re-run), boots services in dependency order with readiness checks, and prints the URL index when everything is live. Logs stream to `scripts/.suite/logs/`.

### Stop

```bash
./scripts/stop_suite.sh
./scripts/stop_suite.ps1
```

### Workbench-only (skip everything else)

```bash
cd active_inference
mix phx.server
# open http://localhost:4000
```

This is the smallest possible run: the Phoenix Workbench with no LLM, no voice, no LibreChat. Chat links show a styled offline page; every non-chat feature works.

### Docker (production release)

```bash
docker compose up --build
# open http://localhost:4000
```

Two-stage Alpine/Elixir build, ~150 MB image, Mnesia state persists in the `orcworkbench_mnesia` named volume. `docker compose down -v` wipes it.

---

## LLM setup — pick one

The suite works with **any** LLM, local or hosted. Pick what you want:

### Option 1 — Local Qwen 3.6 (default, free, private, offline)

Follow [`Qwen3.6/RUNBOOK.md`](Qwen3.6/RUNBOOK.md):

```powershell
cd Qwen3.6
.\scripts\start_qwen.ps1        # boots llama.cpp server on port 8090
```

LibreChat picks it up as **`Qwen 3.6 · Direct`** and **`Qwen 3.6 · Reasoning`** automatically (presets in `librechat.yaml`). The Phoenix Workbench's "Ask Qwen" uber-help drawer also uses it.

Requires ~36 GB disk, CUDA 12.4, and enough VRAM for at least 20 offloaded layers. Context size up to 1M tokens with YaRN.

### Option 2 — OpenAI

Edit `Qwen3.6/librechat/.env`:

```env
OPENAI_API_KEY=sk-...
```

LibreChat exposes `gpt-4o`, `gpt-4o-mini`, `o1`, etc. in the model picker out of the box. To make OpenAI the default, edit `Qwen3.6/librechat/librechat.yaml.template` and set the default model under `endpoints.openAI`.

### Option 3 — Anthropic

Edit `Qwen3.6/librechat/.env`:

```env
ANTHROPIC_API_KEY=sk-ant-...
```

LibreChat exposes every Claude model (Opus, Sonnet, Haiku) in the picker. Same edit as OpenAI to default to Anthropic.

### Option 4 — Any other provider

LibreChat supports Google Gemini, Azure OpenAI, AWS Bedrock, Groq, Mistral, Cohere, OpenRouter, and any **OpenAI-compatible** endpoint (Ollama, LM Studio, vLLM, text-generation-webui, Together.ai, Fireworks, Perplexity, DeepInfra, etc.). Add credentials to `Qwen3.6/librechat/.env`; see the [LibreChat AI endpoints docs](https://www.librechat.ai/docs/configuration/librechat_yaml/ai_endpoints) for the full matrix.

### Option 5 — LibreChat-only (no Phoenix Workbench, no local infra)

The LibreChat stack runs standalone:

```bash
cd Qwen3.6/librechat
docker compose -p librechat up -d
# open http://localhost:3080
```

You get all 27 custom tutor agents (seeded by `python tools/librechat_seed/agents_from_content.py` + `prompts_from_content.py`) talking to whichever API key you configured. No Elixir required.

---

## Using the Workbench

Once `mix phx.server` is running, open <http://localhost:4000>. Start here:

| Surface | Route | What to do |
|---------|-------|------------|
| **Overview** | `/` | Orientation + quick links |
| **Learn hub** | `/learn` | Pick a chapter + path; step through sessions |
| **Guide** | `/guide` | Tutorial + feature index + prebuilt examples |
| **Cookbook** | `/cookbook` | Browse 50 runnable recipes; click **Run in Studio** |
| **Builder** | `/builder/new` | Compose a generative model on the canvas |
| **Labs** | `/labs` | Run a saved spec × a maze (fresh agent/world each click) |
| **Studio** | `/studio` | Long-lived agents with full lifecycle + world attachment |
| **Glass** | `/glass` | Inspect any agent's signal river with equation traces |

### Key routes reference

| Route | Purpose |
|---|---|
| `/guide/creator` | About Michael Polzin (ORCHESTRATE + LEVEL UP author) |
| `/guide/orchestrate` | Primer on the 11-letter framework |
| `/guide/level-up` | Primer on the AI-UMM 6-level model |
| `/guide/features` | Honest state (works / partial / scaffold) for every feature |
| `/guide/learning` | Learning flow guide (paths, chapters, sessions, quizzes, progress) |
| `/guide/workbench` | Workbench surfaces guide |
| `/guide/labs` | 7 learning labs with launch params + coach agents |
| `/guide/voice` | Piper / XTTS-v2 / narrator / autoplay shim |
| `/guide/chat` | LibreChat integration, all 27 agents |
| `/guide/jido` | Jido primer + curated knowledgebase (27 topics) |
| `/guide/jido/:topic` | Render any knowledgebase markdown inline |
| `/guide/credits` | Consolidated credits + attributions |
| `/guide/studio` | Studio vs. Labs, 3-flow picker, lifecycle model |
| `/cookbook/:slug` | Recipe detail + Run in Builder / Labs / Studio |
| `/studio/new` | New run picker: Attach existing / Instantiate from spec / Build from recipe |
| `/studio/run/:session_id` | Live attached-episode view |
| `/studio/agents/:agent_id` | Per-agent lifecycle panel |
| `/studio/trash` | Restore / Permanent delete / Empty trash |
| `/equations` | Book equation registry with filters |
| `/models` | Model-family taxonomy |
| `/world` | Run a maze episode step-by-step |

---

## Development

```bash
cd active_inference
mix test                 # 60+ tests across 7 apps
mix q                    # format + compile-warnings-as-errors + credo + dialyzer
mix cookbook.validate    # verify every cookbook recipe compiles against real actions
mix docs                 # build API docs to ./doc/
```

### Updating content

- **Session narration**: `apps/workbench_web/lib/workbench_web/book/sessions.ex`, then `mix compile`.
- **Labs**: `learninglabs/*.html`, then `mix workbench_web.sync_labs`.
- **Figures**: `python apps/workbench_web/priv/book/extract_figures.py`.
- **Cookbook recipes**: author JSON under `apps/workbench_web/priv/cookbook/*.json` per [the schema](active_inference/apps/workbench_web/priv/cookbook/_schema.yaml); validate with `mix cookbook.validate`.
- **LibreChat prompts**: ORCHESTRATE-shaped YAML in `tools/librechat_seed/`; re-seed with `python tools/librechat_seed/seed.py`. See [PROMPT_DESIGN.md](tools/librechat_seed/PROMPT_DESIGN.md).

---

## Architecture in one paragraph

The Elixir umbrella splits into three **planes** separated by a typed Markov blanket: `world_plane` (the generative process — maze, collisions, rewards), `agent_plane` (the generative model — native Jido agents with Perceive/Plan/Act actions), and `shared_contracts` (the only types that cross — `ActionPacket`, `ObservationPacket`, `Blanket`). `workbench_web` is the orchestrator + UI; `world_models` owns the Mnesia event log and spec registry; `composition_runtime` handles multi-agent signal routing. Every signal is traceable back to the book equation that produced it, viewable live at `/glass`. Full architecture in [`ARCHITECTURE.md`](ARCHITECTURE.md).

---

## Graceful degradation

The launcher is tolerant. If any service is unavailable, the UI still works:

| Service offline | Behaviour |
|-----------------|-----------|
| Qwen local LLM | Ask-Qwen drawer shows **"Start Qwen: ..."** message with exact command |
| Speech HTTP (Piper) | Narrator falls back to browser Web Speech API |
| Speech MCP (SSE) | `claude_speak` shows as disconnected in LibreChat; voice tools unavailable |
| LibreChat | "Full chat" link shows a styled offline page with `docker compose up` hint |
| Docker | Launcher prints a yellow warning and continues without LibreChat |

---

## Repository layout

```
WorldModels/
├── active_inference/             # Elixir umbrella (the application)
│   └── apps/
│       ├── active_inference_core/    # math, equation registry, model taxonomy
│       ├── shared_contracts/         # Markov-blanket packets
│       ├── world_plane/              # generative process (maze engine)
│       ├── agent_plane/              # generative model (native Jido agents)
│       ├── world_models/             # Mnesia event log + spec registry + PubSub bus
│       ├── composition_runtime/      # multi-agent signal broker
│       └── workbench_web/            # Phoenix LiveView UI + episode orchestrator
├── ClaudeSpeak/                  # Piper TTS connector (HTTP + MCP/SSE)
├── Qwen3.6/                      # local LLM runbook + LibreChat Docker stack
├── knowledgebase/jido/           # curated Jido v2.2.0 reference (26 markdown files)
├── jido/                         # git submodule -- upstream Jido v2.2.0 (reference)
├── learninglabs/                 # 7 standalone interactive simulations
├── tools/librechat_seed/         # 27 ORCHESTRATE-shaped agent + prompt seeds
├── scripts/                      # suite launcher (start/stop, PowerShell + bash)
├── docs/                         # doc index
├── ARCHITECTURE.md               # canonical architecture reference
├── BRANDING.md                   # names, taglines, citation blocks
├── BOOK_SOURCES.md               # how contributors supply gitignored book files
├── CLAUDE.md                     # project rules (Jido-only mandate)
├── CONTRIBUTING.md               # contribution rules
├── RUN_LOCAL.md                  # suite runtime details
└── STUDIO_PLAN.md                # Studio design + lifecycle model
```

---

## Verified vs scaffolded

Honesty policy borrowed from the equation registry ([`ActiveInferenceCore.Equation.verification_status`](active_inference/apps/active_inference_core/lib/active_inference_core/equation.ex)):

- **Verified**: discrete-time POMDP inference (eq. 4.10 / 4.11 / 4.13 / 4.14, appendix B.5 / B.9 / B.29 / B.30), Labs + Studio episode loops end-to-end.
- **Scaffolded**: continuous-time generalised filtering, Dirichlet learning, hybrid + hierarchical models — registry + runtime hooks in place.
- **Uncertain**: flagged per-function in `@doc` when present.

See `/guide/features` (in-app) or [`active_inference/DELIVERABLE.md`](active_inference/DELIVERABLE.md) (static) for the full inventory.

---

## Copyright & citation

**Apply the frameworks, never reproduce book prose.** Three books inform the suite, all cited wherever referenced, never reproduced:

1. **THE ORCHESTRATE METHOD™** (Polzin, 2025) — prompt-shaping framework. Commercial; gitignored. [Buy](https://www.amazon.com/ORCHESTRATE-Prompting-Professional-AI-Outputs-ebook/dp/B0G2B9LG6V).
2. **LEVEL UP — The AI Usage Maturity Model** (Polzin, 2026) — learner-level taxonomy. Commercial; gitignored. [Buy](https://www.amazon.com/Level-Usage-Maturity-Model-Excellence-ebook/dp/B0GS4WDVFZ).
3. **Active Inference — The Free Energy Principle in Mind, Brain, and Behavior** (Parr, Pezzulo, Friston; MIT Press 2022; CC BY-NC-ND 4.0) — the subject taught. Attributed derivative extracts live in `priv/book/`; the original file is gitignored.

The repository code is released under the license in this repo. See [`BRANDING.md`](BRANDING.md) for canonical citation strings and [`BOOK_SOURCES.md`](BOOK_SOURCES.md) for how contributors supply the book sources locally.

---

## Credits

- **Michael Polzin** — ORCHESTRATE METHOD™, LEVEL UP, AI-UMM framework. [LinkedIn](https://www.linkedin.com/in/mpolzin/).
- **Thomas Parr, Giovanni Pezzulo, Karl J. Friston** — *Active Inference* (MIT Press, 2022). [Book](https://mitpress.mit.edu/9780262045353/active-inference/).
- **agentjido** — [Jido v2.2.0](https://github.com/agentjido/jido), the pure-Elixir agent framework powering this suite.
- **Danny Avila + LibreChat contributors** — [LibreChat](https://github.com/danny-avila/LibreChat).
- **Piper TTS** — [rhasspy/piper](https://github.com/rhasspy/piper).
- **llama.cpp** — [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp).
- **Qwen team** — [Qwen3.6-35B-A3B](https://huggingface.co/Qwen/Qwen3.6-35B-A3B-FP8).

---

## Project rules (if you're contributing)

Read [`CLAUDE.md`](CLAUDE.md) before touching agent code. Non-negotiables — enforced by the test suite and `mix q`:

- `cmd/2` is pure; directives describe effects; state mutation stays inside `cmd/2`.
- Cross-agent comms: **signals** (`Jido.Signal`) or **directives**. Never `send/2` / `GenServer.call/3` / `PubSub.broadcast/3` from `cmd/2`.
- Errors at public boundaries are `{:error, %Jido.Error.*{}}` (Splode-structured).
- No `Process.sleep/1` in tests — use `Jido.await/2`, `JidoTest.Eventually`, or event-driven assertions.
- No `--no-verify` on commits unless explicitly authorised.

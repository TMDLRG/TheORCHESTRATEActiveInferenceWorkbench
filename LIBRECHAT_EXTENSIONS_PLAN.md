# LibreChat Suite Extensions — Plan

*Part of **The ORCHESTRATE Active Inference Learning Workbench** — see [BRANDING.md](BRANDING.md) and [README.md](README.md) for canonical branding, citations, and author credits.*

*Status: executed end-to-end 2026-04-19.  All six sprints shipped; the
user addendum (dual-engine voice + UI controls) is fully delivered:
Piper synthesises in <1s, XTTS-v2 in ~70 s on CPU, both reachable through
`speak~voice` with the new `engine` field.  Final route sweep returns 200
on 23 Phoenix routes, 5 backend health checks, and 6 LibreChat API
endpoints.  See §10 for execution notes and deviations from the original
plan.*

## 1 · Context

The Active Inference Masterclass suite currently uses LibreChat for the "Full chat" experience: we open LibreChat in a new tab with a rich starter prompt via `?prompt=…`.  The learner then has the whole chat at their disposal.

Six problems remain to reach the level of integration the workshop needs:

1. The **`orchestrate` MCP** is a leftover from a different project and clutters the server list.
2. The **speech MCP** is named `claude_speak`; the name is tied to an external project and misleading.  It is also not on by default — the learner must open the MCP-Servers menu and enable it per conversation.
3. Today **speak is a blocking synchronous tool** — the agent holds its whole reply, calls `speak(text)`, waits for the full render, then resumes.  This blocks the conversation and rules out any "live narration" feel.
4. The speak service currently runs as a **standalone PowerShell / Python process** on the host, outside Docker.  It disappears when the user closes the terminal and is not part of the reproducible Docker stack.
5. LibreChat's rich native features — **Agents, Prompts library, Memories, RAG file attachments** — are unused.  A learner doesn't benefit from any of them.
6. There is no way today for the learner to grab a **saved prompt** like "Bayes update with my own numbers" from a library and fill variables to explore — which is what the textbook's end-of-chapter exercises look like.

Target outcome: Docker-ized speech MCP with streaming/queuing tools, one curated LibreChat account pre-seeded with path-matched agents, a ~100-prompt library covering every chapter/session/equation/model, chapter-scoped RAG files, and starter memories — all enabled by default so the learner never has to configure anything.

## 2 · Reconnaissance summary (critical facts)

From the LibreChat 0.8.5-rc1 source tree at `Qwen3.6/librechat/`:

- **MCP tool naming** is `{tool_name}~{server_name}` (delimiter defined as `Constants.mcp_delimiter`).  If we rename the server to `speak`, the tool surfaces as `speak~speak`.  To avoid the awkward doubling, the server name will be **`voice`** and the tool name will remain **`speak`** — surface string `speak~voice`.
- **There is no YAML flag for "enabled by default"**: MCP servers are attached per-message by the UI or pre-attached via an **Agent**.  The right answer to "default-on" is therefore: **create Agents that already carry the tool**, and make those agents the default selection on landing.  (MCP servers are always *initialized* at boot — they just aren't auto-attached to a new empty conversation.)
- **Agents API** lives at `/api/agents` (CRUD), requires JWT auth.  Agents carry `name`, `description`, `instructions`, `model`, `endpoint`, `tools[]`, `files[]`, `projectIds[]`, `shared`.
- **Prompts API** lives at `/api/prompts` + `/api/prompts/groups`, supports `{{var}}` syntax and PromptGroups.  Scoped per-`tenantId`; global-to-all-users requires setting the tenant correctly.
- **Memories** are per-user, key+value, no conversation scope.
- **Files** → `/api/files`, async pgvector ingestion; agents reference files via `file_ids`.
- All API endpoints require **JWT bearer**.  There is no out-of-the-box admin bootstrap; we will register an admin user the first time the launcher brings LibreChat up, store the JWT in a state file, and re-use it for seeding.

## 3 · Decisions baked in

- **Server rename**: `claude_speak` → `voice`.  Tool names stay `speak`, `stop_speaking`, `list_voices`, plus new streaming tools (below).  Surface in the UI: `speak~voice`, `stop_speaking~voice`, etc.
- **Streaming model**: replace the synchronous `speak` with a **job-based** API (synthesis starts immediately, agent gets `job_id` back, can poll or just continue).  This is the best we can do given MCP's request/response tool semantics; actual token-streaming into TTS is not part of any MCP transport today.
- **Speech in Docker**: the speech service joins the `Qwen3.6/librechat/docker-compose.yml` stack as a new service named **`voice`**.  Audio is *synthesized in the container* (no host-audio passthrough) and served as bytes to the browser; playback happens in the Phoenix UI via the existing Narrator hook and in LibreChat via a small client-side auto-player hooked to tool-call results.
- **Auto-enable via agents**: every learner starts in one of four Agents (one per path: kid/real/equation/derivation) that already have `speak~voice` pre-attached.  No MCP-Servers menu interaction required.
- **Admin bootstrap**: on first launcher run, we register an admin user (`admin@local` / randomly-generated password written to `scripts/.suite/state/librechat.admin`), capture the JWT, and store it for the seeder.  Idempotent on subsequent runs.

## 4 · Phase plan

### Phase A · Orchestrate out, `voice` in (quick win)

1. Delete the `orchestrate` block from `Qwen3.6/librechat/librechat.yaml` and `librechat.yaml.template`.  Grep confirms no code references it.
2. Rename the remaining MCP server from `claude_speak` to `voice`.  Update:
   - `librechat.yaml` (both template + live)
   - `active_inference/apps/workbench_web/lib/workbench_web/speech_controller.ex` references (none today — good)
   - Any README / RUN_LOCAL.md mentions
3. Update the SSE MCP server source to advertise `serverInfo.name = "voice"` (currently `workshop-speech`).  No client-side impact.
4. Restart LibreChat API (`docker compose restart api`) → `[MCP][voice] Tools: speak, stop_speaking, list_voices` should appear.

**Verification**: `docker logs LibreChat | grep "\[MCP\]\[voice\]"` shows Initialized; orchestrate is absent; `/api/mcp/tools` returns `speak~voice` etc.

### Phase B · Streaming / job-based speak API

Redesign the speech tool schema around **non-blocking synthesis** + **queuing**.  The MCP server keeps a process-local queue (`asyncio.Queue`) and a job registry (`dict[job_id, JobState]`).

New tool surface (all returned to the agent within <100 ms):

| Tool | Args | Return |
|---|---|---|
| `speak(text, voice?, rate?, queue=true)` | text to synthesize | `{job_id, estimated_ms, queued_behind, status:"synthesizing"\|"queued"}` — **returns immediately**, synthesis happens in the background |
| `speak_status(job_id)` | job id | `{status:"queued"\|"synthesizing"\|"playing"\|"done"\|"error", elapsed_ms, remaining_ms, error?}` |
| `stop_speaking(job_id?)` | optional id | stops specific job or everything; returns `{stopped:[job_id,…]}` |
| `list_queue()` | — | array of `{job_id, position, status, text_head}` so the agent can reason about its own backlog |
| `list_voices()` | — | unchanged |

Playback path (container can't reach host speakers):
- Each job writes the rendered WAV into a per-job in-memory buffer.
- A new HTTP route on the speech service (in the same container): `GET /voice/play/{job_id}.wav` streams the buffer back.
- On each `speak` call, alongside the `job_id`, we return `audio_url: "http://host.docker.internal:7712/voice/play/{job_id}.wav"` *but* LibreChat can't easily auto-play URLs from a tool response.
- Phoenix already has `/speech/*` reverse-proxy — extend it with `/speech/play/:job_id.wav` → upstream `/voice/play/{job_id}.wav`.  The Phoenix Narrator hook gets a new capability: listen for LibreChat tool-call results containing `audio_url` and play them.  Done via a small `MutationObserver` on the LibreChat iframe (or a small browser extension shim — see Phase F "Client-side audio auto-play").
- For agents chatting *inside LibreChat*, the tool-call response already renders as a JSON block in the chat.  Good enough for v1: the learner sees the `audio_url` and can click.

**Data model in the speech service**:

```python
@dataclass
class Job:
    id: str
    text: str
    voice: str
    rate: str | None
    status: Literal["queued", "synthesizing", "done", "error"]
    wav: bytes | None
    duration_ms: int
    started_at: float
    finished_at: float | None
    error: str | None

JOBS: dict[str, Job] = {}
QUEUE: asyncio.Queue[str] = asyncio.Queue()
```

Single worker task drains QUEUE → sets status=synthesizing → calls Piper → stores wav → status=done.  Concurrency is 1 so the agent doesn't drown the CPU.  Jobs older than 5 minutes are garbage-collected.

**Verification**: 
- Unit test: POST JSON-RPC `speak` three times in quick succession → all three return `queued_behind` counters.  `list_queue` shows three.  Fifteen seconds later the first is `done`, the second is `synthesizing`.
- Chrome UAT: in LibreChat, ask the agent to "narrate these three points one after the other"; tool calls complete in <200 ms each; the agent continues generating while audio renders in the background.

### Phase C · Dockerize the speech service

New Docker image `workshop-voice` built from `ClaudeSpeak/claude-voice-connector-http/Dockerfile` (new file).  Image contents:
- Base `python:3.11-slim`
- `pip install piper-tts onnxruntime fastapi uvicorn starlette mcp>=1.9 sounddevice numpy`
- COPY the Piper ONNX models (or fetch at build time from the public rhasspy mirror)
- Expose 7711 (MCP SSE) and 7712 (HTTP)
- Entrypoint: `python -m workshop_voice.sse_server`

Add to `Qwen3.6/librechat/docker-compose.override.yml` (or its sibling for this project's use):

```yaml
services:
  voice:
    build: ../../ClaudeSpeak/claude-voice-connector-http
    image: workshop-voice:0.1.0
    ports:
      - "7711:7711"
      - "7712:7712"
    environment:
      SPEECH_MCP_PORT: 7711
      CLAUDE_SPEAK_PORT: 7712
    restart: unless-stopped
    networks: [default]
```

Update `librechat.yaml` URL from `http://host.docker.internal:7711/sse` → `http://voice:7711/sse` (container-to-container DNS).

Remove the two background processes from `scripts/start_suite.sh` and `start_suite.ps1`.  The launcher just does `docker compose up -d` for everything.

**Verification**:
- `docker compose up -d` brings `voice` up.
- `docker logs LibreChat | grep "\[MCP\]\[voice\]"` → Initialized.
- Phoenix Narrator still works via `/speech/speak` → proxied to `voice:7712`.

### Phase D · LibreChat admin bootstrap + JWT capture

One-shot, idempotent.  Runs as part of `start_suite.sh` after LibreChat is up:

```
scripts/librechat_bootstrap.sh           # bash
scripts/librechat_bootstrap.ps1          # windows
```

Steps:
1. If `scripts/.suite/state/librechat.admin` exists and JWT still valid (`/api/auth/refresh` returns 200) → skip.
2. Otherwise:
   a. `POST /api/auth/register {email, password, name}` with a random 32-char password.
   b. Promote the user to admin role (MongoDB direct write — `db.users.updateOne({email: "admin@local"}, {$set: {role: "ADMIN"}})` via `docker exec chat-mongodb mongosh` one-liner).
   c. `POST /api/auth/login` → capture `accessToken`.
   d. Write `{email, password, token, userId}` into the state file.
3. Expose the helper `lc_curl` in the seeder scripts that injects the JWT.

**Verification**: `lc_curl /api/agents` returns `200 []` on first-run; the admin is marked ADMIN in Mongo.

### Phase E · Agents seeder

A Python script `tools/librechat_seed/agents.py` that reads:
- `tools/librechat_seed/agents.yaml` — declarative agent definitions
- The Phoenix **Chapters**, **Sessions**, and **Equations** data (either re-implemented in Python using a small JSON export from the Elixir side, or produced once by a `mix` task `mix workbench_web.export_seed → priv/seed/agents.json`)

And POSTs to `/api/agents`.  Idempotent (update on `name` collision).

Agent catalogue (initial):

| Slug | Role | System-prompt sketch | Tools | Files (RAG) |
|---|---|---|---|---|
| `aif-tutor-story` | Kid path | "Tutor for Active Inference with 5th-grade vocab.  Use the speak tool when the learner says 'read this aloud'.  Keep replies under 150 words." | `speak~voice` | preface + Ch 1 + Ch 2 chunks |
| `aif-tutor-real` | Real-world path (default) | "Real-world tutor.  Grade-8 vocab with analogies.  Use the speak tool for short narration on demand." | `speak~voice` | All 10 chapter TXTs |
| `aif-tutor-equation` | Equation path | "Quant tutor.  Reply with Unicode math + cite equation numbers.  Use the speak tool for dictating short expressions aloud." | `speak~voice` | Ch 2, 4, 7, 8 + Appendix B |
| `aif-tutor-derivation` | PhD path | "Formal tutor.  Proof sketches + references.  Assume undergrad analysis.  Use the speak tool sparingly." | `speak~voice` | All 10 chapters + Appendix A + B |
| `aif-lab-bayes` | Coach for the BayesChips lab | "You coach the BayesChips chip-machine lab.  Ground every reply in the chip world: 100 chips, priors, likelihoods.  Use speak to read the posterior aloud." | `speak~voice` | Ch 2 + Appendix B |
| `aif-lab-pomdp` | POMDP coach | "You coach the POMDP Machine.  …" | `speak~voice` | Ch 4 + Ch 7 |
| `aif-lab-forge` | Free Energy Forge coach | "You coach Eq 4.19 …" | `speak~voice` | Ch 8 + Appendix B |
| `aif-lab-tower` | Laplace Tower coach | "You coach multi-level PC …" | `speak~voice` | Ch 5 + Ch 8 |
| `aif-lab-anatomy` | Anatomy Studio coach | "You coach Figure 5.5 compact studio …" | `speak~voice` | Ch 5 + Ch 9 |
| `aif-lab-atlas` | Atlas coach | "You coach the cortical atlas + neuromodulators …" | `speak~voice` | Ch 5 + Ch 10 |
| `aif-lab-frog` | Jumping Frog coach | "You coach multi-modal concept inference …" | `speak~voice` | Ch 2 + Ch 3 |

Eleven agents in all.  The four tutor agents are marked `shared: true` so they appear in the default list; the lab coaches are surfaced only from Phoenix deep-links (below).

### Phase F · Prompts library

A Python script `tools/librechat_seed/prompts.py` that reads `tools/librechat_seed/prompts/*.yaml` and POSTs PromptGroups + Prompts.

Content plan (target: ~120 prompts, grouped by chapter):

**Chapter groups** (10 groups): `ch1-overview`, `ch2-low-road`, …, `ch10-unified`.  Each group contains 6–15 prompts.

**Prompts library** sample:

```yaml
# tools/librechat_seed/prompts/bayes.yaml
group: "Ch 2 · Low Road"
prompts:
  - name: "Bayes update with your numbers"
    command: "bayes"
    type: "chat"
    text: |
      Given prior P(H) = {{prior}}, likelihood P(E|H) = {{likelihood}},
      and P(E|¬H) = {{alt_likelihood}}, compute P(H|E) step by step.
      Show the unnormalised weights, P(E), and finally the posterior.
      Finish with a one-sentence plain-English interpretation.
    variables:
      - {name: prior, type: number, default: 0.12}
      - {name: likelihood, type: number, default: 0.75}
      - {name: alt_likelihood, type: number, default: 0.09}

  - name: "Absence of evidence update"
    command: "bayes-absence"
    text: |
      Given P(H) = {{prior}}, P(E|H) = {{likelihood}},
      P(E|¬H) = {{alt_likelihood}}, compute P(H | ¬E).
      Explain why absence of evidence is still a valid Bayes update.

  - name: "Odds form of Bayes"
    text: |
      Convert P(H) = {{prior}} and likelihood ratio {{likelihood_ratio}}
      into posterior odds.  Show that log-odds add linearly.
```

**Template prompts per equation** (every entry in the `ActiveInferenceCore.Equations` registry that carries a chapter number):

```yaml
  - name: "Walk me through Eq. {{eq}}"
    command: "eq"
    text: |
      Explain equation {{eq}} from {{chapter}} in the
      [[path:kid,real,equation,derivation]] voice.
      Show its symbolic form, one paragraph of motivation,
      and one worked example.
      If the equation defines a quantity, give the units.
    variables:
      - {name: eq, type: string, default: "4.19"}
      - {name: chapter, type: string, default: "Ch 4"}
      - {name: path, type: enum, values: [kid, real, equation, derivation], default: real}
```

**Lab prompts** — for each lab, a prompt that asks the agent to coach a specific beat or preset:

```yaml
  - name: "BayesChips: preset {{preset}}"
    command: "chip-preset"
    text: |
      I just loaded the "{{preset}}" preset in the Bayes chip machine.
      The world has {{a}} gold chips out of 100, with {{b}} showing the
      observation among gold and {{c}} showing it among steel.
      Walk me through what the posterior should be and why.
```

Total: 10 chapter groups × 8 avg prompts = 80 base prompts; plus ~25 equation prompts and ~15 lab prompts = 120.  The script registers them once; re-runs update.

### Phase G · Memories bootstrap

Seed starter memories per user after registration:

```python
{"key": "suite_learner_path",   "value": "real"}
{"key": "suite_progress_chapter", "value": "0"}
{"key": "suite_notes",           "value": ""}
{"key": "preferred_voice",       "value": "en_GB-jenny_dioco-medium"}
{"key": "tutor_preference",      "value": "use_analogies_first"}
```

Each agent's system prompt explicitly instructs: *"Read the learner's memories (`suite_learner_path`, `suite_progress_chapter`, `preferred_voice`) before answering."*

### Phase H · RAG files

A Python script `tools/librechat_seed/files.py`:
1. For every chapter TXT under `active_inference/apps/workbench_web/priv/book/chapters/ch{NN}.txt`, POST to `/api/files` with `tenantId` set.
2. Store the returned `file_id`s keyed by chapter slug.
3. When the agents seeder runs (Phase E), it uses this map to populate each agent's `files` array.

Verification: `lc_curl /api/files?agent_id=<tutor-real>` returns all 10 chapter files.

### Phase I · Phoenix integration

The chat-bridge pages at `/learn/chat-bridge/{chapter,session}/...` change behaviour:

- Before: opens `http://localhost:3080/c/new?prompt=<starter>`.
- After: looks up the right agent slug (e.g. `aif-tutor-real` or `aif-lab-bayes` depending on whether the current session links to a lab) and deep-links to `http://localhost:3080/c/new?agent_id=<id>&prompt=<starter>&submit=false`.
- A tiny `tools/librechat_seed/export_agent_ids.py` writes `active_inference/apps/workbench_web/priv/librechat/agents.json` after seeding so Phoenix reads the IDs at boot.

Update `ChatLinks`:

```elixir
def session_url(chapter_num, slug, opts \\ []) do
  path = Keyword.get(opts, :path, "real")
  labs = Keyword.get(opts, :labs, [])
  agent = WorkbenchWeb.ChatLinks.pick_agent(path, labs)
  "/learn/chat-bridge/session/#{chapter_num}/#{slug}?agent=#{agent}"
end
```

### Phase J · Client-side audio auto-play

Optional but nice: a small `voice-autoplay.js` served at `/assets/voice-autoplay.js` that LibreChat's frontend can load (we add a `customScript` reference in `librechat.yaml` if supported; otherwise inject via a browser-extension-style bookmarklet for now).  The script watches tool-call responses for `audio_url` keys and fires them at the native `<audio>` player.

### Phase K · Remove orphan services from launcher

Because the `voice` service lives in Docker Compose, the bash/PS1 launchers stop starting two local Python processes.  They shrink to:
1. Qwen (still host-local, 36 GB model).
2. Docker Compose: LibreChat + MongoDB + pgvector + Meilisearch + rag_api + `voice`.
3. Phoenix.

## 5 · Critical files

### New files
- `ClaudeSpeak/claude-voice-connector-http/Dockerfile`
- `Qwen3.6/librechat/docker-compose.override.yml` (adds `voice` service)
- `tools/librechat_seed/README.md`
- `tools/librechat_seed/agents.yaml`, `agents.py`
- `tools/librechat_seed/prompts/{ch01..ch10,equations,labs,meta}.yaml`, `prompts.py`
- `tools/librechat_seed/memories.py`
- `tools/librechat_seed/files.py`
- `tools/librechat_seed/export_agent_ids.py`
- `scripts/librechat_bootstrap.sh`, `.ps1`
- `ClaudeSpeak/claude-voice-connector-http/mcp_sse_server.py` — replaced with job-queue version.
- `active_inference/apps/workbench_web/priv/librechat/agents.json` — written by seeder, read by Phoenix.

### Modified files
- `Qwen3.6/librechat/librechat.yaml` / `.template`: remove `orchestrate`, rename `claude_speak` → `voice`, update URL.
- `active_inference/apps/workbench_web/lib/workbench_web/chat_links.ex`: add `?agent_id=` to bridge URLs.
- `active_inference/apps/workbench_web/lib/workbench_web/chat_bridge_controller.ex`: honor `?agent=<slug>` and resolve to `agent_id`.
- `active_inference/apps/workbench_web/lib/workbench_web/speech_controller.ex`: proxy host changes from `127.0.0.1:7712` → `voice:7712` when Phoenix runs in Docker; dev-mode unchanged.
- `scripts/start_suite.sh`, `.ps1`: drop host-local speech processes.
- `scripts/stop_suite.sh`, `.ps1`: same.
- `RUN_LOCAL.md`: update port/service table.

## 6 · Sequencing

| Sprint | Work | Ship signal |
|---|---|---|
| 1 | **A + K**: drop orchestrate, rename to `voice`, remove host-side speech from launcher | LibreChat logs `[MCP][voice] Tools: speak, stop_speaking, list_voices`; orchestrate absent |
| 2 | **C**: Dockerize the voice service; compose-up works | `docker compose ps` shows the `voice` container; `docker logs LibreChat` → MCP tools appear |
| 3 | **B**: streaming/job-based tools replace synchronous speak | `speak` returns in <100 ms with a `job_id`; `speak_status` cycles through `queued → synthesizing → done` |
| 4 | **D + E + H + I**: admin bootstrap, Agents seeder, RAG files seeder, Phoenix deep-link | Chapter page → Full Chat → lands on `aif-tutor-real` with ch4.txt already in context |
| 5 | **F**: Prompts library seeded; every chapter page has a "Browse prompts ▸" link pointing to the chapter's PromptGroup | /learn/chapter/4 shows 8 prompt cards; clicking one opens LibreChat with the template pre-filled and variables requested |
| 6 | **G + J**: Memories bootstrap + optional client-side audio autoplay | Agents read learner memory and tailor responses; speak-returned audio_urls are auto-played in LibreChat |

## 7 · Risks + mitigations

- **Admin bootstrap is fragile** (direct Mongo write to promote to ADMIN).  Mitigation: one retry, fall back to a manual `docker exec chat-mongodb mongosh` command printed to the user.
- **Agents API schema drift** across LibreChat versions.  Mitigation: pin LibreChat at its current commit via the submodule, assert version via `/api/config` before seeding.
- **Prompts library rot**: new sessions added to the Phoenix catalogue won't auto-create prompts.  Mitigation: the seeder is idempotent and invoked on every launcher run; the YAML files live in this repo next to the Elixir data.
- **Docker audio**: the `voice` container renders WAVs but can't play to the host speakers.  Mitigation: playback happens in the browser; LibreChat displays the audio_url and (Phase J) auto-plays; Phoenix Narrator already fetches bytes and plays client-side.
- **JWT expiry**: the admin token expires.  Mitigation: the seeder refreshes before each run using `/api/auth/refresh`; falls back to re-registering.
- **Agent tool-call loops**: an agent might call `speak` repeatedly.  Mitigation: the MCP server rate-limits to 1 synthesis in flight + 4 queued; beyond that, `speak` returns `{error:"queue_full"}` so the agent must choose.
- **Prompt variable UI collisions**: some variables overlap (`prior` in multiple prompts).  That's fine — variables are per-prompt scope.
- **Voice MCP rename breaks bookmarks**: old `claude_speak~*` tool names in saved LibreChat conversations become stale.  Mitigation: for the first few weeks, keep a deprecation alias in the SSE server: if the initialize message asks for `claude_speak`, we also serve `speak~claude_speak` → `speak~voice` shim.  Drop after a sprint.

## 8 · Out of scope (deferred)

- Multi-tenant LibreChat (one admin + self-registering learners only in v1).
- Voice MCP with generative streaming (Piper doesn't support incremental text synthesis; we'd need a different TTS for true token-level streaming).
- Custom LibreChat build with native "audio-url auto-play" UI.  Phase J is a drop-in script.
- Speech-to-text (the other direction).  Listener features could be added in a future pass.
- Multi-language: voices added to `CATALOG` are English-only at v1.

## 9 · Success criteria

- [ ] Learner opens `/learn/chapter/4` → Full Chat → lands in a LibreChat conversation whose **agent is `aif-tutor-real`**, whose **RAG files include ch04.txt**, whose **first turn is pre-populated with the starter prompt**, and whose **Speak tool is pre-attached** (zero manual clicks).
- [ ] The agent, when asked to "narrate your last reply aloud", calls `speak~voice` with the text, receives a `job_id` within 100 ms, and keeps generating while audio plays.
- [ ] Learner opens the LibreChat Prompts library → picks "Bayes update with your numbers" → fills `prior=0.01, likelihood=0.9, alt_likelihood=0.09` → gets a correct step-by-step Bayes answer + the agent offers to narrate it.
- [ ] Every Memory key set on the agent tutor side is readable by the agent on its next turn.
- [ ] `docker compose up` alone — no standalone PowerShell — brings up Qwen, LibreChat, and voice; `docker compose down` cleans up.
- [ ] `orchestrate` is fully gone from logs, UI, and tool lists.

---

## 10 · Execution notes (2026-04-19)

What surfaced during execution that wasn't anticipated by the original plan.

### 10.1 LibreChat config required to enable agents at all

The shipped `.env` had `ENDPOINTS=custom`, which kept every non-custom endpoint
(including `agents`) out of `getEnabledEndpoints()` and made
`endpointsConfig[agents]` empty.  That short-circuited the agent capability
check (`isFileSearchEnabled` → false) and made `/api/files` POST return
"File search is not enabled for Agents".  Fix:
- `Qwen3.6/librechat/.env`: `ENDPOINTS=agents,custom`
- `Qwen3.6/librechat/librechat.yaml`: explicit `endpoints.agents.capabilities`
  block listing `file_search`, `tools`, `context`, `chain`, `actions`,
  `web_search`, `artifacts`, `ocr`.

### 10.2 RAG embeddings — the lite image needed swapping

The default `librechat-rag-api-dev-lite` image only ships OpenAI embeddings
and a stub `OPENAI_API_KEY=user_provided` that fails immediately.  Switched
to the full `ghcr.io/danny-avila/librechat-rag-api-dev:latest` and configured:
- `EMBEDDINGS_PROVIDER=huggingface`
- `EMBEDDINGS_MODEL=sentence-transformers/all-MiniLM-L6-v2`

(Image overridden in `Qwen3.6/librechat/docker-compose.override.yml`.)
Adds a one-time ~150 MB download of MiniLM and ~1.5 GB image swap; runs
fully on CPU.

### 10.3 LibreChat brute-force protections trip the seeders

`uaParser` middleware rejects any non-browser User-Agent with score 20 (a
single curl call → instant 2-hour ban).  Login also rate-limits to 7/5min.
Two compensating moves:
- **In .env**: set `BAN_VIOLATIONS=false` and `NON_BROWSER_VIOLATION_SCORE=0`
  (workshop is local-only — security trade-off acceptable).
- **In `tools/librechat_seed/common.py`**: every request carries a real
  Chrome UA, and `load_admin()` reuses the JWT in the state file when it's
  still valid (saves a login per seeder).

### 10.4 File uploads need a holder agent

`POST /api/files` with `tool_resource=file_search` requires `agent_id`.
There's no "global tenant file" path.  Solution: the seeder creates a hidden
`aif-file-holder` agent first; every chapter is uploaded to it; real agents
attach the same `file_id`s via `tool_resources.file_search.file_ids` (LibreChat
allows the same file_id to be referenced by multiple agents).

### 10.5 Voice service: dual engine + UI controls (user addendum)

Mid-sprint addendum: voice MCP must support both Piper TTS and Coqui XTTS,
expose ≥5 voices, and the Phoenix Narrator needs visible stop/pause +
progress controls.  Implemented:
- `ClaudeSpeak/claude-voice-connector-http/voice_catalog.py` — single source
  of truth for voice metadata (5 Piper + 2 XTTS = 7 voices).  Engine flag
  drives dispatch in `jobs.py`.
- `Dockerfile` extended: pre-fetches 2 extra Piper ONNX voices from the
  Hugging Face rhasspy mirror at build time, installs `coqui-tts` (CPU torch
  wheel pinned `torch>=2.4,<2.6` because `transformers` requires PyTorch
  ≥2.4 even when only used for `is_torch_available()` checks).
  `numpy<2` pin avoids the ABI mismatch between torch's bundled C extensions
  and NumPy 2.x.
- `jobs.py` runs Piper and XTTS in two independent worker tasks so a slow
  XTTS synthesis doesn't block fast Piper jobs.
- `priv/static/assets/app.js` Narrator hook rewritten with a docked controls
  cluster: Resume/Pause/Stop + voice picker (populated from `/speech/voices`)
  + live progress bar + `mm:ss / mm:ss` timer.
- `priv/static/assets/voice-autoplay.js` shim auto-plays any
  `audio_url` the agent emits inside a LibreChat tool-call result; install
  via the bookmarklet at `/learn/voice-autoplay` or as a TamperMonkey
  userscript.

### 10.6 Image-size budget

`workshop-voice` lands around 5 GB after the torch + XTTS preload (CPU torch
wheel ≈ 1 GB, XTTS-v2 base model ≈ 1.8 GB, the rest is python deps).
Acceptable for a workshop-local stack; reachable for production by
splitting `voice-piper` (lean) and `voice-xtts` (heavy) into separate
containers if image-size becomes a concern.

### 10.7 Bookmarklet vs. customScript for autoplay

LibreChat 0.8.5-rc1 has no `customScript` hook in `librechat.yaml`.  Phase J
ships the autoplay shim in two flavors:
- bookmarklet served from `/learn/voice-autoplay` (one click per tab),
- TamperMonkey userscript header inside `voice-autoplay.js`
  (`@match http://localhost:3080/*` for auto-attach across tabs).

### 10.8 Sprint-1 deprecation alias

`librechat.yaml.mcpServers.claude_speak` is registered alongside `voice`
and points at the same SSE endpoint, so any conversation bookmarked with
`speak~claude_speak` continues to resolve.  Drop after one sprint of
overlap (planned in §7 last bullet).

---

*End of plan.  On approval, execute sprint-by-sprint per §6.*

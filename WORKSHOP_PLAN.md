# Active Inference Masterclass — Full Interactive Workshop Plan

*Status: plan (not yet executed). Authored 2026-04-18 after reconnaissance of book assets, LibreChat/Qwen, and ClaudeSpeak.*

## 1 · Context

The repo already hosts a learning suite — 7 Learning Labs, a Phoenix Workbench, a hub at `/learn`, persona cookie propagation. This plan uplifts that suite into a **chapter-by-chapter interactive workshop** over the entire Parr / Pezzulo / Friston (2022) book, with four learning paths (Kid / Real-world / Equation / Derivation), integrated Qwen chat (both embedded "uber help" and full LibreChat panel), book-text and podcast narration via the ClaudeSpeak MCP, per-chapter RAG attached files, and a progress dashboard. Everything ties together; the labs and Workbench are used inside sessions, not beside them.

The outcome: a single landing at `/learn` points the learner at **a 10-chapter curriculum × 4 voice paths × 3–5 session segments per chapter**, with a Qwen assistant one click away on every page and a "narrate this" button that reads the current section aloud.

## 2 · Reconnaissance summary

### 2.1 Book assets
| Asset | Path | Shape |
|---|---|---|
| Full text | `book_9780262369978 (1).txt` | 15,100 lines; chapter markers `^Chapter [0-9]`; equations `(4.19)`; figures `Figure 5.5` |
| Full PDF (for images) | `book_9780262369978.pdf` | 6.3 MB, ~330 pages |
| Podcasts | `audio book/ch{01-10}_part{01-03}.mp3` + `preface/preface.mp3` | 31 MP3s, 3 parts × 10 chapters + preface, total ~260 MB |
| Chapter→equation link | `active_inference/apps/active_inference_core/lib/active_inference_core/equations.ex` | each equation already carries `chapter:` — reuse |

Structure:
- **Part I** (theory): Ch 1–5 (Overview, Low Road, High Road, Generative Models, Message Passing & Neurobiology)
- **Part II** (practice): Ch 6–10 (Recipe, Discrete-time AIF, Continuous-time AIF, Model-based analysis, Unified theory)
- **Appendices**: A (math background), B (equations of AIF)

### 2.2 LibreChat + Qwen (`Qwen3.6/`)
- `librechat/` — v0.8.5-rc1 Docker Compose on port **3080**. MongoDB + pgvector (RAG) + Meilisearch. MCP enabled. No `X-Frame-Options` → can be iframed or reverse-proxied.
- `models/Qwen3.6-35B-A3B-Q8_0.gguf` (36.9 GB) served by `llama.cpp-bin/llama-server.exe` on port **8090** (dynamic, written to `.qwen_port`). OpenAI-compatible `/v1/chat/completions`, tool-calling via `--jinja` + `enable_thinking`.
- `librechat.yaml` already references two Qwen endpoints ("Qwen 3.6 Reasoning" / "Qwen 3.6 Direct") and has an `mcpServers:` block.

### 2.3 ClaudeSpeak (`ClaudeSpeak/claude-voice-connector-stdio/`)
- Python MCP server. STDIO JSON-RPC. Exposes `speak`, `stop_speaking`, `list_voices`.
- Piper TTS, local, offline, no creds. Three voices (en_GB-jenny_dioco-medium default, en_US-amy-medium, en_GB-alba-medium).
- Plays directly to the host's audio device (no file return).
- Already registered in root `.mcp.json` for Claude Code.

## 3 · Target shape (one paragraph)

A learner lands on `/learn`, picks a path, and sees a 10-chapter curriculum ladder. Each **chapter is a module**; each module is **3–5 sessions**. A session page shows: (a) the book excerpt for this session with path-appropriate narration tone, (b) a podcast-segment player synced to the excerpt, (c) a "Narrate this" button that speaks the excerpt through the ClaudeSpeak MCP (or the Web Speech API fallback), (d) a figure strip extracted from the PDF for this section, (e) a linked Learning-Lab entry beat with a pre-seeded preset, (f) a linked Workbench surface (equation page / builder spec / glass trace), (g) a check-for-understanding micro-quiz, (h) a persistent **Ask Qwen** drawer that can answer from chapter-scoped RAG, and (i) a **Full Chat** link that pops LibreChat in a side panel with the same RAG files pre-attached. Every button on every surface can escalate to Qwen; every chapter can be played as a podcast or narrated text; every path stays honest about the math.

## 4 · Curriculum architecture

### 4.1 Data layer — new modules

- `WorkbenchWeb.Book` — book-level metadata (ISBN, edition, paths, figure inventory).
- `WorkbenchWeb.Book.Chapters` — 10 entries + Preface. Each:
  ```elixir
  %{
    num: 4, slug: "generative-models", title: "The Generative Models of Active Inference",
    part: :theory, page_range: {77, 124}, txt_lines: {4123, 5840},
    podcasts: ["audio book/ch04_part01.mp3", "audio book/ch04_part02.mp3", "audio book/ch04_part03.mp3"],
    sessions: [:s1_setup, :s2_a_matrix, :s3_efe_intro, :s4_mdp_world, :s5_practice],
    equations: ~w(4.1 4.2 4.7 4.13 4.14 4.19),
    figures: ~w(4.1 4.2 4.5),
    hero: "Perception, action, learning and inference all live inside one generative model.",
    prereq: [3]
  }
  ```
- `WorkbenchWeb.Book.Sessions` — 30–50 entries. Each:
  ```elixir
  %{
    chapter: 4, slug: "s3_efe_intro", title: "Expected Free Energy — your first look",
    minutes: 12, ordinal: 3,
    txt_lines: {4720, 4880},         # excerpt for this session
    podcast: {"audio book/ch04_part02.mp3", {180, 540}}, # seconds
    figures: ~w(4.5),                 # pulled from PDF page images
    concepts: ~w(efe_risk efe_ambiguity softmax_policy),
    path_text: %{
      kid: "Guess which plan will surprise you least…",
      real: "Expected Free Energy scores a plan by adding two bills…",
      equation: "G_π = E_Q(o,s|π)[ ln q(s|π) − ln p(o,s) ]  ≈  risk + ambiguity",
      derivation: "The proxy follows by expanding the KL …"
    },
    labs: [%{slug: "pomdp-machine", beat: 5}, %{slug: "anatomy-studio", beat: 2}],
    workbench: [%{route: "/equations/4.14", label: "Eq. 4.14 record"}],
    quiz: [%{q: "…", a: :b, why: "…"}, …],
    qwen_seed: "You are the book's Chapter-4 tutor. The learner is on the EFE-intro session…"
  }
  ```
- `WorkbenchWeb.Book.Glossary` — extended from the Shell's `TERMS` to cover every data-term across all 10 chapters (~200 entries).
- `WorkbenchWeb.Book.Chunker` — at boot, parses the TXT into chapter chunks and writes to `priv/book/chapters/ch01.txt` … `ch10.txt` so they can be served to the LibreChat RAG uploader and to the narrator.
- `WorkbenchWeb.Book.FigureExtractor` — one-time offline mix task that rasterises the relevant PDF pages into `priv/static/book/figures/<fig>.png`. Python script called from the task; no runtime PDF I/O.

### 4.2 Content model

Four persona paths × N sessions × per-path narration. All four paths read the same book excerpt verbatim (accuracy non-negotiable), but the **surrounding scaffolding** (intro/outro sentences, exercise choice, quiz difficulty, Qwen system prompt) varies. No path ever gets a "baby" version of the math; kid path just wraps the math in a story. Each session has a **hero quantity** the learner moves or names, a **micro-mission** they can finish in the session, and a **follow-up** that points either at the next session or at a lab/Workbench experiment.

### 4.3 Tie-in map (labs + Workbench reused across the curriculum)

| Chapter | Uses Labs | Uses Workbench |
|---|---|---|
| 1 Overview | BayesChips (intro) | `/guide`, `/models` |
| 2 Low Road | BayesChips, Jumping Frog | `/equations` (eq 2.1, 2.5) |
| 3 High Road | Jumping Frog, Anatomy Studio | `/equations` (eq 3.x), `/guide/examples/l3_epistemic_explorer` |
| 4 Generative Models | POMDP Machine, Free Energy Forge | `/equations` (4.13, 4.14, 4.19), `/builder/new` |
| 5 Message Passing & Neurobiology | Laplace Tower, Atlas | `/glass` (signal provenance) |
| 6 Recipe | — | `/builder` (builder flow) |
| 7 Discrete Time | POMDP Machine (deep) | `/world`, `/labs/run` |
| 8 Continuous Time | Free Energy Forge, Laplace Tower | — |
| 9 Model-Based Analysis | Anatomy Studio | `/equations` (Appendix B) |
| 10 Unified Theory | Atlas | `/guide` |

Every module ends with "now go to /world and run this config", or "open the equation page for (4.19)", or "launch the POMDP machine and try this preset" — the labs and Workbench are tools in the session, not a separate menu.

## 5 · Phase plan

### Phase A · Curriculum data + pattern-setter module

**Scope**: stand up the data layer, build **Chapter 4** (Generative Models) end-to-end as the pattern-setter, validate the template before scaling.

Critical files:
- `active_inference/apps/workbench_web/lib/workbench_web/book/` — new namespace with `chapters.ex`, `sessions.ex`, `glossary.ex`, `chunker.ex`.
- `active_inference/apps/workbench_web/priv/book/chapters/ch04.txt` — extracted excerpt.
- `active_inference/apps/workbench_web/priv/static/book/figures/fig_4_1.png` etc. — extracted figure images (mix task `mix workbench_web.extract_figures`).
- `active_inference/apps/workbench_web/lib/workbench_web/live/learning_live/chapter.ex` — `/learn/chapter/:num`.
- `active_inference/apps/workbench_web/lib/workbench_web/live/learning_live/session.ex` — `/learn/session/:num/:slug`.
- `active_inference/apps/workbench_web/lib/workbench_web/live/learning_live/path_view.ex` — `/learn/path/:path_id` (filters the whole ladder to one persona).
- Router: add `live "/learn/chapter/:num"`, `live "/learn/session/:num/:slug"`, `live "/learn/path/:path_id"`.
- Hub update: each chapter card on `/learn` now shows sessions + % complete (progress cookie).

Verification:
- `/learn/chapter/4` renders 5 session cards.
- `/learn/session/4/s3_efe_intro` renders excerpt + figure + lab link + workbench link + quiz + Ask-Qwen drawer stub.
- Switching the path cookie changes the narration but not the excerpt.

Ship point: Chapter 4 complete; all other chapters are stubs that say "coming in Phase H".

### Phase B · Podcasts

**Scope**: embed the 31 MP3s with per-session segment markers.

- Static serve: `Plug.Static` mounts `priv/static/book/audio/` (symlinked or copied from repo-root `audio book/`).
- Mix task `mix workbench_web.sync_audio` — copies MP3s into `priv/static/book/audio/` with sanitised filenames (`audio book/ch04_part02.mp3` → `/book/audio/ch04_part02.mp3`).
- Dockerfile: `COPY "audio book" /audio_book` before `mix release`; the task reads from `$AUDIO_BOOK_DIR || "../../../../audio book"`.
- New component `WorkbenchWeb.Components.PodcastPlayer` — given `{src, start_s, end_s, title}`, renders a `<audio>` element with JS-bounded playback (pauses at `end_s`), a scrubber clamped to the segment, and a title.
- Every session renders exactly one PodcastPlayer with its `podcast: {file, {start, end}}` config.
- Chapter-level podcast (the full three parts concatenated) also available on `/learn/chapter/:num` behind a "Listen to the whole chapter" button.

Verification: `/book/audio/ch04_part02.mp3` serves 200; session page plays only seconds 180–540 of it; chapter page plays all three parts back-to-back.

### Phase C · ClaudeSpeak speech MCP (4 surfaces)

**Scope**: one MCP server, four consumers — Claude Code (already), LibreChat, Qwen, Phoenix UI.

#### C.1 HTTP wrapper for the browser
ClaudeSpeak speaks to the host's audio device, not the browser's. For the Phoenix UI we need audio *bytes*, not a played stream. Thin HTTP wrapper alongside the existing STDIO server:

- `ClaudeSpeak/claude-voice-connector-http/` — tiny FastAPI process. Single `POST /speak` endpoint: `{text, voice?, rate?}` → `audio/wav` bytes (200). Uses the existing Piper bindings (imports from `claude_voice_connector.piper_tts`, just writes PCM to an in-memory buffer instead of sounddevice).
- Bonus `GET /voices` → same payload as MCP `list_voices`.
- Served at `127.0.0.1:7712` (configurable).
- Phoenix reverse-proxies to it at `/speech/*` so the browser never leaves the origin.

#### C.2 Browser narration component
- `WorkbenchWeb.Components.Narrator` — renders a "🔊 Narrate" button + a voice picker + a rate slider.
- On click: first tries `fetch("/speech/speak", {method:"POST", body: JSON.stringify({text, voice})})` and plays the returned blob via an `<audio>` element.
- Falls back to the browser's `SpeechSynthesisUtterance` if the HTTP wrapper is offline (so the UI never breaks when the MCP isn't running).
- Highlights the currently-spoken sentence by pre-chunking the text on sentence boundaries, speaking one chunk at a time, and applying a CSS class `.ls-speaking` to the current `<span>`.
- A global "Narrate this session" button at the top of every session page narrates the full excerpt.
- A compact "Narrate book" control on `/learn` can serialize all 10 chapters (one at a time).

#### C.3 LibreChat MCP wiring
- Register ClaudeSpeak in `Qwen3.6/librechat/librechat.yaml` `mcpServers:` block using stdio transport:
  ```yaml
  mcpServers:
    claude_speak:
      type: stdio
      command: python
      args: ["-m", "claude_voice_connector.stdio_main"]
      env:
        PYTHONPATH: "C:/Users/mpolz/Documents/WorldModels/ClaudeSpeak/claude-voice-connector-stdio/src"
      timeout: 15000
  ```
- LibreChat MCP client discovers `speak` / `stop_speaking` / `list_voices`; Qwen (via LibreChat's function-calling) can now speak as an agent action.

#### C.4 Qwen uber-help direct tool access
- The uber-help drawer (Phase D) sends a POST to a small Phoenix controller that in turn calls Qwen with `tools=[speak]` wired as a function schema pointing at our HTTP `/speech/speak`. Qwen can decide to narrate its own reply without going through LibreChat.

Verification:
- `curl -X POST http://127.0.0.1:7712/speak -d '{"text":"hello"}'` returns audio bytes.
- `/speech/speak` returns the same via the Phoenix reverse proxy.
- LibreChat UI shows `claude_speak` in the MCP tool picker; a Qwen message like "narrate this" results in a `tools/call` to `speak`.
- Clicking "Narrate this session" on a session page plays through the browser speakers.
- Turning off the HTTP wrapper falls back to `SpeechSynthesisUtterance` silently.

### Phase D · Qwen "uber help" drawer (embedded)

**Scope**: one-click Qwen chat on every page, small and always available, with context pre-seeded from the page.

- `WorkbenchWeb.Components.UberHelp` — floating button bottom-right on every layout. Opens a side drawer. Shows: a compact chat history, an input, three quick-chips ("Explain this", "Give me an analogy", "What's next?"), a "Narrate response" toggle, and an "Open full chat ▸" escape hatch that links to `/chat`.
- `WorkbenchWeb.UberHelpController` — POST `/api/uber-help` takes `{session_slug, user_msg, seed?}`, appends the session's `qwen_seed` + excerpt + glossary context + current path, POSTs to Qwen at `http://127.0.0.1:8090/v1/chat/completions` with `{enable_thinking: false, max_tokens: 2048}`, streams tokens back as SSE.
- Port discovery from `Qwen3.6/.qwen_port` on boot (same mechanism llama-server uses).
- Graceful degradation: if Qwen is offline, the drawer says "Qwen is sleeping. Start it with `./Qwen3.6/scripts/start_qwen.ps1`."
- Can also be triggered from any `data-term` tooltip's "Ask Qwen about this" button — sends the term + its glossary entry as context.
- Sessions store conversation turns in `localStorage` keyed by `ls.uber.<session_slug>` so re-opening the drawer resumes the thread.

### Phase E · LibreChat full panel (`/chat`)

**Scope**: a full-fledged chat experience with RAG, file attachments, reasoning-mode toggle.

- **Integration model**: reverse-proxy LibreChat at `/chat/*` from the Phoenix endpoint (same origin → cookies, MongoDB sessions, meilisearch all work unchanged; no iframe).
- `active_inference/apps/workbench_web/lib/workbench_web/plugs/chat_proxy.ex` — tiny Plug routed from `/chat/*rest`. Uses `Finch` to HTTP-proxy both HTTP and the WS upgrade. Sets `X-Forwarded-Host` so LibreChat's absolute URLs resolve.
- `/chat` link added to Workbench top-nav.
- **Per-chapter preset conversations**: Phoenix pre-creates a LibreChat agent template per chapter via LibreChat's `/api/presets` endpoint, carrying:
  - System prompt from `qwen_seed`
  - Attached RAG files: `priv/book/chapters/ch{N}.txt` + extracted figures
  - Model: "Qwen 3.6 Reasoning"
- Clicking "Open full chat ▸" from the uber-help drawer deep-links to `/chat?preset=chapter-{N}`.
- The "Full chat" button on `/learn` opens a free-form conversation, not pinned to a chapter.

### Phase F · Progress tracking + assessment

**Scope**: light-weight, cookie-only (no auth).

- Cookie `suite_progress` is a URL-safe-base64 JSON blob of `{ch_num: {session_slug: %{done: bool, quiz_score: int, last_visited: iso8601}}}`.
- `WorkbenchWeb.Plugs.Progress` parses it into `conn.assigns.progress`.
- Updated from LV events (`session_completed`, `quiz_submitted`).
- `/learn/progress` shows a grid: rows = chapters, columns = sessions, cell = completion + score.
- Hub cards show a per-chapter progress ring.

### Phase G · Accessibility, offline, polish

- **Captions / transcripts**: for each podcast part, an offline `whisper`-generated VTT lives at `priv/static/book/captions/ch04_part02.vtt`. The PodcastPlayer exposes them via `<track kind="captions">`.
- **Figure alt-text**: FigureExtractor also runs `pdftotext` on the figure caption region; the alt-text is saved alongside the PNG.
- **Reduced motion**: all narration highlights respect `prefers-reduced-motion` and collapse to a single static indicator instead of a moving underline.
- **Keyboard**: uber-help drawer has focus trap; chat proxy forwards TAB events; narrator has Space play/pause.
- **Service worker** (optional Phase G.2): pre-caches chapter texts + captions for offline learning; podcasts remain online-only due to size.
- **Dyslexia-friendly font** and path-toggle propagation already shipped.

## 6 · Lesson plans — per-chapter session skeletons

Each cell below is a session tuple (slug · hero concept · lab link · workbench link · podcast). Full path-specific copy is authored per session as part of Phase A/H. This table is the **curriculum map**, not the final copy.

### Chapter 1 · Overview (3 sessions)
1. **s1_what_is_ai** — Active Inference in one picture. `BayesChips` (beat 1) · `/models` · `ch01_part01.mp3`.
2. **s2_perception_and_action** — One loop, two moves. `Jumping Frog` (beat 1) · `/equations` · `ch01_part02.mp3`.
3. **s3_why_one_theory** — What this book will cover. no lab · `/guide` · `ch01_part03.mp3`.

### Chapter 2 · The Low Road (4 sessions)
1. **s1_inference_as_bayes** — Bayes' rule revisited. `BayesChips` (all beats) · `/equations/2.1` · `ch02_part01.mp3@0-420`.
2. **s2_why_free_energy** — The bound on surprise. — · `/equations/2.5` · `ch02_part01.mp3@420-end`.
3. **s3_cost_of_being_wrong** — VFE decomposed. `Free Energy Forge` (beat 1) · `/equations/2.6` · `ch02_part02.mp3`.
4. **s4_action_as_inference** — Active inference as sampling from prior. `Jumping Frog` (beat 5) · `/equations/2.12` · `ch02_part03.mp3`.

### Chapter 3 · The High Road (4 sessions)
1. **s1_expected_free_energy** — EFE's first appearance. `Jumping Frog` (beat 6) · `/equations/3.1` · `ch03_part01.mp3`.
2. **s2_epistemic_pragmatic** — Two value axes. `Anatomy Studio` (beat 5) · `/guide/examples/l3_epistemic_explorer` · `ch03_part02.mp3@0-360`.
3. **s3_softmax_policy** — π = softmax(−G). `POMDP Machine` (beat 5) · `/equations/3.7` · `ch03_part02.mp3@360-end`.
4. **s4_what_makes_an_agent_active** — The active-inference recipe. all labs · `/guide/build-your-first` · `ch03_part03.mp3`.

### Chapter 4 · Generative Models (5 sessions) — **PATTERN-SETTER, fully authored in Phase A**
1. **s1_setup** — Why generative models. `POMDP Machine` (beat 1) · `/models` · `ch04_part01.mp3@0-300`.
2. **s2_a_matrix** — A as emission. `POMDP Machine` (beat 2) · `/equations/4.1` · `ch04_part01.mp3@300-end`.
3. **s3_efe_intro** — EFE intro (risk + ambiguity). `POMDP Machine` (beat 5) · `/equations/4.14` · `ch04_part02.mp3@180-540`.
4. **s4_mdp_world** — Discrete MDP roll-through. `POMDP Machine` (all beats) · `/builder/new` · `ch04_part02.mp3@540-end`.
5. **s5_practice** — Build your first AIF agent. all labs · `/world` · `ch04_part03.mp3`.

### Chapter 5 · Message Passing & Neurobiology (4 sessions)
1. **s1_factor_graphs** — Message passing on factor graphs. `Laplace Tower` (beat 1) · `/equations/5.1` · `ch05_part01.mp3`.
2. **s2_predictive_coding** — Cortex as a hierarchy. `Laplace Tower` (all beats) · `/equations/5.7` · `ch05_part02.mp3`.
3. **s3_neuromodulation** — ACh, NA, DA, 5-HT. `Atlas` (beat 5) · `/equations` · `ch05_part03.mp3@0-500`.
4. **s4_brain_map** — Anatomy of belief updates. `Atlas` · `/glass` · `ch05_part03.mp3@500-end`.

### Chapter 6 · Recipe (3 sessions)
1. **s1_states_obs_actions** — What's hidden, what's seen. — · `/builder/new` · `ch06_part01.mp3`.
2. **s2_ab_c_d** — A, B, C, D matrices. — · `/builder` (guided flow) · `ch06_part02.mp3`.
3. **s3_run_and_inspect** — Ship your agent. `POMDP Machine` · `/world` + `/glass` · `ch06_part03.mp3`.

### Chapter 7 · Discrete Time (5 sessions)
1. **s1_discrete_refresher** — Time slices. `POMDP Machine` (beat 1) · `/equations/7.1` · `ch07_part01.mp3@0-400`.
2. **s2_message_passing_4_13** — Eq 4.13 in generalized form. `POMDP Machine` (beat 3) · `/equations/7.3` · `ch07_part01.mp3@400-end`.
3. **s3_learning_a_b** — Dirichlet learning. — · `/guide/examples/l4_dirichlet_learner` · `ch07_part02.mp3`.
4. **s4_hierarchical** — Multi-step planning. `POMDP Machine` · `/labs/run` · `ch07_part03.mp3@0-400`.
5. **s5_worked_example** — End-to-end run. `POMDP Machine` · `/world` · `ch07_part03.mp3@400-end`.

### Chapter 8 · Continuous Time (4 sessions)
1. **s1_generalized_coords** — Motion of the mode. `Laplace Tower` (beat 1) · `/equations/8.1` · `ch08_part01.mp3`.
2. **s2_eq_4_19** — The quadratic free energy. `Free Energy Forge` (all beats) · `/equations/4.19` · `ch08_part02.mp3`.
3. **s3_action_on_sensors** — u̇ = −∂F/∂u. `Laplace Tower` (beat 7) · `/equations/8.14` · `ch08_part03.mp3@0-400`.
4. **s4_continuous_play** — Sandbox session. `Free Energy Forge` + `Laplace Tower` · — · `ch08_part03.mp3@400-end`.

### Chapter 9 · Model-Based Analysis (3 sessions)
1. **s1_fit_to_data** — Free-energy as log-evidence. — · `/equations` (App B) · `ch09_part01.mp3`.
2. **s2_comparing_models** — Bayesian model comparison. `Anatomy Studio` (beat 5) · `/equations` · `ch09_part02.mp3`.
3. **s3_case_study** — Walk the worked analysis. `Anatomy Studio` · `/glass` · `ch09_part03.mp3`.

### Chapter 10 · Unified Theory (3 sessions)
1. **s1_perception_action_learning** — One machine. `Atlas` · `/guide` · `ch10_part01.mp3`.
2. **s2_limitations_and_open_problems** — Where the theory bends. — · — · `ch10_part02.mp3`.
3. **s3_where_next** — Reading recommendations + community. — · `/guide/technical` · `ch10_part03.mp3`.

### Preface (1 session · optional warm-up)
- **s1_orientation** — What this book and this suite are for. — · `/` · `preface/preface.mp3`.

**Total**: 38 sessions across 10 chapters + 1 preface = ~7–8 hours of guided learning at the recommended pace. Four paths × 38 sessions = 152 variants of path-specific narration (~50 words each, ~7,600 words total → tractable).

## 7 · Sequencing (what ships when)

The plan is big but fronts its risk:

| Sprint | Work | Ship signal |
|---|---|---|
| 1 | Phase A (data layer + Chapter 4) + Phase B (podcasts for Ch 4 only) | `/learn/chapter/4` fully works, 5 sessions, audio inline |
| 2 | Phase C (speech MCP) all 4 surfaces | "Narrate this" works in Ch 4; LibreChat can call `speak` |
| 3 | Phase D (uber-help drawer) + Phase E (LibreChat `/chat` proxy) | Chat on every page, full panel at `/chat`, Ch 4 conversation pre-attached |
| 4 | Phase F (progress tracker) | Completion grid at `/learn/progress` |
| 5–6 | Chapters 1, 2, 3, 5 | Part I complete |
| 7–8 | Chapters 6, 7, 8, 9, 10 + Preface | Part II complete, suite done |
| 9 | Phase G (accessibility, offline, polish) | Captions, alt-text, service worker, final QA |

Sprint 1 alone is a defensible vertical slice — a learner can go through **Chapter 4** end-to-end with text, audio, lab tie-ins, Workbench tie-ins, quiz, and eventually Qwen.

## 8 · Things to reuse (don't rewrite)

- **Learning Shell** inside each lab — already carries path toggle, glossary, analogies, exercises. The session page **wraps** it rather than replacing it. When a session launches a lab, the lab comes up with the right path + the right beat (pass `?path=kid&beat=5` in the URL; Shell already reads path from cookie — add a `beat` query-param reader).
- **Equations registry** (`ActiveInferenceCore.Equations`) — already indexed by chapter. The session uses it verbatim for the "related equations" sidebar.
- **Glass Engine** at `/glass` — already traces every agent signal. Chapter 5 + 9 sessions link to specific signal traces.
- **`ActiveInferenceCore.Models`** — already taxonomy-tagged. Chapter 1 uses it for the "see all models" card.
- **LearningCatalog** (from the prior unification pass) — already maps slug → lab file. Reuse for every session's `labs:` field.
- **Suite-tokens CSS** — already shared; session pages pick up `--suite-*` tokens automatically.

## 9 · Risks and mitigations

- **Qwen sleeps** — 36 GB model; always-on is expensive locally. Mitigation: uber-help drawer gracefully degrades to a "start Qwen" message with a copy-paste command; LibreChat panel shows the same. Don't hard-depend on Qwen for the curriculum.
- **Audio latency on the narration MCP** — Piper targets <800 ms first-audio but a cold voice load is slower. Mitigation: the HTTP wrapper warms both cache voices on boot; the browser also shows a "⏳ synthesising…" label during load.
- **PDF figure extraction fidelity** — rasterising MIT Press pages is workable but figures may be embedded at odd crops. Mitigation: extract the entire page as the fallback, with a caption pointing to the figure number; invest in manual crops only for the top-used figures (about ~20 across the book).
- **Path 1 (kid) over-simplification** — the book is technical; some sessions can't honestly collapse into kid-voice. Mitigation: mark those sessions as "Real-world minimum path" on `/learn/path/kid`, with a link that upshifts to the real-world path for just that session. Retain the narrative hook.
- **LibreChat version drift** — our proxy pins to 0.8.5-rc1. Mitigation: health-check route `/chat/healthz` expected JSON is contract-tested; CI flags incompatibility early.
- **Copyright / fair use** — excerpting MIT Press text for interactive education in a local tool is fair use for private study, but hosting the book text + audio publicly is not. Mitigation: the chapter texts + audio files stay in the user's local filesystem; the Dockerfile does **not** publish them to any registry; the release is explicitly "for private classroom use, not redistribution." A prominent banner on `/learn` reminds the user.

## 10 · Out of scope (deferred)

- Re-recording podcasts or generating new podcasts via TTS (we have 31 existing, sufficient).
- A mobile app wrapper.
- Multi-user auth / cohort features (the suite is single-user; LibreChat has its own auth but the Phoenix layer doesn't care).
- Cloud-hosted variant (this is a local-first educational tool).
- Full-text transcription of the podcasts beyond the one-time Whisper VTT generation.
- Translations to non-English paths (all paths are English-only).
- Rich-text authoring UI for sessions (sessions are authored as Elixir structs; content editing is via PR).

## 11 · Success criteria

The workshop is "done" when:

1. `/learn` lists 10 chapters with per-chapter progress rings.
2. Every chapter page at `/learn/chapter/:num` lists 3–5 sessions.
3. Every session page at `/learn/session/:num/:slug` renders: excerpt, figure strip, podcast player, narrate button, lab-link, workbench-link, quiz, uber-help drawer.
4. Switching the path cookie re-voices every session's scaffolding without changing the book excerpt.
5. ClaudeSpeak `/speak` serves audio bytes over HTTP; the browser narrator plays them; LibreChat's MCP can call `speak`; Qwen's uber-help can trigger `speak`.
6. LibreChat is reachable at `/chat`; per-chapter preset conversations pre-load the chapter text + figures as RAG.
7. Every sim's math regression from the prior uplift still passes bit-exact.
8. Offline: a learner with the podcasts on disk but no internet can still read, narrate, chat with the (local) Qwen, and use every lab.
9. The Parr/Pezzulo/Friston 2022 book text is fully covered (every chapter has ≥3 sessions; every session has ≥1 data-term glossary entry in the shared glossary).
10. A user opening the suite for the first time lands at `/learn`, sees the audience picker, and can reach the Chapter 1 Preface session within 2 clicks.

---

*File produced by the planning pass; execution has not begun. The plan will be revised in-place as sprints land.*

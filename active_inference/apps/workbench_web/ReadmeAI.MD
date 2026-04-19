# apps/workbench_web/ — ReadmeAI

## Purpose

The **Phoenix LiveView workbench UI** and **episode orchestrator**. The only app aware of both the agent plane and the world plane — runs them side-by-side across the Markov blanket, publishes events to `WorldModels.Bus`, and renders live visuals (composition canvas, Glass Engine, labs, guide, equation registry, model taxonomy).

## Contents

| Path | Role |
|---|---|
| [`lib/workbench_web.ex`](lib/workbench_web.ex) | Root module with `controller/view/live` macros |
| [`lib/workbench_web/application.ex`](lib/workbench_web/application.ex) | OTP Application; children: `WorkbenchWeb.PubSub`, `Endpoint` |
| [`lib/workbench_web/endpoint.ex`](lib/workbench_web/endpoint.ex) | Phoenix endpoint (Bandit, `/live` socket, session, CSRF, static) |
| [`lib/workbench_web/router.ex`](lib/workbench_web/router.ex) | 18 routes — see below |
| [`lib/workbench_web/episode.ex`](lib/workbench_web/episode.ex) | GenServer orchestrator: Perceive → Plan → Act → Engine → events |
| [`lib/workbench_web/spec_compiler.ex`](lib/workbench_web/spec_compiler.ex) | Pure compiler: `Spec × Maze → {bundle, agent_opts}` |
| [`lib/workbench_web/live/`](lib/workbench_web/live/) | 16 LiveView modules grouped by feature |
| [`lib/workbench_web/components/`](lib/workbench_web/components/) | Core components + layouts + policy visuals |
| [`priv/static/`](priv/static/) | Static assets + robots.txt |
| [`test/`](test/) | 12 test files — [`test/ReadmeAI.MD`](test/ReadmeAI.MD) |

### LiveView subtrees (detail)

- [`live/workbench_live/`](lib/workbench_web/live/workbench_live/) — dashboard `/`
- [`live/equations_live/`](lib/workbench_web/live/equations_live/) — `/equations`, `/equations/:id`
- [`live/models_live/`](lib/workbench_web/live/models_live/) — `/models`
- [`live/world_live/`](lib/workbench_web/live/world_live/) — `/world` (maze runner, supervised)
- [`live/run_live/`](lib/workbench_web/live/run_live/) — `/run` (legacy alias)
- [`live/glass_live/`](lib/workbench_web/live/glass_live/) — `/glass`, `/glass/agent/:id`, `/glass/signal/:id`
- [`live/builder_live/`](lib/workbench_web/live/builder_live/) — `/builder/new`, `/builder/:spec_id`
- [`live/labs_live/`](lib/workbench_web/live/labs_live/) — `/labs`, `/labs/run`
- [`live/guide_live/`](lib/workbench_web/live/guide_live/) — `/guide/*` (user guide + tutorial + examples + block catalogue)

## Public API surface (non-LiveView)

| Module | Function | Arity | Purpose |
|---|---|---|---|
| `WorkbenchWeb.Episode` | `start_link/1` | 1 | Spawn episode GenServer (opts: `:maze`, `:blanket`, `:bundle`, `:agent_id`, `:max_steps`, `:goal_idx`, `:session_id`, `:mode`, `:planner_mode`, `:extra_actions`) |
| `WorkbenchWeb.Episode` | `step/1` | 1 | Single tick; `{:ok, entry} \| {:done, summary} \| {:error, term}` |
| `WorkbenchWeb.Episode` | `inspect_state/1` | 1 | Summary snapshot |
| `WorkbenchWeb.Episode` | `reset/1` | 1 | Full reset (agent + world) |
| `WorkbenchWeb.Episode` | `reset_world/1` | 1 | Reset world only, keep agent's bundle / beliefs / history |
| `WorkbenchWeb.Episode` | `stop/1` | 1 | Stop episode (and supervised AgentServer if `:supervised` mode) |
| `WorkbenchWeb.SpecCompiler` | `compile/3` | 3 | `{Spec, Maze, opts} → {:ok, bundle, agent_opts} \| {:error, atom}` |

## Routes (from [`router.ex`](lib/workbench_web/router.ex))

| Path | LiveView | Purpose |
|---|---|---|
| `/` | `WorkbenchLive.Index` | Dashboard |
| `/equations` | `EquationsLive.Index` | Equation registry (filterable) |
| `/equations/:id` | `EquationsLive.Show` | Equation detail |
| `/models` | `ModelsLive.Index` | Model-family taxonomy |
| `/run` | `WorldLive.Index` | (legacy alias → `/world`) |
| `/world` | `WorldLive.Index` | Maze episode, supervised agent |
| `/glass` | `GlassLive.Index` | Live + historic agents |
| `/glass/agent/:agent_id` | `GlassLive.Agent` | Per-agent Glass |
| `/glass/signal/:signal_id` | `GlassLive.Signal` | Single-signal provenance |
| `/builder/new` | `BuilderLive.Compose` | Canvas (empty) |
| `/builder/:spec_id` | `BuilderLive.Compose` | Canvas (load spec) |
| `/guide` | `GuideLive.Index` | Guide landing |
| `/guide/blocks` | `GuideLive.Blocks` | Block catalogue |
| `/guide/examples` | `GuideLive.Examples` | L1–L5 |
| `/guide/examples/:slug` | `GuideLive.Examples` | Example detail |
| `/guide/build-your-first` | `GuideLive.Tutorial` | 6-step tutorial |
| `/labs` | `LabsLive.Run` | Any spec × any maze |
| `/labs/run` | `LabsLive.Run` | (alias) |

**Phase D (this documentation pass)** adds additional routes under `/guide/technical/*` — see [subtree README](lib/workbench_web/live/guide_live/ReadmeAI.MD).

## Data types & schemas

| Type | Where | Purpose |
|---|---|---|
| `Episode.state` (GenServer) | [episode.ex](lib/workbench_web/episode.ex) | `:world_pid`, `:agent`, `:steps`, `:max_steps`, `:history`, `:mode`, `:agent_id`, `:session_id` |
| Compile output | [spec_compiler.ex](lib/workbench_web/spec_compiler.ex) | `{bundle :: map, agent_opts :: keyword}` |

## Constants & config keys

See [`../../config/ReadmeAI.MD`](../../config/ReadmeAI.MD) for the full Endpoint config table. Key runtime values:

- HTTP port — dev `4000`, test `4002`
- Session salt `ai-workbench-salt-2026`
- PubSub server `WorkbenchWeb.PubSub`
- LiveView signing salt `ai-workbench-salt-2026`

## Telemetry / signals / events emitted here

- `WorkbenchWeb.Episode` publishes these `WorldModels.Event.type` values to `WorldModels.Bus`:
  - `"world.observation"` — Engine obs packet (initial + after each apply)
  - `"agent.perceived"` — post-Perceive state beliefs
  - `"agent.planned"` — F, G, policy posterior
  - `"agent.action_emitted"` — chosen action
  - `"world.terminal"` — terminal condition reached

- Phoenix endpoint emits `[:phoenix, :endpoint, ...]` events (standard).

## Dependencies

- **Inbound**: end users via HTTP/WebSocket; integration tests.
- **Outbound (Hex)**: `:phoenix ~> 1.7.14`, `:phoenix_html ~> 4.1`, `:phoenix_live_view ~> 0.20.17`, `:phoenix_pubsub ~> 2.1`, `:bandit ~> 1.5`, `:jason ~> 1.4`, `:plug_cowboy ~> 2.7` (dev/test), `:floki >= 0.30` (test).
- **Outbound (umbrella)**: `:active_inference_core`, `:shared_contracts`, `:world_models`, `:world_plane`, `:agent_plane`.

## Verification status

- `:verified` — smoke tests, LiveView tests, MVP golden test, spec compiler tests, integration tests for episode publishing (see [`test/ReadmeAI.MD`](test/ReadmeAI.MD)).
- `:verified` — 38-test umbrella suite includes 1 end-to-end MVP here.
- `:scaffolded` — examples L2–L5 are wired but not all end-to-end tested.

## Related

- Episode pair: [`../world_plane/`](../world_plane/) + [`../agent_plane/`](../agent_plane/) + [`../shared_contracts/`](../shared_contracts/)
- Events: [`../world_models/`](../world_models/)
- Live URL: <http://localhost:4000>

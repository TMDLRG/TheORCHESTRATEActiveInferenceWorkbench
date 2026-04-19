# Architecture — The ORCHESTRATE Active Inference Learning Workbench

Canonical high-level architecture reference. The suite is built with wisdom from [THE ORCHESTRATE METHOD™](https://www.amazon.com/ORCHESTRATE-Prompting-Professional-AI-Outputs-ebook/dp/B0G2B9LG6V) and [LEVEL UP](https://www.amazon.com/Level-Usage-Maturity-Model-Excellence-ebook/dp/B0GS4WDVFZ) by Michael Polzin, runs on pure [Jido](https://github.com/agentjido/jido) v2.2.0 on the BEAM, and teaches Active Inference from Parr, Pezzulo & Friston (2022, MIT Press, CC BY-NC-ND).

For run instructions see [`README.md`](README.md); for branding/citation strings see [`BRANDING.md`](BRANDING.md); for the full extraction report and equation-by-equation completion status see [`active_inference/DELIVERABLE.md`](active_inference/DELIVERABLE.md); for the Studio runtime + agent-lifecycle design see [`STUDIO_PLAN.md`](STUDIO_PLAN.md).

## Episode runners: `/labs` vs. `/studio`

Two coexisting surfaces expose the episode loop:

- **`/labs`** (stable) — fresh `{agent, world}` pair per click, via `WorkbenchWeb.Episode.start/3`. Never regresses.
- **`/studio`** (flexible) — attach already-running agents to any world via `WorkbenchWeb.Episode.attach/1`; tracks lifecycle in `AgentPlane.Instances` (Mnesia `:agent_plane_instances`). Any module implementing [`WorldPlane.WorldBehaviour`](active_inference/apps/world_plane/lib/world_plane/world_behaviour.ex) plugs into Studio — the forward-compat surface for the custom world builder.

---

## 1. The three planes (and the Markov blanket between them)

Active Inference separates the generative **process** (the world) from the generative **model** (the agent's beliefs about the world). The project enforces that separation at the code level by splitting into three planes and requiring all cross-plane communication to cross a typed Markov blanket:

```
 ┌────────────────────────────────┐          ┌────────────────────────────────┐
 │         AGENT PLANE            │          │         WORLD PLANE            │
 │  (generative model, beliefs)   │          │  (generative process, truth)   │
 │                                │          │                                │
 │  AgentPlane.Runtime            │          │  WorldPlane.Engine             │
 │  AgentPlane.ActiveInference-   │          │  WorldPlane.Maze               │
 │      Agent  (Jido.Agent)       │          │  WorldPlane.Worlds             │
 │  AgentPlane.Actions.{Perceive, │          │  WorldPlane.ObservationEncoder │
 │      Plan, Act, Step,          │          │                                │
 │      DirichletUpdateA/B,       │          │                                │
 │      SophisticatedPlan}        │          │                                │
 │  AgentPlane.BundleBuilder      │          │                                │
 │  AgentPlane.ObsAdapter         │          │                                │
 │                                │          │                                │
 └──────────────┬─────────────────┘          └──────────────┬─────────────────┘
                │                                           │
                │  ActionPacket                             │  ObservationPacket
                │  (t, action, agent_id)                    │  (t, channels, world_run_id, terminal?)
                │                                           │
                └──────────────┬────────────────────────────┘
                               │
                ┌──────────────▼────────────────┐
                │       SHARED CONTRACTS        │
                │   (Markov blanket boundary)   │
                │                               │
                │   SharedContracts.Blanket     │
                │   SharedContracts.ActionPacket│
                │   SharedContracts.ObservationPacket
                │                               │
                └───────────────────────────────┘
```

**Invariant**: [`apps/world_plane/mix.exs`](active_inference/apps/world_plane/mix.exs) does not depend on `:agent_plane` or `:active_inference_core`. [`apps/agent_plane/mix.exs`](active_inference/apps/agent_plane/mix.exs) does not depend on `:world_plane`. Both depend on `:shared_contracts`. Enforced by `apps/*/test/plane_separation_test.exs`.

## 2. Umbrella apps

The Elixir umbrella ([`active_inference/`](active_inference/)) has seven apps. The dependency graph is strictly directed:

```
                         ┌──────────────────────┐
                         │ active_inference_core│  (pure math — no process, no deps)
                         └──────────┬───────────┘
                                    │
           ┌────────────────────────┼────────────────────────┐
           │                        │                        │
  ┌────────▼────────┐      ┌────────▼────────┐      ┌────────▼────────┐
  │ shared_contracts│      │   agent_plane   │      │   world_plane   │
  │ (boundary types)│◄─────┤  (Jido agent +  ├──────►(generative     │
  │                 │      │   actions)      │      │   process)     │
  └────────┬────────┘      └────────┬────────┘      └────────┬────────┘
           │                        │                        │
           └────────────┬───────────┴────────────────────────┘
                        │
               ┌────────▼──────────────┐
               │     world_models      │  (Phoenix.PubSub + Mnesia event log + Spec)
               └────────┬──────────────┘
                        │
           ┌────────────┴────────────┐
           │                         │
  ┌────────▼───────────┐    ┌────────▼─────────┐
  │ composition_runtime│    │   workbench_web  │  (Phoenix LiveView UI)
  │  (multi-agent      │    │                  │
  │   signal broker)   │    │                  │
  └────────────────────┘    └──────────────────┘
```

### App responsibilities

| App | Role | Key modules |
|---|---|---|
| [`active_inference_core`](active_inference/apps/active_inference_core/) | Pure tensor/POMDP math; equation + model registries. Zero process involvement. | `DiscreteTime`, `Math`, `Equation`, `Equations`, `Model`, `Models` |
| [`shared_contracts`](active_inference/apps/shared_contracts/) | Markov-blanket packets — the only types that cross agent↔world. | `Blanket`, `ActionPacket`, `ObservationPacket` |
| [`world_plane`](active_inference/apps/world_plane/) | Generative process: map topology, goal, collisions, rewards, terminals. Never reads agent state. | `Engine` (GenServer), `Maze`, `Worlds`, `ObservationEncoder` |
| [`agent_plane`](active_inference/apps/agent_plane/) | Generative model: Jido-native agent; beliefs, policy inference, action selection. | `ActiveInferenceAgent`, `Runtime`, `BundleBuilder`, `Actions.*`, `Telemetry.Bus` |
| [`world_models`](active_inference/apps/world_models/) | Central event log (Mnesia), spec registry (content-addressed), Phoenix.PubSub bus. | `Bus`, `Event`, `EventLog`, `AgentRegistry`, `Spec`, `Archetypes` |
| [`composition_runtime`](active_inference/apps/composition_runtime/) | Multi-agent composition supervisor + Jido.Signal routing. | `Composition`, `SignalBroker`, `Registry` |
| [`workbench_web`](active_inference/apps/workbench_web/) | Phoenix LiveView UI, episode orchestrator, composition canvas, Glass Engine. | `Endpoint`, `Router`, `Episode`, `SpecCompiler`, `*Live.*` |

## 3. The agent loop (one tick)

Every tick of an episode executes this precise sequence:

```
   ┌──────────────────────────────────────────────────────────────────────┐
   │                   WorkbenchWeb.Episode (GenServer)                   │
   │                                                                      │
   │  1. WorldPlane.Engine.current_observation/1                          │
   │         → ObservationPacket                    world.observation     │
   │  2. AgentPlane.Runtime.perceive/2                                    │
   │     • Actions.Perceive (eq. 4.13 / B.5)        agent.perceived       │
   │         → state beliefs updated                                      │
   │  3. AgentPlane.Runtime.plan/1                                        │
   │     • Actions.Plan (eq. 4.11, 4.10, 4.14)      agent.planned         │
   │         → F, G, policy posterior, best policy                        │
   │  4. AgentPlane.Runtime.act/2                                         │
   │     • Actions.Act                              agent.action_emitted  │
   │         → ActionPacket emitted via Directive.Emit                    │
   │  5. WorldPlane.Engine.apply_action/2                                 │
   │         → new Engine state + next obs          world.observation     │
   │         → terminal?                            world.terminal        │
   │  6. (optional) Dirichlet learners update A/B in bundle               │
   │         (eq. 7.10, B.10–B.12)                                        │
   │                                                                      │
   │  All steps publish to WorldModels.Bus → Mnesia EventLog              │
   └──────────────────────────────────────────────────────────────────────┘
```

Source: [`workbench_web/lib/workbench_web/episode.ex`](active_inference/apps/workbench_web/lib/workbench_web/episode.ex).

## 4. Event flow (telemetry → bus → event log → LiveView)

Every event in the system is a `WorldModels.Event` ([`lib/world_models/event.ex`](active_inference/apps/world_models/lib/world_models/event.ex)) carrying a provenance tuple (`:agent_id`, `:spec_id`, `:bundle_id`, `:family_id`, `:world_run_id`, `:equation_id`, `:trace_id`, `:span_id`).

```
   Jido.AgentServer ─┐
                     ├─ :telemetry ──► AgentPlane.Telemetry.Bus ─┐
   ActiveInference-  │                 (lib/agent_plane/         │
      Core.Discrete- │                  telemetry/bus.ex)        │
      Time          ─┘                                           │
                                                                 ▼
   WorkbenchWeb.Episode ──────────────────────► WorldModels.Bus ────► Phoenix.PubSub
                                                (lib/world_models/     │
                                                 bus.ex)               ├─► EventLog.append/1
                                                                       │   (Mnesia, disc_copies)
                                                                       │
                                                                       ├─► GlassLive.*
                                                                       ├─► WorldLive.Index
                                                                       └─► LabsLive.Run
```

Topics: `events:global`, `events:agent:<id>`, `events:world:<id>`, `events:spec:<id>`. See [`WorldModels.Bus`](active_inference/apps/world_models/lib/world_models/bus.ex).

## 5. Persistence (Mnesia)

Three Mnesia tables, all managed by [`WorldModels.EventLog.Setup`](active_inference/apps/world_models/lib/world_models/event_log/setup.ex):

| Table | Type | Copies | Purpose |
|---|---|---|---|
| `:world_models_events` | `ordered_set` | `disc_copies` | Append-only event log; key `{ts_usec, id}`; indices on `:agent_id`, `:type` |
| `:world_models_specs` | `set` | `disc_copies` | Content-addressed spec registry; indices on `:archetype_id`, `:family_id`, `:hash` |
| `:world_models_live_agents` | `set` | `ram_copies` | Ephemeral `agent_id → pid` map; index on `:spec_id` |

Auto-start controlled by `:world_models, :auto_start_event_log` (default `true`; tests override).

## 6. Composition canvas

The Lego-style builder ([`BuilderLive.Compose`](active_inference/apps/workbench_web/lib/workbench_web/live/builder_live/compose.ex)) uses [litegraph.js](https://github.com/jagenjo/litegraph.js) as the canvas via a JS hook (`/assets/composition_canvas.js`). Node types and port definitions come from [`WorldModels.Spec.Topology`](active_inference/apps/world_models/lib/world_models/spec/topology.ex) and [`WorldModels.Spec.BlockSchema`](active_inference/apps/world_models/lib/world_models/spec/block_schema.ex). Specs are content-addressed via BLAKE2b (`WorldModels.Spec.provenance_hash/1`) and compiled at run-time by [`WorkbenchWeb.SpecCompiler`](active_inference/apps/workbench_web/lib/workbench_web/spec_compiler.ex).

ADR: [`active_inference/docs/decisions/canvas-library.md`](active_inference/docs/decisions/canvas-library.md).

## 7. Runtime baseline

- Elixir `~> 1.18` (tested 1.19.5), OTP `27+` (tested 28)
- Phoenix 1.7.14, Phoenix LiveView 0.20.17, Phoenix.PubSub 2.1, Bandit 1.5
- Jido 2.2.0 (upstream reference at [`jido/`](jido/) as a git submodule)
- Mnesia (built into OTP)
- No Node.js / esbuild / Tailwind

## 8. Non-negotiables (enforced)

From [`CLAUDE.md`](CLAUDE.md):

- `cmd/2` is pure: same input → same `{agent, directives}` output
- Directives describe external effects; they never mutate agent state
- Cross-agent communication is **signals** (`Jido.Signal`) or **directives** — never raw `send/2`, `GenServer.call/3` to an agent pid, or `Phoenix.PubSub.broadcast/3` from `cmd/2`
- Errors at public boundaries are `{:error, %Jido.Error.*{}}` (Splode-structured)
- Tests never use `Process.sleep/1` — use `Jido.await/2`, `JidoTest.Eventually`, or event-driven assertions
- Writing to reserved `:__xxx__` state keys directly is off-limits
- `--no-verify` / skipping pre-commit hooks is off-limits unless explicitly authorized

## 9. Related reading

- [`knowledgebase/jido/MASTER-INDEX.md`](knowledgebase/jido/MASTER-INDEX.md) — Jido framework reference (26 topic files)
- [`active_inference/DELIVERABLE.md`](active_inference/DELIVERABLE.md) — full extraction report with equation ledger
- In-app: `/guide/technical/architecture` (data-driven view of the same material)

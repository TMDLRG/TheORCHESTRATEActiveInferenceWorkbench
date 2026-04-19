# Active Inference Workbench

A BEAM-native Active Inference workbench on Elixir / OTP. Extracts and verifies
the mathematics of *Active Inference: The Free Energy Principle in Mind, Brain,
and Behavior* (Parr, Pezzulo, Friston, MIT Press 2022), then operationalises
it as a **Lego-style drag-and-drop builder** for generative models, reasoning
primitives, and active-inference agents — all on pure Elixir / BEAM with native
JIDO agents. **No LLMs, no external AI.** Reasoning is done by Active
Inference itself: sophisticated policy search, epistemic-value planning,
Dirichlet learning, hierarchical composition.

Five prebuilt examples form a capability gradient in the maze:

| Level | Example | World | Teaches |
|-------|---------|-------|---------|
| L1 | Hello POMDP | `tiny_open_goal` | Core Perceive/Plan/Act loop |
| L2 | Epistemic explorer | `forked_paths` | Information-seeking behaviour |
| L3 | Sophisticated planner | `deceptive_dead_end` | Deep-horizon policy search (Ch 7) |
| L4 | Online Dirichlet learner | `corridor_turns` | Structure learning (eq 7.10) |
| L5 | Hierarchical composition | `hierarchical_maze` | Multi-agent, signal-brokered |

Browse them at <http://localhost:4000/guide/examples>, or follow the
10-minute click-through tutorial at <http://localhost:4000/guide/build-your-first>.

This README is the **run guide**. For the extraction report, architecture
ADR, and completion status, see [`DELIVERABLE.md`](DELIVERABLE.md).

---

## Prerequisites

- Elixir `~> 1.17` (tested on 1.19.5)
- Erlang/OTP 26+ (tested on OTP 28)
- The JIDO library checked out at `../jido` (relative to this umbrella root).

No Node.js, esbuild, or Tailwind pipeline is required — the UI uses inline
CSS and Bandit as the HTTP adapter for maximum portability.

## Install dependencies

```bash
cd active_inference
mix deps.get
```

## Run the test suite

```bash
mix test
```

Current status (as of 2026-04-17): **38 tests passing across 5 apps**. No skips.

- `active_inference_core` — 20 tests (equation registry, math primitives, POMDP).
- `shared_contracts` — 4 tests (blanket enforcement).
- `world_plane` — 8 tests (mazes solvable via BFS, engine contract, plane separation).
- `agent_plane` — 5 tests (native JIDO integration, plane separation, corridor convergence).
- `workbench_web` — 1 test (end-to-end MVP: agent reaches goal).

## Start the workbench

```bash
mix phx.server
```

Then open <http://localhost:4000>. Key sections:

- <http://localhost:4000/guide> — user-facing guide with the 10-minute tutorial
  and the five prebuilt Active Inference examples.
- <http://localhost:4000/guide/blocks> — block catalogue, auto-generated from
  the topology registry.
- <http://localhost:4000/builder/new> — Lego-style drag-and-drop canvas with a
  schema-bound Inspector. Open any seeded example directly via
  `/builder/example-l1-hello-pomdp` … `/builder/example-l5-hierarchical-composition`.
- <http://localhost:4000/labs> — **run any saved spec × any registered maze**.
  Picks a spec + a maze, compiles via `WorkbenchWeb.SpecCompiler`, and boots
  a supervised episode with the same live visuals as `/world` (policy-direction
  bars + predicted-trajectory overlay). Deep-link with query params:
  `/labs/run?spec_id=example-l3-sophisticated-planner&world_id=deceptive_dead_end`.
- <http://localhost:4000/equations> — equation registry with filters + detail pages.
- <http://localhost:4000/models> — model-family taxonomy.
- <http://localhost:4000/world> — run a maze episode step-by-step or continuously.
- <http://localhost:4000/glass> — Glass Engine: every signal traced back to the
  book equation that produced it.

## The MVP demo (maze)

1. Go to `/run`.
2. Pick a world: try **Tiny Open Goal** first (guaranteed two-step solution).
3. Leave the blanket at its default (6 observation channels, 4 cardinal actions).
4. Keep planning horizon = 5, policy depth = 5, preference strength = 4.0.
5. Click **Create agent + world**.
6. Click **Step** to advance a single tick, or **Run** to animate to completion.
7. Watch:
   - The maze grid in the right column — the orange `@` is the agent.
   - The green heat-map below it — marginal state beliefs.
   - The policy-posterior table — top-5 policies with their F and G values.
   - The step history — actions the agent emitted.

For the deceptive-dead-end maze, raise `policy_depth` to 6+ so the agent's
planning horizon is long enough to see past the cul-de-sac.

## Project layout

```
active_inference/
├── apps/
│   ├── active_inference_core/    # math, equation registry, model taxonomy
│   ├── shared_contracts/         # blanket packets — ObservationPacket, ActionPacket
│   ├── world_plane/              # generative process (maze engine)
│   ├── agent_plane/              # generative model (native JIDO agents)
│   └── workbench_web/            # Phoenix LiveView UI + episode orchestrator
├── config/
├── mix.exs
└── README.md
```

## Architecture invariants

- `world_plane` **does not** depend on `agent_plane` or `active_inference_core`.
  The world is a pure generative process.
- `agent_plane` **does not** depend on `world_plane`. The agent communicates
  only via `shared_contracts`.
- `workbench_web` is the only app aware of both planes (it's the orchestrator
  outside the blanket).

Verified by `apps/*/test/plane_separation_test.exs`.

## What is verified vs scaffolded

- **Verified**: discrete-time POMDP inference, eq. 4.10 / 4.11 / 4.13 / 4.14
  and Appendix-B eq. B.5 / B.9 / B.29 / B.30. Maze MVP end-to-end.
- **Scaffolded** (registry present, runtime hooks exist): continuous-time
  generalised filtering (eq. 8.1 / 8.2 / B.42 / B.47 / B.48), Dirichlet
  learning (eq. 7.10 / B.10–B.12), hybrid models.

See `DELIVERABLE.md` for the full inventory.

## Troubleshooting

- **`:jido not found`** — verify that `../jido` exists relative to the
  umbrella root. The path dep is in `apps/agent_plane/mix.exs`.
- **Port 4000 in use** — change the port in `config/dev.exs`.
- **Elixir 1.19 compile warnings** — Phoenix LiveView 0.20 emits some
  dynamic-struct warnings on 1.19; they are cosmetic and don't affect the
  runtime.

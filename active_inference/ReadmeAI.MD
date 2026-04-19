# active_inference/ — ReadmeAI

## Purpose

The Elixir umbrella application implementing the Active Inference workbench. Contains seven umbrella apps plus shared configuration. This file complements [`README.md`](README.md) (human run guide) with an AI-oriented navigation view.

## Contents

| Path | Role | Deeper doc |
|---|---|---|
| [`README.md`](README.md) | Umbrella run guide | — |
| [`DELIVERABLE.md`](DELIVERABLE.md) | Extraction report, equation ledger, inline ADRs, completion status | — |
| [`mix.exs`](mix.exs) | Umbrella project definition; `apps_path: "apps"`; ExDoc config | — |
| [`.formatter.exs`](.formatter.exs) | Mix formatter config |  — |
| [`.gitignore`](.gitignore) | Build artefacts + Mnesia on-disk dirs |  — |
| [`apps/`](apps/) | The seven umbrella apps | per-app `ReadmeAI.MD` |
| [`config/`](config/) | Runtime configuration | [`config/ReadmeAI.MD`](config/ReadmeAI.MD) |
| [`scripts/`](scripts/) | Phase observation scripts | [`scripts/ReadmeAI.MD`](scripts/ReadmeAI.MD) |
| [`docs/`](docs/) | ADRs | [`docs/ReadmeAI.MD`](docs/ReadmeAI.MD) |

## The seven umbrella apps

Strict directed dependency graph (see [`../ARCHITECTURE.md`](../ARCHITECTURE.md) §2):

| App | Directory | Depends on (in-umbrella) | ReadmeAI |
|---|---|---|---|
| `active_inference_core` | [`apps/active_inference_core/`](apps/active_inference_core/) | (none) | [ReadmeAI](apps/active_inference_core/ReadmeAI.MD) |
| `shared_contracts` | [`apps/shared_contracts/`](apps/shared_contracts/) | (none) | [ReadmeAI](apps/shared_contracts/ReadmeAI.MD) |
| `world_plane` | [`apps/world_plane/`](apps/world_plane/) | `:shared_contracts` | [ReadmeAI](apps/world_plane/ReadmeAI.MD) |
| `agent_plane` | [`apps/agent_plane/`](apps/agent_plane/) | `:active_inference_core`, `:shared_contracts`, `:world_models`, `:jido` | [ReadmeAI](apps/agent_plane/ReadmeAI.MD) |
| `world_models` | [`apps/world_models/`](apps/world_models/) | `:phoenix_pubsub` | [ReadmeAI](apps/world_models/ReadmeAI.MD) |
| `composition_runtime` | [`apps/composition_runtime/`](apps/composition_runtime/) | `:agent_plane`, `:jido`, `:jido_signal` | [ReadmeAI](apps/composition_runtime/ReadmeAI.MD) |
| `workbench_web` | [`apps/workbench_web/`](apps/workbench_web/) | all of the above | [ReadmeAI](apps/workbench_web/ReadmeAI.MD) |

Plane-separation invariant: `world_plane` does not depend on `agent_plane` or `active_inference_core`; `agent_plane` does not depend on `world_plane`. Enforced by `apps/*/test/plane_separation_test.exs`.

## Public API surface (umbrella)

Umbrellas do not expose a single API — each app exports its own. See the per-app `ReadmeAI.MD` tables for the full public surface. High-traffic entry points:

- [`AgentPlane.Runtime`](apps/agent_plane/lib/agent_plane/runtime.ex) — start/step/perceive/plan/act a Jido agent
- [`WorldPlane.Engine`](apps/world_plane/lib/world_plane/engine.ex) — create/advance an episode (GenServer)
- [`WorkbenchWeb.Episode`](apps/workbench_web/lib/workbench_web/episode.ex) — orchestrates agent + world across the Markov blanket
- [`WorldModels.Bus`](apps/world_models/lib/world_models/bus.ex) — subscribe to event streams
- [`WorldModels.EventLog`](apps/world_models/lib/world_models/event_log.ex) — append / query the Mnesia event log
- [`ActiveInferenceCore.DiscreteTime`](apps/active_inference_core/lib/active_inference_core/discrete_time.ex) — pure POMDP math
- [`ActiveInferenceCore.Equations`](apps/active_inference_core/lib/active_inference_core/equations.ex) — equation registry

## Data types & schemas

Top-level types by app (full list in each app's `ReadmeAI.MD`):

- Math: `Math.vec/0`, `Math.mat/0`, `DiscreteTime.belief/0` — [`apps/active_inference_core/lib/active_inference_core/`](apps/active_inference_core/lib/active_inference_core/)
- Packets: `ActionPacket.t/0`, `ObservationPacket.t/0`, `Blanket.t/0` — [`apps/shared_contracts/lib/shared_contracts/`](apps/shared_contracts/lib/shared_contracts/)
- World: `Maze.t/0`, `Engine.t/0` — [`apps/world_plane/lib/world_plane/`](apps/world_plane/lib/world_plane/)
- Agent state: `ActiveInferenceAgent.State` — [`apps/agent_plane/lib/agent_plane/active_inference_agent.ex`](apps/agent_plane/lib/agent_plane/active_inference_agent.ex)
- Events / specs: `Event.t/0`, `Event.provenance/0`, `Spec.t/0`, `Archetypes.t/0` — [`apps/world_models/lib/world_models/`](apps/world_models/lib/world_models/)
- Signal broker state: `SignalBroker.state/0` — [`apps/composition_runtime/lib/composition_runtime/signal_broker.ex`](apps/composition_runtime/lib/composition_runtime/signal_broker.ex)

## Constants & config keys

See [`config/ReadmeAI.MD`](config/ReadmeAI.MD) for the exhaustive config key table. Key env overrides:

- `:mnesia, :dir` — disk location for the event log
- `:world_models, :auto_start_event_log` — tests set `false`; dev/prod default `true`
- `:agent_plane, AgentPlane.JidoInstance, :max_tasks` — `1000`
- `:workbench_web, WorkbenchWeb.Endpoint, :http, :port` — dev `4000`, test `4002`

## Telemetry / signals / events emitted here

Full taxonomy in [`apps/agent_plane/lib/agent_plane/telemetry/bus.ex:17-32`](apps/agent_plane/lib/agent_plane/telemetry/bus.ex). Summary:

- `[:active_inference_core, :discrete_time, :call, :start|:stop|:exception]` — pure math span
- `[:jido, :agent_server, :signal, :start|:stop|:exception]` — Jido signal lifecycle
- `[:jido, :agent_server, :directive, :start|:stop|:exception]` — Jido directive lifecycle
- `[:jido, :agent, :cmd, :start|:stop|:exception]` — Jido cmd lifecycle

Re-emitted as `WorldModels.Event` of type `"equation.evaluated"` or `"runtime.jido.*"` by [`AgentPlane.Telemetry.Bus`](apps/agent_plane/lib/agent_plane/telemetry/bus.ex).

## Dependencies

- **Inbound**: `mix phx.server`, `mix test`, `mix run scripts/*`, `mix docs`.
- **Outbound (Hex)**: `:phoenix`, `:phoenix_live_view`, `:phoenix_pubsub`, `:phoenix_html`, `:bandit`, `:jason`, `:plug_cowboy`, `:floki` (test), `:ex_doc` (dev), `:jido`, `:jido_signal`.

## Verification status

- `:verified` — 38 tests across 5 apps pass ([`README.md:52-58`](README.md)).
- `:verified` — `mix q` (format + warnings-as-errors test) defined in [`mix.exs:34-37`](mix.exs).
- `:scaffolded` — continuous-time / Dirichlet / hybrid families have registry + runtime hooks; no end-to-end tests yet (see [`DELIVERABLE.md`](DELIVERABLE.md) §10).

## Related

- Repo root: [`../README.md`](../README.md), [`../ARCHITECTURE.md`](../ARCHITECTURE.md), [`../CONTRIBUTING.md`](../CONTRIBUTING.md), [`../CLAUDE.md`](../CLAUDE.md)
- Master doc index: [`../docs/INDEX.md`](../docs/INDEX.md)

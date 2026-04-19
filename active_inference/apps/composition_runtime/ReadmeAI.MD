# apps/composition_runtime/ — ReadmeAI

## Purpose

Multi-agent composition runtime. Provides a supervisor + signal broker so multiple Jido agents can cooperate via `Jido.Signal` routing — **never via raw `send/2` or `GenServer.call`** (see [`CLAUDE.md`](../../../CLAUDE.md) non-negotiables).

## Contents

| Path | Role |
|---|---|
| [`lib/composition_runtime.ex`](lib/composition_runtime.ex) | Root (no public API) |
| [`lib/composition_runtime/application.ex`](lib/composition_runtime/application.ex) | OTP Application |
| [`lib/composition_runtime/composition.ex`](lib/composition_runtime/composition.ex) | Supervisor of `{SignalBroker, agents, tasks}` |
| [`lib/composition_runtime/signal_broker.ex`](lib/composition_runtime/signal_broker.ex) | GenServer routing `Jido.Signal` by `target_agent_id` |
| [`lib/composition_runtime/registry.ex`](lib/composition_runtime/registry.ex) | Live composition registry (unique name tracker) |
| [`test/`](test/) | Composition smoke tests — [`test/ReadmeAI.MD`](test/ReadmeAI.MD) |

## Public API surface

| Module | Function | Arity | Purpose |
|---|---|---|---|
| `CompositionRuntime.Composition` | `start_link/1` | 1 | Start a supervised composition with `:one_for_one` strategy |
| `CompositionRuntime.SignalBroker` | `start_link/1` | 1 | Start a broker keyed by `composition_id` |
| `CompositionRuntime.SignalBroker` | `register_agent/3` | 3 | Register `{agent_id, pid, wires}` |
| `CompositionRuntime.SignalBroker` | `route/2` | 2 | Route a `Jido.Signal` to its target |
| `CompositionRuntime.SignalBroker` | `agents/1` | 1 | List registered agents in a composition |

## Data types & schemas

| Type | File:Line | Fields |
|---|---|---|
| `SignalBroker.state/0` | [signal_broker.ex:19](lib/composition_runtime/signal_broker.ex) | `:composition_id :: String.t`, `:agents :: %{String.t => pid()}`, `:wires :: [wire]` |

## Constants & config keys

None. Application has three children in [`application.ex`](lib/composition_runtime/application.ex):

1. `{Elixir.Registry, keys: :unique, name: CompositionRuntime.NameRegistry}`
2. `{DynamicSupervisor, name: CompositionRuntime.RootSupervisor}`
3. `CompositionRuntime.Registry`

Parent supervisor: `CompositionRuntime.AppSup`.

## Telemetry / signals / events emitted here

None directly. Routed signals carry their own `trace_id` / `span_id` set by Jido.

## Dependencies

- **Inbound**: [`../workbench_web/`](../workbench_web/) (planned use in example L5).
- **Outbound (Hex)**: `:jido` (path), `:jido_signal` (transitive).
- **Outbound (umbrella)**: `:agent_plane`, `:shared_contracts`, `:world_models`.

## Verification status

- `:scaffolded` — supervisor + broker compile and pass smoke tests; example L5 (hierarchical composition) is the end-to-end consumer.
- `:uncertain` — multi-agent coordination primitives beyond routing (aggregation, fan-out) not yet exercised.

## Related

- Jido signal reference: [`../../../knowledgebase/jido/03-signals.md`](../../../knowledgebase/jido/03-signals.md)
- Orchestration patterns: [`../../../knowledgebase/jido/13-orchestration.md`](../../../knowledgebase/jido/13-orchestration.md)

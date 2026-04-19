# knowledgebase/ — ReadmeAI

## Purpose

Curated reference material for the **Jido** framework, condensed and cross-referenced so contributors can work without re-reading the upstream guides end-to-end. This is **reference material about a dependency**, not documentation of this project's own code.

Primary source of truth is the upstream submodule at [`jido/`](../jido/) (v2.2.0, matches `hexdocs.pm/jido`). The knowledgebase here summarises and cross-links that content.

## Contents

### `jido/` — 27 files

| File | Topic |
|---|---|
| [MASTER-INDEX.md](jido/MASTER-INDEX.md) | Navigation hub, ecosystem table, runtime baseline, topic list, decision tree, upstream references |
| [00-philosophy.md](jido/00-philosophy.md) | Invariants, the `cmd/2` contract, what NOT to do |
| [01-agents.md](jido/01-agents.md) | `use Jido.Agent`, schemas, `cmd/2`, hooks, `set/2`, `validate/2` |
| [02-actions.md](jido/02-actions.md) | `use Jido.Action`, `run/2` contract, return shapes |
| [03-signals.md](jido/03-signals.md) | `Jido.Signal`, routing, emit helpers, dispatch adapters |
| [04-directives.md](jido/04-directives.md) | `Emit`, `SpawnAgent`, `Schedule`, `Cron`, `RunInstruction`, etc. |
| [05-state-ops.md](jido/05-state-ops.md) | `SetState`, `ReplaceState`, `DeleteKeys`, `SetPath`, `DeletePath` |
| [06-runtime.md](jido/06-runtime.md) | `use Jido`, `AgentServer`, `call/cast`, instance API |
| [07-strategies.md](jido/07-strategies.md) | `Direct`, `FSM`, custom strategy contract |
| [08-plugins.md](jido/08-plugins.md) | Plugin definition, state isolation, Identity / Thread / Memory |
| [09-sensors.md](jido/09-sensors.md) | `Jido.Sensor`, `Sensor.Runtime`, ingress directives |
| [10-persistence.md](jido/10-persistence.md) | `Jido.Storage`, `hibernate/thaw`, `InstanceManager`, Thread journal |
| [11-pods.md](jido/11-pods.md) | `Jido.Pod`, topology, `mutate/3`, `reconcile/2`, `ensure_node/3` |
| [12-multi-tenancy.md](jido/12-multi-tenancy.md) | `partition`, Pod-first tenancy |
| [13-orchestration.md](jido/13-orchestration.md) | Fan-out, parent/child, aggregation |
| [14-orphans-adoption.md](jido/14-orphans-adoption.md) | `on_parent_death`, `adopt_child`, orphan lifecycle |
| [15-scheduling.md](jido/15-scheduling.md) | Declarative `schedules:`, dynamic `Cron`, `Schedule` |
| [16-worker-pools.md](jido/16-worker-pools.md) | `agent_pools:`, `WorkerPool.with_agent/4` |
| [17-observability.md](jido/17-observability.md) | Telemetry events, spans, tracers, metrics |
| [18-debugging.md](jido/18-debugging.md) | Debug mode, ring buffer, Logger setup |
| [19-errors.md](jido/19-errors.md) | `Jido.Error.*`, `Directive.Error`, error policies |
| [20-testing.md](jido/20-testing.md) | `JidoTest.Case`, pure tests, `Jido.await/2`, `mimic` |
| [21-configuration.md](jido/21-configuration.md) | Instance config, supervision tree, env overrides |
| [22-discovery.md](jido/22-discovery.md) | `Jido.Discovery`, `list_*`, `get_*_by_slug` |
| [23-integrations.md](jido/23-integrations.md) | Phoenix/LiveView, Ash, PubSub patterns |
| [24-migration-1-to-2.md](jido/24-migration-1-to-2.md) | Upgrading from Jido 1.x |
| [25-cheatsheet.md](jido/25-cheatsheet.md) | Common code patterns, which tool for which job |

## Public API surface

None — this folder is documentation, not code.

## Data types & schemas

None emitted from this folder. The topic files document Jido framework types (`Jido.Agent.t`, `Jido.Signal.t`, etc.); see upstream [`jido/lib/`](../jido/lib/) for canonical definitions.

## Constants & config keys

None emitted from this folder.

## Telemetry / signals / events emitted here

None. The files document the Jido telemetry surface — actual events are emitted by the Jido framework itself (see [17-observability.md](jido/17-observability.md)).

## Dependencies

- **Inbound**: [`CLAUDE.md`](../CLAUDE.md) instructs contributors to read the MASTER-INDEX before writing agent code.
- **Outbound**: [`jido/`](../jido/) submodule (upstream source of truth).

## Verification status

- `:verified` — topic files exist and match the upstream `jido/` v2.2.0 source. Last sync date is recorded in `jido/AGENTS.md` upstream.
- `:uncertain` — knowledge drift is possible between upstream releases and these files. Refresh protocol is in [`CLAUDE.md`](../CLAUDE.md) ("Knowledgebase Maintenance").

## Related

- Upstream submodule: [`jido/`](../jido/) (v2.2.0 @ `github.com/agentjido/jido`)
- Project rules: [`CLAUDE.md`](../CLAUDE.md)
- Hex docs: <https://hexdocs.pm/jido/readme.html>
- Project architecture: [`ARCHITECTURE.md`](../ARCHITECTURE.md)

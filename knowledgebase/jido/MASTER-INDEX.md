# Jido Knowledgebase — Master Index

> **Mandate:** This project uses **pure Jido / Elixir / BEAM** for all agent work. No Python, no external agent runtimes, no LangChain/CrewAI/Autogen. AI model calls use the `jido_ai` companion package.

> **Primary source of truth:** The cloned upstream repo at `jido/` (version `2.2.0`, matches `hexdocs.pm/jido`). This knowledgebase condenses and cross-references that content so you can work without re-reading the guides end-to-end.

## How to Use This Knowledgebase

1. **Start with [00-philosophy.md](00-philosophy.md)** — the invariants that must never be violated.
2. **When building a feature**, open the topic file(s) listed below, then jump to the upstream guide only for edge cases.
3. **Before writing code**, check [25-cheatsheet.md](25-cheatsheet.md) for the right module/pattern.
4. **Upstream paths** in citations are relative to `jido/` (the cloned repo root).

## Ecosystem

| Package | Purpose | Hex |
|---|---|---|
| `jido` | Core agent framework (this repo) | `~> 2.2` |
| `jido_action` | Composable validated actions | `~> 2.2` |
| `jido_signal` | CloudEvents envelope + routing | `~> 2.1` |
| `jido_ai` | LLM integration for agents | (opt-in) |
| `req_llm` | HTTP client for LLM APIs | (opt-in) |

## Runtime Baseline

- Elixir `~> 1.18` (README says `1.17+`; upstream `mix.exs` sets `~> 1.18`)
- OTP `27+` (release QA baseline; README lists `26+`)
- Use `Zoi` schemas for **new** agent/plugin/signal/directive contracts (legacy `NimbleOptions` still accepted)

## Topic Files (read order)

### Core Model
- [00-philosophy.md](00-philosophy.md) — Invariants, the `cmd/2` contract, what NOT to do
- [01-agents.md](01-agents.md) — `use Jido.Agent`, schemas, `cmd/2`, hooks, `set/2`, `validate/2`
- [02-actions.md](02-actions.md) — `use Jido.Action`, `run/2` contract, return shapes
- [03-signals.md](03-signals.md) — `Jido.Signal`, routing, emit helpers, dispatch adapters
- [04-directives.md](04-directives.md) — `Emit`, `SpawnAgent`, `Schedule`, `Cron`, `RunInstruction`, etc.
- [05-state-ops.md](05-state-ops.md) — `SetState`, `ReplaceState`, `DeleteKeys`, `SetPath`, `DeletePath`

### Runtime
- [06-runtime.md](06-runtime.md) — `use Jido`, `AgentServer`, `call/cast`, instance API
- [07-strategies.md](07-strategies.md) — `Direct`, `FSM`, custom strategy contract
- [08-plugins.md](08-plugins.md) — Plugin definition, state isolation, default plugins (Identity / Thread / Memory)
- [09-sensors.md](09-sensors.md) — `Jido.Sensor` behaviour, `Sensor.Runtime`, ingress directives

### Persistence & Topology
- [10-persistence.md](10-persistence.md) — `Jido.Storage`, `hibernate/thaw`, `InstanceManager`, Thread journal / Checkpoint
- [11-pods.md](11-pods.md) — `Jido.Pod`, topology, `mutate/3`, `reconcile/2`, `ensure_node/3`
- [12-multi-tenancy.md](12-multi-tenancy.md) — `partition`, Pod-first tenancy

### Coordination
- [13-orchestration.md](13-orchestration.md) — Fan-out, parent/child, aggregation
- [14-orphans-adoption.md](14-orphans-adoption.md) — `on_parent_death`, `adopt_child`, orphan lifecycle
- [15-scheduling.md](15-scheduling.md) — Declarative `schedules:`, dynamic `Cron`, `Schedule`
- [16-worker-pools.md](16-worker-pools.md) — `agent_pools:`, `WorkerPool.with_agent/4`

### Operations
- [17-observability.md](17-observability.md) — Telemetry events, spans, tracers, metrics
- [18-debugging.md](18-debugging.md) — Debug mode, ring buffer, Logger setup
- [19-errors.md](19-errors.md) — `Jido.Error.*`, `Directive.Error`, error policies
- [20-testing.md](20-testing.md) — `JidoTest.Case`, pure tests, `Jido.await/2`, `mimic`
- [21-configuration.md](21-configuration.md) — Instance config, supervision tree, env overrides
- [22-discovery.md](22-discovery.md) — `Jido.Discovery`, `list_*`, `get_*_by_slug`

### Integration & Migration
- [23-integrations.md](23-integrations.md) — Phoenix/LiveView, Ash, PubSub patterns
- [24-migration-1-to-2.md](24-migration-1-to-2.md) — Upgrading from Jido 1.x

### Quick Reference
- [25-cheatsheet.md](25-cheatsheet.md) — Common code patterns, which tool for which job

## Decision Tree (runtime pattern)

| Need | Use | Source |
|---|---|---|
| One live agent, ephemeral | `MyApp.Jido.start_agent/2` | [06](06-runtime.md) |
| Live tracked child of current parent | `Directive.spawn_agent/3` | [04](04-directives.md) |
| One durable named agent (hibernate/thaw) | `Jido.Agent.InstanceManager.get/3` | [10](10-persistence.md) |
| Durable named team with topology | `Jido.Pod.get/3` + `ensure_node/3` | [11](11-pods.md) |
| Tenancy over any of the above | add `partition:` | [12](12-multi-tenancy.md) |
| Pre-warmed pool for throughput | `agent_pools:` + `WorkerPool.with_agent/4` | [16](16-worker-pools.md) |

## Upstream References

- Cloned repo: `C:\Users\mpolz\Documents\WorldModels\jido\`
- Guides: `jido/guides/` (maps 1:1 to hexdocs pages)
- `jido/usage-rules.md` — canonical author rules
- `jido/AGENTS.md` — runtime baseline, QA commands
- `jido/test/AGENTS.md` — test helpers
- Hex docs: https://hexdocs.pm/jido/readme.html
- GitHub: https://github.com/agentjido/jido

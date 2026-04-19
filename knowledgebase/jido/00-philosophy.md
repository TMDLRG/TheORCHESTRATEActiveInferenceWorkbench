# 00 — Philosophy & Invariants

> **One-sentence model:** `Signal → Router → Action → cmd/2 → {agent, directives} → Runtime executes directives`

## The `cmd/2` Contract (immutable)

```elixir
{updated_agent, directives} = MyAgent.cmd(agent, action)
```

Three invariants that must **never** be violated:

1. **`cmd/2` is a pure function.** Same inputs → same outputs. No process reads, no I/O, no clocks (inside the agent's internal transition logic — actions themselves may do I/O).
2. **The returned agent is complete.** There is no "apply directives" step that mutates state afterward. All state changes landed before `cmd/2` returned.
3. **Directives never mutate agent state.** They describe external effects (emit a signal, spawn a child, schedule a message). The runtime interprets them.

If you're tempted to put side effects directly in `cmd/2` or a strategy callback, **stop** — return a directive instead.

## The Actions ↔ Directives ↔ StateOps Separation

| Concept | Module | Purpose | Handled By |
|---|---|---|---|
| **Action** | `use Jido.Action` | Domain work; may I/O; transforms state | Called from `cmd/2` |
| **Directive** | `Jido.Agent.Directive.*` | External effect description | `AgentServer` runtime |
| **StateOp** | `Jido.Agent.StateOp.*` | Internal state transition | Strategy layer (during `cmd/2`) |

- StateOps **never leave the strategy** — they're applied before `cmd/2` returns.
- Directives **never modify state** — they pass through to the runtime unchanged.
- Actions live in their own package (`jido_action`); they can emit both StateOps and Directives.

## When to Use What

- **Pure data transform?** Return a map from `run/2` (deep-merged) or a `StateOp.SetState` / `SetPath`.
- **Remove keys or reset state?** `StateOp.DeleteKeys` / `DeletePath` / `ReplaceState`.
- **Emit a signal?** `Directive.Emit` (or `emit_to_pid`, `emit_to_parent`).
- **Start a child agent?** `Directive.SpawnAgent` (tracked) — never raw `GenServer.start_link` inside actions.
- **Start a task?** `Directive.Spawn` (untracked, fire-and-forget).
- **Delay something?** `Directive.Schedule` (one-shot) or `Directive.Cron` (recurring).
- **Runtime logic (routing, lookup, pooling)?** Use the instance module (`MyApp.Jido.start_agent/2` etc.), never reach past it.

## "Why Jido, not raw GenServer?"

Raw GenServer works until you have multiple cooperating agents. Then you reinvent:

| Raw OTP | Jido formalizes |
|---|---|
| Ad-hoc message shapes | CloudEvents-shaped `Jido.Signal` |
| Business logic in callbacks | `Jido.Action` with schemas |
| Implicit effects scattered | `Jido.Agent.Directive` typed effects |
| Custom child tracking | Built-in parent/child via `SpawnAgent` |
| Process exit = completion | State-based completion (`status: :completed`) |

Jido is a **formalized agent pattern built on GenServer**, not a replacement for it.

## Instance-Scoped Architecture (no global singletons)

```elixir
defmodule MyApp.Jido do
  use Jido, otp_app: :my_app
end
```

Then `children = [MyApp.Jido]`. This gives you:

- An isolated `Registry`, `DynamicSupervisor`, `Task.Supervisor`, `RuntimeStore` per instance.
- Multiple isolated Jido instances per app (hard multi-tenancy).
- Partition-scoped namespaces within one instance (logical multi-tenancy — see [12](12-multi-tenancy.md)).

Never pass `Jido` (the module) where `MyApp.Jido` (your instance) belongs.

## Schemas: Zoi-First

- **New** agents, plugins, directives, signals, sensors → `Zoi` schemas.
- Legacy `NimbleOptions` keyword schemas still work (the Agent module transparently handles both), but don't author new code with them.

```elixir
# Preferred (Zoi)
schema: Zoi.object(%{
  status: Zoi.atom() |> Zoi.default(:idle),
  counter: Zoi.integer() |> Zoi.default(0)
})

# Legacy (still supported)
schema: [
  status: [type: :atom, default: :idle],
  counter: [type: :integer, default: 0]
]
```

## Error Discipline

- Public boundaries return tagged tuples: `{:ok, ...}` / `{:error, %Jido.Error.*{}}`.
- Errors are **structured** (`Splode`-based): `ValidationError`, `ExecutionError`, `RoutingError`, `TimeoutError`, `CompensationError`, `InternalError`.
- Never return naked strings, atoms, or raw maps as errors from public APIs.
- See [19-errors.md](19-errors.md) for complete taxonomy and error policies.

## Testing Discipline

- **Pure-agent tests first** — `{agent, directives} = MyAgent.cmd(agent, action)` without any runtime.
- **Then integration tests** via `JidoTest.Case` — per-test isolated Jido instance.
- **Never use `Process.sleep/1`** — use `Jido.await/2` or `JidoTest.Eventually` helpers.
- Mock external dependencies with `Mimic`, not `mock` or raw ETS fakes.

See [20-testing.md](20-testing.md).

## Things This Project Explicitly Rejects

- Python-side agent orchestration, shelling out to Python, or using Python-first frameworks (LangChain, CrewAI, Autogen).
- Using other Elixir agent frameworks that bypass Jido's pure-`cmd/2`/directive separation.
- Embedding runtime side effects (PubSub broadcast, HTTP calls) directly in strategy or agent-module callbacks.
- Using directives as a back door to mutate agent state.
- Tight coupling between unrelated agent modules — cross-agent communication is signals or directives only.
- `Process.sleep` in tests or production.
- `--no-verify` / skipping pre-commit hooks.

## Release Checklist (from `jido/AGENTS.md`)

- `mix test` (default excludes `:flaky`)
- `mix test --include flaky` (full suite)
- `mix test --cover`
- `mix q` (alias for `mix quality` — format, compile with warnings-as-errors, credo, dialyzer)
- Update `CHANGELOG.md`, guides, examples for API/behavior changes
- Keep semver ranges stable (`~> 2.0` for Jido ecosystem peers)
- Use Conventional Commits

## Source

- `jido/README.md`
- `jido/usage-rules.md`
- `jido/AGENTS.md`
- `jido/guides/core-loop.md`

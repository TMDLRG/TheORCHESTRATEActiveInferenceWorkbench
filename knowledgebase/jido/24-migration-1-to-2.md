# 24 — Migration 1.x → 2.x

> The major breaking changes when upgrading, with before/after code.

## Breaking Changes at a Glance

| Area | V1 | V2 | Effort |
|---|---|---|---|
| Runtime | Global singleton | Instance-scoped supervisor | Small |
| Lifecycle | `AgentServer.start/1` | `Jido.start_agent/3` | Small–Medium |
| Side effects | Mixed in callbacks | Directive-based | Medium |
| Messaging | `Jido.Instruction` | CloudEvents `Jido.Signal` | Medium–Large |
| Orchestration | Runners (Simple/Chain) | Strategies + Plans | Medium |
| Validation | NimbleOptions only | Zoi schemas preferred | Small–Medium |
| Errors | Ad-hoc tuples | Splode-structured `Jido.Error` | Small–Medium |

## 1. Instance Module + Supervision

```elixir
# V2
defmodule MyApp.Jido do
  use Jido, otp_app: :my_app
end

# application.ex
children = [MyApp.Jido, MyApp.Repo, MyAppWeb.Endpoint]
```

## 2. Agent Lifecycle

```elixir
# V1
{:ok, pid} = MyAgent.start_link(id: "agent-1")

# V2
{:ok, pid} = MyApp.Jido.start_agent(MyAgent, id: "agent-1")
```

```elixir
# V1
AgentServer.stop(pid)     # or GenServer.stop(pid)
Process.whereis(:"agent_agent-1")

# V2
MyApp.Jido.stop_agent("agent-1")
MyApp.Jido.whereis("agent-1")
```

## 3. Side Effects → Directives

```elixir
# V1: mixed in callbacks
def handle_result(agent, result) do
  Phoenix.PubSub.broadcast(MyApp.PubSub, "events", result)
  %{agent | state: Map.put(agent.state, :last_result, result)}
end

# V2: declarative
def cmd(agent, signal) do
  result = process(signal)
  signal_out = Jido.Signal.new!("processed", result, source: "/agent")

  {%{agent | state: Map.put(agent.state, :last_result, result)}, [
    Directive.emit(signal_out, {:pubsub, topic: "events"})
  ]}
end
```

Core directives to know: `Emit`, `Spawn`, `SpawnAgent`, `StopChild`, `Schedule`, `Cron`, `Stop`, `Error`. See [04-directives.md](04-directives.md).

## 4. CloudEvents Signals

```elixir
# V1
send(pid, {:task_complete, %{id: 123}})

# V2
signal = Jido.Signal.new!("task.completed", %{id: 123}, source: "/workers")
{:ok, agent} = Jido.AgentServer.call(pid, signal)
# or fire-and-forget:
Jido.AgentServer.cast(pid, signal)
```

Signal anatomy:

```elixir
%Jido.Signal{
  type: "order.placed",
  source: "/checkout/web",
  id: "550e8400-...",
  data: %{order_id: 123},
  subject: "user/456",
  time: ~U[2024-01-15 10:30:00Z]
}
```

## 5. Actions → Tools namespace (and `jido_action` package)

```elixir
# V1
Jido.Actions.*

# V2
Jido.Tools.*     # namespace renamed in some places
# Plus: Actions live in the separate jido_action package
```

## 6. Zoi Schemas (replacing NimbleOptions in new code)

```elixir
# V1
schema: [
  name: [type: :string, required: true],
  count: [type: :integer, default: 0]
]

# V2 (preferred)
@schema Zoi.struct(__MODULE__, %{
  name: Zoi.string(),
  count: Zoi.integer() |> Zoi.default(0)
})
```

Both are still accepted — `use Jido.Agent` handles both transparently. Migrate when you touch the module.

## 7. Splode Errors

```elixir
# V2
Jido.Error.validation_error("Invalid email", field: :email)
Jido.Error.execution_error("Failed", phase: :execution)
Jido.Error.routing_error("No handler", target: "user.created")
Jido.Error.timeout_error("Timed out", timeout: 5000)
```

## 8. Strategies + Plans (orchestration)

`Jido.Runner.Simple` / `Jido.Runner.Chain` → `Jido.Agent.Strategy.Direct` / `Jido.Agent.Strategy.FSM` (and custom strategies). See [07-strategies.md](07-strategies.md).

## New Features to Consider Adopting

- **Parent-child hierarchy:** `Directive.spawn_agent/3` → tracked children, `emit_to_parent/3`, child exit signals
- **Orphan lifecycle:** `on_parent_death: :emit_orphan` → durable work survives coordinator death
- **Plugins:** `use Jido.Plugin` → isolated state + routing + actions as reusable modules
- **Strategies:** `Jido.Agent.Strategy.FSM` → explicit execution-state tracking
- **Telemetry:** events on all core operations (see [17](17-observability.md))
- **Pods:** `use Jido.Pod` → durable named teams with topology ([11](11-pods.md))
- **Multi-tenancy:** `partition:` option ([12](12-multi-tenancy.md))
- **Worker pools:** pre-warmed throughput ([16](16-worker-pools.md))
- **Debug mode:** `MyApp.Jido.debug(:on)` + ring buffer ([18](18-debugging.md))

## Gradual Adoption Patterns

1. **Start with the instance module.** Wrap all lifecycle calls through `MyApp.Jido.*` — even legacy agents work under the supervision tree.
2. **Directives incrementally.** New code uses directives; legacy callback-style code works alongside. Migrate when you touch the module.
3. **Signal adapter for legacy messages.** If you have external systems sending raw tuples, build a single sensor/bridge that converts them to Signals.

## Troubleshooting

- **"Agent not found":** verify the Jido instance name. Use `MyApp.Jido.whereis/1`, not `Jido.whereis/1` (the latter requires a default instance).
- **Directives not executing:** ensure they're returned from `cmd/2` (or `run/2` for actions). Directives that stay in local variables never reach the runtime.
- **Schema validation errors:** Zoi fields are **required by default**. Use `Zoi.optional()` or `Zoi.default(...)` for optional/defaulted fields.

## Source

- `jido/guides/migration.md`
- `jido/CHANGELOG.md`
- `jido/README.md`

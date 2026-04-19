# 03 — Signals & Routing

> Signals (from `jido_signal`) are CloudEvents-shaped messages that trigger agent behaviour. They are the **only** approved cross-agent communication channel.

## Anatomy

```elixir
%Jido.Signal{
  type: "order.placed",          # REQUIRED — used for routing
  source: "/checkout/web",       # REQUIRED — where it came from
  id: "550e8400-...",            # auto-generated if not set
  data: %{order_id: 123},        # payload (second arg of new!)
  subject: "user/456",           # optional — who/what it's about
  time: ~U[2024-01-15 10:30:00Z] # auto-set
}
```

## Creating Signals

```elixir
# Basic
signal = Jido.Signal.new!("increment", %{amount: 10}, source: "/user")

# Full
signal = Jido.Signal.new!("order.completed", %{
  order_id: 456,
  total: 99.99
}, source: "/checkout", subject: "/orders/456")

# Map form also accepted
Jido.Signal.new!(%{type: "sensor.tick", source: "/sensor/tick", data: %{count: 3}})
```

Use dotted type names (`"domain.event"`, `"chat.message.new"`) — plugin/agent signal_patterns use glob matching.

## Sending Signals to a Running Agent

```elixir
# Synchronous — blocks for result
{:ok, agent} = Jido.AgentServer.call(pid, signal)
{:ok, agent} = Jido.AgentServer.call(pid, signal, 10_000)           # custom timeout
{:ok, agent} = Jido.AgentServer.call("agent-id", signal)            # via Registry

# Asynchronous — fire and forget
:ok = Jido.AgentServer.cast(pid, signal)
:ok = Jido.AgentServer.cast("agent-id", signal)
```

Default call timeout is 5000ms.

## Signal Routing (priority order)

When a signal arrives at `AgentServer`, the `SignalRouter` resolves a handler in this order:

| Priority | Source | How to declare |
|---|---|---|
| 50+ | Strategy routes | `def signal_routes(_ctx)` callback on the strategy |
| 0 | Agent routes | `signal_routes: [{"type", Action}]` on `use Jido.Agent` |
| -10 | Plugin routes | `signal_patterns:` + `signal_routes:` on `use Jido.Plugin` |

Higher priority wins. First match in each tier wins.

### Agent routes (static, compile-time)

```elixir
defmodule MyApp.CounterAgent do
  use Jido.Agent,
    name: "counter",
    signal_routes: [
      {"increment", MyApp.Actions.Increment},
      {"decrement", MyApp.Actions.Decrement},
      {"reset", MyApp.Actions.Reset}
    ]
end
```

### Strategy routes (dynamic, from strategy context)

```elixir
defmodule MyStrategy do
  use Jido.Agent.Strategy

  @impl true
  def signal_routes(_ctx) do
    [
      {"react.user_query", {:strategy_cmd, :react_start}},
      {"ai.llm_result", {:strategy_cmd, :react_llm_result}}
    ]
  end
end
```

The `{:strategy_cmd, :internal_action}` tuple targets a strategy-internal handler — see [07-strategies.md](07-strategies.md).

### Plugin routes (compile-time or callback)

```elixir
defmodule MyApp.ChatPlugin do
  use Jido.Plugin,
    name: "chat",
    state_key: :chat,
    actions: [MyApp.Actions.SendMessage, MyApp.Actions.ClearHistory],
    signal_patterns: ["chat.*"],
    signal_routes: [
      {"chat.send", MyApp.Actions.SendMessage},
      {"chat.clear", MyApp.Actions.ClearHistory}
    ]
end
```

Pattern matching: `"chat.*"` matches single segment (`chat.send`, `chat.clear`); `"chat.**"` matches multi-segment (`chat.message`, `chat.room.join`).

Only use the `signal_routes/1` callback on a plugin when routes must be computed from runtime config.

## Emitting Signals from Actions

Use the `Emit` directive:

```elixir
alias Jido.Agent.Directive
alias Jido.Signal

def run(%{order_id: id}, _context) do
  signal = Signal.new!(
    "order.processed",
    %{order_id: id, processed_at: DateTime.utc_now()},
    source: "/orders"
  )

  {:ok, %{status: :processed}, [Directive.emit(signal)]}
end
```

## Dispatch Adapters

The `Emit` directive can target different adapters:

```elixir
Directive.emit(signal)                                  # default adapter
Directive.emit(signal, {:pubsub, pubsub: MyApp.PubSub, topic: "events"})
Directive.emit_to_pid(signal, pid)
Directive.emit_to_parent(agent, signal)                 # child → parent (nil if orphaned)
```

Under the hood, `AgentServer` hands off to `Jido.Signal.Dispatch` (from `jido_signal`) which interprets the adapter spec. Consult `jido_signal` docs for custom adapters.

## Built-in Framework Signal Types

`AgentServer` emits these automatically — wire them up in agent `signal_routes:` if you care:

| Type | When |
|---|---|
| `jido.agent.child.started` | A child agent spawned via `SpawnAgent` is up |
| `jido.agent.child.exit` | A tracked child exited |
| `jido.agent.orphaned` | This agent's parent died (with `on_parent_death: :emit_orphan`) |
| `jido.agent.cron.tick` | A declarative/dynamic cron job fired |
| `jido.agent.scheduled` | A `Directive.Schedule` delay elapsed |

See [15-scheduling.md](15-scheduling.md), [13-orchestration.md](13-orchestration.md), [14-orphans-adoption.md](14-orphans-adoption.md).

## End-to-End Example

```elixir
defmodule MyApp.Actions.Increment do
  use Jido.Action,
    name: "increment",
    schema: [amount: [type: :integer, default: 1]]

  def run(params, context) do
    current = Map.get(context.state, :counter, 0)
    {:ok, %{counter: current + params.amount}}
  end
end

defmodule MyApp.CounterAgent do
  use Jido.Agent,
    name: "counter",
    schema: [counter: [type: :integer, default: 0]],
    signal_routes: [{"increment", MyApp.Actions.Increment}]
end

{:ok, pid} = MyApp.Jido.start_agent(MyApp.CounterAgent, id: "counter-1")
signal = Jido.Signal.new!("increment", %{amount: 10}, source: "/user")
{:ok, agent} = Jido.AgentServer.call(pid, signal)
agent.state.counter  # => 10
```

## Source

- `jido/guides/signals.md`
- [`jido_signal` HexDocs](https://hexdocs.pm/jido_signal)

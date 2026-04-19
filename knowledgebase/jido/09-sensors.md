# 09 — Sensors

> Sensors bridge **external events** (HTTP, PubSub, timers, file-system, GenStage, Broadway) into Jido signals. The pattern: `External → Sensor → Signal → Agent`.

## Definition

```elixir
defmodule MetricSensor do
  use Jido.Sensor,
    name: "metric_sensor",
    description: "Monitors a specific metric",
    schema: Zoi.object(%{
      metric: Zoi.string(),
      threshold: Zoi.integer() |> Zoi.default(100)
    }, coerce: true)

  @impl Jido.Sensor
  def init(config, _context) do
    {:ok, %{metric: config.metric, threshold: config.threshold, last_value: nil}}
  end

  @impl Jido.Sensor
  def handle_event({:metric_update, value}, state) do
    signal = Jido.Signal.new!(%{
      source: "/sensor/metric",
      type: "metric.updated",
      data: %{value: value, previous: state.last_value, exceeded: value > state.threshold}
    })

    {:ok, %{state | last_value: value}, [{:emit, signal}]}
  end
end
```

## Callbacks

### `init(config, context)` (required)

Initialize sensor state from validated config and runtime context.

```elixir
def init(config, context) do
  {:ok, %{interval: config.interval, count: 0}, [{:schedule, config.interval}]}
end
```

Return values:
- `{:ok, state}` — initial state
- `{:ok, state, directives}` — initial state plus startup directives
- `{:error, reason}` — init failed

`context` typically contains `:agent_ref` for signal delivery.

### `handle_event(event, state)` (required)

Process incoming events and emit signals.

```elixir
def handle_event(:tick, state) do
  signal = Jido.Signal.new!(%{source: "/sensor/tick", type: "sensor.tick", data: %{count: state.count}})
  {:ok, %{state | count: state.count + 1}, [{:emit, signal}, {:schedule, state.interval}]}
end
```

Return values:
- `{:ok, state, directives}`
- `{:error, reason}`

### `terminate(reason, state)` (optional)

Clean up resources. Default returns `:ok`.

## Sensor Directives (returned from callbacks)

Sensor directives are a **small tuple vocabulary** interpreted by `Jido.Sensor.Runtime`:

| Directive | Description |
|---|---|
| `{:schedule, ms}` | Schedule a `:tick` event after `ms` ms |
| `{:schedule, ms, payload}` | Schedule a custom event after `ms` ms |
| `{:emit, signal}` | Deliver signal to the agent immediately |
| `{:connect, adapter}` | Connect to an external source |
| `{:connect, adapter, opts}` | Connect with options |
| `{:disconnect, adapter}` | Disconnect from a source |
| `{:subscribe, topic}` | Subscribe to a topic/pattern |
| `{:unsubscribe, topic}` | Unsubscribe from a topic |

Note: **Sensor directives are distinct** from agent `Jido.Agent.Directive` structs. They use tuple shapes and only apply inside `Jido.Sensor.Runtime`.

## Starting Sensors

```elixir
{:ok, sensor_pid} = Jido.Sensor.Runtime.start_link(
  sensor: MetricSensor,
  config: %{metric: "cpu_usage", threshold: 80},
  context: %{agent_ref: agent_pid},
  id: :cpu_sensor                 # optional; auto-generated if not given
)
```

### Under supervision

```elixir
children = [
  {Jido.Sensor.Runtime,
   sensor: TickSensor,
   config: %{interval: 1000},
   context: %{agent_ref: {:via, Registry, {MyApp.Registry, "my-agent"}}},
   id: :tick_sensor}
]

Supervisor.start_link(children, strategy: :one_for_one)
```

## Signal Delivery

When a sensor emits `{:emit, signal}`:

1. If `context.agent_ref` is a pid → sends `{:signal, signal}` directly
2. If `context.agent_ref` is a via/Registry tuple → uses `Jido.Signal.Dispatch`
3. If `agent_ref` missing → signal is logged but not delivered

## Built-in Sensors

### `Jido.Sensors.Heartbeat`

Emits periodic `"jido.sensor.heartbeat"` signals for liveness checks.

```elixir
{:ok, _} = Jido.Sensor.Runtime.start_link(
  sensor: Jido.Sensors.Heartbeat,
  config: %{interval: 5000, message: "alive"},
  context: %{agent_ref: agent_pid}
)
```

Payload: `%{message: ..., timestamp: ~U[...]}`.

### `Jido.Sensors.Bus` — PubSub bridge

Subscribes to Phoenix.PubSub topics and forwards messages as signals. See `jido/lib/jido/sensors/bus.ex`.

## Manual Event Injection

Inject events into a running sensor from external code:

```elixir
Jido.Sensor.Runtime.event(sensor_pid, {:external_data, payload})
```

The sensor's `handle_event/2` receives this. Use this to bridge GenStage, Broadway, custom GenServers, or external webhook handlers.

## Common Patterns

### Periodic API polling

```elixir
def init(config, _ctx) do
  {:ok, %{url: config.url, interval: config.interval}, [{:schedule, 0}]}  # poll immediately
end

def handle_event(:tick, state) do
  case fetch_data(state.url) do
    {:ok, data} ->
      signal = Jido.Signal.new!(%{source: "/sensor/api", type: "api.data", data: data})
      {:ok, state, [{:emit, signal}, {:schedule, state.interval}]}

    {:error, reason} ->
      signal = Jido.Signal.new!(%{source: "/sensor/api", type: "api.error", data: %{error: reason}})
      {:ok, state, [{:emit, signal}, {:schedule, state.interval}]}
  end
end
```

### Rate limiting

```elixir
def handle_event(:tick, state) do
  if can_emit?(state) do
    {:ok, %{state | last_emit: now_ms()}, [{:emit, signal}, {:schedule, state.interval}]}
  else
    {:ok, state, [{:schedule, state.interval}]}
  end
end

defp can_emit?(state) do
  now_ms() - state.last_emit > state.min_interval
end
```

### Deduplication

```elixir
data_hash = :erlang.phash2(new_data)
if data_hash != state.last_hash do
  {:ok, %{state | last_hash: data_hash}, [{:emit, signal}, {:schedule, state.interval}]}
else
  {:ok, state, [{:schedule, state.interval}]}
end
```

### Batching

```elixir
def handle_event({:data, item}, state) do
  buffer = [item | state.buffer]

  if length(buffer) >= state.batch_size do
    signal = Jido.Signal.new!(%{source: "/sensor/batch", type: "batch.ready", data: %{items: Enum.reverse(buffer)}})
    {:ok, %{state | buffer: []}, [{:emit, signal}]}
  else
    {:ok, %{state | buffer: buffer}, []}
  end
end
```

## Full Tutorial Example

```elixir
defmodule HandleTickAction do
  use Jido.Action,
    name: "handle_tick",
    schema: [count: [type: :integer, required: true]]

  def run(params, context) do
    current = Map.get(context.state, :tick_count, 0)
    {:ok, %{tick_count: current + 1, last_sensor_count: params.count}}
  end
end

defmodule TickCounterAgent do
  use Jido.Agent,
    name: "tick_counter",
    schema: [
      tick_count: [type: :integer, default: 0],
      last_sensor_count: [type: :integer, default: 0]
    ],
    signal_routes: [{"sensor.tick", HandleTickAction}]
end

defmodule TickSensor do
  use Jido.Sensor,
    name: "tick_sensor",
    schema: Zoi.object(%{interval: Zoi.integer() |> Zoi.default(1000)}, coerce: true)

  @impl true
  def init(config, _ctx), do: {:ok, %{interval: config.interval, count: 0}, [{:schedule, config.interval}]}

  @impl true
  def handle_event(:tick, state) do
    count = state.count + 1
    signal = Jido.Signal.new!(%{source: "/sensor/tick", type: "sensor.tick", data: %{count: count}})
    {:ok, %{state | count: count}, [{:emit, signal}, {:schedule, state.interval}]}
  end
end

# Wire together
{:ok, agent_pid} = Jido.AgentServer.start_link(agent: TickCounterAgent.new())
{:ok, _sensor} = Jido.Sensor.Runtime.start_link(
  sensor: TickSensor,
  config: %{interval: 1000},
  context: %{agent_ref: agent_pid}
)
```

## Source

- `jido/guides/sensors.md`
- `jido/guides/your-first-sensor.md`
- `jido/lib/jido/sensor.ex`, `jido/lib/jido/sensor/runtime.ex`, `jido/lib/jido/sensors/*.ex`

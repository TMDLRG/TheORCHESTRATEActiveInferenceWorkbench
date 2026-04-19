# 16 — Worker Pools

> Pre-warmed agent pools for throughput. Use when you want bounded concurrency and sub-millisecond checkout. Built on poolboy.

## Configuration

Define pools on the Jido instance:

```elixir
config :my_app, MyApp.Jido,
  agent_pools: [
    {:fast_search, MyApp.SearchAgent, size: 8, max_overflow: 4, strategy: :lifo},
    {:planner, MyApp.PlannerAgent, size: 4, strategy: :fifo}
  ]
```

Each pool entry: `{pool_name_atom, AgentModule, opts}`.

### Pool options

| Option | Default | Description |
|---|---|---|
| `:size` | `5` | Fixed pre-warmed workers |
| `:max_overflow` | `0` | Temp workers when pool exhausted |
| `:strategy` | `:lifo` | `:lifo` (warm cache) or `:fifo` (round-robin) |
| `:worker_opts` | `[]` | Passed to `AgentServer.start_link/1`, e.g. `initial_state:` |

## API

### `with_agent/4` (recommended)

Transaction-style checkout/checkin — safest:

```elixir
Jido.Agent.WorkerPool.with_agent(MyApp.Jido, :fast_search, fn pid ->
  signal = Jido.Signal.new!("search", %{query: "cats"}, source: "/api")
  {:ok, agent} = Jido.AgentServer.call(pid, signal)
  agent.state.last_result
end, timeout: 5000)
```

Handles checkin even if the callback raises.

### `call/4` — signal with result

```elixir
Jido.Agent.WorkerPool.call(MyApp.Jido, :fast_search, signal,
  timeout: 5000,       # checkout timeout
  call_timeout: 5000   # signal processing timeout
)
```

Three timeout boundaries exist:
1. **Checkout timeout** — pool exhausted
2. **Call timeout** — signal processing
3. **Combined** — overall ceiling

### `cast/3` — fire and forget

```elixir
:ok = Jido.Agent.WorkerPool.cast(MyApp.Jido, :fast_search, signal)
```

**Warning:** `cast/3` returns the agent to the pool **before processing completes**. Use `call/4` if you need the result, or the next caller may see a worker still executing your signal.

### `status/2` — health

```elixir
Jido.Agent.WorkerPool.status(MyApp.Jido, :fast_search)
# => %{state: :ready | :full | :overflow, available: int, overflow: int, checked_out: int}
```

### Low-level checkout/checkin (prefer `with_agent/4`)

```elixir
{:ok, pid} = Jido.Agent.WorkerPool.checkout(MyApp.Jido, :fast_search, block: true)
try do
  # ... use pid ...
after
  Jido.Agent.WorkerPool.checkin(MyApp.Jido, :fast_search, pid)
end
```

`block: false` returns `:full` (or `{:noproc, _}` on exhaustion) immediately instead of waiting.

## Critical: Pooled Agents Are LONG-LIVED STATEFUL

A pooled worker keeps its state across checkouts **unless it crashes**. If you need per-request isolation:

- Design the agent to be stateless (pure transforms per signal)
- Start each transaction by sending a "reset" signal
- Or use a fresh `start_agent/2` per request instead of a pool

## Pool Sizing

Rough formula:

```
size = expected_concurrent_requests × avg_duration_seconds
```

Overflow policy:
- `max_overflow: 0` — strict limit (backpressure)
- `max_overflow: div(size, 2)` — burst buffer
- `max_overflow: size * 2` — elastic (less predictable)

Configure via `config/runtime.exs` with env vars:

```elixir
pool_size = String.to_integer(System.get_env("SEARCH_POOL_SIZE", "10"))
config :my_app, MyApp.Jido,
  agent_pools: [
    {:search, MyApp.SearchAgent, size: pool_size, max_overflow: div(pool_size, 2)}
  ]
```

## Telemetry

```elixir
[:jido, :agent, :call, :start]
[:jido, :agent, :call, :stop]
[:jido, :agent, :call, :exception]
```

Include pool metadata (name, instance, etc). Poll `status/2` periodically for queue depth.

A custom `PoolMonitor` GenServer pattern is documented in `jido/guides/worker-pools.md` for long-term monitoring.

## Common Patterns

### Bounded concurrency matching DB pool

```elixir
config :my_app, MyApp.Jido,
  agent_pools: [
    {:db_workers, MyApp.DbAgent, size: 20, max_overflow: 0}  # matches Repo pool
  ]
```

### Backpressure via fail-fast

```elixir
case Jido.Agent.WorkerPool.call(MyApp.Jido, :search, signal, timeout: 500) do
  {:ok, agent} -> agent
  {:error, {:noproc, _}} ->
    # Pool exhausted; shed load instead of queueing
    {:error, :overloaded}
end
```

### Warm pool with loaded model

```elixir
agent_pools: [
  {:llm, MyApp.LlmAgent, size: 2, worker_opts: [initial_state: %{model: loaded_model}]}
]
```

## When NOT to Use Pools

- Per-user stateful agents → `InstanceManager` ([10](10-persistence.md))
- Long-running durable teams → `Pod` ([11](11-pods.md))
- One-off ephemeral work → `start_agent/2` or `Directive.spawn_agent/3`
- When you need isolation per request → start fresh or send reset signal

## Source

- `jido/guides/worker-pools.md`
- `jido/lib/jido/agent/worker_pool.ex`

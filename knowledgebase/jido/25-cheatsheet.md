# 25 — Cheatsheet: Common Patterns

> Quick lookup for "which tool, which shape, which module".

## 30-Second Setup

```elixir
# mix.exs
{:jido, "~> 2.0"}

# lib/my_app/jido.ex
defmodule MyApp.Jido do
  use Jido, otp_app: :my_app
end

# application.ex
children = [MyApp.Jido]
Supervisor.start_link(children, strategy: :one_for_one)

# lib/my_app/counter_agent.ex
defmodule MyApp.CounterAgent do
  use Jido.Agent,
    name: "counter",
    schema: [count: [type: :integer, default: 0]],
    signal_routes: [{"increment", MyApp.Actions.Increment}]
end

# lib/my_app/actions/increment.ex
defmodule MyApp.Actions.Increment do
  use Jido.Action,
    name: "increment",
    schema: [amount: [type: :integer, default: 1]]

  def run(%{amount: amount}, context) do
    current = Map.get(context.state, :count, 0)
    {:ok, %{count: current + amount}}
  end
end

# Use it
{:ok, pid} = MyApp.Jido.start_agent(MyApp.CounterAgent, id: "c-1")
signal = Jido.Signal.new!("increment", %{amount: 5}, source: "/user")
{:ok, agent} = Jido.AgentServer.call(pid, signal)
agent.state.count   # => 5
```

## "Which Tool For…"

| Task | Pattern |
|---|---|
| Pure state transform | return `{:ok, %{key: val}}` from action |
| Nested state update | `%StateOp.SetPath{path: [:a, :b], value: v}` |
| Append to list in state | `SetPath` with `current ++ [new]` |
| Emit a signal | `Directive.emit(signal)` |
| Send to PubSub topic | `Directive.emit(signal, {:pubsub, topic: "t"})` |
| Send to specific pid | `Directive.emit_to_pid(signal, pid)` |
| Child → parent msg | `Directive.emit_to_parent(ctx, signal)` |
| Spawn worker agent | `Directive.spawn_agent(WorkerAgent, :tag)` |
| Spawn generic Task | `Directive.spawn(child_spec)` |
| Schedule delayed work | `Directive.schedule(5_000, :check)` |
| Recurring work | `Directive.cron("*/5 * * * *", :tick, job_id: :t)` |
| Stop a child | `Directive.stop_child(:tag)` |
| Stop self | `Directive.stop()` |
| Adopt orphan | `Directive.adopt_child("child-id", :new_tag)` |
| Error from action | `{:error, Jido.Error.validation_error("...")}` |

## "Which Runtime Pattern For…"

| Scenario | Pattern |
|---|---|
| One-off live agent | `MyApp.Jido.start_agent/2` |
| Tracked child for one turn | `Directive.spawn_agent/3` |
| Per-user durable agent | `Jido.Agent.InstanceManager.get/3` |
| Durable named team | `Jido.Pod.get/3` + `ensure_node/3` |
| High-throughput pool | `agent_pools:` + `WorkerPool.with_agent/4` |
| Multi-tenant | add `partition:` to any of the above |
| Hard multi-tenant | separate `MyApp.TenantA.Jido`, `MyApp.TenantB.Jido` |

## Core API Quick Reference

```elixir
# Instance
MyApp.Jido.start_agent(MyAgent, id: "a-1", initial_state: %{})
MyApp.Jido.stop_agent("a-1")
MyApp.Jido.whereis("a-1")
MyApp.Jido.list_agents()

# Per-agent
Jido.AgentServer.call(pid, signal)
Jido.AgentServer.call(pid, signal, 10_000)
Jido.AgentServer.cast(pid, signal)
Jido.AgentServer.state(pid)                       # => {:ok, state}
Jido.AgentServer.set_debug(pid, true)
Jido.AgentServer.recent_events(pid, limit: 20)

# Coordination
Jido.await(pid, 10_000)
Jido.await_child(parent, :tag, 30_000)
Jido.await_all([pids], 30_000)
Jido.await_any([pids], 10_000)
Jido.alive?(pid)
{:ok, children} = Jido.get_children(parent)
Jido.cancel(pid, reason: :timeout)

# Persistence
MyApp.Jido.hibernate(agent)
MyApp.Jido.thaw(MyAgent, "key")
Jido.Agent.InstanceManager.get(:pool, "key", initial_state: %{})

# Signals
Jido.Signal.new!("type", %{data: ...}, source: "/origin")
Jido.Signal.new!(%{type: "...", source: "/...", data: %{...}})

# Pod
Jido.Pod.get(:pod_manager, "pod-id", partition: :tenant_alpha)
Jido.Pod.ensure_node(pod_pid, :reviewer)
Jido.Pod.reconcile(pod_pid)
Jido.Pod.mutate(pod_pid, [Jido.Pod.Mutation.add_node(...)])
Jido.Pod.fetch_topology(pod_pid)

# Worker pool
Jido.Agent.WorkerPool.with_agent(MyApp.Jido, :pool, fn pid -> ... end, timeout: 5000)
Jido.Agent.WorkerPool.call(MyApp.Jido, :pool, signal, call_timeout: 5000)
Jido.Agent.WorkerPool.status(MyApp.Jido, :pool)

# Debug
MyApp.Jido.debug(:on)      # :verbose | :off
MyApp.Jido.debug_status()
MyApp.Jido.recent(pid, 50)
```

## Return Shapes Reference

### Action `run/2` returns

```elixir
{:ok, state_map}
{:ok, state_map, directive}
{:ok, state_map, [directive, state_op, ...]}
{:error, binary_or_struct}
```

### `cmd/2` returns

```elixir
{updated_agent, [directive, ...]}
```

### `await/2` returns

```elixir
{:ok, %{status: :completed, result: any, state: map}}
{:ok, %{status: :failed, result: error, state: map}}
{:error, :timeout}
{:error, :not_found}
{:error, {:timeout, %{hint: ..., server_status: ..., queue_length: ..., iteration: ..., waited_ms: ...}}}
```

### `thaw/2` returns

```elixir
{:ok, agent}
:not_found
{:error, :missing_thread}
{:error, :thread_mismatch}
```

## State Key Conventions

```elixir
# Reserved (framework-managed)
:__thread__           # Thread journal (Jido.Thread.Plugin)
:__identity__         # Identity (Jido.Identity.Plugin)
:__memory__           # Memory (Jido.Memory.Plugin)
:__pod__              # Pod topology (Jido.Pod.Plugin)
:__parent__           # ParentRef while attached
:__orphaned_from__    # ParentRef after orphaning
:__strategy__         # Strategy-specific state
:__cron_specs__       # Persisted dynamic cron manifest
:__partition__        # Partition binding

# User plugin state
:your_plugin_key      # whatever state_key you choose on use Jido.Plugin

# User agent state
:any_other_field      # from your schema
```

## Signal Naming Conventions

- Use dotted types: `"domain.event"`, `"domain.subresource.event"`
- Keep them CloudEvents-compatible (lowercase, dot-separated)
- Built-in framework types you'll want to handle:
  - `jido.agent.child.started`
  - `jido.agent.child.exit`
  - `jido.agent.orphaned`
  - `jido.agent.cron.tick`
  - `jido.agent.scheduled`
  - `jido.sensor.heartbeat`

## Source Conventions

```elixir
source: "/api"           # HTTP controller
source: "/liveview"      # LiveView event
source: "/worker"        # background worker
source: "/sensor/xxx"    # sensor
source: "/agent"         # another agent
source: "/scheduler"     # scheduled task
source: "/test"          # tests
```

## Common Testing Patterns

```elixir
# Pure test
use ExUnit.Case, async: true
agent = MyAgent.new()
{agent, directives} = MyAgent.cmd(agent, {MyAction, %{}})

# Integration test
use JidoTest.Case, async: true
{:ok, pid} = Jido.start_agent(jido, MyAgent)
{:ok, agent} = AgentServer.call(pid, signal)

# Async coordination (never Process.sleep)
{:ok, result} = Jido.await(pid, 10_000)
eventually_state(pid, fn s -> s.agent.state.status == :completed end)

# Mocking
use Mimic
expect(MyApp.Http, :get, fn _ -> {:ok, %{status: 200}} end)
```

## Project Convention Quick Checks

- [ ] Instance module exists: `MyApp.Jido` with `use Jido, otp_app: :my_app`
- [ ] Added to supervision tree in `application.ex`
- [ ] Agent defined with `use Jido.Agent`, `name:`, `schema:`, `signal_routes:`
- [ ] Actions in `jido_action` style, `use Jido.Action` with `name:` + `schema:`
- [ ] All state mutations go through `cmd/2` → action `run/2` return values or StateOps
- [ ] Side effects expressed as directives, never direct process calls from actions
- [ ] Error returns are `{:error, %Jido.Error.*{}}`, not strings
- [ ] Tests use `JidoTest.Case` or pure agent tests — no `Process.sleep`
- [ ] Multi-tenant concerns use `partition:` or separate instances

## Anti-Patterns (NEVER do these)

- ❌ `send(pid, {...})` between agents — use signals
- ❌ `GenServer.call(some_agent_pid, :thing)` — use `AgentServer.call/3` with a signal
- ❌ `Phoenix.PubSub.broadcast/3` inside `cmd/2` — use `Directive.emit/2`
- ❌ Mutating state outside `cmd/2` return — strategies ignore it
- ❌ `Process.sleep/1` in tests or production
- ❌ Global `Jido.start_agent/2` when you have your own instance
- ❌ Python / external agent runtimes — use `jido_ai` for LLM needs
- ❌ `--no-verify` on commits / bypassing pre-commit hooks
- ❌ Writing to reserved `:__xxx__` state keys directly

## Frequent Imports/Aliases

```elixir
alias Jido.{Signal, AgentServer}
alias Jido.Agent.{Directive, StateOp}
alias Jido.Agent.Strategy.State, as: StratState
alias Jido.Identity.Agent, as: IdentityAgent
alias Jido.Identity.Profile
alias Jido.Thread.Agent, as: ThreadAgent
alias Jido.Memory.Agent, as: MemoryAgent
```

## Where to Look First

- Not sure which runtime pattern? → [06-runtime.md](06-runtime.md) + [MASTER-INDEX.md](MASTER-INDEX.md) decision tree
- Building an agent? → [01-agents.md](01-agents.md) + [02-actions.md](02-actions.md)
- Cross-agent messaging? → [03-signals.md](03-signals.md)
- Effect descriptions? → [04-directives.md](04-directives.md)
- Fan-out work? → [13-orchestration.md](13-orchestration.md)
- Durable/persistent? → [10-persistence.md](10-persistence.md) + [11-pods.md](11-pods.md)
- Tests failing? → [20-testing.md](20-testing.md) + [18-debugging.md](18-debugging.md)

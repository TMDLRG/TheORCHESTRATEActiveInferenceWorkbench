# 04 — Directives

> Directives are **pure descriptions of external effects** emitted by actions (or strategies). The `AgentServer` runtime executes them. They never mutate agent state.

## The Directive Table

| Directive | Purpose | Tracking |
|---|---|---|
| `Emit` | Dispatch a signal via adapters | — |
| `Error` | Signal an error from `cmd/2` | — |
| `Spawn` | Spawn generic BEAM child (Task/GenServer) | None (fire-and-forget) |
| `SpawnAgent` | Spawn child Jido agent | Monitor + exit signals + `emit_to_parent` |
| `AdoptChild` | Attach an orphaned/unattached child | Monitor + refresh parent ref |
| `StopChild` | Gracefully stop a tracked child | Uses children map |
| `Schedule` | One-shot delayed message | — |
| `Cron` | Recurring scheduled execution | Persisted with `InstanceManager`+storage |
| `CronCancel` | Cancel a cron job | Write-through durable |
| `RunInstruction` | Runtime executes instruction, routes result back to `cmd/2` | — |
| `Stop` | Stop the agent process (self) | — |

## Helper Constructors

```elixir
alias Jido.Agent.Directive

# Signals
Directive.emit(signal)
Directive.emit(signal, {:pubsub, pubsub: MyApp.PubSub, topic: "events"})
Directive.emit_to_pid(signal, pid)
Directive.emit_to_parent(agent_or_ctx, signal)    # returns nil if orphaned/standalone

# Process spawning
Directive.spawn(child_spec)                       # generic Task/GenServer child_spec
Directive.spawn_agent(MyWorker, :tag)
Directive.spawn_agent(MyWorker, :tag, opts: %{initial_state: %{batch: 100}})
Directive.spawn_agent(MyWorker, :durable, restart: :permanent)
Directive.adopt_child("child-123", :tag, meta: %{restored: true})
Directive.adopt_child(child_pid, :tag)

# Stopping
Directive.stop_child(:tag)
Directive.stop_child(:tag, :normal)
Directive.stop()
Directive.stop(:shutdown)

# Scheduling
Directive.schedule(5_000, :timeout_msg)
Directive.cron("*/5 * * * *", :tick, job_id: :heartbeat)
Directive.cron("0 9 * * *", :daily, job_id: :daily_report, timezone: "America/New_York")
Directive.cron_cancel(:heartbeat)

# Runtime instruction execution (used by strategies that keep cmd/2 pure)
Directive.run_instruction(instruction, result_action: :fsm_instruction_result)

# Errors
Directive.error(Jido.Error.validation_error("Invalid input"))
```

## `Spawn` vs `SpawnAgent`

| `Spawn` | `SpawnAgent` |
|---|---|
| Generic Task/GenServer | Child Jido agents |
| Fire-and-forget | Full hierarchy tracking |
| No monitoring | Monitors + exit signals |
| — | Enables `emit_to_parent/3` |

```elixir
# Fire-and-forget task
Directive.spawn({Task, :start_link, [fn -> send_webhook(url) end]})

# Tracked child agent
Directive.spawn_agent(WorkerAgent, :worker_1, opts: %{initial_state: state})
```

### `SpawnAgent` options (forwarded to child startup)

Supported: `:id`, `:initial_state`, `:on_parent_death`.

**Rejected**: `:storage`, `:idle_timeout`, `:lifecycle_mod`, `:pool`, `:pool_key`, `:restored_from_storage` — these are InstanceManager concerns ([10](10-persistence.md), [16](16-worker-pools.md)), not live-hierarchy concerns.

Default `restart: :transient`, so:
- `Directive.stop_child/2` cleanly removes them
- Abnormal exits still restart the child
- Override to `:permanent` or `:temporary` when needed

## `on_parent_death` Policies

Set via `opts: %{on_parent_death: ...}` on `spawn_agent/3`:

| Value | Behavior |
|---|---|
| `:stop` | (default) Child stops when parent dies |
| `:continue` | Child stays alive, orphaned silently |
| `:emit_orphan` | Child stays alive, receives `jido.agent.orphaned` signal |

See [14-orphans-adoption.md](14-orphans-adoption.md).

## `emit_to_parent/3` Semantics (strict)

- Works only while `agent.state.__parent__` is present
- Returns `nil` for standalone agents
- Returns `nil` for orphaned agents (runtime clears `__parent__`)

After orphaning, read `agent.state.__orphaned_from__` or handle `jido.agent.orphaned` — do not rely on `emit_to_parent/3` for reconnection.

## `Cron` / `CronCancel` Semantics

**Failure-isolated:**
- Invalid cron expression or timezone → rejected at runtime, agent stays alive, returns `{:error, {:invalid_timezone, reason}}`.
- Scheduler registration failures → error returned, agent state unchanged.
- `CronCancel` is safe when runtime pid is missing; durable spec removal still applies.

**Durability:**
- Under `InstanceManager` + storage enabled → dynamic cron mutations are write-through durable via `Jido.Persist`/`Jido.Storage` before state commit.
- Non-persistent lifecycles keep cron state runtime-only.

**Upsert:** a new job with the same `job_id` validates and starts the replacement, then swaps and cancels the old.

**Missed runs are not replayed** — cron resumes at next scheduled time after restart.

See [15-scheduling.md](15-scheduling.md).

## `RunInstruction`

Used by strategies that want to keep `cmd/2` pure. Instead of calling `Jido.Exec.run/1` inline, the strategy emits:

```elixir
%Directive.RunInstruction{instruction: instruction, result_action: :some_handler}
```

The runtime executes the instruction asynchronously and routes the result back through `cmd/2` using `result_action`. This is how the FSM strategy handles multi-step workflows without blocking.

## `Error` Directive

Wraps a `Jido.Error.t()` and a context atom:

```elixir
%Directive.Error{
  error: %Jido.Error.ValidationError{...},
  context: :instruction    # or :normalize, :fsm_transition, :routing, :plugin_handle_signal
}
```

Error policies in `AgentServer` decide what to do: log, stop, emit, custom handler. See [19-errors.md](19-errors.md).

## Custom Directives

External packages can define their own:

```elixir
defmodule MyApp.Directive.CallLLM do
  defstruct [:model, :prompt, :tag]
end
```

The runtime dispatches on struct type — no core changes needed. Implement a custom `AgentServer` or middleware to handle them.

## Complete Example

```elixir
defmodule ProcessOrderAction do
  use Jido.Action,
    name: "process_order",
    schema: [order_id: [type: :string, required: true]]

  alias Jido.Agent.{Directive, StateOp}

  def run(%{order_id: order_id}, context) do
    signal = Jido.Signal.new!(
      "order.processed",
      %{order_id: order_id, processed_at: DateTime.utc_now()},
      source: "/orders"
    )

    {:ok, %{order_id: order_id}, [
      StateOp.set_state(%{last_order: order_id}),  # applied by strategy during cmd/2
      Directive.emit(signal)                        # passed to runtime post-cmd
    ]}
  end
end
```

## Source

- `jido/guides/directives.md`
- `jido/lib/jido/agent/directive.ex`

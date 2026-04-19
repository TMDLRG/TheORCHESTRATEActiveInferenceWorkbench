# 10 — Persistence & Storage

> Unified persistence built on two concepts: **Thread** (append-only journal, source of truth) and **Checkpoint** (serialized state snapshot for fast resume).

## Core Principle

**Never persist the full Thread inside the Agent checkpoint.** Store a pointer:

```elixir
%{thread_id: "thread_abc123", thread_rev: 42}
```

This prevents duplication, consistency drift, and memory bloat.

## Configuration

```elixir
# ETS (default, ephemeral)
defmodule MyApp.Jido do
  use Jido, otp_app: :my_app
end

# File-based (simple production)
defmodule MyApp.Jido do
  use Jido,
    otp_app: :my_app,
    storage: {Jido.Storage.File, path: "priv/jido/storage"}
end

# Or just the module (options default to [])
use Jido, otp_app: :my_app, storage: Jido.Storage.ETS
```

### Built-in Adapters

| Adapter | Durability | Use case |
|---|---|---|
| `Jido.Storage.ETS` | Ephemeral | Dev, testing |
| `Jido.Storage.File` | Disk | Simple production |
| `Jido.Storage.Redis` | Durable | Shared external store (BYO Redix client) |

### ETS options

```elixir
{Jido.Storage.ETS, table: :my_jido_storage}
```
Creates three tables: `{table}_checkpoints`, `{table}_threads`, `{table}_thread_meta`.

### File options

```elixir
{Jido.Storage.File, path: "priv/jido/storage"}
```
Directory layout:
```
{path}/checkpoints/{key_hash}.term
{path}/threads/{thread_id}/meta.term
{path}/threads/{thread_id}/entries.log
```

### Redis options

```elixir
{Jido.Storage.Redis,
  command_fn: &MyApp.RedisStorage.command/1,
  prefix: "jido",        # default
  ttl: nil               # default; set ms for auto-expiry
}
```

Key layout: `{prefix}:cp:{hex_hash}` (checkpoints), `{prefix}:th:{thread_id}` (threads). You supply a `command_fn/1` that executes Redis commands (Redix, etc.) — Jido core doesn't add a Redis dependency.

## High-Level API (via instance module)

```elixir
:ok                        = MyApp.Jido.hibernate(agent)
{:ok, agent}               = MyApp.Jido.thaw(MyAgent, "user-123")
{:error, :not_found}       = MyApp.Jido.thaw(MyAgent, "missing")
{:error, :missing_thread}  # checkpoint references deleted thread
{:error, :thread_mismatch} # loaded thread.rev ≠ checkpoint pointer
```

## Direct API (`Jido.Persist`)

```elixir
storage = {Jido.Storage.ETS, table: :my_storage}
:ok          = Jido.Persist.hibernate(storage, agent)
{:ok, agent} = Jido.Persist.thaw(storage, MyAgent, "user-123")

# Or pass anything with a :storage field
jido_like = %{storage: {Jido.Storage.ETS, []}}
:ok = Jido.Persist.hibernate(jido_like, agent)
```

## Hibernate / Thaw Flow

### Hibernate

```
1. Extract thread from agent.state[:__thread__]
2. Flush thread entries to Journal Store
3. Call agent_module.checkpoint/2  (excludes full thread, includes pointer)
4. Write checkpoint to Snapshot Store
```

Journal is flushed **before** checkpoint — ensures thread exists before any checkpoint references it.

### Thaw

```
1. Load checkpoint from Snapshot Store
2. Call agent_module.restore/2
3. If checkpoint has thread pointer:
   - Load thread from Journal Store
   - Verify rev matches pointer
   - Attach to agent.state[:__thread__]
4. Return hydrated agent
```

## Agent Callbacks (optional)

### `checkpoint/2`

```elixir
@impl true
def checkpoint(agent, _ctx) do
  thread = agent.state[:__thread__]
  {:ok, %{
    version: 1,
    agent_module: __MODULE__,
    id: agent.id,
    state: agent.state |> Map.drop([:__thread__, :temp_cache]),
    thread: thread && %{id: thread.id, rev: thread.rev}
  }}
end
```

### `restore/2` (with schema migration)

```elixir
@impl true
def restore(%{version: 1} = data, ctx) do
  migrated = put_in(data, [:state, :preferences], %{theme: :light})
  restore(%{migrated | version: 2}, ctx)
end

def restore(%{version: 2} = data, _ctx) do
  {:ok, agent} = new(id: data.id)
  {:ok, %{agent | state: Map.merge(agent.state, data.state)}}
end
```

Defaults are good enough for most cases — only override when skipping fields or migrating.

## Automatic Lifecycle: `Jido.Agent.InstanceManager`

For per-user / per-entity agents, `InstanceManager` provides keyed lookup plus automatic hibernate on idle and thaw on demand.

### Supervision child spec

```elixir
children = [
  Jido.Agent.InstanceManager.child_spec(
    name: :sessions,
    agent: MyApp.SessionAgent,
    idle_timeout: :timer.minutes(15),
    storage: {Jido.Storage.File, path: "priv/sessions"}   # or omit to inherit from Jido instance
  )
]
```

Storage resolution:
- `storage: {Adapter, opts}` or `storage: Adapter` — explicit backend override
- `storage` omitted — uses the configured Jido instance storage (`jido.__jido_storage__/0`)
- `storage: nil` — disables hibernate/thaw for that manager

### API

```elixir
# Get or start (thaws if hibernated)
{:ok, pid} = Jido.Agent.InstanceManager.get(:sessions, "user-123")
{:ok, pid} = Jido.Agent.InstanceManager.get(:sessions, "user-123",
  initial_state: %{user_id: "user-123"}
)

# Track interest (per-caller reference counting)
:ok = Jido.AgentServer.attach(pid)
:ok = Jido.AgentServer.detach(pid)     # when all detach → idle timer → hibernate

# Explicit stop
:ok = Jido.Agent.InstanceManager.stop(:sessions, "user-123")

# Partitioned
Jido.Agent.InstanceManager.get(:sessions, "user-123", partition: :tenant_alpha)
```

### Lifecycle

1. `get/3` looks up by key in Registry
2. If not running but storage exists → agent restored via `thaw`
3. If no stored checkpoint → starts fresh agent
4. Callers track interest via `attach`
5. When all attachments detach → idle timer starts
6. On timeout → agent persisted via `hibernate`, then process stops

Manager-backed checkpoints are keyed by `{manager_name, pool_key}` to prevent cross-manager collisions when sharing storage.

### Scope

Automatic lifecycle applies **only** to agents started via `InstanceManager`. It does NOT apply to `SpawnAgent` children, and hibernating a parent does NOT recursively persist the child tree. Model durable collaborators as keyed managed agents and reacquire/adopt them explicitly.

## Dynamic Cron Durability

When an agent registers a cron via `Directive.cron/3` under `InstanceManager` + storage:

- The schedule is persisted as part of the checkpoint state, under reserved key `:__cron_specs__`
- Re-registered on thaw
- Durability keyed by `{manager_name, pool_key}` (instance-scoped)
- Missed ticks are NOT replayed (no catch-up)
- `storage: nil` → dynamic cron stays runtime-only

Declarative `schedules:` entries and plugin schedules are recreated from code on start — not persisted.

## Optimistic Concurrency

`append_thread/3` accepts `:expected_rev`:

```elixir
case adapter.append_thread(thread_id, entries, expected_rev: 5) do
  {:ok, thread} -> :ok                  # now at rev 6+
  {:error, :conflict} -> :retry         # someone else appended first
end
```

ETS and File adapters both support this.

## Error Cases on Thaw

```elixir
case MyApp.Jido.thaw(MyAgent, "user-123") do
  {:ok, agent} -> agent
  :not_found ->
    # No checkpoint; start fresh
    {:ok, agent} = MyAgent.new(id: "user-123")
    agent
  {:error, :missing_thread} ->
    # Checkpoint references deleted thread
    Logger.error("Missing thread for user-123")
  {:error, :thread_mismatch} ->
    # Checkpoint pointer ≠ actual thread rev — consistency drift
    Logger.error("Thread mismatch for user-123")
end
```

## Custom Storage Adapter

Implement `Jido.Storage` behaviour:

```elixir
@behaviour Jido.Storage

# Checkpoint ops (key-value, overwrite semantics)
def get_checkpoint(key, opts)      # {:ok, data} | :not_found | {:error, _}
def put_checkpoint(key, data, opts) # :ok | {:error, _}
def delete_checkpoint(key, opts)   # :ok | {:error, _}

# Journal ops (append-only, sequence ordering)
def load_thread(thread_id, opts)                 # {:ok, %Jido.Thread{}} | :not_found | {:error, _}
def append_thread(thread_id, entries, opts)      # {:ok, %Jido.Thread{}} | {:error, :conflict | _}
def delete_thread(thread_id, opts)               # :ok | {:error, _}
```

See `jido/guides/storage.md` for a full Ecto/Postgres reference implementation including transactional `expected_rev` checks.

## Pods & Persistence

Pods ([11](11-pods.md)) use ordinary checkpoints — no separate storage contract. The pod agent persists its topology snapshot as state under `:__pod__`. Thaw restores the topology; live relationships are re-established explicitly with `Jido.Pod.reconcile/2` / `Jido.Pod.ensure_node/3`.

## When NOT to Persist

- Stateless agents that fetch from external sources on start
- State cheap to rebuild
- Short-lived workers (task duration < hibernate overhead)
- Sensitive data (secrets shouldn't hit disk/cache)
- High-churn start/stop

```elixir
Jido.Agent.InstanceManager.child_spec(
  name: :tasks,
  agent: MyApp.TaskAgent,
  idle_timeout: :timer.seconds(30),
  storage: nil                              # disable
)
```

## Thread Storage: Late Metadata Pattern

When provider metadata arrives after an entry is appended, record a follow-up entry rather than mutating the original:

```elixir
entry_id = "entry_" <> Jido.Util.generate_id()

ThreadAgent.append(agent, %{
  id: entry_id,
  kind: :message,
  payload: %{role: "assistant", content: "Working on it"}
})

# Later:
ThreadAgent.append(agent, %{
  kind: :message_committed,
  payload: %{provider: :slack, remote_id: slack_ts},
  refs: %{entry_id: entry_id}
})
```

Keeps journal canonical and append-only.

## Source

- `jido/guides/storage.md`
- `jido/lib/jido/persist.ex`, `jido/lib/jido/storage*.ex`, `jido/lib/jido/agent/instance_manager.ex`

# 21 — Configuration

> Instance-scoped. No global singletons. Multiple instances supported for hard multi-tenancy.

## Instance Definition

```elixir
defmodule MyApp.Jido do
  use Jido, otp_app: :my_app
end
```

Options on `use Jido`:
- `:otp_app` (required)
- `:storage` (default `{Jido.Storage.ETS, [table: :jido_storage]}`) — adapter for `hibernate`/`thaw`
- `:default_plugins` — override built-in defaults for all agents under this instance

## Supervision Tree

```elixir
# lib/my_app/application.ex
children = [
  MyApp.Repo,
  MyApp.Jido,
  # InstanceManagers for durable agents:
  Jido.Agent.InstanceManager.child_spec(
    name: :sessions,
    agent: MyApp.SessionAgent,
    jido: MyApp.Jido,
    idle_timeout: :timer.minutes(15)
  ),
  # InstanceManagers for pods:
  Jido.Agent.InstanceManager.child_spec(
    name: :workspace_pods,
    agent: MyApp.WorkspacePod,
    jido: MyApp.Jido
  ),
  MyAppWeb.Endpoint
]

Supervisor.start_link(children, strategy: :one_for_one)
```

## What the Instance Supervises

```
MyApp.Jido (Supervisor)
├── MyApp.Jido.TaskSupervisor    (Task.Supervisor, max_children: max_tasks)
├── MyApp.Jido.Registry          (Registry, keys: :unique)
├── MyApp.Jido.RuntimeStore      (ETS table for parent/child bindings)
├── MyApp.Jido.AgentSupervisor   (DynamicSupervisor, max_restarts: 1000/5s)
└── <pool children>              (one AgentPool per configured pool)
```

Default shutdown timeout: 10 seconds.

## Runtime Config

```elixir
# config/config.exs or config/runtime.exs
config :my_app, MyApp.Jido,
  max_tasks: 2000,
  agent_pools: [],
  debug: false,                             # or true | :verbose
  telemetry: [
    log_level: :info,                       # :error | :warning | :info | :debug | :trace
    log_args: :keys_only,                   # :none | :keys_only | :full
    slow_signal_threshold_ms: 100,
    slow_directive_threshold_ms: 100,
    debug_max_events: 500
  ],
  observability: [
    log_level: :info,
    debug_events: :off,                     # :off | :minimal | :all
    redact_sensitive: true,
    tracer: MyApp.Tracer,
    tracer_failure_mode: :warn              # :warn | :strict
  ]
```

### Options summary

| Option | Default | Purpose |
|---|---|---|
| `:max_tasks` | `1000` | Max children in `Task.Supervisor` |
| `:agent_pools` | `[]` | Pool definitions (see [16](16-worker-pools.md)) |
| `:debug` | `false` | Enable debug at startup |
| `:telemetry` | `%{}` | Logger/threshold settings |
| `:observability` | `%{}` | Structured observability / tracer |
| `:storage` (via `use Jido`) | `{ETS, []}` | Default storage adapter |
| `:default_plugins` (via `use Jido`) | `nil` (use built-ins) | Override framework defaults |

### Resolution order (observability)

1. Runtime override (`Jido.Debug`, `:persistent_term`)
2. Per-instance app config
3. Global app config (`config :jido, :telemetry`)
4. Hardcoded defaults

## Environment-Based Config (runtime.exs)

```elixir
# config/runtime.exs
import Config

pool_size = String.to_integer(System.get_env("SEARCH_POOL_SIZE", "10"))

config :my_app, MyApp.Jido,
  max_tasks: String.to_integer(System.get_env("MAX_TASKS", "1000")),
  agent_pools: [
    {:search, MyApp.SearchAgent,
       size: pool_size,
       max_overflow: div(pool_size, 2)}
  ]
```

## Multiple Instances (hard multi-tenancy)

```elixir
defmodule MyApp.TenantA.Jido, do: use Jido, otp_app: :my_app
defmodule MyApp.TenantB.Jido, do: use Jido, otp_app: :my_app

config :my_app, MyApp.TenantA.Jido, max_tasks: 500
config :my_app, MyApp.TenantB.Jido, max_tasks: 1000

# application.ex
children = [MyApp.TenantA.Jido, MyApp.TenantB.Jido, ...]
```

For single-instance logical multi-tenancy, use `partition:` — see [12-multi-tenancy.md](12-multi-tenancy.md).

## Instance API (auto-generated)

See [06-runtime.md](06-runtime.md) for the full list:

- Lifecycle: `start_agent/2`, `stop_agent/2`, `whereis/2`, `list_agents/1`, `agent_count/1`
- Persistence: `hibernate/1`, `thaw/2`
- Debug: `debug/0`, `debug/1`, `debug/2`, `debug_status/0`, `recent/2`
- Introspection: `registry_name/0`, `agent_supervisor_name/0`, `task_supervisor_name/0`, `runtime_store_name/0`
- Config: `config/1`

## Global Jido Settings (not instance-scoped)

### Timezone database for cron

```elixir
config :jido, :time_zone_database, TimeZoneInfo.TimeZoneDatabase  # default
```

### Global telemetry/observability defaults

```elixir
config :jido, :telemetry, log_level: :info
config :jido, :observability, debug_events: :off
```

Per-instance config wins over global.

## Testing Config

`JidoTest.Case` provides isolated instances:

```elixir
defmodule MyTest do
  use JidoTest.Case, async: true

  test "uses isolated instance", %{jido: jido, jido_pid: _pid} do
    {:ok, pid} = Jido.start_agent(jido, MyAgent)
    # ...
  end
end
```

## Source

- `jido/guides/configuration.md`
- `jido/lib/jido.ex`
- `jido/lib/jido/config/defaults.ex`

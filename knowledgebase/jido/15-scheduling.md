# 15 — Scheduling

> Declare recurring and delayed work tied to agent lifecycle. Two flavors: **declarative** (code-first, recreated on start) and **dynamic** (directive-driven, persisted when durable).

## The API Surface

| Need | API | Durability |
|---|---|---|
| Declarative cron on agent | `schedules: [{"*/5 * * * *", "sig.type", job_id: :id}]` | Recreated from code on start; NOT persisted |
| Dynamic cron at runtime | `Directive.cron(expr, signal, job_id:, timezone:)` | Persisted when `InstanceManager` + storage |
| Cancel cron | `Directive.cron_cancel(job_id)` | Write-through durable (InstanceManager + storage) |
| One-shot delay | `Directive.schedule(ms, message)` | Always in-memory; lost on crash |

## Declarative Schedules

Declared on the agent module:

```elixir
defmodule HeartbeatAgent do
  use Jido.Agent,
    name: "heartbeat",
    schedules: [
      {"*/5 * * * *", "heartbeat.tick", job_id: :heartbeat},
      {"0 9 * * *", "daily.report", job_id: :daily, timezone: "America/New_York"}
    ],
    signal_routes: [
      {"heartbeat.tick", HandleTickAction},
      {"daily.report", HandleDailyAction}
    ]
end
```

Options per entry: `{cron_expr, signal_type}` or `{cron_expr, signal_type, opts}` where opts include `:job_id` and `:timezone`.

- **Not persisted.** Recreated from code on `AgentServer` start.
- Plugin-declared schedules behave the same way.
- Job IDs are namespaced internally as `{:agent_schedule, agent_name, job_id}` for declarative jobs.

## Dynamic Cron

Emit `Directive.cron/3` from an action or strategy:

```elixir
def run(%{interval: interval}, _context) do
  {:ok, %{}, [
    Directive.cron(interval, :ai_check, job_id: :ai_check, timezone: "UTC")
  ]}
end
```

- **Persisted when `InstanceManager` + storage enabled** (write-through durable via `Jido.Persist`/`Jido.Storage` before state commit).
- Stored under reserved key `:__cron_specs__` in the checkpoint.
- Re-registered on thaw.
- Durability keyed by `{manager_name, pool_key}` (instance-scoped).

### Upsert behavior

A new job with the same `job_id` validates and starts the replacement, then swaps and cancels the old.

### Failure isolation

- Invalid cron expression or timezone → rejected at runtime; agent stays alive; returns `{:error, {:invalid_timezone, reason}}` or similar
- Scheduler registration failures → error returned, agent state unchanged
- Missed runs are **not** replayed (no catch-up) — cron resumes at next scheduled time after restart

### Cancel

```elixir
Directive.cron_cancel(:ai_check)
```

Safe when runtime pid is missing; durable spec removal still applies.

### Cleanup on termination

All cron jobs are auto-cancelled in `terminate/2` for the agent.

## One-Shot Delays

```elixir
Directive.schedule(5_000, :timeout_check)
Directive.schedule(30_000, {:expire, some_data})
```

- Uses `Process.send_after/3` under the hood
- Always in-memory; lost on crash
- Agent receives the message in a `handle_info/2` callback (or via a runtime-wired signal route if configured that way)

## Timezone Configuration

Default database: `TimeZoneInfo.TimeZoneDatabase` (via `time_zone_info` dep).

```elixir
# config/config.exs (optional override)
config :jido, :time_zone_database, TimeZoneInfo.TimeZoneDatabase
```

## Idempotency Patterns

Exactly-once is **not** guaranteed by in-process cron. If you need exactly-once, use an external persistent scheduler (Oban, Quantum).

### Dedupe keys

```elixir
def run(%{tick_id: tick_id}, context) do
  seen = Map.get(context.state, :seen_ticks, MapSet.new())

  if MapSet.member?(seen, tick_id) do
    {:ok, %{}}
  else
    {:ok, %{}, [
      %StateOp.SetState{attrs: %{seen_ticks: MapSet.put(seen, tick_id)}}
    ]}
  end
end
```

### Last-run timestamps

```elixir
def run(_params, context) do
  last = Map.get(context.state, :last_run, nil)
  cutoff = DateTime.utc_now() |> DateTime.add(-60, :second)

  if last == nil or DateTime.compare(last, cutoff) == :lt do
    do_work()
    {:ok, %{last_run: DateTime.utc_now()}}
  else
    {:ok, %{}}
  end
end
```

## Scope & Limits

- Not suitable for exactly-once semantics
- No distributed scheduling across nodes (pods are single-node v1)
- Missed cron ticks during hibernate/downtime are not replayed
- If you need those guarantees → Oban, Quantum, or your own durable scheduler emitting Jido signals

## Source

- `jido/guides/scheduling.md`
- `jido/lib/jido/scheduler.ex`, `jido/lib/jido/scheduler/**`
- `jido/lib/jido/agent/directive/cron.ex`, `cron_cancel.ex`, `schedule.ex`

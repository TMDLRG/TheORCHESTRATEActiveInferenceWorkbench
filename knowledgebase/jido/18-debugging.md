# 18 — Debugging

> Instance-scoped debug mode + ring buffer of recent events. Don't rely on `IO.inspect` in production agents.

## Step 0: Logger Config (REQUIRED)

```elixir
config :logger, level: :debug
config :logger, :default_formatter,
  format: "[$level] $message $metadata\n",
  metadata: [:agent_id, :agent_module, :jido_instance, :jido_trace_id]
```

Without `:debug` level, Logger discards messages before Jido sees them. Debug mode alone is not enough.

## Instance-Scoped Debug (primary workflow)

```elixir
MyApp.Jido.debug()                  # current level
MyApp.Jido.debug(:on)               # dev-friendly verbosity
MyApp.Jido.debug(:verbose)          # maximum detail (trace-level logs, full args)
MyApp.Jido.debug(:off)              # back to configured defaults
MyApp.Jido.debug_status()           # full status map incl. active overrides
MyApp.Jido.debug(:on, redact: false) # disable redaction (security warning!)
```

### Level semantics

| Level | log_level | log_args | debug_events |
|---|---|---|---|
| `:on` | `:debug` | `:keys_only` | `:minimal` |
| `:verbose` | `:trace` | `:full` | `:all` |
| `:off` | (configured default) | (default) | (default) |

Instance-level debug enables recording for **all** agents managed by that instance.

## Config Resolution Order

1. `Jido.Debug` runtime override (`:persistent_term`, per-instance)
2. Per-instance app config (`config :my_app, MyApp.Jido, telemetry: [...]`)
3. Global app config (`config :jido, :telemetry`)
4. Hardcoded defaults

## Per-Agent Debug

Surgical — single process, doesn't pull in all agents:

```elixir
# At start
{:ok, pid} = MyApp.Jido.start_agent(MyAgent, debug: true)
{:ok, pid} = Jido.AgentServer.start_link(agent: MyAgent, debug: true)

# Runtime toggle
:ok = Jido.AgentServer.set_debug(pid, true)

# Via instance module (also toggles per-agent)
MyApp.Jido.debug(pid)
```

## Ring Buffer

Up to 500 events per agent (configurable via `debug_max_events`). In-memory, newest-first. Development aid, not an audit log.

```elixir
{:ok, events} = MyApp.Jido.recent(pid)          # default 50 limit
{:ok, events} = MyApp.Jido.recent(pid, 100)
{:ok, events} = Jido.AgentServer.recent_events(pid, limit: 20)

Enum.each(events, fn e ->
  IO.inspect({e.type, e.data}, label: "event at #{e.at}")
end)
```

Each event:
- `:at` — monotonic timestamp (ms)
- `:type` — event atom (e.g. `:signal_received`, `:directive_started`, `:directive_completed`)
- `:data` — event-specific details

## Common Log Lines (debug mode)

```
[debug] [Agent] Command started agent_id="..." action="..."
[debug] [Agent] Command completed duration_μs=... directive_count=...
[debug] [AgentServer] Signal processing started agent_id="..." signal_type="..."
[debug] [AgentServer] Signal processing completed duration_μs=... directive_count=...
```

At debug/trace levels, the `[signal]` log includes a directive-type summary like `directives=2 Emit=1 Schedule=1`.

## Common Issues

### Agent hangs / `await` times out

```elixir
{:ok, events} = MyApp.Jido.recent(pid)
{:ok, state} = Jido.AgentServer.state(pid)

# Look for:
# - :signal_received without corresponding :cmd_completed
# - error directives
# - large queue_length in timeout diagnostic
```

`Jido.await/2` timeout returns a diagnostic map on `{:error, {:timeout, diag}}`:
- `:hint`, `:server_status`, `:queue_length`, `:iteration`, `:waited_ms`

### No debug output

- Verify Logger level is `:debug`: `Application.get_env(:logger, :level)`
- Check `MyApp.Jido.debug()` returns `:on` or `:verbose`
- Check formatter includes `agent_id` / `jido_trace_id` in metadata

### Too much noise

- Use per-instance debug with `:on` (minimal events) rather than `:verbose`
- Tune thresholds: `slow_signal_threshold_ms`, `slow_directive_threshold_ms`
- Or use per-agent debug for the one process you're investigating

### Debug state leaking in tests

Debug overrides live in `:persistent_term`. Reset in `setup` / `on_exit`:

```elixir
setup %{jido: jido} = context do
  Jido.Debug.reset(jido)
  on_exit(fn -> Jido.Debug.reset(jido) end)
  context
end
```

## Boot-Time Debug (from config)

```elixir
# config/dev.exs
config :my_app, MyApp.Jido, debug: true
config :my_app, MyApp.Jido, debug: :verbose
```

Applied at instance startup via `Jido.Debug.maybe_enable_from_config/2`.

## Telemetry-Based Diagnosis

For production-grade diagnosis, attach a handler and log selectively:

```elixir
:telemetry.attach_many(
  "diagnose",
  [
    [:jido, :agent, :cmd, :stop],
    [:jido, :agent, :cmd, :exception]
  ],
  fn event, m, md, _ ->
    if md[:agent_id] == "target-agent-id" do
      Logger.debug("[#{inspect(event)}] #{inspect(md)} #{inspect(m)}")
    end
  end,
  nil
)
```

## Key Modules

- `Jido.Debug` — per-instance runtime debug mode
- `Jido.Telemetry` — built-in handler emitting log lines at configured level
- `Jido.Observe` — unified observability façade

See [17-observability.md](17-observability.md) for the full telemetry-event catalog.

## Source

- `jido/guides/debugging.md`
- `jido/guides/observability-intro.md`
- `jido/lib/jido/debug.ex`, `jido/lib/jido/telemetry*.ex`

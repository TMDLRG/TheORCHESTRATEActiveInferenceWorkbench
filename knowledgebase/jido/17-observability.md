# 17 — Observability (Telemetry, Spans, Metrics)

> Production monitoring via `:telemetry` events, spans, structured logs, and optional tracer integrations (OTEL).

## Logger Metadata (always enable)

```elixir
config :logger, level: :info,
  metadata: [:agent_id, :jido_trace_id, :jido_span_id, :jido_instance, :signal_type]
```

## Instance-Level Config

```elixir
config :my_app, MyApp.Jido,
  telemetry: [
    log_level: :debug,                      # :error | :warning | :info | :debug | :trace
    log_args: :keys_only,                   # :none | :keys_only | :full
    slow_signal_threshold_ms: 10,
    slow_directive_threshold_ms: 10,
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

## Core Telemetry Events

### Agent Events

| Event | Measurements | Key metadata |
|---|---|---|
| `[:jido, :agent, :cmd, :start]` | `system_time` | `agent_id`, `agent_module`, `action`, `jido_instance` |
| `[:jido, :agent, :cmd, :stop]` | `duration` | same, plus `directive_count`, `directive_types` |
| `[:jido, :agent, :cmd, :exception]` | `duration` | same, plus `kind`, `reason`, `stacktrace` |

### AgentServer Events

| Event | Measurements | Key metadata |
|---|---|---|
| `[:jido, :agent_server, :signal, :start]` | `system_time` | `agent_id`, `signal_type`, `jido_instance` |
| `[:jido, :agent_server, :signal, :stop]` | `duration` | + `directive_count`, `directive_types` |
| `[:jido, :agent_server, :signal, :exception]` | `duration` | |
| `[:jido, :agent_server, :directive, :start]` | | `directive_type`, `directive` |
| `[:jido, :agent_server, :directive, :stop]` | `duration` | + `result` |
| `[:jido, :agent_server, :queue, :overflow]` | `queue_size` | |

### Strategy Events

| Event | Measurements | Metadata |
|---|---|---|
| `[:jido, :agent, :strategy, :init, :start/:stop/:exception]` | duration | strategy module, agent |
| `[:jido, :agent, :strategy, :cmd, :start/:stop/:exception]` | duration | |
| `[:jido, :agent, :strategy, :tick, :start/:stop/:exception]` | duration | |

### Pod Events

| Event | Measurements | Metadata |
|---|---|---|
| `[:jido, :pod, :reconcile, :start]` | | pod, node_count, requested_count |
| `[:jido, :pod, :reconcile, :stop]` | `duration` | + failure_count, pending_count, wave_count |
| `[:jido, :pod, :node, :ensure, :start]` | | pod, node, source |
| `[:jido, :pod, :node, :ensure, :stop]` | `duration` | + source: `:started \| :running \| :adopted`, owner |

All include `:jido_partition` when a partition is active.

## Correlation Metadata (when trace context is active)

Automatically attached to telemetry metadata and log entries:

- `:jido_trace_id` — shared across the entire call chain
- `:jido_span_id` — unique per operation
- `:jido_parent_span_id` — parent operation
- `:jido_causation_id` — the signal ID that caused this signal

Propagate across async boundaries:

```elixir
metadata = Jido.Tracing.Context.to_telemetry_metadata()
Task.async(fn ->
  Jido.Tracing.Context.from_telemetry_metadata(metadata)
  # ... work ...
end)
```

## Attaching Handlers

```elixir
:telemetry.attach_many(
  "my-jido-handler",
  [
    [:jido, :agent, :cmd, :stop],
    [:jido, :agent, :cmd, :exception],
    [:jido, :agent_server, :queue, :overflow]
  ],
  fn event, measurements, metadata, _config ->
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
    Logger.info("Agent command",
      event: inspect(event),
      duration_ms: duration_ms,
      agent_id: metadata.agent_id
    )
  end,
  nil
)
```

## Emitting Custom Domain Events

Use `Jido.Observe.emit_event/3` for events that ALWAYS emit (**not** gated by `:debug_events`):

```elixir
Jido.Observe.emit_event(
  [:my_app, :order, :created],
  %{amount: 99.99},
  %{order_id: "o-123", tenant: "alpha"}
)
```

### Event contracts

Validate shapes at event definition time:

```elixir
Jido.Observe.EventContract.validate_event(
  event,
  measurements,
  metadata,
  required_metadata: [:request_id, :tenant],
  required_measurements: [:duration_ms]
)
```

### Namespace ownership

- `jido` owns `[:jido, ...]`
- Domain packages own `[:jido, :domain_name, ...]` only if they're Jido-ecosystem
- App-owned events: use your own top-level namespace (`[:my_app, ...]`)

## Spans (manual)

```elixir
span = Jido.Observe.start_span([:my_app, :request], %{request_id: "r-123"})
# ... do work ...
Jido.Observe.finish_span(span, %{duration: 42})

# Or on exception:
try do
  do_work()
  Jido.Observe.finish_span(span, %{})
rescue
  e -> Jido.Observe.span_exception(span, :error, e, __STACKTRACE__); reraise e, __STACKTRACE__
end
```

## Custom Tracer (e.g. OpenTelemetry)

Implement `Jido.Observe.Tracer` behaviour:

```elixir
defmodule MyApp.Tracer do
  @behaviour Jido.Observe.Tracer

  @impl true
  def span_start(name, metadata), do: # ...
  @impl true
  def span_stop(span, measurements), do: # ...
  @impl true
  def span_exception(span, kind, reason, stacktrace), do: # ...
  @impl true
  def with_span_scope(span, fun, opts \\ []), do: # ...  (optional)
end

config :jido, :observability,
  tracer: MyApp.Tracer,
  tracer_failure_mode: :warn     # :strict raises, :warn logs
```

## Metrics (Prometheus, StatsD, etc.)

With `telemetry_metrics_prometheus`:

```elixir
import Telemetry.Metrics

{TelemetryMetricsPrometheus, metrics: [
  distribution("jido.agent.cmd.duration",
    unit: {:native, :millisecond},
    buckets: [10, 50, 100, 500, 1000]
  ),
  counter("jido.agent.cmd.stop.count"),
  counter("jido.agent.cmd.exception.count"),
  summary("jido.agent.cmd.directive_count")
]}
```

Or use the framework-provided set:

```elixir
{TelemetryMetricsPrometheus, metrics: Jido.Telemetry.metrics()}
```

## Recommended Event Taxonomy for AI Workloads

- `[:jido, :ai, :request, :start]` — measurements `{system_time: ...}`, metadata `{request_id, model, ...}`
- `[:jido, :ai, :request, :completed]` — `{duration_ms}`, `{terminal_state: :success, request_id}`
- `[:jido, :ai, :request, :failed]` — `{duration_ms}`, `{terminal_state: :failed, reason, request_id}`
- `[:jido, :ai, :request, :cancelled]`
- `[:jido, :ai, :request, :rejected]`
- `[:jido, :ai, :request, :tool, :start]` — `{tool}` in metadata
- `[:jido, :ai, :request, :tool, :stop]`

## SLO Targets (baseline)

- Command success rate: 99.9%
- Signal latency p99: < 500ms
- Directive success rate: 99.99%
- Queue overflow rate: 0

## Key Modules

- `Jido.Telemetry` — built-in handler + metrics definitions
- `Jido.Observe` — unified façade with span helpers, event emission, contract validation
- `Jido.Observe.Config` — per-instance config resolution
- `Jido.Observe.Tracer` — behaviour for custom tracers
- `Jido.Observe.NoopTracer` — default no-op tracer
- `Jido.Observe.SpanCtx` — span context struct
- `Jido.Tracing.Context` — correlation ID propagation
- `Jido.Tracing.Trace` — trace state

## Source

- `jido/guides/observability.md`
- `jido/guides/observability-intro.md`
- `jido/lib/jido/observe*.ex`, `jido/lib/jido/telemetry*.ex`, `jido/lib/jido/tracing/**`

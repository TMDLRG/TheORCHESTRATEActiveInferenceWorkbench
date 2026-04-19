# agent_plane/lib/agent_plane/telemetry/ — ReadmeAI

## Purpose

The bridge between raw `:telemetry` events (emitted by Jido and by `ActiveInferenceCore.DiscreteTime`) and the durable `WorldModels` event log. Also provides a process-dictionary context wrapper so agent_id / spec_id / bundle_id / family_id propagate into events without being threaded through every call.

## Contents

| File | Module | Purpose |
|---|---|---|
| [`bus.ex`](bus.ex) | `AgentPlane.Telemetry.Bus` | `:telemetry` attach → convert spans → `WorldModels.Event` → `WorldModels.Bus.broadcast/1` |
| [`context.ex`](context.ex) | `AgentPlane.Telemetry.Context` | `with_agent_context/2` wraps a block with `Process.put(:wm_telemetry_context, ctx)` |

## Public API

| Module | Function | Arity | Purpose |
|---|---|---|---|
| `AgentPlane.Telemetry.Bus` | `attach/0` | 0 | `:telemetry.attach_many/4` for all 11 handled events |
| `AgentPlane.Telemetry.Bus` | `detach/0` | 0 | `:telemetry.detach/1` |
| `AgentPlane.Telemetry.Bus` | `handle/4` | 4 | `:telemetry` callback; called by framework |
| `AgentPlane.Telemetry.Context` | `with_agent_context/2` | 2 | Scoped context; restores prior value in `on_exit` |

## Constants

| Constant | Value | Where |
|---|---|---|
| `@handler_id` | `AgentPlane.Telemetry.Bus` | [bus.ex:17](bus.ex) |
| `@dt_call_stop` | `[:active_inference_core, :discrete_time, :call, :stop]` | [bus.ex:18](bus.ex) |
| `@events` | 11 event names (jido lifecycle × {start, stop, exception} + dt span) | [bus.ex:20-32](bus.ex) |

## Telemetry mapping (observed → emitted)

| `:telemetry` event | `WorldModels.Event.type` |
|---|---|
| `[:active_inference_core, :discrete_time, :call, :stop]` | `"equation.evaluated"` |
| `[:jido, :agent_server, :signal, :start\|:stop\|:exception]` | `"runtime.jido.agent_server.signal.*"` |
| `[:jido, :agent_server, :directive, :start\|:stop\|:exception]` | `"runtime.jido.agent_server.directive.*"` |
| `[:jido, :agent, :cmd, :start\|:stop\|:exception]` | `"runtime.jido.agent.cmd.*"` |

Provenance tuple (`:agent_id`, `:spec_id`, `:bundle_id`, `:family_id`, `:equation_id`, `:trace_id`, `:span_id`) is populated from `Process.get(:wm_telemetry_context)`.

## Verification status

- `:verified` — integration test at [`../../../../workbench_web/test/integration/equation_telemetry_test.exs`](../../../../workbench_web/test/integration/equation_telemetry_test.exs) proves equation span → `equation.evaluated` event round-trip.

## Related

- Upstream reference: [`knowledgebase/jido/17-observability.md`](../../../../../../knowledgebase/jido/17-observability.md)
- Consumer: [`../../../../world_models/lib/world_models/bus.ex`](../../../../world_models/lib/world_models/bus.ex)

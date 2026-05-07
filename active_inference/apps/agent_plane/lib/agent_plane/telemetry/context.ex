defmodule AgentPlane.Telemetry.Context do
  @moduledoc """
  Plan §8.4 — propagates the provenance tuple from the agent's state into
  the process dict, where `AgentPlane.Telemetry.Bus`'s DiscreteTime
  forwarder picks it up when it receives an
  `[:active_inference_core, :discrete_time, :call, :stop]` span.

  `DiscreteTime` itself is a pure-math module and does NOT read this
  context; the forwarder runs synchronously in the caller's process and
  reads the dict during event dispatch.

  ## Concurrency caveat (audit anchor K3, v1.2-hardening)

  This module uses `Process.put/get`. **The process dictionary does NOT
  propagate across `Task.async`, `Task.async_stream`, or `spawn`.**

  If you parallelise a hot path that calls `with_agent_context/2` —
  for example, mapping `Task.async_stream` over policies inside
  `sweep_state_beliefs/7` — provenance will silently disappear in the
  child processes. Telemetry events will fire WITHOUT
  `agent_id`/`spec_id`/`bundle_id`/`family_id`, and the Glass Engine's
  back-traces will break.

  **Rule: do not parallelise callers without explicitly threading the
  context map through.** If you must parallelise, capture
  `current/0` before fan-out and pass it as an argument; the child
  function must call `with_agent_context/2` itself with that captured
  map before invoking the instrumented body.

  Verified by `agent_plane/test/telemetry_context_test.exs`: a property
  test using `Task.async_stream` confirms either (a) provenance is
  threaded explicitly through and survives, or (b) provenance is nil
  in the child task — never a silent partial loss.

  This is a known limitation of `Process.put/get`-based context
  propagation. A future refactor could move the context to a
  `Logger.metadata/1`-style ETS-backed mechanism, but that costs a
  hot-path lookup per span. The current trade-off favours hot-path
  speed + caller discipline over implicit propagation.
  """

  @key :wm_telemetry_context

  @spec with_agent_context(map(), (-> any())) :: any()
  def with_agent_context(%{} = state, fun) when is_function(fun, 0) do
    ctx = %{
      agent_id: Map.get(state, :agent_id),
      spec_id: Map.get(state, :spec_id),
      bundle_id: Map.get(state, :bundle_id),
      family_id: Map.get(state, :family_id),
      verification_status: Map.get(state, :verification_status)
    }

    previous = Process.get(@key)
    Process.put(@key, ctx)

    try do
      fun.()
    after
      if previous, do: Process.put(@key, previous), else: Process.delete(@key)
    end
  end

  @spec current() :: map() | nil
  def current, do: Process.get(@key)
end

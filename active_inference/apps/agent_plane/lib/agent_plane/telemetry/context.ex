defmodule AgentPlane.Telemetry.Context do
  @moduledoc """
  Plan §8.4 — propagates the provenance tuple from the agent's state into
  the process dict, where `AgentPlane.Telemetry.Bus`'s DiscreteTime
  forwarder picks it up when it receives an
  `[:active_inference_core, :discrete_time, :call, :stop]` span.

  `DiscreteTime` itself is a pure-math module and does NOT read this
  context; the forwarder runs synchronously in the caller's process and
  reads the dict during event dispatch.
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

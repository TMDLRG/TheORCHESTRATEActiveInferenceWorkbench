defmodule AgentPlane.Telemetry.Bus do
  @moduledoc """
  Plan §8.6 — forwards JIDO's built-in telemetry onto `WorldModels.Bus`.

  Attaches at `AgentPlane.Application.start/2`. For every JIDO signal,
  directive, and cmd lifecycle event, emits a corresponding
  `runtime.*` event on the shared bus (and persists it via EventLog).

  This is what gives the Glass Engine insight into the supervised runtime
  layer without any Episode-level instrumentation.
  """

  alias ActiveInferenceCore.DiscreteTime
  alias AgentPlane.EquationMap
  alias WorldModels.{Bus, Event, EventLog}

  @handler_id __MODULE__
  @dt_call_stop [:active_inference_core, :discrete_time, :call, :stop]

  @events [
    [:jido, :agent_server, :signal, :start],
    [:jido, :agent_server, :signal, :stop],
    [:jido, :agent_server, :signal, :exception],
    [:jido, :agent_server, :directive, :start],
    [:jido, :agent_server, :directive, :stop],
    [:jido, :agent_server, :directive, :exception],
    [:jido, :agent, :cmd, :start],
    [:jido, :agent, :cmd, :stop],
    [:jido, :agent, :cmd, :exception],
    # Plan §8.4 — per-equation spans from DiscreteTime.
    @dt_call_stop
  ]

  @spec attach() :: :ok | {:error, :already_exists}
  def attach do
    :telemetry.attach_many(@handler_id, @events, &__MODULE__.handle/4, %{})
  end

  @spec detach() :: :ok
  def detach, do: :telemetry.detach(@handler_id)

  @doc false
  # Plan §8.4 — DiscreteTime span: turn it into an equation.evaluated event
  # and enrich with the agent-side provenance context stashed in the
  # calling process's dict by Perceive/Plan/Act.
  def handle(@dt_call_stop, measurements, metadata, _config) do
    unless Bus.running?() do
      :ok
    else
      ctx = Process.get(:wm_telemetry_context, %{})
      fn_name = Map.get(metadata, :fn)
      arity = Map.get(metadata, :arity)
      equation_id = EquationMap.lookup(DiscreteTime, fn_name, arity)

      event =
        Event.new(%{
          type: "equation.evaluated",
          provenance: %{
            agent_id: Map.get(ctx, :agent_id),
            spec_id: Map.get(ctx, :spec_id),
            bundle_id: Map.get(ctx, :bundle_id),
            family_id: Map.get(ctx, :family_id),
            world_run_id: Map.get(ctx, :world_run_id),
            equation_id: equation_id,
            verification_status: Map.get(ctx, :verification_status)
          },
          data: %{
            module: "ActiveInferenceCore.DiscreteTime",
            fn_name: fn_name,
            arity: arity,
            duration_native: Map.get(measurements, :duration, 0),
            duration_us:
              System.convert_time_unit(
                Map.get(measurements, :duration, 0),
                :native,
                :microsecond
              )
          }
        })

      safe_append(event)
    end
  end

  # Default handler: every JIDO built-in event becomes a runtime.* event.
  def handle(event_name, measurements, metadata, _config) do
    unless Bus.running?() do
      :ok
    else
      type =
        "runtime." <>
          (event_name |> Enum.map_join(".", &Atom.to_string/1))

      event =
        Event.new(%{
          type: type,
          provenance: %{
            agent_id: Map.get(metadata, :agent_id),
            trace_id: Map.get(metadata, :jido_trace_id),
            span_id: Map.get(metadata, :jido_span_id)
          },
          data: %{
            measurements: measurements,
            metadata: safe_meta(metadata)
          }
        })

      safe_append(event)
    end
  end

  defp safe_append(event) do
    try do
      :ok = EventLog.append(event)
    rescue
      # If the event-log table isn't up yet (e.g., during boot race),
      # drop the event rather than take down the caller.
      _ -> :ok
    end
  end

  # Keep only fields that are safe to serialize / meaningful to the UI.
  defp safe_meta(meta) do
    Map.take(meta, [
      :agent_id,
      :agent_module,
      :signal_type,
      :jido_instance,
      :action,
      :directive_types,
      :jido_trace_id,
      :jido_span_id,
      :jido_parent_span_id,
      :jido_causation_id,
      :duration,
      :directive_count
    ])
  end
end

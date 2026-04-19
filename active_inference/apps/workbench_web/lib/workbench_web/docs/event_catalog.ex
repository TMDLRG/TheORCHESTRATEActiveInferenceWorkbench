defmodule WorkbenchWeb.Docs.EventCatalog do
  @moduledoc """
  Declarative catalog of every event type the system emits.

  Sources (code-cited):
    * `AgentPlane.Telemetry.Bus.@events` — 11 telemetry event names
      (`../../agent_plane/lib/agent_plane/telemetry/bus.ex:20-32`)
    * `WorkbenchWeb.Episode` publishes `world.observation`,
      `agent.perceived`, `agent.planned`, `agent.action_emitted`,
      `world.terminal` via `WorldModels.Bus.broadcast/1`.
    * `AgentPlane.Actions.Act` emits a `Jido.Signal` of type
      `"active_inference.action"` via `Jido.Agent.Directive.Emit`.

  If the list drifts from source, the authority is the source — update
  this file.
  """

  @type event_entry :: %{
          kind: :telemetry | :event_log | :jido_signal | :jido_directive,
          name: String.t(),
          emitter: String.t(),
          file: String.t(),
          purpose: String.t(),
          payload: String.t()
        }

  @entries [
    %{
      kind: :telemetry,
      name: "[:active_inference_core, :discrete_time, :call, :start|:stop|:exception]",
      emitter: "ActiveInferenceCore.DiscreteTime",
      file: "apps/active_inference_core/lib/active_inference_core/discrete_time.ex:60",
      purpose:
        "Pure-math span for every public DiscreteTime call. Re-emitted as \"equation.evaluated\" event.",
      payload: "measurements: %{duration: native} (on :stop); metadata: %{fn: atom, arity: int}"
    },
    %{
      kind: :telemetry,
      name: "[:jido, :agent_server, :signal, :start|:stop|:exception]",
      emitter: "Jido framework",
      file: "apps/agent_plane/lib/agent_plane/telemetry/bus.ex:20",
      purpose:
        "Jido.AgentServer signal lifecycle. Re-emitted as \"runtime.jido.agent_server.signal.*\".",
      payload: "per Jido framework; propagated agent_id, jido_trace_id, jido_span_id"
    },
    %{
      kind: :telemetry,
      name: "[:jido, :agent_server, :directive, :start|:stop|:exception]",
      emitter: "Jido framework",
      file: "apps/agent_plane/lib/agent_plane/telemetry/bus.ex:23",
      purpose:
        "Jido.AgentServer directive lifecycle. Re-emitted as \"runtime.jido.agent_server.directive.*\".",
      payload: "per Jido framework"
    },
    %{
      kind: :telemetry,
      name: "[:jido, :agent, :cmd, :start|:stop|:exception]",
      emitter: "Jido framework",
      file: "apps/agent_plane/lib/agent_plane/telemetry/bus.ex:26",
      purpose: "Jido.Agent cmd/2 lifecycle. Re-emitted as \"runtime.jido.agent.cmd.*\".",
      payload: "per Jido framework"
    },
    %{
      kind: :event_log,
      name: "equation.evaluated",
      emitter: "AgentPlane.Telemetry.Bus",
      file: "apps/agent_plane/lib/agent_plane/telemetry/bus.ex",
      purpose: "Durable record of a DiscreteTime math call. Carries equation_id provenance.",
      payload: "%{fn: atom, arity: int, duration_us: integer, equation_ids: [String.t]}"
    },
    %{
      kind: :event_log,
      name: "runtime.jido.agent_server.signal.(start|stop|exception)",
      emitter: "AgentPlane.Telemetry.Bus",
      file: "apps/agent_plane/lib/agent_plane/telemetry/bus.ex",
      purpose: "Durable Jido signal lifecycle events.",
      payload: "%{trace_id, span_id, duration_us, signal_type}"
    },
    %{
      kind: :event_log,
      name: "runtime.jido.agent_server.directive.(start|stop|exception)",
      emitter: "AgentPlane.Telemetry.Bus",
      file: "apps/agent_plane/lib/agent_plane/telemetry/bus.ex",
      purpose: "Durable Jido directive lifecycle events.",
      payload: "%{trace_id, span_id, duration_us, directive_type}"
    },
    %{
      kind: :event_log,
      name: "runtime.jido.agent.cmd.(start|stop|exception)",
      emitter: "AgentPlane.Telemetry.Bus",
      file: "apps/agent_plane/lib/agent_plane/telemetry/bus.ex",
      purpose: "Durable Jido cmd lifecycle events.",
      payload: "%{trace_id, span_id, duration_us, action}"
    },
    %{
      kind: :event_log,
      name: "world.observation",
      emitter: "WorkbenchWeb.Episode",
      file: "apps/workbench_web/lib/workbench_web/episode.ex",
      purpose:
        "Observation packet emitted from engine at initial mount + after each apply_action.",
      payload: "ObservationPacket serialisation"
    },
    %{
      kind: :event_log,
      name: "agent.perceived",
      emitter: "WorkbenchWeb.Episode",
      file: "apps/workbench_web/lib/workbench_web/episode.ex",
      purpose: "Post-Perceive belief update summary.",
      payload: "%{state_beliefs, marginal_state_belief, t}"
    },
    %{
      kind: :event_log,
      name: "agent.planned",
      emitter: "WorkbenchWeb.Episode",
      file: "apps/workbench_web/lib/workbench_web/episode.ex",
      purpose: "Post-Plan F, G, and policy posterior.",
      payload: "%{f: [float], g: [float], policy_posterior: [float], best_policy_idx: int}"
    },
    %{
      kind: :event_log,
      name: "agent.action_emitted",
      emitter: "WorkbenchWeb.Episode",
      file: "apps/workbench_web/lib/workbench_web/episode.ex",
      purpose: "Action chosen and dispatched to the world.",
      payload: "ActionPacket serialisation"
    },
    %{
      kind: :event_log,
      name: "world.terminal",
      emitter: "WorkbenchWeb.Episode",
      file: "apps/workbench_web/lib/workbench_web/episode.ex",
      purpose: "Terminal condition reached (goal or max_steps).",
      payload: "%{reason: :goal | :max_steps, summary: map}"
    },
    %{
      kind: :jido_signal,
      name: "active_inference.action",
      emitter: "AgentPlane.Actions.Act",
      file: "apps/agent_plane/lib/agent_plane/actions/act.ex",
      purpose:
        "Jido.Signal carrying the chosen ActionPacket + F / G / policy posterior for observability.",
      payload: "%{action, f, g, policy_posterior, best_policy_chain}"
    },
    %{
      kind: :jido_directive,
      name: "Jido.Agent.Directive.Emit",
      emitter: "AgentPlane.Actions.Act",
      file: "apps/agent_plane/lib/agent_plane/actions/act.ex",
      purpose: "Directive that dispatches the action signal via the AgentServer.",
      payload: "{Directive.Emit, signal}"
    }
  ]

  @doc "Every event the system emits, with emitter + payload + file."
  @spec all() :: [event_entry()]
  def all, do: @entries

  @doc "Filter by kind (`:telemetry | :event_log | :jido_signal | :jido_directive`)."
  @spec by_kind(atom()) :: [event_entry()]
  def by_kind(kind), do: Enum.filter(@entries, &(&1.kind == kind))
end

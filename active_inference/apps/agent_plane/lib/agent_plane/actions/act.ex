defmodule AgentPlane.Actions.Act do
  @moduledoc """
  JIDO action: emit a `SharedContracts.ActionPacket` through a JIDO
  `Directive.Emit` signal.

  Preconditions: `:last_action` has been set by a prior `Plan` action and
  the agent's blanket is non-nil.

  Post-conditions:

    * Telemetry for the current step is prepended to `:telemetry`.
    * A `Jido.Signal` of type `"active_inference.action"` is emitted.
  """

  use Jido.Action,
    name: "act",
    description:
      "Emit the chosen action as a blanket-compliant ActionPacket (eq. 2.5 action term).",
    schema: [
      dispatch: [type: :any, default: nil]
    ]

  alias Jido.Agent.Directive
  alias Jido.Signal
  alias SharedContracts.ActionPacket

  @impl true
  def run(%{dispatch: dispatch}, context) do
    state = context.state

    if is_nil(state.last_action) do
      {:error, "Act invoked before Plan; state.last_action is nil"}
    else
      packet =
        ActionPacket.new(%{
          t: state.t + 1,
          action: state.last_action,
          agent_id: state.agent_id,
          blanket: state.blanket
        })

      telemetry_entry = %{
        t: state.t,
        selected_action: state.last_action,
        policy_posterior: state.policy_posterior,
        f: state.last_f,
        g: state.last_g,
        marginal_state_belief: state.marginal_state_belief,
        best_policy_index: state.last_policy_best_idx,
        emitted_packet: packet
      }

      new_state = %{telemetry: [telemetry_entry | state.telemetry]}

      # Plan §10.4 — every action emission carries the provenance tuple so
      # Glass Engine can trace: signal → agent_id → bundle_id → family_id
      # → equation_ids without any UI-side joins. equation_id here is the
      # driving equation for action selection — eq. 4.14 / B.9.
      signal =
        Signal.new!(%{
          type: "active_inference.action",
          source: "/agent/#{state.agent_id}",
          data: %{
            action: packet.action,
            t: packet.t,
            agent_id: packet.agent_id,
            equation_id: "eq_4_14_policy_posterior",
            spec_id: state.spec_id,
            bundle_id: state.bundle_id,
            family_id: state.family_id,
            verification_status: state.verification_status,
            policy_posterior: state.policy_posterior,
            f: state.last_f,
            g: state.last_g,
            best_policy_index: state.last_policy_best_idx
          }
        })

      directive =
        case dispatch do
          nil -> %Directive.Emit{signal: signal}
          d -> %Directive.Emit{signal: signal, dispatch: d}
        end

      {:ok, new_state, directive}
    end
  end
end

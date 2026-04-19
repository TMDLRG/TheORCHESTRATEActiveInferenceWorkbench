defmodule AgentPlane.Actions.Plan do
  @moduledoc """
  JIDO action: compute F, G, and the policy posterior.

  Implements eq. 4.11, 4.10, and 4.14 (with habit term E per B.9) via
  `ActiveInferenceCore.DiscreteTime.choose_action/4`. The action doesn't
  *emit* anything yet; it just records the result in agent state so the
  subsequent `Act` action can reuse it.
  """

  use Jido.Action,
    name: "plan",
    description: "Compute per-policy VFE, EFE, and policy posterior (eq. 4.14 / B.9).",
    schema: []

  alias ActiveInferenceCore.DiscreteTime
  alias AgentPlane.Telemetry.Context

  @impl true
  def run(_params, context) do
    state = context.state

    # Temporal integration — use the previous step's marginal as the
    # prior D so the agent's localization accumulates evidence across
    # steps. Without this, each step would re-start from the original
    # D (point mass at start) and the belief would never sharpen
    # beyond a single-step likelihood update. On step 0
    # marginal_state_belief is still the bundle's D.
    prior_d =
      case state.marginal_state_belief do
        [] -> state.bundle.d
        [_ | _] = prev -> prev
      end

    bundle_with_prior = %{state.bundle | d: prior_d}

    result =
      Context.with_agent_context(state, fn ->
        DiscreteTime.choose_action(
          bundle_with_prior,
          state.beliefs,
          state.obs_history,
          state.t
        )
      end)

    {:ok,
     %{
       beliefs: result.beliefs,
       policy_posterior: result.policy_posterior,
       last_f: result.f,
       last_g: result.g,
       last_policy_best_idx: result.telemetry.best_policy_index,
       marginal_state_belief: result.marginal_state_belief,
       best_policy_chain: result.best_policy_chain,
       last_action: result.action
     }}
  end
end

defmodule AgentPlane.Actions.SophisticatedPlan do
  @moduledoc """
  Lego-uplift Phase G — deep-horizon sophisticated inference (Ch 7).

  Extends the naïve `Plan` action with two additions:

  1. **Deeper policy horizon.** The bundle's prebuilt policies list is
     re-enumerated at a configurable depth at runtime so one canvas can
     host mazes of varying difficulty.
  2. **Beam-width pruning.** Instead of enumerating all `|A|^horizon`
     policies, at each depth we keep only the top-`beam_width` prefixes
     by single-step ambiguity. Solves the deceptive dead-end maze the
     naïve planner wall-bumps on, without combinatorial blow-up.

  Mode `:exhaustive` keeps the full enumeration; `:beam` applies the
  prune. Every call emits an `equation.evaluated` span through the same
  `with_agent_context` wrapper as the naïve planner so Glass can show
  the rollout tree.
  """

  use Jido.Action,
    name: "sophisticated_plan",
    description:
      "Deep-horizon iterative policy search with optional beam-width pruning (eq 4.14 / Ch 7).",
    schema: [
      horizon: [type: :integer, default: 5],
      tree_policy: [type: :string, default: "exhaustive"],
      beam_width: [type: :integer, default: 8],
      discount: [type: :float, default: 0.95]
    ]

  alias ActiveInferenceCore.{DiscreteTime, Math}
  alias AgentPlane.Telemetry.Context

  @impl true
  def run(params, context) do
    state = context.state

    policies = plan_policies(state.bundle, params)

    # Temporal integration — reuse the previous step's marginal as D.
    prior_d =
      case state.marginal_state_belief do
        [] -> state.bundle.d
        [_ | _] = prev -> prev
      end

    bundle_override = %{state.bundle | policies: policies, d: prior_d}

    # `choose_action` calls `sweep_state_beliefs`, which does
    # `Map.fetch!(beliefs, pi)` for every policy index in `policies`.
    # When we re-enumerate policies here the existing state.beliefs
    # map is keyed by the bundle's original policy indices, so we must
    # initialise a fresh per-policy belief map that matches the new
    # `policies` list.
    fresh =
      Context.with_agent_context(state, fn ->
        DiscreteTime.fresh_beliefs(bundle_override)
      end)

    result =
      Context.with_agent_context(state, fn ->
        DiscreteTime.choose_action(
          bundle_override,
          fresh,
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

  defp plan_policies(bundle, %{horizon: horizon, tree_policy: tree_policy, beam_width: beam_width}) do
    actions = bundle.actions

    case tree_policy do
      "beam" -> beam_search_policies(bundle, actions, horizon, beam_width)
      _ -> enumerate_policies(actions, horizon)
    end
  end

  defp enumerate_policies(actions, horizon) do
    Enum.reduce(1..horizon, [[]], fn _, acc ->
      for prefix <- acc, a <- actions, do: prefix ++ [a]
    end)
  end

  # Greedy beam search — at each depth, score each prefix by cumulative
  # ambiguity of the predicted state trajectory from D forward and keep
  # only the top-`beam_width` (lowest ambiguity). Ambiguity is the
  # expected entropy of the likelihood under the rolled-out belief,
  # dot(ambiguity_vector(A), s_pred).
  defp beam_search_policies(bundle, actions, horizon, beam_width) do
    initial_beam = Enum.map(actions, &[&1])

    Enum.reduce(2..horizon, initial_beam, fn _depth, beam ->
      expanded = for prefix <- beam, a <- actions, do: prefix ++ [a]
      scored = Enum.map(expanded, &{score_prefix(bundle, &1), &1})

      scored
      |> Enum.sort_by(fn {s, _} -> s end)
      |> Enum.take(beam_width)
      |> Enum.map(fn {_, p} -> p end)
    end)
  end

  # Score a prefix by the cumulative ambiguity of the rolled-out belief
  # under the bundle's starting prior D. Lower is better.
  defp score_prefix(%{b: b_per_action, a: a, d: d}, prefix) do
    h = Math.ambiguity_vector(a)

    prefix
    |> Enum.reduce({d, 0.0}, fn act, {s_curr, acc} ->
      b = Map.fetch!(b_per_action, act)
      s_next = Math.matvec(b, s_curr)
      {s_next, acc + Math.dot(h, s_next)}
    end)
    |> elem(1)
  end
end

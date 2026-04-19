defmodule AgentPlane.EquationMap do
  @moduledoc """
  Plan §8.4 — authoritative mapping from `{module, fn_name, arity}` in the
  Active Inference math core to equation IDs in
  `ActiveInferenceCore.Equations`.

  Glass Engine uses this to turn raw
  `[:active_inference_core, :discrete_time, :call]` telemetry spans into
  `equation.evaluated` events with a concrete `equation_id` that resolves
  in the registry.

  Invariants (verified by `AgentPlane.EquationMapTest`):
  - every mapped id is a real `%Equation{}` in the registry,
  - every public `DiscreteTime` function has a mapping.
  """

  alias ActiveInferenceCore.DiscreteTime

  @table %{
    {DiscreteTime, :predict_obs, 2} => "eq_4_5_pomdp_likelihood",
    {DiscreteTime, :update_state_beliefs, 8} => "eq_4_13_state_belief_update",
    {DiscreteTime, :sweep_state_beliefs, 7} => "eq_4_13_state_belief_update",
    {DiscreteTime, :variational_free_energy, 6} => "eq_4_11_vfe_linear_algebra",
    {DiscreteTime, :expected_free_energy, 4} => "eq_4_10_efe_linear_algebra",
    {DiscreteTime, :policy_posterior, 3} => "eq_4_14_policy_posterior",
    {DiscreteTime, :choose_action, 4} => "eq_4_14_policy_posterior",
    {DiscreteTime, :marginal_over_policies, 3} => "eq_4_14_policy_posterior",
    {DiscreteTime, :fresh_beliefs, 1} => "eq_4_6_pomdp_prior_over_states",
    {DiscreteTime, :rollout_forward, 4} => "eq_4_6_pomdp_prior_over_states"
  }

  @spec lookup(module(), atom(), non_neg_integer()) :: String.t() | nil
  def lookup(module, fn_name, arity), do: Map.get(@table, {module, fn_name, arity})

  @spec all() :: %{{module(), atom(), non_neg_integer()} => String.t()}
  def all, do: @table
end

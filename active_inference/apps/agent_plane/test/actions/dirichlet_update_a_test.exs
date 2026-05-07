defmodule AgentPlane.Actions.DirichletUpdateATest do
  @moduledoc """
  AUDIT REGRESSION (external review C2, v1+v2): proves that
  `DirichletUpdateA` reads the agent's posterior from `state.marginal_state_belief`,
  not from the (always-empty) `bundle.marginal_state_belief`.

  The bug being guarded against: prior to the v1.1 remediation, the action
  used `Map.get(bundle, :marginal_state_belief, uniform(...))` which always
  hit the uniform fallback — making every L4 Dirichlet update silently
  state-independent.

  These tests must do MORE than confirm "alpha changes after one call." A
  test that just checks alpha mutation passes even with the bug (the
  uniform fallback also mutates alpha). The tests below assert
  state-dependent updates: two scenarios that differ ONLY in
  `state.marginal_state_belief` must produce DIFFERENT alpha deltas.
  """

  use ExUnit.Case, async: true

  alias AgentPlane.{ActiveInferenceAgent, BundleBuilder.Meadow}
  alias AgentPlane.Actions.DirichletUpdateA
  alias SharedContracts.Blanket

  defp fresh_agent_with_obs(marginal) do
    bundle = Meadow.simple(width: 4, height: 4, preferred_token: :t1)
    blanket = Blanket.meadow_default()
    agent = ActiveInferenceAgent.fresh("dir-a-test", bundle, blanket)
    n_obs = length(bundle.a)
    # Place a known one-hot observation at index 7 (arbitrary, fixed).
    obs_vec = for i <- 0..(n_obs - 1), do: if(i == 7, do: 1.0, else: 0.0)

    agent
    |> put_in([Access.key!(:state), Access.key!(:obs_history)], [obs_vec])
    |> put_in([Access.key!(:state), Access.key!(:marginal_state_belief)], marginal)
  end

  defp run_update(agent) do
    {agent2, _} =
      ActiveInferenceAgent.cmd(
        agent,
        {DirichletUpdateA, %{prior_concentration: 1.0, learning_rate: 1.0}}
      )

    agent2.state.bundle
  end

  describe "state-dependent alpha-A update" do
    test "alpha at observed obs-row tracks state.marginal_state_belief" do
      n_states = 16
      # Concentrated posterior at state index 3.
      q_star = for i <- 0..(n_states - 1), do: if(i == 3, do: 1.0, else: 0.0)
      agent = fresh_agent_with_obs(q_star)

      bundle_after = run_update(agent)
      alpha = Map.fetch!(bundle_after, :dirichlet_a_counts)

      # Row 7 (the observed obs index) — column 3 should have grown by 1.0,
      # other columns by 0.0. Initial alpha is `prior_concentration = 1.0`
      # for all entries, so we expect row 7 ≈ [1.0, 1.0, 1.0, 2.0, 1.0, ...]
      row_7 = Enum.at(alpha, 7)
      assert_in_delta Enum.at(row_7, 3), 2.0, 1.0e-9
      assert_in_delta Enum.at(row_7, 0), 1.0, 1.0e-9
      assert_in_delta Enum.at(row_7, 5), 1.0, 1.0e-9

      # Other obs-rows (e.g. row 0) should not have shifted at all.
      row_0 = Enum.at(alpha, 0)
      assert_in_delta Enum.at(row_0, 3), 1.0, 1.0e-9
    end

    test "two scenarios with different marginal produce different alphas" do
      n_states = 16
      q_a = for i <- 0..(n_states - 1), do: if(i == 3, do: 1.0, else: 0.0)
      q_b = for i <- 0..(n_states - 1), do: if(i == 11, do: 1.0, else: 0.0)

      bundle_a = run_update(fresh_agent_with_obs(q_a))
      bundle_b = run_update(fresh_agent_with_obs(q_b))

      alpha_a = Map.fetch!(bundle_a, :dirichlet_a_counts)
      alpha_b = Map.fetch!(bundle_b, :dirichlet_a_counts)

      row_7_a = Enum.at(alpha_a, 7)
      row_7_b = Enum.at(alpha_b, 7)

      # Scenario A bumped column 3; scenario B bumped column 11.
      refute row_7_a == row_7_b,
             "alpha matrices must differ when state.marginal_state_belief differs " <>
               "(this is the bug we're guarding against)"

      assert_in_delta Enum.at(row_7_a, 3), 2.0, 1.0e-9
      assert_in_delta Enum.at(row_7_a, 11), 1.0, 1.0e-9

      assert_in_delta Enum.at(row_7_b, 11), 2.0, 1.0e-9
      assert_in_delta Enum.at(row_7_b, 3), 1.0, 1.0e-9
    end

    test "uniform-marginal fallback preserved when state has no posterior yet" do
      # Empty marginal → uniform fallback. This is the documented behaviour
      # for an agent that hasn't run Plan yet.
      agent =
        Meadow.simple(width: 4, height: 4, preferred_token: :t1)
        |> then(fn b -> ActiveInferenceAgent.fresh("dir-a-empty", b, Blanket.meadow_default()) end)
        |> put_in([Access.key!(:state), Access.key!(:marginal_state_belief)], [])
        |> put_in([Access.key!(:state), Access.key!(:obs_history)], [
          for(i <- 0..(length(elem({hd_a(), 0}, 0)) - 1), do: if(i == 7, do: 1.0, else: 0.0))
        ])

      bundle_after = run_update(agent)
      alpha = Map.fetch!(bundle_after, :dirichlet_a_counts)
      row_7 = Enum.at(alpha, 7)

      # Uniform 1/16 across 16 states means every column gets +1/16.
      Enum.each(row_7, fn v ->
        assert_in_delta v, 1.0 + 1.0 / 16.0, 1.0e-9
      end)
    end
  end

  defp hd_a do
    Meadow.simple(width: 4, height: 4, preferred_token: :t1).a
  end
end

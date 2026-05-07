defmodule AgentPlane.Actions.DirichletUpdateBTest do
  @moduledoc """
  AUDIT REGRESSION (external review C2, v1+v2): proves that
  `DirichletUpdateB` reads `q_now` from `state.marginal_state_belief`, not
  from the (always-empty) `bundle.marginal_state_belief`.

  The bug being guarded against: prior to v1.1 remediation, both
  `q_prev = Map.get(bundle, :prev_marginal_state_belief, nil)` AND
  `q_now = Map.get(bundle, :marginal_state_belief, nil)` always returned
  `nil` (the second because the bundle simply doesn't carry that key —
  the agent's *state* does). The cond branch on line 32 then always took
  the no-op path. DirichletUpdateB was silently dead.

  After the fix, `q_now` reads from `state.marginal_state_belief` while
  `q_prev` continues to come from `bundle.prev_marginal_state_belief`
  (which DirichletUpdateB itself writes back on line 53 — the per-tick
  rotation works for tick 1 onward; tick 0 correctly no-ops on q_prev=nil).
  """

  use ExUnit.Case, async: true

  alias AgentPlane.{ActiveInferenceAgent, BundleBuilder.Meadow}
  alias AgentPlane.Actions.DirichletUpdateB
  alias SharedContracts.Blanket

  defp fresh_agent(marginal, last_action) do
    bundle = Meadow.simple(width: 4, height: 4, preferred_token: :t1)
    blanket = Blanket.meadow_default()
    agent = ActiveInferenceAgent.fresh("dir-b-test", bundle, blanket)

    agent
    |> put_in([Access.key!(:state), Access.key!(:marginal_state_belief)], marginal)
    |> put_in([Access.key!(:state), Access.key!(:last_action)], last_action)
  end

  defp run_update(agent) do
    {agent2, _} =
      ActiveInferenceAgent.cmd(
        agent,
        {DirichletUpdateB, %{prior_concentration: 1.0, learning_rate: 1.0}}
      )

    agent2.state.bundle
  end

  describe "two-tick rotation produces non-uniform alpha-B" do
    test "tick 0 no-ops; tick 1 fires with q_prev=q_t0, q_now=q_t1" do
      n_states = 16

      # Tick 0: marginal = point-mass at state 2. No prev_marginal yet.
      q_t0 = for i <- 0..(n_states - 1), do: if(i == 2, do: 1.0, else: 0.0)
      agent_t0 = fresh_agent(q_t0, :move_east)
      bundle_t0 = run_update(agent_t0)

      # The tick-0 update wrote prev_marginal = q_t0 to the bundle but did
      # NOT touch dirichlet_b_counts (q_prev was nil — no-op branch).
      assert Map.get(bundle_t0, :prev_marginal_state_belief) == q_t0

      assert Map.get(bundle_t0, :dirichlet_b_counts) == nil or
               Map.get(bundle_t0, :dirichlet_b_counts) == %{}

      # Tick 1: marginal = point-mass at state 5. Re-use bundle_t0 so
      # prev_marginal is preserved.
      q_t1 = for i <- 0..(n_states - 1), do: if(i == 5, do: 1.0, else: 0.0)

      agent_t1 =
        agent_t0
        |> put_in([Access.key!(:state), Access.key!(:bundle)], bundle_t0)
        |> put_in([Access.key!(:state), Access.key!(:marginal_state_belief)], q_t1)

      bundle_t1 = run_update(agent_t1)

      counts = Map.fetch!(bundle_t1, :dirichlet_b_counts)
      alpha_action = Map.fetch!(counts, :move_east)

      # The outer product q_t1 ⊗ q_t0 has a single non-zero entry at
      # (s_next=5, s_curr=2), magnitude 1.0. So alpha_action[5][2] should
      # be the prior (1.0) + learning rate × 1.0 × 1.0 = 2.0; everything
      # else is the prior 1.0.
      row_5 = Enum.at(alpha_action, 5)
      assert_in_delta Enum.at(row_5, 2), 2.0, 1.0e-9
      assert_in_delta Enum.at(row_5, 0), 1.0, 1.0e-9

      # Other rows undisturbed.
      row_0 = Enum.at(alpha_action, 0)
      assert_in_delta Enum.at(row_0, 2), 1.0, 1.0e-9
    end

    test "two scenarios with different (q_prev, q_now) pairs produce different alphas" do
      n_states = 16

      run_two_ticks = fn q_t0, q_t1 ->
        agent_a = fresh_agent(q_t0, :move_west)
        bundle_a = run_update(agent_a)

        agent_b =
          agent_a
          |> put_in([Access.key!(:state), Access.key!(:bundle)], bundle_a)
          |> put_in([Access.key!(:state), Access.key!(:marginal_state_belief)], q_t1)

        run_update(agent_b)
      end

      q_t0_x = for i <- 0..(n_states - 1), do: if(i == 1, do: 1.0, else: 0.0)
      q_t1_x = for i <- 0..(n_states - 1), do: if(i == 4, do: 1.0, else: 0.0)

      q_t0_y = for i <- 0..(n_states - 1), do: if(i == 9, do: 1.0, else: 0.0)
      q_t1_y = for i <- 0..(n_states - 1), do: if(i == 12, do: 1.0, else: 0.0)

      bundle_x = run_two_ticks.(q_t0_x, q_t1_x)
      bundle_y = run_two_ticks.(q_t0_y, q_t1_y)

      alpha_x = bundle_x.dirichlet_b_counts |> Map.fetch!(:move_west)
      alpha_y = bundle_y.dirichlet_b_counts |> Map.fetch!(:move_west)

      refute alpha_x == alpha_y,
             "alpha-B must differ when (q_prev, q_now) differ — guards C2 regression"

      # Specific incremented entries differ.
      assert_in_delta Enum.at(Enum.at(alpha_x, 4), 1), 2.0, 1.0e-9
      assert_in_delta Enum.at(Enum.at(alpha_y, 12), 9), 2.0, 1.0e-9
    end
  end
end

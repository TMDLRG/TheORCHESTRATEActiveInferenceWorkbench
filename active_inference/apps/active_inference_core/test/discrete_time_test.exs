defmodule ActiveInferenceCore.DiscreteTimeTest do
  use ExUnit.Case, async: true

  alias ActiveInferenceCore.{DiscreteTime, Math}

  describe "softmax / normalise" do
    test "softmax is a probability distribution" do
      p = Math.softmax([0.0, 1.0, 2.0])
      assert_in_delta Enum.sum(p), 1.0, 1.0e-9
      Enum.each(p, fn x -> assert x >= 0.0 end)
    end

    test "softmax is monotone in input" do
      [a, b, c] = Math.softmax([0.0, 1.0, 2.0])
      assert a < b
      assert b < c
    end
  end

  describe "predict_obs (eq. 4.10 / B.28)" do
    test "maps state belief through A to produce outcome distribution" do
      # A: 2 outcomes × 3 states
      a = [[0.9, 0.2, 0.0], [0.1, 0.8, 1.0]]
      s = [0.0, 1.0, 0.0]
      assert DiscreteTime.predict_obs(a, s) == [0.2, 0.8]
    end
  end

  describe "expected_free_energy (eq. 4.10 / B.30)" do
    test "prefers a belief concentrated on the preferred outcome" do
      # 3 states, 2 outcomes (0 = bad, 1 = good). State 2 always yields good.
      a = [[0.9, 0.9, 0.1], [0.1, 0.1, 0.9]]
      c_vec = [0.1, 0.9]
      c_log = Math.log_eps(c_vec)

      s_good = [0.0, 0.0, 1.0]
      s_bad = [1.0, 0.0, 0.0]

      chain_good = [s_good]
      chain_bad = [s_bad]

      g_good = DiscreteTime.expected_free_energy(chain_good, a, c_log, -1).total
      g_bad = DiscreteTime.expected_free_energy(chain_bad, a, c_log, -1).total

      assert g_good < g_bad
    end

    test "decomposes into ambiguity + risk" do
      a = [[0.9, 0.9, 0.1], [0.1, 0.1, 0.9]]
      c_log = Math.log_eps([0.1, 0.9])
      s = [0.3, 0.4, 0.3]

      %{total: total, ambiguity_per_tau: [amb], risk_per_tau: [risk]} =
        DiscreteTime.expected_free_energy([s], a, c_log, -1)

      assert_in_delta total, amb + risk, 1.0e-9
    end
  end

  describe "policy_posterior (eq. 4.14 / B.9)" do
    test "upweights policies with low F and low G" do
      f = [0.0, 2.0, 1.0]
      g = [0.0, 2.0, 0.5]
      pi = DiscreteTime.policy_posterior(f, g)

      assert Enum.at(pi, 0) > Enum.at(pi, 2)
      assert Enum.at(pi, 2) > Enum.at(pi, 1)
      assert_in_delta Enum.sum(pi), 1.0, 1.0e-9
    end
  end

  describe "update_state_beliefs (eq. 4.13 / B.5)" do
    test "observation concentrates posterior on the consistent state" do
      # 2 states, 2 observations, A identity (clean likelihood)
      a = [[0.99, 0.01], [0.01, 0.99]]
      s_prior = [0.5, 0.5]
      obs = [1.0, 0.0]
      # No transition context: just likelihood.
      s_post = DiscreteTime.update_state_beliefs(nil, s_prior, nil, obs, a, nil, nil, 1.0)
      assert Enum.at(s_post, 0) > Enum.at(s_post, 1)
    end
  end

  describe "choose_action end-to-end on a 2-state toy POMDP" do
    test "agent chooses the action that yields the preferred observation" do
      # 2 states, 2 observations. From s=0, action :left stays; action :right moves to s=1.
      # Observation matches state (clean A). Preference is for obs 1 (i.e., state 1).
      a = [[0.95, 0.05], [0.05, 0.95]]
      b_left = [[1.0, 1.0], [0.0, 0.0]]
      b_right = [[0.0, 0.0], [1.0, 1.0]]

      bundle = %{
        a: a,
        b: %{left: b_left, right: b_right},
        c: Math.log_eps(Math.softmax([0.0, 4.0])),
        d: [1.0, 0.0],
        e: nil,
        actions: [:left, :right],
        policies: [[:left, :left], [:right, :right], [:left, :right], [:right, :left]],
        horizon: 2
      }

      beliefs = DiscreteTime.fresh_beliefs(bundle)
      result = DiscreteTime.choose_action(bundle, beliefs, [], -1)

      assert result.action == :right
    end
  end
end

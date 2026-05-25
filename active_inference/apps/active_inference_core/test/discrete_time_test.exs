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

    test "γ=1, T=1 recovers the textbook σ(ln E − F − G)" do
      f = [0.2, 0.5]
      g = [0.1, 0.9]
      got = DiscreteTime.policy_posterior(f, g, nil, gamma: 1.0, temperature: 1.0)
      want = Math.softmax([-0.2 - 0.1, -0.5 - 0.9])
      assert_in_delta Enum.at(got, 0), Enum.at(want, 0), 1.0e-9
      assert_in_delta Enum.at(got, 1), Enum.at(want, 1), 1.0e-9
    end

    test "policy precision γ sharpens the posterior toward the lowest-G policy" do
      # Equal F so only G (scaled by γ) drives the posterior. Policy 0 has min G.
      f = [0.0, 0.0, 0.0]
      g = [0.0, 1.0, 2.0]
      low = DiscreteTime.policy_posterior(f, g, nil, gamma: 0.5)
      high = DiscreteTime.policy_posterior(f, g, nil, gamma: 4.0)

      # Higher γ concentrates more probability on the min-G policy.
      assert Enum.at(high, 0) > Enum.at(low, 0)
      # ...and less on the worst (max-G) policy.
      assert Enum.at(high, 2) < Enum.at(low, 2)
      assert_in_delta Enum.sum(high), 1.0, 1.0e-9
      assert_in_delta Enum.sum(low), 1.0, 1.0e-9
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
        horizon: 2,
        action_selection: :argmax
      }

      beliefs = DiscreteTime.fresh_beliefs(bundle)
      result = DiscreteTime.choose_action(bundle, beliefs, [], -1)

      assert result.action == :right
    end
  end

  describe "Math.precision_weight (sensory / transition precision)" do
    test "gamma = 1.0 is the identity" do
      m = [[0.7, 0.2], [0.3, 0.8]]
      assert Math.precision_weight(m, 1.0) == m
    end

    test "columns stay normalised for any gamma" do
      m = [[0.7, 0.2], [0.3, 0.8]]

      for g <- [0.2, 0.5, 2.0, 6.0] do
        weighted = Math.precision_weight(m, g)

        for col <- Math.transpose(weighted) do
          assert_in_delta Enum.sum(col), 1.0, 1.0e-9
        end
      end
    end

    test "gamma > 1 sharpens — the dominant entry grows" do
      m = [[0.7, 0.5], [0.3, 0.5]]
      [[a00, _], [_, _]] = Math.precision_weight(m, 5.0)
      assert a00 > 0.7
    end

    test "gamma < 1 flattens toward uniform" do
      m = [[0.9, 0.5], [0.1, 0.5]]
      [[a00, _], [_, _]] = Math.precision_weight(m, 0.2)
      assert a00 < 0.9
      assert a00 > 0.5
    end

    test "a deterministic point-mass column is invariant under any gamma" do
      m = [[1.0, 0.0], [0.0, 1.0]]
      assert Math.precision_weight(m, 0.3) == m
      assert Math.precision_weight(m, 4.0) == m
    end
  end

  describe "choose_action — sensory precision (gamma_a)" do
    test "gamma_a = 1.0 reproduces the un-parameterised result" do
      base = DiscreteTime.choose_action(goal_bundle(), %{}, [], -1)
      g1 = DiscreteTime.choose_action(goal_bundle(%{gamma_a: 1.0}), %{}, [], -1)
      assert base.f == g1.f
      assert base.g == g1.g
      assert base.policy_posterior == g1.policy_posterior
    end

    test "lower gamma_a raises EFE ambiguity (a less legible world)" do
      sharp = DiscreteTime.choose_action(goal_bundle(%{gamma_a: 4.0}), %{}, [], -1)
      flat = DiscreteTime.choose_action(goal_bundle(%{gamma_a: 0.25}), %{}, [], -1)
      assert total_ambiguity(flat) > total_ambiguity(sharp)
    end
  end

  describe "choose_action — transition precision (gamma_b)" do
    test "gamma_b = 1.0 reproduces the un-parameterised result" do
      bundle = stochastic_b_bundle()
      base = DiscreteTime.choose_action(bundle, %{}, [], -1)
      g1 = DiscreteTime.choose_action(Map.put(bundle, :gamma_b, 1.0), %{}, [], -1)
      assert base.f == g1.f
      assert base.g == g1.g
    end

    test "gamma_b reshapes planning when transitions are stochastic" do
      bundle = stochastic_b_bundle()
      sharp = DiscreteTime.choose_action(Map.put(bundle, :gamma_b, 5.0), %{}, [], -1)
      flat = DiscreteTime.choose_action(Map.put(bundle, :gamma_b, 0.3), %{}, [], -1)
      refute sharp.g == flat.g
    end
  end

  describe "learned-likelihood inference — E[ln A] (digamma, eq. 7.x)" do
    test "inference_log_a returns E[ln A] only when learning is live with counts" do
      counts = [[3.0, 1.0], [1.0, 3.0]]

      assert DiscreteTime.inference_log_a(%{}) == nil
      assert DiscreteTime.inference_log_a(%{learning_enabled: true}) == nil

      assert DiscreteTime.inference_log_a(%{learning_enabled: false, dirichlet_a_counts: counts}) ==
               nil

      assert DiscreteTime.inference_log_a(%{learning_enabled: true, dirichlet_a_counts: counts}) ==
               Math.dirichlet_expected_log(counts)
    end

    test "a learned-A sweep converges to the mean-log sweep as evidence concentrates" do
      # Light vs heavy Dirichlet counts sharing the same mean A = [[0.9,0.1],[0.1,0.9]].
      light = [[9.0, 1.0], [1.0, 9.0]]
      heavy = Enum.map(light, fn row -> Enum.map(row, &(&1 * 1000.0)) end)

      mean_a = light |> Math.transpose() |> Enum.map(&Math.normalise/1) |> Math.transpose()

      b = %{stay: [[1.0, 0.0], [0.0, 1.0]]}
      policies = [[:stay]]
      d = [0.5, 0.5]
      obs = [[1.0, 0.0]]

      sweep = fn ln_a ->
        fresh = DiscreteTime.fresh_beliefs(%{d: d, horizon: 1, b: b, policies: policies})

        DiscreteTime.sweep_state_beliefs(fresh, policies, b, mean_a, obs, d, 5, ln_a: ln_a)
        |> Map.fetch!(0)
        |> List.first()
      end

      post_mean = sweep.(nil)
      post_light = sweep.(Math.dirichlet_expected_log(light))
      post_heavy = sweep.(Math.dirichlet_expected_log(heavy))

      l1 = fn p, q -> Enum.zip(p, q) |> Enum.map(fn {x, y} -> abs(x - y) end) |> Enum.sum() end

      # Heavy evidence ⇒ E[ln A] → ln(mean A) ⇒ the swept posteriors coincide.
      assert l1.(post_heavy, post_mean) < l1.(post_light, post_mean)
      assert l1.(post_heavy, post_mean) < 1.0e-3
    end

    test "passing ln_a moves the VFE accuracy term (the learned A-path is wired into F)" do
      chain = [[0.6, 0.4]]
      a = [[0.9, 0.1], [0.1, 0.9]]
      counts = [[2.0, 1.0], [1.0, 2.0]]
      b = %{stay: [[1.0, 0.0], [0.0, 1.0]]}
      d = [0.5, 0.5]
      obs = [[1.0, 0.0]]

      f_mean = DiscreteTime.variational_free_energy(chain, [:stay], b, a, obs, d)

      f_learned =
        DiscreteTime.variational_free_energy(chain, [:stay], b, a, obs, d,
          ln_a: Math.dirichlet_expected_log(counts)
        )

      refute_in_delta(f_mean, f_learned, 1.0e-9)
      assert is_number(f_learned)
    end
  end

  # --- helpers ---------------------------------------------------------------

  defp goal_bundle(extra \\ %{}) do
    Map.merge(
      %{
        a: [[0.8, 0.2], [0.2, 0.8]],
        b: %{stay: [[1.0, 0.0], [0.0, 1.0]], go: [[0.0, 0.0], [1.0, 1.0]]},
        c: Math.log_eps(Math.softmax([0.0, 3.0])),
        d: [1.0, 0.0],
        e: nil,
        actions: [:stay, :go],
        policies: [[:stay, :stay], [:go, :go], [:stay, :go], [:go, :stay]],
        horizon: 2,
        action_selection: :argmax
      },
      extra
    )
  end

  defp stochastic_b_bundle do
    %{
      a: [[0.9, 0.1], [0.1, 0.9]],
      b: %{stay: [[0.9, 0.1], [0.1, 0.9]], go: [[0.2, 0.1], [0.8, 0.9]]},
      c: Math.log_eps(Math.softmax([0.0, 3.0])),
      d: [1.0, 0.0],
      e: nil,
      actions: [:stay, :go],
      policies: [[:stay, :stay], [:go, :go], [:stay, :go], [:go, :stay]],
      horizon: 2,
      action_selection: :argmax
    }
  end

  defp total_ambiguity(result) do
    result.efe_per_policy
    |> Enum.flat_map(& &1.ambiguity_per_tau)
    |> Enum.sum()
  end
end

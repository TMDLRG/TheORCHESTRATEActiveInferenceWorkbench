defmodule ActiveInferenceCore.MarkovBlanketTest do
  @moduledoc """
  W-5 — the Markov-blanket conditional-independence residual
  `max_b |p(μ,η|b) − p(μ|b)p(η|b)|`. Independence is *measured*, never assumed:
  a genuine blanket drives the residual to 0; a leaky one keeps it positive.
  """
  use ExUnit.Case, async: true

  alias ActiveInferenceCore.MarkovBlanket, as: MB

  describe "conditional_independence_residual/1" do
    test "a joint built from independent slices has residual 0 (a genuine blanket)" do
      joint = [
        MB.independent_slice(0.5, [0.8, 0.2], [0.3, 0.7]),
        MB.independent_slice(0.5, [0.5, 0.5], [0.9, 0.1])
      ]

      assert MB.conditional_independence_residual(joint) < 1.0e-12
      assert MB.conditionally_independent?(joint)
    end

    test "a joint where μ = η given b leaks — residual is large" do
      # Single blanket state, μ perfectly correlated with η.
      joint = [[[0.5, 0.0], [0.0, 0.5]]]

      # p(μ|b)=p(η|b)=[0.5,0.5] ⇒ product 0.25 on the diagonal vs 0.5 actual.
      assert_in_delta MB.conditional_independence_residual(joint), 0.25, 1.0e-12
      refute MB.conditionally_independent?(joint)
    end

    test "matches a hand-computed residual on a small joint" do
      # p_b = 1; p(μ|b)=[0.3,0.7], p(η|b)=[0.4,0.6]; each cell deviates by 0.02.
      joint = [[[0.1, 0.2], [0.3, 0.4]]]
      assert_in_delta MB.conditional_independence_residual(joint), 0.02, 1.0e-12
    end

    test "blanket states with no probability mass are skipped, not crashed" do
      joint = [
        [[0.0, 0.0], [0.0, 0.0]],
        MB.independent_slice(1.0, [0.6, 0.4], [0.2, 0.8])
      ]

      assert MB.conditional_independence_residual(joint) < 1.0e-12
    end

    test "the residual is the worst blanket state (max over b)" do
      joint = [
        MB.independent_slice(0.5, [0.5, 0.5], [0.5, 0.5]),
        [[0.25, 0.0], [0.0, 0.25]]
      ]

      assert_in_delta MB.conditional_independence_residual(joint), 0.25, 1.0e-12
    end

    test "empty joint is trivially independent" do
      assert MB.conditional_independence_residual([]) == 0.0
      assert MB.conditionally_independent?([])
    end
  end
end

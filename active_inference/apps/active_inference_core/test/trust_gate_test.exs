defmodule ActiveInferenceCore.TrustGateTest do
  @moduledoc """
  W-7 — the numerical trust gate.

  Five golden anchors over the discrete-POMDP path that the implementation must
  reproduce to machine precision before its EFE / policy code is relied upon
  (see `curriculum_app/content/lessons/weeks-08-12-build-gate.md`, "Validation
  gate (numerical trust): Tests 1, 2, 5, 8, 11").

  Per the governing decision the anchors are **derived from** Parr, Pezzulo &
  Friston (2022), *Active Inference*, Appendix B — cited, never reproduced — and
  each is independently cross-checked here against its canonical closed form so
  the constant is not merely the implementation echoed back:

    * Anchor 1 — softmax σ([0,1,2]) = [1, e, e²]/Σ.
    * Anchor 2 — one-step Bayesian state update, and F[q*] = −ln p(o) (the bound
      is tight at the exact posterior).
    * Anchor 5 — expected free energy = ambiguity + risk (nats).
    * Anchor 8 — policy posterior σ(ln E − F − G).
    * Anchor 11 — learned likelihood E[ln A] = ψ(α) − ψ(Σα) = [−1/3, −11/6].

  **Status: PROVISIONAL.** These anchors count as the official trust gate only
  after UNI blesses that they correspond to App. B Tests 1, 2, 5, 8, 11. That
  ratification is the one deliberately-skipped test below; the five anchor tests
  themselves run now as regression guards on the frozen values.
  """
  use ExUnit.Case, async: true

  alias ActiveInferenceCore.{DiscreteTime, Math}

  # — Frozen golden anchors (provisional; pending UNI bless) —
  @softmax_012 [0.09003057317038046, 0.24472847105479764, 0.6652409557748218]
  @bayes_posterior [0.8181818181818181, 0.1818181818181818]
  @surprise 0.5978370007556204
  @efe_total 1.2395762322100239
  @efe_ambiguity 0.3250829733914482
  @efe_risk 0.9144932588185757
  @policy_posterior [0.4289113098797968, 0.5710886901202031]
  @e_log_a [[-0.3333333333333333], [-1.8333333333333333]]

  @tol 1.0e-12

  test "Anchor 1 — softmax normalization σ([0,1,2])" do
    got = Math.softmax([0.0, 1.0, 2.0])
    assert_lists_close(got, @softmax_012, @tol)

    # Independent closed form: [1, e, e²] / (1 + e + e²).
    denom = 1.0 + :math.exp(1.0) + :math.exp(2.0)
    want = [1.0 / denom, :math.exp(1.0) / denom, :math.exp(2.0) / denom]
    assert_lists_close(got, want, @tol)
  end

  test "Anchor 2 — one-step Bayesian state update and the surprise bound" do
    a = [[0.9, 0.2], [0.1, 0.8]]
    d = [0.5, 0.5]
    o = [1.0, 0.0]

    post = DiscreteTime.update_state_beliefs(nil, d, nil, o, a, nil, nil, 1.0)
    assert_lists_close(post, @bayes_posterior, @tol)

    # Independent: with a uniform prior the posterior ∝ A[o, :] = [0.9, 0.2].
    assert_lists_close(post, Math.normalise([0.9, 0.2]), @tol)

    # The variational bound is tight at the exact posterior: F[q*] = −ln p(o).
    f =
      DiscreteTime.variational_free_energy(
        [post],
        [:stay],
        %{stay: [[1.0, 0.0], [0.0, 1.0]]},
        a,
        [o],
        d
      )

    assert_in_delta f, @surprise, 1.0e-9
    assert_in_delta @surprise, -:math.log(0.55), @tol
  end

  test "Anchor 5 — expected free energy decomposes into ambiguity + risk" do
    efe =
      DiscreteTime.expected_free_energy(
        [[0.3, 0.4, 0.3]],
        [[0.9, 0.9, 0.1], [0.1, 0.1, 0.9]],
        Math.log_eps([0.1, 0.9]),
        -1
      )

    assert_in_delta efe.total, @efe_total, @tol
    assert_in_delta hd(efe.ambiguity_per_tau), @efe_ambiguity, @tol
    assert_in_delta hd(efe.risk_per_tau), @efe_risk, @tol
    assert_in_delta efe.total, @efe_ambiguity + @efe_risk, @tol
  end

  test "Anchor 8 — policy posterior σ(ln E − F − G)" do
    f = [0.2, 0.5]
    g = [0.1, 0.9]
    e = [0.2, 0.8]

    got = DiscreteTime.policy_posterior(f, g, e)
    assert_lists_close(got, @policy_posterior, @tol)

    # Independent closed form: σ(ln E − F − G) at γ = 1, T = 1.
    want = Math.softmax(Math.sub(Math.sub(Math.log_eps(e), f), g))
    assert_lists_close(got, want, @tol)
  end

  test "Anchor 11 — learned likelihood E[ln A] = ψ(α) − ψ(Σα)" do
    got = Math.dirichlet_expected_log([[3.0], [1.0]])
    [[e0], [e1]] = got
    [[g0], [g1]] = @e_log_a
    assert_in_delta e0, g0, @tol
    assert_in_delta e1, g1, @tol

    # Independent closed form: ψ(3)−ψ(4) = −1/3 and ψ(1)−ψ(4) = −(1+½+⅓) = −11/6.
    assert_in_delta e0, -1.0 / 3.0, @tol
    assert_in_delta e1, -11.0 / 6.0, @tol
  end

  @tag skip:
         "PROVISIONAL — counts as the trust gate only after UNI blesses these as App. B Tests 1,2,5,8,11 (W-7)"
  test "the five anchors are ratified by UNI against App. B Tests 1,2,5,8,11" do
    flunk("awaiting UNI bless of the five derived trust-gate anchors")
  end

  defp assert_lists_close(a, b, eps) do
    assert length(a) == length(b)

    Enum.zip(a, b)
    |> Enum.each(fn {x, y} -> assert_in_delta(x, y, eps) end)
  end
end

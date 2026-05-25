defmodule ActiveInferenceCore.TrustGateTest do
  @moduledoc """
  W-7 — the numerical trust gate (UNI-RATIFIED 2026-05-25).

  Six golden anchors over the discrete-POMDP path that the implementation must
  reproduce before its EFE / policy code is relied upon (see
  `weeks-08-12-build-gate.md`).

  UNI ruling (2026-05-25): label these **POMDP-B.1 … POMDP-B.6** — NOT the Math
  Reference "Tests 1, 2, 5, 8, 11", whose numbering denotes specific other checks.
  UNI blessed five rows and **corrected** the EFE row (POMDP-B.4): for
  `A=[[.9,.1],[.1,.9]]`, `s=[.3,.7]` the predicted outcome is `A·s=[.34,.66]`, so
  `risk = D_KL([.34,.66] ‖ [.1,.9]) = 0.2113813941` and total `0.5364643675`.
  (The earlier value `0.914…` corresponded to `s=[.7,.3]`.)

  Each anchor is independently cross-checked against its closed form, so the
  frozen constant is not merely the implementation echoed back. Derived from
  Parr, Pezzulo & Friston (2022), Appendix B — cited, never reproduced.
  """
  use ExUnit.Case, async: true

  alias ActiveInferenceCore.{DiscreteTime, Math}

  # — Frozen golden anchors (UNI-ratified 2026-05-25 as POMDP-B.1 … B.6) —
  @softmax_012 [0.09003057317038046, 0.24472847105479764, 0.6652409557748218]
  @bayes_posterior [0.8181818181818181, 0.1818181818181818]
  @surprise 0.5978370007556204
  @efe_total 0.5364643675
  @efe_ambiguity 0.3250829734
  @efe_risk 0.2113813941
  @policy_posterior [0.4289113098797968, 0.5710886901202031]
  @e_log_a [[-0.3333333333333333], [-1.8333333333333333]]

  test "POMDP-B.1 — softmax normalization σ([0,1,2])" do
    got = Math.softmax([0.0, 1.0, 2.0])
    assert_lists_close(got, @softmax_012, 1.0e-12)

    # Independent closed form: [1, e, e²] / (1 + e + e²).
    denom = 1.0 + :math.exp(1.0) + :math.exp(2.0)

    assert_lists_close(
      got,
      [1.0 / denom, :math.exp(1.0) / denom, :math.exp(2.0) / denom],
      1.0e-12
    )
  end

  test "POMDP-B.2 — one-step Bayesian state update" do
    a = [[0.9, 0.2], [0.1, 0.8]]
    post = DiscreteTime.update_state_beliefs(nil, [0.5, 0.5], nil, [1.0, 0.0], a, nil, nil, 1.0)
    assert_lists_close(post, @bayes_posterior, 1.0e-12)
    # Independent: with a uniform prior the posterior ∝ A[o, :] = [0.9, 0.2].
    assert_lists_close(post, Math.normalise([0.9, 0.2]), 1.0e-12)
  end

  test "POMDP-B.3 — variational bound is tight at the exact posterior: F[q*] = −ln p(o)" do
    a = [[0.9, 0.2], [0.1, 0.8]]
    d = [0.5, 0.5]
    o = [1.0, 0.0]
    post = DiscreteTime.update_state_beliefs(nil, d, nil, o, a, nil, nil, 1.0)

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
    assert_in_delta @surprise, -:math.log(0.55), 1.0e-12
  end

  test "POMDP-B.4 — EFE = ambiguity + risk (UNI-corrected for s=[.3,.7])" do
    efe =
      DiscreteTime.expected_free_energy(
        [[0.3, 0.7]],
        [[0.9, 0.1], [0.1, 0.9]],
        Math.log_eps([0.1, 0.9]),
        -1
      )

    assert_in_delta efe.total, @efe_total, 1.0e-9
    assert_in_delta hd(efe.ambiguity_per_tau), @efe_ambiguity, 1.0e-9
    assert_in_delta hd(efe.risk_per_tau), @efe_risk, 1.0e-9
    assert_in_delta efe.total, @efe_ambiguity + @efe_risk, 1.0e-9
  end

  test "POMDP-B.5 — policy posterior σ(ln E − F − G)" do
    f = [0.2, 0.5]
    g = [0.1, 0.9]
    e = [0.2, 0.8]

    got = DiscreteTime.policy_posterior(f, g, e)
    assert_lists_close(got, @policy_posterior, 1.0e-12)
    # Independent closed form at γ = 1, T = 1.
    assert_lists_close(got, Math.softmax(Math.sub(Math.sub(Math.log_eps(e), f), g)), 1.0e-12)
  end

  test "POMDP-B.6 — learned likelihood E[ln A] = ψ(α) − ψ(Σα)" do
    [[e0], [e1]] = Math.dirichlet_expected_log([[3.0], [1.0]])
    [[g0], [g1]] = @e_log_a
    assert_in_delta e0, g0, 1.0e-12
    assert_in_delta e1, g1, 1.0e-12
    # Independent closed form: ψ(3)−ψ(4) = −1/3 ; ψ(1)−ψ(4) = −11/6.
    assert_in_delta e0, -1.0 / 3.0, 1.0e-12
    assert_in_delta e1, -11.0 / 6.0, 1.0e-12
  end

  defp assert_lists_close(a, b, eps) do
    assert length(a) == length(b)

    Enum.zip(a, b)
    |> Enum.each(fn {x, y} -> assert_in_delta(x, y, eps) end)
  end
end

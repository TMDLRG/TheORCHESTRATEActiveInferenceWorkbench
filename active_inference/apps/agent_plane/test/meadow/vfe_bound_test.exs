defmodule AgentPlane.Meadow.VFEBoundTest do
  @moduledoc """
  AUDIT ANCHOR: F[q] ≥ -ln p(y) for every recognition density q.

  Verifies the variational-free-energy upper-bound identity from the
  Maren TR-2019-01v6 audit (project CLAUDE.md adjudication anchor #1).

  Mechanism:
    * Build a tiny hand-rolled HMM bundle (2 hidden states, 2
      observation symbols, 2 actions) — small enough to enumerate every
      length-3 observation sequence by brute force.
    * For each (obs sequence, q candidate) pair, compute:
        - F[q] via `AgentPlane.ExactInference.free_energy/4`
        - -ln p(y) via the brute-force forward algorithm
          (`AgentPlane.ExactInference.log_evidence/4`)
    * Assert `F[q] >= -ln p(y) - tolerance` for every pair.

  Three q families are tested per sequence:
    1. The exact posterior (should achieve `F[q] = -ln p(y)`, the bound
       saturates).
    2. A uniform recognition density (slack > 0).
    3. A point-mass at a wrong state sequence (slack >> 0).

  All three must satisfy the inequality.
  """

  use ExUnit.Case, async: true

  alias ActiveInferenceCore.Math, as: M
  alias AgentPlane.ExactInference

  # Tiny HMM: 2 states, 2 observations, 2 actions.
  # A: P(o|s) — sharp likelihood (state 0 emits obs 0 mostly; state 1 emits obs 1 mostly)
  # B[:left] : 2x2 transition; B[:right] : 2x2 transition
  # D: prior
  defp tiny_bundle do
    %{
      a: [
        # rows are obs, cols are states
        # P(o=0|s=0) = 0.8, P(o=0|s=1) = 0.2
        [0.8, 0.2],
        # P(o=1|s=0) = 0.2, P(o=1|s=1) = 0.8
        [0.2, 0.8]
      ],
      b: %{
        # B[:stay] is identity
        :stay => [
          [1.0, 0.0],
          [0.0, 1.0]
        ],
        # B[:flip] swaps states with prob 0.7, stays with 0.3
        :flip => [
          [0.3, 0.7],
          [0.7, 0.3]
        ]
      },
      d: [0.5, 0.5]
    }
  end

  defp all_seqs(t), do: all_seqs([], t)
  defp all_seqs(acc, 0), do: [Enum.reverse(acc)]

  defp all_seqs(acc, n) do
    [0, 1]
    |> Enum.flat_map(fn o -> all_seqs([o | acc], n - 1) end)
  end

  defp one_hot(idx), do: M.one_hot(2, idx)

  defp seq_to_vecs(seq), do: Enum.map(seq, &one_hot/1)

  describe "F[q] >= -ln p(y) for every observation sequence (the bound)" do
    test "exact-posterior marginals satisfy the bound under stay-stay" do
      bundle = tiny_bundle()
      actions = [:stay, :stay]

      Enum.each(all_seqs(3), fn seq ->
        obs_vecs = seq_to_vecs(seq)
        log_p_y = ExactInference.log_evidence(bundle, obs_vecs, actions)
        post = ExactInference.posterior_exact(bundle, obs_vecs, actions)

        f_post = ExactInference.free_energy(bundle, post, obs_vecs, actions)

        assert f_post >= -log_p_y - 1.0e-6,
               "Bound violated by exact-posterior marginals on seq #{inspect(seq)}: " <>
                 "F = #{f_post}, -ln p(y) = #{-log_p_y}"
      end)
    end

    test "uniform q satisfies the bound" do
      bundle = tiny_bundle()
      actions = [:stay, :stay]
      uniform_q = List.duplicate([0.5, 0.5], 3)

      Enum.each(all_seqs(3), fn seq ->
        obs_vecs = seq_to_vecs(seq)
        log_p_y = ExactInference.log_evidence(bundle, obs_vecs, actions)
        f_unif = ExactInference.free_energy(bundle, uniform_q, obs_vecs, actions)

        assert f_unif >= -log_p_y - 1.0e-6,
               "Bound violated by uniform q on seq #{inspect(seq)}: " <>
                 "F = #{f_unif}, -ln p(y) = #{-log_p_y}"
      end)
    end

    test "point-mass q at a wrong state satisfies the bound (with very large slack)" do
      bundle = tiny_bundle()
      actions = [:stay, :stay]
      wrong_q = List.duplicate([1.0, 0.0], 3)

      Enum.each(all_seqs(3), fn seq ->
        obs_vecs = seq_to_vecs(seq)
        log_p_y = ExactInference.log_evidence(bundle, obs_vecs, actions)
        f_wrong = ExactInference.free_energy(bundle, wrong_q, obs_vecs, actions)

        assert f_wrong >= -log_p_y - 1.0e-6,
               "Bound violated by point-mass-wrong q on seq #{inspect(seq)}"
      end)
    end

    test "controlled (non-trivial) actions: bound still holds for every q" do
      bundle = tiny_bundle()
      actions = [:flip, :stay]
      uniform_q = List.duplicate([0.5, 0.5], 3)

      Enum.each(all_seqs(3), fn seq ->
        obs_vecs = seq_to_vecs(seq)
        log_p_y = ExactInference.log_evidence(bundle, obs_vecs, actions)
        post = ExactInference.posterior_exact(bundle, obs_vecs, actions)
        f_post = ExactInference.free_energy(bundle, post, obs_vecs, actions)
        f_unif = ExactInference.free_energy(bundle, uniform_q, obs_vecs, actions)

        assert f_post >= -log_p_y - 1.0e-6,
               "Bound violated by exact-marginal q under :flip/:stay on seq #{inspect(seq)}"

        assert f_unif >= -log_p_y - 1.0e-6,
               "Bound violated by uniform q under :flip/:stay on seq #{inspect(seq)}"
      end)
    end
  end

  describe "saturation requires product-form joint posterior (mean-field caveat)" do
    test "all-identical-observation sequences under identity dynamics saturate" do
      # When (a) dynamics are identity, (b) likelihood is sharp, AND
      # (c) the observation sequence is constant, the smoothed posterior
      # collapses to a point mass and the mean-field bound saturates.
      # This is the canonical degenerate case where mean-field marginals
      # ARE the joint posterior. Other (non-constant) sequences have
      # genuine cross-time correlations and the bound is strict.
      bundle = %{
        a: [[0.99, 0.01], [0.01, 0.99]],
        b: %{:stay => [[1.0, 0.0], [0.0, 1.0]]},
        d: [0.5, 0.5]
      }

      actions = [:stay, :stay]

      # Constant sequences only — these are the ones where the joint
      # posterior factorises (as a triple-point-mass on the same state).
      constant_seqs = [[0, 0, 0], [1, 1, 1]]

      Enum.each(constant_seqs, fn seq ->
        obs_vecs = seq_to_vecs(seq)
        log_p_y = ExactInference.log_evidence(bundle, obs_vecs, actions)
        post = ExactInference.posterior_exact(bundle, obs_vecs, actions)
        f_post = ExactInference.free_energy(bundle, post, obs_vecs, actions)

        assert f_post >= -log_p_y - 1.0e-6
        assert_in_delta f_post, -log_p_y, 0.05
      end)
    end
  end
end

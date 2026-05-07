defmodule AgentPlane.Meadow.ELBOBoundTest do
  @moduledoc """
  AUDIT ANCHOR: ELBO[q] ≤ ln p(y) for every recognition density q.

  Companion to `vfe_bound_test.exs`. Since `ELBO = -F`, the same tiny
  hand-rolled HMM bundle is exercised; this file asserts the
  *lower-bound* face of the same identity:

      ELBO[q]  ≤  ln p(y)

  with equality at the exact posterior. The two test files exist
  separately so a future code reader cannot mistake one identity for
  the other (corresponds to the audit's adjudication anchor:
  "VFE upper-bounds surprisal; ELBO lower-bounds log evidence" — keep
  them distinct in code as well as in prose).
  """

  use ExUnit.Case, async: true

  alias ActiveInferenceCore.Math, as: M
  alias AgentPlane.ExactInference

  defp tiny_bundle do
    %{
      a: [[0.8, 0.2], [0.2, 0.8]],
      b: %{
        :stay => [[1.0, 0.0], [0.0, 1.0]],
        :flip => [[0.3, 0.7], [0.7, 0.3]]
      },
      d: [0.5, 0.5]
    }
  end

  defp all_seqs(t), do: all_seqs([], t)
  defp all_seqs(acc, 0), do: [Enum.reverse(acc)]
  defp all_seqs(acc, n) do
    [0, 1] |> Enum.flat_map(fn o -> all_seqs([o | acc], n - 1) end)
  end

  defp seq_to_vecs(seq), do: Enum.map(seq, &M.one_hot(2, &1))

  describe "ELBO[q] <= ln p(y) for every observation sequence (the bound)" do
    test "exact-posterior marginals satisfy the bound under stay-stay" do
      bundle = tiny_bundle()
      actions = [:stay, :stay]

      Enum.each(all_seqs(3), fn seq ->
        obs_vecs = seq_to_vecs(seq)
        log_p_y = ExactInference.log_evidence(bundle, obs_vecs, actions)
        post = ExactInference.posterior_exact(bundle, obs_vecs, actions)
        elbo = ExactInference.elbo(bundle, post, obs_vecs, actions)

        assert elbo <= log_p_y + 1.0e-6,
               "Bound violated by exact-posterior marginals on seq #{inspect(seq)}: " <>
                 "ELBO = #{elbo}, ln p(y) = #{log_p_y}"
      end)
    end

    test "uniform q satisfies the bound" do
      bundle = tiny_bundle()
      actions = [:stay, :stay]
      uniform_q = List.duplicate([0.5, 0.5], 3)

      Enum.each(all_seqs(3), fn seq ->
        obs_vecs = seq_to_vecs(seq)
        log_p_y = ExactInference.log_evidence(bundle, obs_vecs, actions)
        elbo_unif = ExactInference.elbo(bundle, uniform_q, obs_vecs, actions)

        assert elbo_unif <= log_p_y + 1.0e-6,
               "Bound violated by uniform q on seq #{inspect(seq)}"
      end)
    end

    test "point-mass-wrong q satisfies the bound (with very large slack)" do
      bundle = tiny_bundle()
      actions = [:stay, :stay]
      wrong_q = List.duplicate([1.0, 0.0], 3)

      Enum.each(all_seqs(3), fn seq ->
        obs_vecs = seq_to_vecs(seq)
        log_p_y = ExactInference.log_evidence(bundle, obs_vecs, actions)
        elbo_wrong = ExactInference.elbo(bundle, wrong_q, obs_vecs, actions)

        assert elbo_wrong <= log_p_y + 1.0e-6,
               "Bound violated by point-mass-wrong q on seq #{inspect(seq)}"
      end)
    end

    test "controlled actions: bound still holds for every q" do
      bundle = tiny_bundle()
      actions = [:flip, :stay]
      uniform_q = List.duplicate([0.5, 0.5], 3)

      Enum.each(all_seqs(3), fn seq ->
        obs_vecs = seq_to_vecs(seq)
        log_p_y = ExactInference.log_evidence(bundle, obs_vecs, actions)
        post = ExactInference.posterior_exact(bundle, obs_vecs, actions)
        elbo_post = ExactInference.elbo(bundle, post, obs_vecs, actions)
        elbo_unif = ExactInference.elbo(bundle, uniform_q, obs_vecs, actions)

        assert elbo_post <= log_p_y + 1.0e-6
        assert elbo_unif <= log_p_y + 1.0e-6
      end)
    end
  end
end

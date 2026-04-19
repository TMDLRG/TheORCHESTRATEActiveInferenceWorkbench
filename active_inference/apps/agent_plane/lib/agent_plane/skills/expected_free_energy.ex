defmodule AgentPlane.Skills.ExpectedFreeEnergy do
  @moduledoc """
  EFE decomposition (eq 2.6 / 4.10):

      G(π) = epistemic(π) + pragmatic(π)

    * **Epistemic** — expected information gain about hidden states under
      the policy. A function of beliefs Q and likelihood A. Drives curiosity.
    * **Pragmatic** — KL divergence between expected observations and
      preferences C. Drives goal-directed behaviour.

  L2 uses this skill to isolate the epistemic term by weighting the
  pragmatic term to zero.
  """

  use Jido.Action,
    name: "expected_free_energy",
    description: "Expected Free Energy G(π) split into epistemic and pragmatic terms.",
    schema: [
      predicted_states: [type: {:list, :float}, required: true],
      a_matrix: [type: {:list, {:list, :float}}, required: true],
      preference_c: [type: {:list, :float}, required: true],
      epistemic_weight: [type: :float, default: 1.0],
      pragmatic_weight: [type: :float, default: 1.0]
    ]

  alias AgentPlane.Skills.{KLDivergence, ShannonEntropy}

  @impl true
  def run(
        %{
          predicted_states: q_s,
          a_matrix: a,
          preference_c: c,
          epistemic_weight: w_eps,
          pragmatic_weight: w_prag
        },
        _ctx
      ) do
    # Predicted observations: q(o) = A · q(s)
    q_o = matmul_vec(a, q_s)

    # Pragmatic: KL[q(o) || C]
    pragmatic = KLDivergence.compute(q_o, c)

    # Epistemic: H[q(o)] - E_q(s)[H[A|s]]
    h_qo = ShannonEntropy.compute(q_o)

    expected_h_a =
      q_s
      |> Enum.with_index()
      |> Enum.reduce(0.0, fn {q_i, i}, acc ->
        # Column i of A — the likelihood over obs given state i.
        col = Enum.map(a, fn row -> Enum.at(row, i, 0.0) end)
        acc + q_i * ShannonEntropy.compute(col)
      end)

    epistemic = h_qo - expected_h_a

    {:ok,
     %{
       epistemic: epistemic,
       pragmatic: pragmatic,
       g: w_eps * epistemic + w_prag * pragmatic
     }}
  end

  defp matmul_vec(matrix, vec) do
    Enum.map(matrix, fn row ->
      Enum.zip(row, vec) |> Enum.reduce(0.0, fn {r, v}, acc -> acc + r * v end)
    end)
  end
end

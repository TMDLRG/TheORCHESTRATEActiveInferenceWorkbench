defmodule AgentPlane.Skills.VariationalFreeEnergy do
  @moduledoc """
  Variational Free Energy (eq 2.5 / 4.11):

      F[Q] = -E_Q[ln P(y, x)] - H[Q]
           = Complexity − Accuracy
           = KL[Q||P] − ln P(y)

  Scalar minimised by perception. A convenience skill for diagnostics —
  the production `perceive` action computes it internally in one pass.
  """

  use Jido.Action,
    name: "variational_free_energy",
    description: "Variational free energy F[Q] of a variational posterior.",
    schema: [
      q: [type: {:list, :float}, required: true],
      log_p_xy: [type: {:list, :float}, required: true]
    ]

  alias AgentPlane.Skills.ShannonEntropy

  @impl true
  def run(%{q: q, log_p_xy: log_p_xy}, _ctx) do
    accuracy = Enum.zip(q, log_p_xy) |> Enum.reduce(0.0, fn {qi, lp}, acc -> acc + qi * lp end)
    entropy = ShannonEntropy.compute(q)
    f = -accuracy - entropy
    {:ok, %{f: f, accuracy: accuracy, entropy: entropy}}
  end
end

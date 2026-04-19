defmodule AgentPlane.Skills.KLDivergence do
  @moduledoc """
  KL[q || p] = Σ qᵢ (log qᵢ - log pᵢ). Nats.

  A foundational primitive behind VFE (eq 2.5) and EFE (eq 2.6).
  """

  use Jido.Action,
    name: "kl_divergence",
    description: "KL divergence KL[q || p] between two probability vectors (nats).",
    schema: [
      q: [type: {:list, :float}, required: true],
      p: [type: {:list, :float}, required: true]
    ]

  @eps 1.0e-16

  @impl true
  def run(%{q: q, p: p}, _ctx) do
    {:ok, %{kl: compute(q, p)}}
  end

  @spec compute([float()], [float()]) :: float()
  def compute(q, p) when length(q) == length(p) do
    Enum.zip(q, p)
    |> Enum.reduce(0.0, fn {qi, pi}, acc ->
      acc + qi * (:math.log(max(qi, @eps)) - :math.log(max(pi, @eps)))
    end)
  end
end

defmodule AgentPlane.Skills.ShannonEntropy do
  @moduledoc """
  H[p] = -Σ pᵢ log pᵢ. Log base e. Zero entries are clamped to 1e-16.

  Exposed as a `Jido.Action` so it can be composed into a workflow and
  traced through Glass like any other equation evaluation.
  """

  use Jido.Action,
    name: "shannon_entropy",
    description: "Shannon entropy H[p] of a probability vector (nats).",
    schema: [
      p: [type: {:list, :float}, required: true]
    ]

  @eps 1.0e-16

  @impl true
  def run(%{p: p}, _ctx) do
    value =
      p
      |> Enum.map(fn x -> x * :math.log(max(x, @eps)) end)
      |> Enum.sum()
      |> Kernel.*(-1.0)

    {:ok, %{entropy: value}}
  end

  @doc "Pure version for direct calls from other skills."
  @spec compute([float()]) :: float()
  def compute(p) do
    -Enum.sum(for x <- p, do: x * :math.log(max(x, @eps)))
  end
end

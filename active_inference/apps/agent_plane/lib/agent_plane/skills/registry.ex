defmodule AgentPlane.Skills.Registry do
  @moduledoc """
  Canonical list of native Active Inference skills, so the Builder's
  `skill` block picker can present them as choices and the
  `/guide/blocks` page can list them without hand-synchronising.
  """

  @skills [
    %{
      id: "ShannonEntropy",
      module: AgentPlane.Skills.ShannonEntropy,
      description: "H[p] — entropy of a probability vector."
    },
    %{
      id: "KLDivergence",
      module: AgentPlane.Skills.KLDivergence,
      description: "KL[q || p] — divergence between two distributions."
    },
    %{
      id: "Softmax",
      module: AgentPlane.Skills.Softmax,
      description: "σ(v) — numerically stable softmax."
    },
    %{
      id: "ExpectedFreeEnergy",
      module: AgentPlane.Skills.ExpectedFreeEnergy,
      description: "G(π) — Expected Free Energy, split into epistemic + pragmatic."
    },
    %{
      id: "VariationalFreeEnergy",
      module: AgentPlane.Skills.VariationalFreeEnergy,
      description: "F[Q] — Variational Free Energy, minimised by perception."
    }
  ]

  @spec all() :: [%{id: String.t(), module: module(), description: String.t()}]
  def all, do: @skills

  @spec ids() :: [String.t()]
  def ids, do: Enum.map(@skills, & &1.id)

  @spec fetch(String.t()) :: {:ok, module()} | :error
  def fetch(id) do
    case Enum.find(@skills, &(&1.id == id)) do
      %{module: mod} -> {:ok, mod}
      _ -> :error
    end
  end
end

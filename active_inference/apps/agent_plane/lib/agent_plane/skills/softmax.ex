defmodule AgentPlane.Skills.Softmax do
  @moduledoc """
  Numerically-stable softmax over a vector of log-potentials.

  σ(v)ᵢ = exp(vᵢ − max(v)) / Σⱼ exp(vⱼ − max(v))

  Backs the policy posterior (eq 4.14 / B.9) and is reusable in any
  block that needs to normalise log-odds.
  """

  use Jido.Action,
    name: "softmax",
    description: "Stable softmax over a vector of log-potentials.",
    schema: [
      logits: [type: {:list, :float}, required: true],
      temperature: [type: :float, default: 1.0]
    ]

  @impl true
  def run(%{logits: logits, temperature: temp}, _ctx) do
    {:ok, %{probabilities: compute(logits, temp)}}
  end

  @spec compute([float()], float()) :: [float()]
  def compute(logits, temperature \\ 1.0) do
    scaled = Enum.map(logits, &(&1 / max(temperature, 1.0e-6)))
    m = Enum.max(scaled)
    exps = Enum.map(scaled, fn x -> :math.exp(x - m) end)
    z = Enum.sum(exps)
    Enum.map(exps, &(&1 / z))
  end
end

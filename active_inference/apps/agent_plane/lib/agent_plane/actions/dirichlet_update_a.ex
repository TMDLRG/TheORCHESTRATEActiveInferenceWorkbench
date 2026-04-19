defmodule AgentPlane.Actions.DirichletUpdateA do
  @moduledoc """
  Lego-uplift Phase H — online Dirichlet update to the A matrix (eq 7.10).

  After each observation + perception step:

      α_A[o, s] ← α_A[o, s] + η · q(s) · 𝟙[o]

  where `α_A` are the Dirichlet pseudo-counts, `q(s)` the posterior
  over hidden states, `η` the learning rate, and `𝟙[o]` the one-hot of
  the just-observed channel index.

  The rebuilt A is then `A[o, s] = α_A[o, s] / Σ_o' α_A[o', s]` —
  column-stochastic, interpretable as Dirichlet means.
  """

  use Jido.Action,
    name: "dirichlet_update_a",
    description: "Online Dirichlet update to A (eq 7.10).",
    schema: [
      prior_concentration: [type: :float, default: 1.0],
      learning_rate: [type: :float, default: 1.0]
    ]

  alias AgentPlane.Telemetry.Context

  @impl true
  def run(%{prior_concentration: alpha0, learning_rate: eta}, context) do
    state = context.state
    bundle = state.bundle
    a = bundle.a
    obs = List.last(state.obs_history) || List.duplicate(0.0, length(a))
    q_s = Map.get(bundle, :marginal_state_belief, uniform(length(hd(a))))

    alpha_a =
      Context.with_agent_context(state, fn ->
        update_counts(Map.get(bundle, :dirichlet_a_counts), a, alpha0, obs, q_s, eta)
      end)

    new_a = renormalise_columns(alpha_a)

    {:ok,
     %{
       bundle: %{bundle | a: new_a} |> Map.put(:dirichlet_a_counts, alpha_a)
     }}
  end

  defp update_counts(nil, a, alpha0, obs, q_s, eta) do
    shape = {length(a), length(hd(a))}
    seed = for _ <- 1..elem(shape, 0), do: List.duplicate(alpha0, elem(shape, 1))
    apply_outer(seed, obs, q_s, eta)
  end

  defp update_counts(counts, _a, _alpha0, obs, q_s, eta), do: apply_outer(counts, obs, q_s, eta)

  defp apply_outer(counts, obs, q_s, eta) do
    counts
    |> Enum.with_index()
    |> Enum.map(fn {row, o_idx} ->
      o = Enum.at(obs, o_idx, 0.0)

      row
      |> Enum.with_index()
      |> Enum.map(fn {c, s_idx} ->
        c + eta * o * Enum.at(q_s, s_idx, 0.0)
      end)
    end)
  end

  defp renormalise_columns(alpha) do
    n_obs = length(alpha)
    n_states = length(hd(alpha))

    for o <- 0..(n_obs - 1) do
      for s <- 0..(n_states - 1) do
        col_sum = Enum.reduce(alpha, 0.0, fn row, acc -> acc + Enum.at(row, s, 0.0) end)
        Enum.at(Enum.at(alpha, o), s, 0.0) / max(col_sum, 1.0e-16)
      end
    end
  end

  defp uniform(n), do: List.duplicate(1.0 / max(n, 1), n)
end

defmodule AgentPlane.Actions.DirichletUpdateB do
  @moduledoc """
  Lego-uplift Phase H — online Dirichlet update to B per action (eq 7.10).

  After each action `a` taken with state belief transitioning from
  q(s_t) to q(s_{t+1}):

      α_B[a][s', s] ← α_B[a][s', s] + η · q(s_{t+1} = s') · q(s_t = s)

  The rebuilt B[a] is the column-stochastic normalisation of α_B[a].
  """

  use Jido.Action,
    name: "dirichlet_update_b",
    description: "Online per-action Dirichlet update to B (eq 7.10).",
    schema: [
      prior_concentration: [type: :float, default: 1.0],
      learning_rate: [type: :float, default: 1.0]
    ]

  alias AgentPlane.Telemetry.Context

  @impl true
  def run(%{prior_concentration: alpha0, learning_rate: eta}, context) do
    state = context.state
    bundle = state.bundle
    action = state[:last_action]
    q_prev = Map.get(bundle, :prev_marginal_state_belief, nil)
    q_now = Map.get(bundle, :marginal_state_belief, nil)

    cond do
      is_nil(action) or is_nil(q_prev) or is_nil(q_now) ->
        {:ok, %{bundle: bundle}}

      true ->
        counts_map = Map.get(bundle, :dirichlet_b_counts, %{})
        b_action = Map.get(bundle.b, action)

        alpha_b =
          Context.with_agent_context(state, fn ->
            update_counts(Map.get(counts_map, action), b_action, alpha0, q_prev, q_now, eta)
          end)

        new_b_action = renormalise_columns(alpha_b)
        new_b = Map.put(bundle.b, action, new_b_action)
        new_counts = Map.put(counts_map, action, alpha_b)

        {:ok,
         %{
           bundle:
             %{bundle | b: new_b}
             |> Map.put(:dirichlet_b_counts, new_counts)
             |> Map.put(:prev_marginal_state_belief, q_now)
         }}
    end
  end

  defp update_counts(nil, b, alpha0, q_prev, q_now, eta) do
    n = length(b)
    seed = for _ <- 1..n, do: List.duplicate(alpha0, n)
    apply_outer(seed, q_now, q_prev, eta)
  end

  defp update_counts(counts, _b, _alpha0, q_prev, q_now, eta) do
    apply_outer(counts, q_now, q_prev, eta)
  end

  defp apply_outer(counts, q_next, q_prev, eta) do
    counts
    |> Enum.with_index()
    |> Enum.map(fn {row, s_next} ->
      row
      |> Enum.with_index()
      |> Enum.map(fn {c, s_curr} ->
        c + eta * Enum.at(q_next, s_next, 0.0) * Enum.at(q_prev, s_curr, 0.0)
      end)
    end)
  end

  defp renormalise_columns(alpha) do
    n = length(alpha)

    for r <- 0..(n - 1) do
      for c <- 0..(n - 1) do
        col_sum = Enum.reduce(alpha, 0.0, fn row, acc -> acc + Enum.at(row, c, 0.0) end)
        Enum.at(Enum.at(alpha, r), c, 0.0) / max(col_sum, 1.0e-16)
      end
    end
  end
end

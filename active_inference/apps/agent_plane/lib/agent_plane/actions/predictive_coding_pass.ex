defmodule AgentPlane.Actions.PredictiveCodingPass do
  @moduledoc """
  Jido action: run one sweep of 2-level predictive coding over a single
  observation.  G3 (RUNTIME_GAPS.md) -- cookbook recipes that teach the
  Laplace Tower hierarchy use this as their Jido entry point.

  At each level, the belief x_l is a Gaussian with mean mu_l and precision
  pi_l.  Predictions flow top-down (level 2 predicts level 1's mean),
  errors flow bottom-up (precision-weighted residual), beliefs are updated
  by one gradient step on the local free energy.

  Scope is deliberately narrow -- two levels, scalar states, Gaussian
  messages.  This is the Parr/Pezzulo/Friston (2022) Chapter 5 "canonical
  predictive-coding microcircuit" reduced to pure code with no
  side-effects so the cookbook can script it.
  """

  use Jido.Action,
    name: "predictive_coding_pass",
    description:
      "Run one 2-level predictive-coding pass (Ch 5 / Fig 5.5) over a scalar observation.",
    schema: [
      observation: [type: :float, required: true],
      mu1: [type: :float, required: true, doc: "level-1 belief mean (prior)"],
      mu2: [type: :float, required: true, doc: "level-2 belief mean (prior)"],
      pi1: [type: :float, default: 1.0, doc: "level-1 precision"],
      pi2: [type: :float, default: 1.0, doc: "level-2 precision"],
      learning_rate: [type: :float, default: 0.1]
    ]

  alias AgentPlane.Skills.VariationalFreeEnergy

  @impl true
  def run(
        %{
          observation: y,
          mu1: mu1,
          mu2: mu2,
          pi1: pi1,
          pi2: pi2,
          learning_rate: lr
        },
        _ctx
      ) do
    # Level 1: observation error weighted by pi1.
    err_obs = y - mu1

    # Level 2 predicts level 1's mean.  Minimal topology: prediction is
    # just mu2 (identity link -- the cookbook recipes will show how to
    # layer a learned link on top).
    err_top_down = mu1 - mu2

    # Belief updates: one gradient step on local free energy.
    mu1_new = mu1 + lr * (pi1 * err_obs - pi2 * err_top_down)
    mu2_new = mu2 + lr * (pi2 * err_top_down)

    # Diagnostic: approximate free energy at each level for Glass traces.
    f1 = 0.5 * pi1 * err_obs * err_obs
    f2 = 0.5 * pi2 * err_top_down * err_top_down

    {:ok,
     %{
       mu1: mu1_new,
       mu2: mu2_new,
       err_obs: err_obs,
       err_top_down: err_top_down,
       f1: f1,
       f2: f2,
       f_total: f1 + f2
     }}
  end

  @doc """
  Convenience API used by unit tests and cookbook recipes:
  run `n` passes and return the trajectory of (mu1, mu2) pairs.
  """
  @spec sweep(float(), float(), float(), float(), float(), float(), pos_integer()) ::
          %{mus: [{float(), float()}], final_f: float()}
  def sweep(y, mu1, mu2, pi1 \\ 1.0, pi2 \\ 1.0, lr \\ 0.1, n \\ 20) do
    Enum.reduce(1..n, %{mu1: mu1, mu2: mu2, mus: [{mu1, mu2}], final_f: 0.0}, fn _, acc ->
      {:ok, r} =
        run(
          %{
            observation: y,
            mu1: acc.mu1,
            mu2: acc.mu2,
            pi1: pi1,
            pi2: pi2,
            learning_rate: lr
          },
          %{}
        )

      %{
        mu1: r.mu1,
        mu2: r.mu2,
        mus: acc.mus ++ [{r.mu1, r.mu2}],
        final_f: r.f_total
      }
    end)
  end

  @doc "Reference to the top-level VFE skill (same units, one-level reduction)."
  def vfe_reference, do: VariationalFreeEnergy
end

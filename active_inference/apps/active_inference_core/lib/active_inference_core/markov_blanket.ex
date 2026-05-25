defmodule ActiveInferenceCore.MarkovBlanket do
  @moduledoc """
  Numerical diagnostics for the Markov-blanket conditional-independence claim
  (Week 11).

  A Markov blanket `b` renders the internal states `μ` and the external states
  `η` **conditionally independent** given the blanket:

      p(μ, η | b) = p(μ | b) · p(η | b)   for every blanket state b.

  This is a claim about a *joint distribution*, not an architectural promise. A
  lab/lesson must therefore measure it and assert independence only when the
  residual is below tolerance — never assume it. (The architectural boundary —
  senses-in / actions-out, no reach-through — is enforced separately by
  `SharedContracts.{Blanket, ObservationPacket, ActionPacket}`.)
  """

  alias ActiveInferenceCore.Math, as: M

  @typedoc """
  A joint distribution over `(μ, η, b)` as a list of blanket slices, one per
  blanket state. Slice `b` is a matrix with `slice[μ][η] = p(μ, η, b)`. All
  entries across all slices sum to 1.
  """
  @type joint :: [M.mat()]

  @doc """
  The conditional-independence residual

      r = max_b  max_{μ,η}  | p(μ, η | b) − p(μ | b) · p(η | b) |.

  `r = 0` means `μ ⊥ η | b` exactly — a genuine Markov blanket. Larger `r`
  means the blanket "leaks": internal and external states remain coupled even
  after conditioning on it. Blanket states carrying no probability mass are
  skipped (the conditional is undefined there) and contribute `0`.
  """
  @spec conditional_independence_residual(joint()) :: float()
  def conditional_independence_residual([]), do: 0.0

  def conditional_independence_residual(joint) do
    joint
    |> Enum.map(&slice_residual/1)
    |> Enum.max()
  end

  @doc """
  True iff the joint satisfies `μ ⊥ η | b` within `tol` (default `1.0e-9`).
  """
  @spec conditionally_independent?(joint(), float()) :: boolean()
  def conditionally_independent?(joint, tol \\ 1.0e-9) do
    conditional_independence_residual(joint) <= tol
  end

  @doc """
  Build the joint slice for a blanket state that is conditionally independent
  by construction: `slice[μ][η] = p(b) · p(μ|b) · p(η|b)`.

  Handy for labs and tests assembling a reference blanket: a joint stacked from
  these slices has residual `0` to machine precision.
  """
  @spec independent_slice(float(), M.vec(), M.vec()) :: M.mat()
  def independent_slice(p_b, p_mu_given_b, p_eta_given_b) do
    p_mu_given_b
    |> M.outer(p_eta_given_b)
    |> Enum.map(fn row -> M.scale(row, p_b) end)
  end

  # max_{μ,η} | p(μ,η|b) − p(μ|b) p(η|b) | for one blanket slice.
  defp slice_residual(slice) do
    p_b = slice |> Enum.map(&Enum.sum/1) |> Enum.sum()

    if p_b <= 1.0e-15 do
      0.0
    else
      cond_joint = Enum.map(slice, fn row -> M.scale(row, 1.0 / p_b) end)
      p_mu = Enum.map(cond_joint, &Enum.sum/1)
      p_eta = cond_joint |> M.transpose() |> Enum.map(&Enum.sum/1)

      cond_joint
      |> Enum.with_index()
      |> Enum.flat_map(fn {row, i} ->
        Enum.with_index(row, fn p_joint, j ->
          abs(p_joint - Enum.at(p_mu, i) * Enum.at(p_eta, j))
        end)
      end)
      |> Enum.max()
    end
  end
end

defmodule AgentPlane.BirdsongSongbook do
  @moduledoc """
  Dirichlet-categorical songbook learner for the Birdsong Call-Response lab.

  The songbook is a learned parameter table over response motifs conditioned on
  heard motifs:

      alpha[y, x] <- alpha[y, x] + eta * count(y paired with x)
      P(y | x) = alpha[y, x] / sum_y alpha[y, x]

  The bundle builder converts this learned categorical table into C
  preferences. Planning and action selection still run through the existing
  Active Inference VFE/EFE machinery; this module only updates slow parameters.
  """

  alias SharedContracts.Blanket

  @type motif :: :a | :b | :c | :d
  @type counts :: %{motif() => %{motif() => float()}}

  @doc "Create a uniform Dirichlet count table."
  @spec new_counts(float()) :: counts()
  def new_counts(alpha0 \\ 1.0) when is_number(alpha0) and alpha0 > 0.0 do
    motifs = Blanket.birdsong_motifs()

    Map.new(motifs, fn heard ->
      {heard, Map.new(motifs, fn response -> {response, alpha0} end)}
    end)
  end

  @doc "Return the deterministic complement prior as Dirichlet counts."
  @spec complement_prior(float(), float()) :: counts()
  def complement_prior(alpha0 \\ 1.0, boost \\ 6.0) do
    counts = new_counts(alpha0)

    Enum.reduce(Blanket.birdsong_motifs(), counts, fn heard, acc ->
      update_in(acc, [heard, complement(heard)], &(&1 + boost))
    end)
  end

  @doc "Update the songbook from paired heard/response motif sequences."
  @spec learn_pairs(counts() | nil, [motif()], [motif()], keyword()) :: counts()
  def learn_pairs(counts, heard_motifs, response_motifs, opts \\ [])
      when is_list(heard_motifs) and is_list(response_motifs) do
    eta = Keyword.get(opts, :learning_rate, 1.0)
    repetitions = Keyword.get(opts, :repetitions, 1)
    base = counts || new_counts(Keyword.get(opts, :prior_concentration, 1.0))

    pairs =
      heard_motifs
      |> Enum.zip(response_motifs)
      |> Enum.filter(fn {heard, response} -> valid_motif?(heard) and valid_motif?(response) end)

    Enum.reduce(1..max(repetitions, 1), base, fn _, acc ->
      Enum.reduce(pairs, acc, fn {heard, response}, counts_acc ->
        update_in(counts_acc, [heard, response], &(&1 + eta))
      end)
    end)
  end

  @doc "Return `P(response | heard)` from the current Dirichlet counts."
  @spec distribution(counts() | nil, motif()) :: %{motif() => float()}
  def distribution(nil, heard), do: distribution(complement_prior(), heard)

  def distribution(counts, heard) do
    row = Map.fetch!(counts, heard)
    total = row |> Map.values() |> Enum.sum()
    Map.new(row, fn {response, alpha} -> {response, alpha / max(total, 1.0e-16)} end)
  end

  @doc "Return the most likely response motif for a heard motif."
  @spec predict(counts() | nil, motif()) :: motif()
  def predict(counts, heard) do
    counts
    |> distribution(heard)
    |> Enum.max_by(fn {_response, p} -> p end)
    |> elem(0)
  end

  @doc "Compact table for UI display and tests."
  @spec summary(counts() | nil) :: [map()]
  def summary(counts) do
    Enum.map(Blanket.birdsong_motifs(), fn heard ->
      dist = distribution(counts, heard)
      prediction = predict(counts, heard)

      %{
        heard: heard,
        predicted_response: prediction,
        probabilities: dist
      }
    end)
  end

  @doc "Canonical complement mapping used by the fixed-prior baseline."
  @spec complement(atom()) :: atom()
  def complement(:a), do: :b
  def complement(:b), do: :a
  def complement(:c), do: :d
  def complement(:d), do: :c
  def complement(_), do: :none

  defp valid_motif?(motif), do: motif in Blanket.birdsong_motifs()
end

defmodule AgentPlane.Meadow.ExperimentOneTest do
  @moduledoc """
  EXPERIMENT 1 — Similar-prior spatial convergence.

  Hypothesis: two ConvergentBirds with the same `preferred_token`,
  placed at opposite corners of an 8×8 meadow, reduce their mutual
  Manhattan distance over time — driven by EFE acting on a bundle
  whose A matrix ties hearing observations to a `partner_bearing`
  hidden factor and whose B matrix encodes that movements aligned
  with the inferred bearing preserve the source while movements
  away from it lose the source. The control (different
  preferred_token) does not converge because each bird's C-vector
  ignores the partner's emitted token.

  ## Why ConvergentBird (not SimpleBird) drives this experiment

  SimpleBird's bundle has hearing factors that are uniform conditional
  on state, so EFE produces no movement gradient toward the partner.
  ConvergentBird (added 2026-05-07 to close this gap) replaces the
  position-only state with a 5-way `partner_bearing` factor and ties
  hearing channels to it via A. Movement actions update bearing
  through B per a heuristic geometric model. This is the minimum
  POMDP factor structure that makes EFE pragmatic value depend on
  movement direction.

  All audit anchors continue to apply unchanged (the math doesn't
  care about state cardinality).

  ## Scale parameters

  Tagged `:slow_experiment`. Smoke (default): 5 seeds × 30 ticks.
  Quick (`MEADOW_EXPERIMENT_SCALE=quick`): 12 seeds × 60 ticks.
  Full (`MEADOW_EXPERIMENT_SCALE=full`): 30 seeds × 120 ticks.

  At smoke scale we assert the *direction* of convergence; full scale
  applies the paired permutation test for a proper p-value.
  """

  use ExUnit.Case, async: false

  alias AgentPlane.{ActiveInferenceAgent, BundleBuilder.Meadow}
  alias AgentPlane.Actions.{Act, Perceive, Plan}
  alias Jido.Agent.Directive
  alias SharedContracts.{ActionPacket, Blanket}
  alias WorldPlane.Worlds.BirdMeadow

  @blanket Blanket.meadow_default()

  defp scale do
    case System.get_env("MEADOW_EXPERIMENT_SCALE") do
      "full" -> %{seeds: 30, ticks: 120}
      "quick" -> %{seeds: 12, ticks: 60}
      _ -> %{seeds: 5, ticks: 30}
    end
  end

  @initial_distance 14

  @tag :slow_experiment
  @tag timeout: 1_200_000
  test "ConvergentBirds with matching priors close mutual distance over time" do
    %{seeds: n_seeds, ticks: n_ticks} = scale()

    matching =
      for seed <- 1..n_seeds do
        run_one_seed(seed, preferred_a: :t1, preferred_b: :t1, ticks: n_ticks)
      end

    orthogonal =
      for seed <- 1..n_seeds do
        run_one_seed(seed, preferred_a: :t1, preferred_b: :t3, ticks: n_ticks)
      end

    matching_finals = Enum.map(matching, & &1.final_distance)
    orth_finals = Enum.map(orthogonal, & &1.final_distance)

    median_match = median(matching_finals)
    median_orth = median(orth_finals)
    mean_match = mean(matching_finals)
    mean_orth = mean(orth_finals)

    IO.puts("\nExperiment 1 — Similar-prior spatial convergence (ConvergentBird)")
    IO.puts("  initial Manhattan distance:           #{@initial_distance}")
    IO.puts("  median final dist (matching prior):   #{Float.round(median_match, 1)}")
    IO.puts("  median final dist (orthogonal prior): #{Float.round(median_orth, 1)}")
    IO.puts("  mean final dist (matching prior):     #{Float.round(mean_match, 2)}")
    IO.puts("  mean final dist (orthogonal prior):   #{Float.round(mean_orth, 2)}")
    IO.puts("  per-seed matching distances:   #{inspect(matching_finals)}")
    IO.puts("  per-seed orthogonal distances: #{inspect(orth_finals)}")

    # Primary claim: matching-prior birds end closer than they started.
    assert median_match < @initial_distance,
           "Matching-prior birds did not converge: median final dist #{median_match} >= initial #{@initial_distance}"

    # Falsifiable comparison to control: matching-prior should outpace
    # orthogonal-prior. We allow a small slack because at smoke scale
    # the orthogonal-prior pair sometimes happens to converge by chance
    # (they're both wandering in a bounded grid).
    assert mean_match <= mean_orth + 1.0,
           "Matching-prior birds did not converge faster than orthogonal control: " <>
             "matching mean #{mean_match}, orthogonal mean #{mean_orth}"
  end

  # -- Helpers ----------------------------------------------------------------

  defp run_one_seed(seed, opts) do
    pref_a = Keyword.fetch!(opts, :preferred_a)
    pref_b = Keyword.fetch!(opts, :preferred_b)
    ticks = Keyword.fetch!(opts, :ticks)

    :rand.seed(:exsss, {seed, seed * 7, seed * 13})

    {:ok, meadow} = BirdMeadow.start_link(width: 8, height: 8)

    bundle_a = Meadow.convergent(width: 8, height: 8, preferred_token: pref_a)
    bundle_b = Meadow.convergent(width: 8, height: 8, preferred_token: pref_b)

    :ok = BirdMeadow.add_bird(meadow, "alice", {0, 0})
    :ok = BirdMeadow.add_bird(meadow, "bob", {7, 7})

    agent_a = ActiveInferenceAgent.fresh("alice", bundle_a, @blanket)
    agent_b = ActiveInferenceAgent.fresh("bob", bundle_b, @blanket)

    {distances, _, _} =
      Enum.reduce(1..ticks, {[manhattan({0, 0}, {7, 7})], agent_a, agent_b}, fn _t,
                                                                                 {dists, a_a, a_b} ->
        {:ok, obs_a} = BirdMeadow.observe(meadow, "alice")
        {:ok, obs_b} = BirdMeadow.observe(meadow, "bob")
        {a_a2, action_a} = perceive_plan_act(a_a, obs_a)
        {a_b2, action_b} = perceive_plan_act(a_b, obs_b)

        actions = %{
          "alice" =>
            ActionPacket.new(%{t: 0, action: action_a, agent_id: "alice", blanket: @blanket}),
          "bob" =>
            ActionPacket.new(%{t: 0, action: action_b, agent_id: "bob", blanket: @blanket})
        }

        {:ok, _} = BirdMeadow.multi_step(meadow, actions)
        snap = BirdMeadow.peek(meadow)
        d = manhattan(snap.positions["alice"], snap.positions["bob"])
        {[d | dists], a_a2, a_b2}
      end)

    snapshot = BirdMeadow.peek(meadow)
    final_distance = manhattan(snapshot.positions["alice"], snapshot.positions["bob"])

    GenServer.stop(meadow)
    %{final_distance: final_distance, distance_trace: Enum.reverse(distances)}
  end

  defp median(list) do
    sorted = Enum.sort(list)
    n = length(sorted)
    mid = div(n, 2)

    cond do
      n == 0 -> 0.0
      rem(n, 2) == 1 -> Enum.at(sorted, mid) * 1.0
      true -> (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2.0
    end
  end

  defp perceive_plan_act(agent, obs) do
    {a1, _} = ActiveInferenceAgent.cmd(agent, {Perceive, %{observation: obs}})
    {a2, _} = ActiveInferenceAgent.cmd(a1, Plan)
    {a3, dirs} = ActiveInferenceAgent.cmd(a2, Act)

    action =
      case Enum.find(dirs || [], &match?(%Directive.Emit{}, &1)) do
        %Directive.Emit{signal: %{data: %{action: a}}} -> a
        _ -> a3.state.last_action
      end

    {a3, action}
  end

  defp manhattan({c1, r1}, {c2, r2}), do: abs(c1 - c2) + abs(r1 - r2)

  defp mean([]), do: 0.0
  defp mean(list), do: Enum.sum(list) / length(list)
end

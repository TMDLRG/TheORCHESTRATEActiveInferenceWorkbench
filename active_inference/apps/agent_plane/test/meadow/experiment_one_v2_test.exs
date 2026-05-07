defmodule AgentPlane.Meadow.ExperimentOneV2Test do
  @moduledoc """
  EXPERIMENT 1 v2 — three-arm falsifiability isolation (audit anchor GW1, v1.3).

  ## Hypothesis structure

  External-review GW1 (Wolpert/Gershman, v2): the v1 matching/orthogonal
  control isolated the C-vector contribution but NOT the inference
  machinery's contribution. ConvergentBird's `partner_bearing` factor is
  a hand-built geometric prior — Wolpert's no-free-lunch escape made
  textual. We need a baseline that uses the **same bundle** but a
  **different planner** to isolate what Active Inference is actually
  contributing.

  ## The three arms

  All arms run on identical setup:
    - 8×8 meadow, ConvergentBird × 2, both `preferred_token = :t1`
    - Bird at corners {0,0} and {7,7}; initial Manhattan distance 14
    - K seeds × N ticks per seed
    - Each arm is run with the SAME seed across the three arms so the
      randomness is a controlled variable, not a free dimension

  | Arm | Action selection | Inference machinery | Hypothesis |
  |---|---|---|---|
  | 1: Active Inference | `Perceive → Plan → Act` (production) | Full VMP + EFE + softmax over policies | If much better than Arms 2/3, EFE contributes specifically |
  | 2: GreedyLoudest | `Perceive → GreedyLoudest → Act` | Pragmatic-value greedy on the same bundle | If similar to Arm 1, the bundle structure is doing the work |
  | 3: Random walk | uniform sample from action vocab | None | Floor — no inference, no prior structure exploited |

  ## Falsifiability decisions

  - **Arm 1 ≈ Arm 2 (within ~1 tile)**: the bundle's `partner_bearing`
    B-matrix structure is doing the geometric work. Active Inference is
    not contributing specific value over a one-step pragmatic greedy.
    This would be Wolpert's NFL escape made empirical, and a publishable
    finding *against* the EFE-machinery-as-special claim.
  - **Arm 1 substantially better than Arm 2**: the EFE machinery
    (epistemic value driving exploration, softmax-weighted policies)
    contributes beyond the prior. This would be empirical support for
    the active-inference-is-special claim on this task.
  - **Arms 1 and 2 both much better than Arm 3**: the bundle's prior
    structure is non-trivially effective regardless of planner. Confirms
    the prior IS doing real geometric work (not a degenerate prior).

  Either outcome is publishable. Honesty wins.

  ## Scale parameters

  Tagged `:slow_experiment`. Smoke (default): 5 seeds × 30 ticks × 3 arms.
  Full (`MEADOW_EXPERIMENT_SCALE=full`): 30 seeds × 100 ticks × 3 arms.
  """

  use ExUnit.Case, async: false

  alias AgentPlane.{ActiveInferenceAgent, BundleBuilder.Meadow}
  alias AgentPlane.Actions.{Act, GreedyLoudest, Perceive, Plan}
  alias Jido.Agent.Directive
  alias SharedContracts.{ActionPacket, Blanket}
  alias WorldPlane.Worlds.BirdMeadow

  @blanket Blanket.meadow_default()

  defp scale do
    case System.get_env("MEADOW_EXPERIMENT_SCALE") do
      "full" -> %{seeds: 30, ticks: 100}
      "quick" -> %{seeds: 12, ticks: 60}
      _ -> %{seeds: 5, ticks: 30}
    end
  end

  @tag :slow_experiment
  @tag timeout: 1_800_000
  test "three-arm comparison: Active Inference vs GreedyLoudest vs random walk" do
    %{seeds: n_seeds, ticks: n_ticks} = scale()

    arms = [:active_inference, :greedy_loudest, :random_walk]

    # Run all arms × seeds, collecting per-seed final distances.
    results =
      for arm <- arms, into: %{} do
        seeds_results =
          for seed <- 1..n_seeds do
            run_seed(arm, seed, ticks: n_ticks)
          end

        {arm, seeds_results}
      end

    # Compute summary stats per arm.
    summary =
      Enum.into(arms, %{}, fn arm ->
        finals = Enum.map(results[arm], & &1.final_distance)
        sing_rates = Enum.map(results[arm], & &1.sang_count) |> Enum.map(&(&1 / (n_ticks * 2)))

        {arm,
         %{
           median_final: median(finals),
           mean_final: mean(finals),
           min_final: Enum.min(finals),
           max_final: Enum.max(finals),
           sing_rate_mean: mean(sing_rates)
         }}
      end)

    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("EXPERIMENT 1 v2 — Three-arm falsifiability isolation (GW1)")
    IO.puts("Scale: #{n_seeds} seeds × #{n_ticks} ticks × 3 arms")
    IO.puts("Setup: ConvergentBird × 2, both prefer t1, opposite corners of 8×8")
    IO.puts("Initial Manhattan distance: 14")
    IO.puts(String.duplicate("=", 70))

    Enum.each(arms, fn arm ->
      s = summary[arm]
      IO.puts("\n  ARM: #{arm}")
      IO.puts("    median final distance:  #{Float.round(s.median_final, 2)}")
      IO.puts("    mean final distance:    #{Float.round(s.mean_final, 2)}")
      IO.puts("    min/max final distance: #{s.min_final} / #{s.max_final}")
      IO.puts("    mean sing rate:         #{Float.round(s.sing_rate_mean, 3)}")
    end)

    # Compare Arms 1 vs 2 vs 3.
    a1 = summary[:active_inference]
    a2 = summary[:greedy_loudest]
    a3 = summary[:random_walk]

    IO.puts("\n  COMPARISON:")

    IO.puts(
      "    Arm 1 (AI) vs Arm 2 (greedy):  median diff = #{Float.round(a1.median_final - a2.median_final, 2)}"
    )

    IO.puts(
      "    Arm 1 (AI) vs Arm 3 (random):  median diff = #{Float.round(a1.median_final - a3.median_final, 2)}"
    )

    IO.puts(
      "    Arm 2 (greedy) vs Arm 3 (random): median diff = #{Float.round(a2.median_final - a3.median_final, 2)}"
    )

    publishable_finding =
      cond do
        abs(a1.median_final - a2.median_final) < 1.5 and a1.median_final < a3.median_final - 1.5 ->
          "BUNDLE-PRIOR HYPOTHESIS: Arm 1 ≈ Arm 2 ≪ Arm 3. The partner_bearing prior structure is doing the geometric work; EFE machinery does not contribute specific value over greedy on this task. Wolpert NFL prediction confirmed."

        a1.median_final < a2.median_final - 1.5 ->
          "ACTIVE-INFERENCE-CONTRIBUTES HYPOTHESIS: Arm 1 < Arm 2 by >1.5 tiles. EFE machinery (epistemic value, softmax over policies) contributes beyond the prior structure. Active Inference is not equivalent to greedy on this task."

        a1.median_final > a3.median_final - 1.5 ->
          "PRIOR-INSUFFICIENT HYPOTHESIS: Arm 1 ≈ Arm 3. Neither machinery beats random — the prior structure may need re-tuning, or this scale is too small to distinguish."

        true ->
          "MIXED: see numbers above; arm differences are intermediate. May need full-scale run for statistical power."
      end

    IO.puts("\n  PUBLISHABLE FINDING:")
    IO.puts("    " <> publishable_finding)
    IO.puts(String.duplicate("=", 70))

    # Test assertions are deliberately weak — the experiment's purpose is
    # to surface the empirical relationship between arms, not to enforce
    # a specific outcome. The published finding is whatever the data says.
    Enum.each(arms, fn arm ->
      s = summary[arm]

      assert s.median_final >= 0,
             "Arm #{arm} median should be non-negative; got #{s.median_final}"

      assert s.median_final <= 14,
             "Arm #{arm} median should not exceed initial distance; got #{s.median_final}"
    end)

    # Random walk should not perform better than Active Inference on average
    # — if it does, something is fundamentally wrong with the bundle.
    assert a1.median_final <= a3.median_final + 2.0,
           "Active Inference performed worse than random walk by more than 2 tiles. " <>
             "AI: #{a1.median_final}, Random: #{a3.median_final}. Bundle structure may be broken."
  end

  # -- Per-arm runners --------------------------------------------------------

  defp run_seed(:active_inference, seed, opts) do
    run_with_planner(seed, opts, &perceive_plan_act_full/2)
  end

  defp run_seed(:greedy_loudest, seed, opts) do
    run_with_planner(seed, opts, &perceive_greedy_act/2)
  end

  defp run_seed(:random_walk, seed, opts) do
    run_random_walk(seed, opts)
  end

  defp run_with_planner(seed, opts, planner_fn) do
    ticks = Keyword.fetch!(opts, :ticks)
    :rand.seed(:exsss, {seed, seed * 7, seed * 13})

    {:ok, meadow} = BirdMeadow.start_link(width: 8, height: 8)
    bundle_a = Meadow.convergent(width: 8, height: 8, preferred_token: :t1)
    bundle_b = Meadow.convergent(width: 8, height: 8, preferred_token: :t1)

    :ok = BirdMeadow.add_bird(meadow, "alice", {0, 0})
    :ok = BirdMeadow.add_bird(meadow, "bob", {7, 7})

    agent_a = ActiveInferenceAgent.fresh("alice", bundle_a, @blanket)
    agent_b = ActiveInferenceAgent.fresh("bob", bundle_b, @blanket)

    {sang_count, _, _} =
      Enum.reduce(1..ticks, {0, agent_a, agent_b}, fn _t, {sangs, a_a, a_b} ->
        {:ok, obs_a} = BirdMeadow.observe(meadow, "alice")
        {:ok, obs_b} = BirdMeadow.observe(meadow, "bob")
        {a_a2, action_a} = planner_fn.(a_a, obs_a)
        {a_b2, action_b} = planner_fn.(a_b, obs_b)

        actions = %{
          "alice" =>
            ActionPacket.new(%{t: 0, action: action_a, agent_id: "alice", blanket: @blanket}),
          "bob" =>
            ActionPacket.new(%{t: 0, action: action_b, agent_id: "bob", blanket: @blanket})
        }

        {:ok, _} = BirdMeadow.multi_step(meadow, actions)
        sang_inc = (if sang?(action_a), do: 1, else: 0) + (if sang?(action_b), do: 1, else: 0)
        {sangs + sang_inc, a_a2, a_b2}
      end)

    snapshot = BirdMeadow.peek(meadow)
    final_distance = manhattan(snapshot.positions["alice"], snapshot.positions["bob"])
    GenServer.stop(meadow)

    %{sang_count: sang_count, final_distance: final_distance}
  end

  defp run_random_walk(seed, opts) do
    ticks = Keyword.fetch!(opts, :ticks)
    :rand.seed(:exsss, {seed, seed * 7, seed * 13})

    {:ok, meadow} = BirdMeadow.start_link(width: 8, height: 8)

    :ok = BirdMeadow.add_bird(meadow, "alice", {0, 0})
    :ok = BirdMeadow.add_bird(meadow, "bob", {7, 7})

    actions_vocab = Meadow.meadow_actions()

    sang_count =
      Enum.reduce(1..ticks, 0, fn _t, sangs ->
        action_a = Enum.random(actions_vocab)
        action_b = Enum.random(actions_vocab)

        actions = %{
          "alice" =>
            ActionPacket.new(%{t: 0, action: action_a, agent_id: "alice", blanket: @blanket}),
          "bob" =>
            ActionPacket.new(%{t: 0, action: action_b, agent_id: "bob", blanket: @blanket})
        }

        {:ok, _} = BirdMeadow.multi_step(meadow, actions)
        sangs + (if sang?(action_a), do: 1, else: 0) + (if sang?(action_b), do: 1, else: 0)
      end)

    snapshot = BirdMeadow.peek(meadow)
    final_distance = manhattan(snapshot.positions["alice"], snapshot.positions["bob"])
    GenServer.stop(meadow)

    %{sang_count: sang_count, final_distance: final_distance}
  end

  # -- Per-tick planners ------------------------------------------------------

  defp perceive_plan_act_full(agent, obs) do
    {a1, _} = ActiveInferenceAgent.cmd(agent, {Perceive, %{observation: obs}})
    {a2, _} = ActiveInferenceAgent.cmd(a1, Plan)
    {a3, dirs} = ActiveInferenceAgent.cmd(a2, Act)
    extract_action(a3, dirs)
  end

  defp perceive_greedy_act(agent, obs) do
    {a1, _} = ActiveInferenceAgent.cmd(agent, {Perceive, %{observation: obs}})
    {a2, _} = ActiveInferenceAgent.cmd(a1, GreedyLoudest)
    {a3, dirs} = ActiveInferenceAgent.cmd(a2, Act)
    extract_action(a3, dirs)
  end

  defp extract_action(agent, dirs) do
    action =
      case Enum.find(dirs || [], &match?(%Directive.Emit{}, &1)) do
        %Directive.Emit{signal: %{data: %{action: a}}} -> a
        _ -> agent.state.last_action
      end

    {agent, action}
  end

  # -- Helpers ---------------------------------------------------------------

  defp sang?(action) when is_atom(action) do
    String.starts_with?(Atom.to_string(action), "sing_")
  end

  defp manhattan({c1, r1}, {c2, r2}), do: abs(c1 - c2) + abs(r1 - r2)

  defp mean([]), do: 0.0
  defp mean(list), do: Enum.sum(list) / length(list)

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
end

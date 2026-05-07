defmodule WorkbenchWeb.MVPMazeStatisticalTest do
  @moduledoc """
  AUDIT REGRESSION (external review K4, v1+v2): the MVP maze test was
  passing only under hand-tuned `:argmax` + `softmax_temperature: 1.0`.
  The reviewer's "what would satisfy" was *"a test that runs 100
  episodes with the production defaults and asserts ≥95% success on
  tiny_open_goal. If that fails, the production defaults are wrong."*

  Production defaults (from `ActiveInferenceCore.DiscreteTime.choose_action/4`):
    - `action_selection: :sample` (sample from policy posterior)
    - `softmax_temperature: 2.0` (smooth posterior; noisier sampling)

  This test runs 100 episodes on `tiny_open_goal` (3×3 with a single
  open corridor) under those defaults and asserts at least 95 succeed
  within `max_steps`. The bar is set so the production defaults are
  PROVEN viable on the simplest solvable maze.

  Tagged `:slow_experiment` because 100 episodes × ~5 ticks averages
  ~30 seconds wall-clock.
  """

  use ExUnit.Case, async: false

  alias AgentPlane.BundleBuilder
  alias SharedContracts.Blanket
  alias WorkbenchWeb.Episode
  alias WorldPlane.Worlds

  @tag :slow_experiment
  @tag timeout: 300_000
  test "100 episodes with production defaults: ≥95% success on tiny_open_goal" do
    world = Worlds.tiny_open_goal()
    blanket = Blanket.maze_default()

    walls =
      world.grid
      |> Enum.filter(fn {_, t} -> t == :wall end)
      |> Enum.map(fn {{c, r}, _} -> r * world.width + c end)

    start_idx = elem(world.start, 1) * world.width + elem(world.start, 0)
    goal_idx = elem(world.goal, 1) * world.width + elem(world.goal, 0)

    n_episodes = 100
    max_steps_per_episode = 20

    successes =
      for episode <- 1..n_episodes, reduce: 0 do
        acc ->
          # Fresh seed per episode so the empirical success rate is
          # measured under the noise-floor production defaults.
          :rand.seed(:exsss, {episode, episode * 7, episode * 13})

          # Production defaults: NO action_selection or softmax_temperature
          # overrides. DiscreteTime.choose_action falls back to :sample
          # and temperature=2.0.
          bundle =
            BundleBuilder.for_maze(
              width: world.width,
              height: world.height,
              start_idx: start_idx,
              goal_idx: goal_idx,
              walls: walls,
              blanket: blanket,
              horizon: 3,
              policy_depth: 3
            )

          {:ok, pid} =
            Episode.start_link(
              session_id: "k4-stat-#{episode}",
              maze: world,
              blanket: blanket,
              bundle: bundle,
              agent_id: "k4-agent-#{episode}",
              max_steps: max_steps_per_episode,
              goal_idx: goal_idx
            )

          final = run_until_done(pid, max_steps_per_episode)

          inc = if Map.get(final, :goal_reached?, false), do: 1, else: 0
          acc + inc
      end

    success_rate = successes / n_episodes * 100

    IO.puts(
      "\nK4 statistical regime: #{successes}/#{n_episodes} successful " <>
        "(#{Float.round(success_rate, 1)}%) on tiny_open_goal under production defaults."
    )

    assert successes >= 95,
           "Production defaults failed K4: only #{successes}/100 succeeded. " <>
             "Threshold is 95. The production defaults (:sample, softmax=2.0) " <>
             "may need tuning, or `tiny_open_goal` is no longer solvable under noise."
  end

  defp run_until_done(pid, remaining) when remaining > 0 do
    case Episode.step(pid) do
      {:ok, _entry} -> run_until_done(pid, remaining - 1)
      {:done, summary} -> summary
      {:error, _} -> safely_inspect(pid)
    end
  end

  defp run_until_done(pid, _), do: safely_inspect(pid)

  defp safely_inspect(pid) do
    try do
      Episode.inspect_state(pid)
    catch
      :exit, _ -> %{goal_reached?: false}
    end
  end
end

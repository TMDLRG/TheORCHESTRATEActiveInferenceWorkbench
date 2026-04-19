defmodule WorkbenchWeb.MVPGoldenTest do
  @moduledoc """
  Plan §12 Phase 0 — golden replay of `tiny_open_goal`.

  Locks in the deterministic action sequence produced by the unchanged
  POMDP math + bundle + blanket pipeline. If this test fails during the
  uplift, that means an edit changed the math/bundle/encoding — which may
  be intentional (update the fixture) or a regression (investigate before
  accepting).

  Fixture baseline captured 2026-04-17 from
    apps/active_inference_core/lib/active_inference_core/discrete_time.ex
  with horizon=3, policy_depth=3.

  The default action-selection mode is `:sample` (stochastic) as of the
  Lego-uplift stuck-agent fix; this golden test pins `:argmax` in the
  bundle so the sequence stays deterministic for regression detection.
  """

  use ExUnit.Case, async: true

  alias AgentPlane.BundleBuilder
  alias SharedContracts.Blanket
  alias WorkbenchWeb.Episode
  alias WorldPlane.Worlds

  # With the temporal-integration fix (Plan seeds bundle.d from the
  # previous step's marginal belief), the agent localises correctly
  # and solves tiny_open_goal in the optimal two east moves.
  @golden_actions [:move_east, :move_east]
  @golden_steps 2
  @golden_final_pos {2, 1}

  test "tiny_open_goal replay matches golden fixture" do
    summary = run_episode("t-golden-fixture", "agent-golden-fixture")

    actions = Enum.map(summary.history, & &1.action)

    assert actions == @golden_actions,
           "action sequence drifted from golden. got: #{inspect(actions)}"

    assert summary.steps == @golden_steps
    assert summary.goal_reached? == true
    assert summary.world.pos == @golden_final_pos
  end

  defp run_episode(session_id, agent_id) do
    world = Worlds.tiny_open_goal()
    blanket = Blanket.maze_default()

    walls =
      world.grid
      |> Enum.filter(fn {_, t} -> t == :wall end)
      |> Enum.map(fn {{c, r}, _} -> r * world.width + c end)

    start_idx = elem(world.start, 1) * world.width + elem(world.start, 0)
    goal_idx = elem(world.goal, 1) * world.width + elem(world.goal, 0)

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
      |> Map.put(:action_selection, :argmax)

    {:ok, pid} =
      Episode.start_link(
        session_id: session_id,
        maze: world,
        blanket: blanket,
        bundle: bundle,
        agent_id: agent_id,
        max_steps: 8,
        goal_idx: goal_idx
      )

    loop(pid)
  end

  defp loop(pid) do
    case Episode.step(pid) do
      {:ok, _entry} -> loop(pid)
      {:done, summary} -> summary
      {:error, _} -> Episode.inspect_state(pid)
    end
  end
end

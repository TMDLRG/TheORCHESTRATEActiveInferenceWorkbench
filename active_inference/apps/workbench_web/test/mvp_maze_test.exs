defmodule WorkbenchWeb.MVPMazeTest do
  @moduledoc """
  T5 — MVP behaviour.

  End-to-end: create an Active Inference JIDO agent, hand it observations
  from a real `WorldPlane.Engine`, and verify that it reaches the goal on
  a solvable maze within a reasonable number of steps.
  """

  use ExUnit.Case

  alias AgentPlane.BundleBuilder
  alias SharedContracts.Blanket
  alias WorkbenchWeb.Episode
  alias WorldPlane.Worlds

  test "agent reaches the goal on tiny_open_goal" do
    world = Worlds.tiny_open_goal()
    blanket = Blanket.maze_default()

    walls =
      world.grid
      |> Enum.filter(fn {_, t} -> t == :wall end)
      |> Enum.map(fn {{c, r}, _} -> r * world.width + c end)

    start_idx = elem(world.start, 1) * world.width + elem(world.start, 0)
    goal_idx = elem(world.goal, 1) * world.width + elem(world.goal, 0)

    # Pin argmax + softmax_temperature=1.0 so the tiny-maze end-to-end
    # test stays deterministic. The default :sample action-selection
    # adds noise that can waste early steps on 3×3, exceeding the
    # max_steps budget for a test that's asserting *existence* of a
    # solve path, not stochastic convergence time.
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
      |> Map.put(:softmax_temperature, 1.0)

    {:ok, pid} =
      Episode.start_link(
        session_id: "t-tiny",
        maze: world,
        blanket: blanket,
        bundle: bundle,
        agent_id: "agent-tiny",
        max_steps: 8,
        goal_idx: goal_idx
      )

    final = run_until_done(pid, 8)

    assert final.goal_reached?,
           "agent failed to reach goal. History: #{inspect(Enum.map(final.history, & &1.action))}"
  after
    :ok
  end

  defp run_until_done(pid, remaining) when remaining > 0 do
    case Episode.step(pid) do
      {:ok, _entry} -> run_until_done(pid, remaining - 1)
      {:done, summary} -> summary
      {:error, _} -> Episode.inspect_state(pid)
    end
  end

  defp run_until_done(pid, _), do: Episode.inspect_state(pid)
end

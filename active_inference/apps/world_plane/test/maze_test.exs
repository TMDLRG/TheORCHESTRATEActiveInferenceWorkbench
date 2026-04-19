defmodule WorldPlane.MazeTest do
  use ExUnit.Case, async: true

  alias WorldPlane.{Maze, Worlds}

  describe "prebuilt worlds" do
    test "every prebuilt world is solvable (BFS finds a path from start to goal)" do
      Enum.each(Worlds.all(), fn world ->
        assert reachable?(world), "world #{inspect(world.id)} is not solvable"
      end)
    end

    test "at least four mazes are provided" do
      assert length(Worlds.all()) >= 4
    end
  end

  describe "step/3" do
    test "walls block motion" do
      maze = Worlds.tiny_open_goal()
      # Tile {0,0} is wall, so from {0,1} moving north must stay.
      assert Maze.step(maze, {0, 1}, :move_north) == {0, 1}
    end

    test "cardinal moves work in open space" do
      maze = Worlds.tiny_open_goal()
      assert Maze.step(maze, {0, 1}, :move_east) == {1, 1}
    end
  end

  defp reachable?(world) do
    start = world.start
    goal = world.goal
    bfs(MapSet.new([start]), [start], world, goal)
  end

  defp bfs(_seen, [], _world, _goal), do: false

  defp bfs(seen, frontier, world, goal) do
    if goal in frontier do
      true
    else
      next =
        frontier
        |> Enum.flat_map(fn pos ->
          [:move_north, :move_south, :move_east, :move_west]
          |> Enum.map(&Maze.step(world, pos, &1))
        end)
        |> Enum.reject(&MapSet.member?(seen, &1))
        |> Enum.uniq()

      new_seen = Enum.reduce(next, seen, &MapSet.put(&2, &1))
      bfs(new_seen, next, world, goal)
    end
  end
end

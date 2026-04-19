defmodule WorldPlane.EngineTest do
  use ExUnit.Case

  alias SharedContracts.{ActionPacket, Blanket}
  alias WorldPlane.{Engine, Worlds}

  setup do
    maze = Worlds.tiny_open_goal()
    blanket = Blanket.maze_default()
    {:ok, pid} = Engine.start_link(maze: maze, blanket: blanket)
    on_exit(fn -> if Process.alive?(pid), do: Engine.stop(pid) end)
    {:ok, pid: pid, maze: maze, blanket: blanket}
  end

  test "current_observation returns a blanket-valid packet", %{pid: pid, blanket: blanket} do
    packet = Engine.current_observation(pid)
    channels = Map.keys(packet.channels) |> MapSet.new()
    allowed = MapSet.new(blanket.observation_channels)
    assert MapSet.subset?(channels, allowed)
  end

  test "apply_action with an east move advances the agent to the goal", %{
    pid: pid,
    blanket: blanket
  } do
    packet = ActionPacket.new(%{t: 0, action: :move_east, agent_id: "a", blanket: blanket})
    {:ok, _} = Engine.apply_action(pid, packet)

    {:ok, next} =
      Engine.apply_action(
        pid,
        ActionPacket.new(%{t: 1, action: :move_east, agent_id: "a", blanket: blanket})
      )

    assert next.terminal?
  end
end

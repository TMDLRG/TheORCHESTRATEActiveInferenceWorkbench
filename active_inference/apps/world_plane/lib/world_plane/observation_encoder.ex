defmodule WorldPlane.ObservationEncoder do
  @moduledoc """
  Converts world state into a blanket-compliant `SharedContracts.ObservationPacket`.

  The encoder is the *only* module allowed to project world state into the
  observation packet. It reads from `WorldPlane.Maze` and the current run
  state, and writes only channels allowed by the blanket.
  """

  alias SharedContracts.{Blanket, ObservationPacket}
  alias WorldPlane.Maze

  @spec encode(map(), Blanket.t()) :: ObservationPacket.t()
  def encode(
        %{maze: maze, pos: pos, t: t, run_id: run_id, terminal?: terminal?} = state,
        %Blanket{} = blanket
      ) do
    blocked? = Map.get(state, :last_action_blocked?, false)

    channels =
      Enum.reduce(blanket.observation_channels, %{}, fn ch, acc ->
        Map.put(acc, ch, channel_value(ch, maze, pos, blocked?))
      end)

    ObservationPacket.new(%{
      t: t,
      channels: channels,
      world_run_id: run_id,
      terminal?: terminal?,
      blanket: blanket
    })
  end

  defp channel_value(:wall_north, maze, pos, _blocked?), do: Maze.wall?(maze, pos, :north)
  defp channel_value(:wall_south, maze, pos, _blocked?), do: Maze.wall?(maze, pos, :south)
  defp channel_value(:wall_east, maze, pos, _blocked?), do: Maze.wall?(maze, pos, :east)
  defp channel_value(:wall_west, maze, pos, _blocked?), do: Maze.wall?(maze, pos, :west)
  defp channel_value(:goal_cue, maze, pos, _blocked?), do: Maze.goal_bearing(maze, pos)
  defp channel_value(:tile, maze, pos, _blocked?), do: Maze.tile_at(maze, pos)
  defp channel_value(:wall_hit, _maze, _pos, blocked?), do: if(blocked?, do: :hit, else: :clear)

  defp channel_value(other, _maze, _pos, _blocked?) do
    raise ArgumentError, "unknown observation channel: #{inspect(other)}"
  end
end

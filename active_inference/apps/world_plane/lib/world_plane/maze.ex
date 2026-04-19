defmodule WorldPlane.Maze do
  @moduledoc """
  Maze data structure and pure update functions.

  A maze is a 2-D grid of tiles where each tile is one of:

      :empty | :wall | :start | :goal

  Coordinates are `{col, row}` with `{0, 0}` at the top-left.
  """

  @enforce_keys [:id, :name, :width, :height, :grid, :start, :goal, :description]
  defstruct [:id, :name, :width, :height, :grid, :start, :goal, :description]

  @type tile :: :empty | :wall | :start | :goal
  @type coord :: {non_neg_integer(), non_neg_integer()}
  @type action :: :move_north | :move_south | :move_east | :move_west

  @type t :: %__MODULE__{
          id: atom(),
          name: String.t(),
          width: pos_integer(),
          height: pos_integer(),
          grid: %{coord() => tile()},
          start: coord(),
          goal: coord(),
          description: String.t()
        }

  @doc "Build a maze from a list of strings. `#` = wall, `S` = start, `G` = goal, `.` = empty."
  @spec from_rows(atom(), String.t(), [String.t()], String.t()) :: t()
  def from_rows(id, name, rows, description) when is_list(rows) do
    height = length(rows)
    width = rows |> List.first() |> String.length()

    {grid, start, goal} =
      for {row, r} <- Enum.with_index(rows),
          {char, c} <- Enum.with_index(String.graphemes(row)),
          reduce: {%{}, nil, nil} do
        {grid, s, g} ->
          tile =
            case char do
              "#" -> :wall
              "S" -> :start
              "G" -> :goal
              "." -> :empty
              " " -> :empty
              _ -> :empty
            end

          s = if tile == :start, do: {c, r}, else: s
          g = if tile == :goal, do: {c, r}, else: g
          {Map.put(grid, {c, r}, tile), s, g}
      end

    unless start, do: raise(ArgumentError, "Maze #{inspect(id)} has no `S` start tile.")
    unless goal, do: raise(ArgumentError, "Maze #{inspect(id)} has no `G` goal tile.")

    %__MODULE__{
      id: id,
      name: name,
      width: width,
      height: height,
      grid: grid,
      start: start,
      goal: goal,
      description: description
    }
  end

  @doc "Look up the tile at a coordinate. Coordinates out of bounds are walls."
  @spec tile_at(t(), coord()) :: tile()
  def tile_at(%__MODULE__{grid: g, width: w, height: h}, {c, r}) do
    cond do
      c < 0 or r < 0 or c >= w or r >= h -> :wall
      true -> Map.get(g, {c, r}, :empty)
    end
  end

  @doc "Apply a cardinal action to a coordinate. Walls and bounds block motion."
  @spec step(t(), coord(), action()) :: coord()
  def step(%__MODULE__{} = maze, {c, r}, action) do
    {dc, dr} =
      case action do
        :move_north -> {0, -1}
        :move_south -> {0, 1}
        :move_east -> {1, 0}
        :move_west -> {-1, 0}
        _ -> {0, 0}
      end

    candidate = {c + dc, r + dr}

    case tile_at(maze, candidate) do
      :wall -> {c, r}
      _ -> candidate
    end
  end

  @doc "Return `true` iff the given coord is the goal."
  @spec goal?(t(), coord()) :: boolean()
  def goal?(%__MODULE__{goal: g}, coord), do: coord == g

  @doc "Coarse goal-bearing from a coordinate. Returns an atom in the cue vocabulary."
  @spec goal_bearing(t(), coord()) :: atom()
  def goal_bearing(%__MODULE__{goal: {gc, gr}}, {c, r}) do
    cond do
      {gc, gr} == {c, r} -> :here
      gr < r -> :north
      gr > r -> :south
      gc > c -> :east
      gc < c -> :west
      true -> :unknown
    end
  end

  @doc "Wall indicator for one side."
  @spec wall?(t(), coord(), :north | :south | :east | :west) :: :wall | :open
  def wall?(%__MODULE__{} = maze, {c, r}, dir) do
    neighbour =
      case dir do
        :north -> {c, r - 1}
        :south -> {c, r + 1}
        :east -> {c + 1, r}
        :west -> {c - 1, r}
      end

    case tile_at(maze, neighbour) do
      :wall -> :wall
      _ -> :open
    end
  end
end

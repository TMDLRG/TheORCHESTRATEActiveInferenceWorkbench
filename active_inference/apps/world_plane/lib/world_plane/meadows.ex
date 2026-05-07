defmodule WorldPlane.Meadows do
  @moduledoc """
  Catalog of registered Bird Meadow configurations.

  Parallel to `WorldPlane.Worlds` (which lists single-agent mazes).
  Kept separate because meadows are multi-agent and don't fit the
  `%Maze{}` data shape — fitting them in there would force a bunch of
  conditional branches across the maze code paths.

  Each entry is a map with a stable id, a display name, dimensions, and
  the (optional) walls list. UI / experiment code calls `start/1` to
  boot a meadow and gets back `{:ok, pid}`.
  """

  alias WorldPlane.Worlds.BirdMeadow

  @typedoc "A meadow spec — describes how to boot one configured meadow."
  @type spec :: %{
          id: atom(),
          name: String.t(),
          description: String.t(),
          width: pos_integer(),
          height: pos_integer(),
          walls: [{non_neg_integer, non_neg_integer}],
          d_max: pos_integer()
        }

  @doc "All registered meadow specs."
  @spec all() :: [spec()]
  def all do
    [
      %{
        id: :bird_meadow_4x4,
        name: "Bird Meadow 4×4 (call/response fixture)",
        description:
          "Tight 4×4 meadow used for call-response experiments. With d_max = 5 every bird " <>
            "is in mutual hearing range of every other bird from any starting tile.",
        width: 4,
        height: 4,
        walls: [],
        d_max: 5
      },
      %{
        id: :bird_meadow_8x8,
        name: "Bird Meadow 8×8 (similar-prior convergence)",
        description:
          "Open 8×8 meadow used for the prior-convergence experiment. Birds at opposite " <>
            "corners (Manhattan distance 14) are out of hearing range with d_max = 5 and " <>
            "must move toward each other before they can establish call/response.",
        width: 8,
        height: 8,
        walls: [],
        d_max: 5
      }
    ]
  end

  @doc "Look up a spec by id."
  @spec fetch(atom()) :: spec() | nil
  def fetch(id), do: Enum.find(all(), &(&1.id == id))

  @doc """
  Boot a meadow from its id. Extra opts (`:run_id`, `:blanket`) are
  passed through to `BirdMeadow.start_link/1`. Returns `{:ok, pid}`.
  """
  @spec start(atom(), keyword()) :: {:ok, pid()} | {:error, term()}
  def start(id, opts \\ []) do
    case fetch(id) do
      nil ->
        {:error, {:unknown_meadow, id}}

      spec ->
        merged =
          [width: spec.width, height: spec.height, walls: spec.walls, d_max: spec.d_max] ++ opts

        BirdMeadow.start_link(merged)
    end
  end
end

defmodule WorldPlane.Worlds do
  @moduledoc """
  Prebuilt mazes shipped with the MVP.

  Each entry satisfies the build-brief requirements for the MVP world set:
  map topology, start state, goal state, action vocabulary (cardinal moves),
  and observable channels. Terminal condition is "agent on goal".
  """

  alias WorldPlane.Maze

  @doc "Return all prebuilt worlds."
  @spec all() :: [Maze.t()]
  def all,
    do: [
      tiny_open_goal(),
      corridor_turns(),
      forked_paths(),
      deceptive_dead_end(),
      hierarchical_maze(),
      frog_pond()
    ]

  @doc "Fetch by id."
  @spec fetch(atom()) :: Maze.t() | nil
  def fetch(id), do: Enum.find(all(), &(&1.id == id))

  def tiny_open_goal do
    Maze.from_rows(
      :tiny_open_goal,
      "Tiny Open Goal (3×3)",
      [
        "###",
        "S.G",
        "###"
      ],
      "Smallest solvable maze. One-step corridor to verify end-to-end plumbing."
    )
  end

  def corridor_turns do
    Maze.from_rows(
      :corridor_turns,
      "Corridor with Turns (5×5)",
      [
        "#####",
        "#S..#",
        "###.#",
        "#..G#",
        "#####"
      ],
      "Agent must take two turns. Tests planning depth > 1."
    )
  end

  def forked_paths do
    Maze.from_rows(
      :forked_paths,
      "Forked Paths (7×5)",
      [
        "#######",
        "#S....#",
        "#.###.#",
        "#.#.#.#",
        "#...#G#",
        "#######"
      ],
      "Two routes of different lengths. Shortest path wins under uniform preferences."
    )
  end

  def deceptive_dead_end do
    Maze.from_rows(
      :deceptive_dead_end,
      "Deceptive Dead End (7×6)",
      [
        "#######",
        "#S.#..#",
        "#..#..#",
        "##...##",
        "#....G#",
        "#######"
      ],
      "Greedy descent fails — the agent must back out of a dead end to reach the goal."
    )
  end

  # Phase D — an 11×11 maze logically partitioned into 2×2 sectors
  # (each ≈5×5 tiles). L5's meta-agent reasons at sector granularity;
  # its sub-agent reasons at tile granularity. Structurally still a
  # Maze.t() so the existing Engine runs it unchanged.
  def hierarchical_maze do
    Maze.from_rows(
      :hierarchical_maze,
      "Hierarchical Maze (11×11)",
      [
        "###########",
        "#S....#...#",
        "#.###.#.#.#",
        "#.#...#.#.#",
        "#.#.###.#.#",
        "#.#.....#.#",
        "#.#####.#.#",
        "#.......#.#",
        "#.#######.#",
        "#........G#",
        "###########"
      ],
      "Sector-partitioned maze for hierarchical active inference: meta sets sector preferences, sub navigates tiles."
    )
  end

  @doc """
  Phase D — sector mapping for the hierarchical maze. Maps every tile
  `{col, row}` to a sector id ∈ 0..(sector_count - 1). Used by L5's
  meta-agent to project tile-level state down to abstract sectors.
  """
  @spec sectors_for(atom()) :: %{optional(Maze.coord()) => non_neg_integer()} | nil
  def sectors_for(:hierarchical_maze) do
    m = hierarchical_maze()
    # 2×2 quadrants split at the midline.
    mid_x = div(m.width, 2)
    mid_y = div(m.height, 2)

    for r <- 0..(m.height - 1), c <- 0..(m.width - 1), into: %{} do
      sector =
        cond do
          c < mid_x and r < mid_y -> 0
          c >= mid_x and r < mid_y -> 1
          c < mid_x and r >= mid_y -> 2
          true -> 3
        end

      {{c, r}, sector}
    end
  end

  def sectors_for(_), do: nil

  # G2 (RUNTIME_GAPS.md) -- multi-modal fixture.  A 5x3 pond exercises the
  # Jumping Frog cookbook lineage: recipes subscribe `:goal_cue`, `:tile`,
  # and `:wall_hit` as three observation channels and combine them under a
  # single generative model.  Structurally still a Maze so the Engine +
  # ObservationEncoder contracts stay unchanged.
  def frog_pond do
    Maze.from_rows(
      :frog_pond,
      "Frog Pond (5x3)",
      [
        "#####",
        "S...G",
        "#####"
      ],
      "Multi-modal pond: a 4-step corridor where recipes combine goal-bearing (visual), tile (auditory), and wall-hit (tactile) channels into one posterior."
    )
  end
end

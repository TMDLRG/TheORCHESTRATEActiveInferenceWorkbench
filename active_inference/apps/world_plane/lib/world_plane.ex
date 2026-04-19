defmodule WorldPlane do
  @moduledoc """
  The *world plane* of the Active Inference Workbench.

  This app owns the **generative process** (eq. 8.2 vocabulary in the book):
  true map topology, goal state, collision rules, rewards / terminal
  conditions, and episode progression. It never imports anything from the
  agent plane; its only outward-facing types come from `SharedContracts`.

  See `WorldPlane.Engine` for the runtime GenServer, `WorldPlane.Maze` for
  the map data structure, and `WorldPlane.Worlds` for the prebuilt maze set.
  """

  alias WorldPlane.{Engine, Worlds}

  @doc "List all prebuilt mazes."
  defdelegate list_worlds, to: Worlds, as: :all

  @doc "Fetch a prebuilt maze by id."
  defdelegate fetch_world(id), to: Worlds, as: :fetch

  @doc "Start a new world run."
  defdelegate start_run(opts), to: Engine, as: :start_link

  @doc "Fetch current world state (opaque to the agent — read by the UI/runtime)."
  defdelegate peek(pid), to: Engine
end

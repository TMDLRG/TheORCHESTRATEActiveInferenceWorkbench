defmodule WorldPlane.WorldRegistry do
  @moduledoc """
  Uniform lookup + boot for any registered world.  S1 of the Studio plan.

  For each registered world (either a built-in maze or a future custom
  world implementing `WorldPlane.WorldBehaviour`), this module exposes a
  single API so `WorkbenchWeb.Episode` (and the Studio LiveViews)
  don't need to special-case maze-vs-custom code paths.

  Current registrations:

    * All mazes in `WorldPlane.Worlds.all/0` -- wired via `WorldPlane.Engine`.
    * (Future) Modules implementing `WorldPlane.WorldBehaviour`, registered
      at compile time via `register/1` in `config.exs`.  For now the
      registry is static; opening it is a follow-up ticket.

  `WorldPlane.ContinuousWorlds` is intentionally NOT registered here --
  continuous recipes use the G4 `ContinuousStep` action directly and do
  not participate in the Episode runner (there is no supervised
  continuous-time engine yet).
  """

  alias SharedContracts.{ActionPacket, Blanket}
  alias WorldPlane.{Engine, Maze, Worlds}

  @type world_id :: atom()

  @doc "Return every world id known to the registry."
  @spec all() :: [world_id()]
  def all do
    Enum.map(Worlds.all(), & &1.id)
  end

  @doc "Human-readable name for a world."
  @spec name(world_id()) :: String.t() | nil
  def name(world_id) do
    case Worlds.fetch(world_id) do
      %Maze{name: n} -> n
      _ -> nil
    end
  end

  @doc "Blanket the world publishes.  Matches the agent's blanket on compat check."
  @spec blanket(world_id()) :: Blanket.t() | nil
  def blanket(world_id) do
    case Worlds.fetch(world_id) do
      %Maze{} -> Blanket.maze_default()
      _ -> nil
    end
  end

  @doc """
  Dimensional summary used by `Episode.check_compatibility/2`.
  Mazes share a common observation layout via `AgentPlane.ObsAdapter`
  (64-way combined modality); `n_states` is width × height.
  """
  @spec dims(world_id()) :: %{n_obs: pos_integer(), n_states: pos_integer()} | nil
  def dims(world_id) do
    case Worlds.fetch(world_id) do
      %Maze{} = maze -> %{n_obs: 64, n_states: maze.width * maze.height}
      _ -> nil
    end
  end

  @doc "Boot a running instance of the world.  Returns {:ok, pid}."
  @spec boot(world_id(), keyword()) :: {:ok, pid()} | {:error, term()}
  def boot(world_id, opts \\ []) do
    case Worlds.fetch(world_id) do
      %Maze{} = maze ->
        blanket = Keyword.get(opts, :blanket, Blanket.maze_default())
        run_id = Keyword.get(opts, :run_id, "world-#{rand_id()}")

        # Studio fix: unlinked start so the world engine survives LV
        # push_navigate.  Uses the same registry Engine.start_link uses,
        # so subsequent `Engine.apply_action/2` lookups by run_id succeed.
        GenServer.start(WorldPlane.Engine,
          %{maze: maze, blanket: blanket, run_id: run_id},
          name: {:via, Registry, {WorldPlane.Registry, run_id}}
        )

      nil ->
        {:error, {:unknown_world, world_id}}
    end
  end

  @doc "Apply an action to a running world instance."
  @spec step(pid(), ActionPacket.t()) :: {:ok, SharedContracts.ObservationPacket.t()} | {:error, term()}
  def step(pid, %ActionPacket{} = action), do: Engine.apply_action(pid, action)

  @doc "Is this running world instance in a terminal state?"
  @spec terminal?(pid()) :: boolean()
  def terminal?(pid) do
    case Engine.peek(pid) do
      %{terminal?: t} -> t
      _ -> false
    end
  end

  @doc "Reset a running world instance to its initial state."
  @spec reset(pid()) :: :ok
  def reset(pid) do
    _ = Engine.reset(pid)
    :ok
  end

  @doc "Stop a running world instance."
  @spec stop(pid()) :: :ok
  def stop(pid), do: Engine.stop(pid)

  defp rand_id, do: :crypto.strong_rand_bytes(6) |> Base.url_encode64(padding: false)
end

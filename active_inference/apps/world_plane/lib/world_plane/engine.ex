defmodule WorldPlane.Engine do
  @moduledoc """
  World-plane episode runner.

  Owns the generative process. Accepts `SharedContracts.ActionPacket` from the
  agent plane (via `apply_action/2`) and produces
  `SharedContracts.ObservationPacket` values to return to the runtime.

  ## State

  The engine stores:

    * `:maze`   — `WorldPlane.Maze.t()` — map topology and goal.
    * `:pos`    — current `{col, row}` of the agent in the world.
    * `:t`      — integer time-step (starts at 0).
    * `:blanket`— configured `SharedContracts.Blanket.t()`.
    * `:run_id` — run-scoped id for telemetry.
    * `:terminal?` — has the episode reached a terminal state.
    * `:history` — list of `{action, pos_after}` pairs for UI replay.

  The engine NEVER stores or reads agent beliefs, free-energy values, or
  policy posteriors. The only data it receives from the agent is an
  `ActionPacket`.
  """

  use GenServer

  alias SharedContracts.{ActionPacket, Blanket, ObservationPacket}
  alias WorldPlane.{Maze, ObservationEncoder}

  @type t :: %{
          maze: Maze.t(),
          pos: Maze.coord(),
          t: non_neg_integer(),
          blanket: Blanket.t(),
          run_id: String.t(),
          terminal?: boolean(),
          last_action_blocked?: boolean(),
          history: [
            %{
              action: atom(),
              pos_before: Maze.coord(),
              pos_after: Maze.coord(),
              t: non_neg_integer()
            }
          ]
        }

  # -- Public API -------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    maze = Keyword.fetch!(opts, :maze)
    blanket = Keyword.get(opts, :blanket, Blanket.maze_default())
    run_id = Keyword.get(opts, :run_id, random_id())

    GenServer.start_link(__MODULE__, %{maze: maze, blanket: blanket, run_id: run_id},
      name: via(run_id)
    )
  end

  @spec current_observation(pid() | String.t()) :: ObservationPacket.t()
  def current_observation(ref), do: GenServer.call(ref_to_pid(ref), :current_observation)

  @spec apply_action(pid() | String.t(), ActionPacket.t()) ::
          {:ok, ObservationPacket.t()} | {:error, term()}
  def apply_action(ref, %ActionPacket{} = action),
    do: GenServer.call(ref_to_pid(ref), {:apply_action, action})

  @spec peek(pid() | String.t()) :: t()
  def peek(ref), do: GenServer.call(ref_to_pid(ref), :peek)

  @spec reset(pid() | String.t()) :: ObservationPacket.t()
  def reset(ref), do: GenServer.call(ref_to_pid(ref), :reset)

  @spec stop(pid() | String.t()) :: :ok
  def stop(ref), do: GenServer.stop(ref_to_pid(ref))

  # -- GenServer --------------------------------------------------------------

  @impl true
  def init(%{maze: maze, blanket: blanket, run_id: run_id}) do
    state = %{
      maze: maze,
      pos: maze.start,
      t: 0,
      blanket: blanket,
      run_id: run_id,
      terminal?: Maze.goal?(maze, maze.start),
      last_action_blocked?: false,
      history: []
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:current_observation, _from, state) do
    {:reply, encode(state), state}
  end

  def handle_call({:apply_action, %ActionPacket{action: action}}, _from, state) do
    pos_before = state.pos
    pos_after = Maze.step(state.maze, pos_before, action)
    terminal? = Maze.goal?(state.maze, pos_after)

    # Wall-hit detection — the step function returns the same coord when
    # the move target is a wall or out of bounds; any movement action
    # that doesn't change pos was therefore blocked.
    blocked? =
      pos_before == pos_after and action in [:move_north, :move_south, :move_east, :move_west]

    new_state = %{
      state
      | pos: pos_after,
        t: state.t + 1,
        terminal?: terminal?,
        last_action_blocked?: blocked?,
        history:
          state.history ++
            [%{action: action, pos_before: pos_before, pos_after: pos_after, t: state.t + 1}]
    }

    {:reply, {:ok, encode(new_state)}, new_state}
  end

  def handle_call(:peek, _from, state), do: {:reply, state, state}

  def handle_call(:reset, _from, state) do
    new_state = %{
      state
      | pos: state.maze.start,
        t: 0,
        terminal?: Maze.goal?(state.maze, state.maze.start),
        last_action_blocked?: false,
        history: []
    }

    {:reply, encode(new_state), new_state}
  end

  # -- Helpers ----------------------------------------------------------------

  defp encode(state) do
    ObservationEncoder.encode(
      %{
        maze: state.maze,
        pos: state.pos,
        t: state.t,
        run_id: state.run_id,
        terminal?: state.terminal?,
        last_action_blocked?: Map.get(state, :last_action_blocked?, false)
      },
      state.blanket
    )
  end

  defp via(run_id), do: {:via, Registry, {WorldPlane.Registry, run_id}}

  defp ref_to_pid(pid) when is_pid(pid), do: pid

  defp ref_to_pid(run_id) when is_binary(run_id) do
    case Registry.lookup(WorldPlane.Registry, run_id) do
      [{pid, _}] -> pid
      _ -> raise ArgumentError, "no world engine registered for run_id #{inspect(run_id)}"
    end
  end

  defp random_id do
    "world-" <> (:crypto.strong_rand_bytes(6) |> Base.url_encode64(padding: false))
  end
end

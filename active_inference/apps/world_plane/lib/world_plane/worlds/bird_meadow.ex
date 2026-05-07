defmodule WorldPlane.Worlds.BirdMeadow do
  @moduledoc """
  Multi-agent generative process for the Bird Meadow.

  Owns positions of N birds on a bounded 2D grid plus a per-tick ledger
  of song-emission events. Receives a map of per-agent
  `SharedContracts.ActionPacket`s on each tick via `multi_step/2` and
  returns a map of per-agent `SharedContracts.ObservationPacket`s
  encoded by `WorldPlane.Worlds.BirdMeadow.ObservationEncoder`.

  This module implements the optional `multi_step/2` and `observe/2`
  callbacks of `WorldPlane.WorldBehaviour`. Single-agent `step/2` is
  rejected with an explicit error — the meadow is multi-agent by design.

  ## State

      %{
        width:                pos_integer,
        height:               pos_integer,
        walls:                MapSet.t({col, row}),
        positions:            %{agent_id => {col, row}},
        song_events:          [HearingModel.song_event()],   # current tick only
        last_song_per_agent:  %{agent_id => atom()},          # carries `self_sang_token`
        t:                    non_neg_integer,
        blanket:              Blanket.t(),
        run_id:               String.t(),
        d_max:                pos_integer,
        history:              [%{t, actions, positions, song_events}]
      }

  The world NEVER stores or reads agent beliefs / free-energy /
  policy posteriors. The only data it receives from agents is an
  `ActionPacket`; the only data it returns is an `ObservationPacket`.
  """

  use GenServer
  @behaviour WorldPlane.WorldBehaviour

  alias SharedContracts.{ActionPacket, Blanket, ObservationPacket}
  alias WorldPlane.Worlds.BirdMeadow.{HearingModel, ObservationEncoder}

  @movement_actions [:move_north, :move_south, :move_east, :move_west]

  # -- WorldBehaviour callbacks -----------------------------------------------

  @impl WorldPlane.WorldBehaviour
  def id, do: :bird_meadow

  @impl WorldPlane.WorldBehaviour
  def name, do: "Bird Meadow (multi-agent)"

  @impl WorldPlane.WorldBehaviour
  def blanket, do: Blanket.meadow_default()

  @impl WorldPlane.WorldBehaviour
  def dims do
    # Per-bird observation cardinality is fixed by `MeadowObsAdapter.n_obs/0`
    # (1000); state cardinality depends on the bird tier and the grid size,
    # so it isn't returned here. Episodes do tier-specific dim checks.
    %{n_obs: 1000, n_states: 0}
  end

  @impl WorldPlane.WorldBehaviour
  def boot(opts), do: start_link(opts)

  @impl WorldPlane.WorldBehaviour
  def step(_pid, %ActionPacket{}) do
    {:error, :multi_agent_only}
  end

  @impl WorldPlane.WorldBehaviour
  def terminal?(_pid), do: false

  @impl WorldPlane.WorldBehaviour
  def reset(pid), do: GenServer.call(pid, :reset)

  @impl WorldPlane.WorldBehaviour
  def stop(pid), do: GenServer.stop(pid)

  @impl WorldPlane.WorldBehaviour
  def multi_step(pid, action_map) when is_map(action_map) do
    GenServer.call(pid, {:multi_step, action_map})
  end

  @impl WorldPlane.WorldBehaviour
  def observe(pid, agent_id) when is_binary(agent_id) do
    GenServer.call(pid, {:observe, agent_id})
  end

  # -- Public meadow-specific API ---------------------------------------------

  @doc """
  Start a meadow. Required: `:width`, `:height`. Optional: `:walls`
  (list of `{col, row}` interior walls; defaults to none — the boundary
  is always walled), `:blanket`, `:run_id`, `:d_max`.

  Returns `{:ok, pid}`. The meadow starts with **no birds placed**;
  call `add_bird/3` to place each one.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc "Place a bird at `position`. Errors if the tile is a wall, oob, or occupied."
  @spec add_bird(pid(), String.t(), {non_neg_integer, non_neg_integer}) ::
          :ok | {:error, term()}
  def add_bird(pid, agent_id, {c, r} = pos)
      when is_binary(agent_id) and is_integer(c) and is_integer(r) do
    GenServer.call(pid, {:add_bird, agent_id, pos})
  end

  @doc "Remove a bird from the meadow."
  @spec remove_bird(pid(), String.t()) :: :ok
  def remove_bird(pid, agent_id), do: GenServer.call(pid, {:remove_bird, agent_id})

  @doc "Snapshot of current world state — for UI rendering and tests only."
  @spec peek(pid()) :: map()
  def peek(pid), do: GenServer.call(pid, :peek)

  @doc "Per-agent current observation map. Read-only; does not advance time."
  @spec observe_all(pid()) :: %{String.t() => ObservationPacket.t()}
  def observe_all(pid), do: GenServer.call(pid, :observe_all)

  # -- GenServer --------------------------------------------------------------

  @impl GenServer
  def init(opts) do
    width = Keyword.fetch!(opts, :width)
    height = Keyword.fetch!(opts, :height)
    walls = opts |> Keyword.get(:walls, []) |> MapSet.new()
    blanket = Keyword.get(opts, :blanket, Blanket.meadow_default())
    run_id = Keyword.get(opts, :run_id, random_id())
    d_max = Keyword.get(opts, :d_max, HearingModel.default_d_max())

    {:ok,
     %{
       width: width,
       height: height,
       walls: walls,
       positions: %{},
       song_events: [],
       last_song_per_agent: %{},
       t: 0,
       blanket: blanket,
       run_id: run_id,
       d_max: d_max,
       history: []
     }}
  end

  @impl GenServer
  def handle_call({:add_bird, agent_id, pos}, _from, state) do
    cond do
      out_of_bounds?(state, pos) ->
        {:reply, {:error, {:out_of_bounds, pos}}, state}

      MapSet.member?(state.walls, pos) ->
        {:reply, {:error, {:wall_tile, pos}}, state}

      Map.has_key?(state.positions, agent_id) ->
        {:reply, {:error, {:already_placed, agent_id}}, state}

      Enum.any?(state.positions, fn {_id, p} -> p == pos end) ->
        {:reply, {:error, {:tile_occupied, pos}}, state}

      true ->
        new_state = %{
          state
          | positions: Map.put(state.positions, agent_id, pos),
            last_song_per_agent: Map.put(state.last_song_per_agent, agent_id, :none)
        }

        {:reply, :ok, new_state}
    end
  end

  def handle_call({:remove_bird, agent_id}, _from, state) do
    new_state = %{
      state
      | positions: Map.delete(state.positions, agent_id),
        last_song_per_agent: Map.delete(state.last_song_per_agent, agent_id)
    }

    {:reply, :ok, new_state}
  end

  def handle_call({:multi_step, action_map}, _from, state) do
    # Phase 1: classify each action and apply movements.
    {new_positions, sing_acts, stay_acts} = apply_actions(state, action_map)

    # Phase 2: build the per-tick song-event ledger from the sing actions.
    song_events =
      Enum.map(sing_acts, fn {agent_id, token} ->
        %{
          agent_id: agent_id,
          token: token,
          position: Map.fetch!(new_positions, agent_id),
          source_amp: 1.0,
          t: state.t + 1
        }
      end)

    # Phase 3: record each bird's own song (or :none) for self_sang_token.
    last_song =
      state.positions
      |> Map.keys()
      |> Enum.into(%{}, fn agent_id ->
        cond do
          Map.has_key?(action_map, agent_id) and
              Enum.any?(sing_acts, fn {id, _} -> id == agent_id end) ->
            {agent_id, Enum.find_value(sing_acts, fn {id, t} -> if id == agent_id, do: t end)}

          Map.has_key?(action_map, agent_id) ->
            {agent_id, :none}

          true ->
            # No action submitted for this bird this tick → treat as :none.
            {agent_id, :none}
        end
      end)

    new_state =
      %{
        state
        | positions: new_positions,
          song_events: song_events,
          last_song_per_agent: last_song,
          t: state.t + 1,
          history:
            state.history ++
              [
                %{
                  t: state.t + 1,
                  actions: action_map,
                  positions: new_positions,
                  song_events: song_events,
                  stays: stay_acts
                }
              ]
      }

    obs_map =
      new_state.positions
      |> Map.keys()
      |> Enum.into(%{}, fn agent_id ->
        {agent_id, ObservationEncoder.encode(snapshot(new_state), agent_id, new_state.blanket)}
      end)

    {:reply, {:ok, obs_map}, new_state}
  end

  def handle_call({:observe, agent_id}, _from, state) do
    cond do
      not Map.has_key?(state.positions, agent_id) ->
        {:reply, {:error, {:unknown_agent, agent_id}}, state}

      true ->
        obs = ObservationEncoder.encode(snapshot(state), agent_id, state.blanket)
        {:reply, {:ok, obs}, state}
    end
  end

  def handle_call(:observe_all, _from, state) do
    obs =
      state.positions
      |> Map.keys()
      |> Enum.into(%{}, fn agent_id ->
        {agent_id, ObservationEncoder.encode(snapshot(state), agent_id, state.blanket)}
      end)

    {:reply, obs, state}
  end

  def handle_call(:peek, _from, state), do: {:reply, state, state}

  def handle_call(:reset, _from, state) do
    new_state = %{
      state
      | positions: %{},
        song_events: [],
        last_song_per_agent: %{},
        t: 0,
        history: []
    }

    {:reply, :ok, new_state}
  end

  # -- Internal helpers -------------------------------------------------------

  defp apply_actions(state, action_map) do
    state.positions
    |> Enum.reduce({%{}, [], []}, fn {agent_id, pos}, {pos_acc, sing_acc, stay_acc} ->
      case Map.get(action_map, agent_id) do
        nil ->
          # No action submitted → bird stays put, doesn't sing.
          {Map.put(pos_acc, agent_id, pos), sing_acc, [{agent_id, :no_action} | stay_acc]}

        %ActionPacket{action: :stay} ->
          {Map.put(pos_acc, agent_id, pos), sing_acc, [{agent_id, :stay} | stay_acc]}

        %ActionPacket{action: action} when action in @movement_actions ->
          new_pos = step_pos(state, pos, action)

          stay = if new_pos == pos, do: [{agent_id, {:blocked, action}} | stay_acc], else: stay_acc

          {Map.put(pos_acc, agent_id, new_pos), sing_acc, stay}

        %ActionPacket{action: action} ->
          # Singing action atom like :sing_t1 → token :t1
          case decode_sing(action) do
            {:ok, token} ->
              {Map.put(pos_acc, agent_id, pos), [{agent_id, token} | sing_acc], stay_acc}

            :error ->
              raise ArgumentError,
                    "BirdMeadow: unknown action #{inspect(action)} for agent #{agent_id}"
          end
      end
    end)
  end

  defp decode_sing(action) when is_atom(action) do
    str = Atom.to_string(action)

    if String.starts_with?(str, "sing_") do
      token_str = String.slice(str, 5..-1//1)
      {:ok, String.to_existing_atom(token_str)}
    else
      :error
    end
  rescue
    ArgumentError -> :error
  end

  defp step_pos(%{walls: walls, width: w, height: h}, {c, r}, action) do
    {dc, dr} =
      case action do
        :move_north -> {0, -1}
        :move_south -> {0, 1}
        :move_east -> {1, 0}
        :move_west -> {-1, 0}
      end

    target = {c + dc, r + dr}

    cond do
      out_of_bounds_xy?(target, w, h) -> {c, r}
      MapSet.member?(walls, target) -> {c, r}
      true -> target
    end
  end

  defp out_of_bounds?(%{width: w, height: h}, pos), do: out_of_bounds_xy?(pos, w, h)

  defp out_of_bounds_xy?({c, r}, w, h), do: c < 0 or r < 0 or c >= w or r >= h

  defp snapshot(state) do
    %{
      width: state.width,
      height: state.height,
      walls: state.walls,
      positions: state.positions,
      song_events: state.song_events,
      last_song_per_agent: state.last_song_per_agent,
      t: state.t,
      run_id: state.run_id,
      d_max: state.d_max
    }
  end

  defp random_id do
    "meadow-" <> (:crypto.strong_rand_bytes(6) |> Base.url_encode64(padding: false))
  end
end

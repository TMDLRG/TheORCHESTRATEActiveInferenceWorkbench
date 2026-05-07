defmodule WorldPlane.Worlds.BirdMeadow.ObservationEncoder do
  @moduledoc """
  Per-bird observation projection for the Bird Meadow.

  This is the *only* module allowed to project meadow world state into a
  `SharedContracts.ObservationPacket` — the typed Markov-blanket
  boundary stays narrow. It reads from the meadow's positions map and
  per-tick song event ledger; it never reads or writes agent state.

  The encoder must:

    * exclude the listener's own song from the hearing aggregation (a
      bird hearing only its own voice is a degenerate self-loop), and
    * report the bird's own previous-tick song via `:self_sang_token`
      (proprioception — needed by partner-modelling factors in higher
      tiers so the bird can tell "I sang" from "they sang").
  """

  alias SharedContracts.{Blanket, ObservationPacket}
  alias WorldPlane.Worlds.BirdMeadow.HearingModel

  @typedoc """
  The minimum world snapshot required to encode one bird's observation.

  Pure data so the encoder can be tested without spinning up a GenServer.
  """
  @type snapshot :: %{
          required(:width) => pos_integer(),
          required(:height) => pos_integer(),
          required(:walls) => MapSet.t({non_neg_integer, non_neg_integer}),
          required(:positions) => %{String.t() => {non_neg_integer, non_neg_integer}},
          required(:song_events) => [HearingModel.song_event()],
          required(:last_song_per_agent) => %{String.t() => atom()},
          required(:t) => non_neg_integer(),
          required(:run_id) => String.t(),
          required(:d_max) => pos_integer()
        }

  @doc """
  Project the meadow snapshot to an `ObservationPacket` for `agent_id`.

  Raises `ArgumentError` if `agent_id` is not present in the meadow's
  positions map (the agent has not been placed in the world yet).
  """
  @spec encode(snapshot(), String.t(), Blanket.t()) :: ObservationPacket.t()
  def encode(%{positions: positions} = snap, agent_id, %Blanket{} = blanket) do
    pos =
      Map.get(positions, agent_id) ||
        raise(ArgumentError, "BirdMeadow: agent #{inspect(agent_id)} has no position")

    other_events = Enum.reject(snap.song_events, fn ev -> ev.agent_id == agent_id end)

    heard = HearingModel.aggregate_per_listener(other_events, pos, d_max: snap.d_max)

    self_sang = Map.get(snap.last_song_per_agent, agent_id, :none)

    channels = %{
      wall_sig: wall_sig(snap, pos),
      hearing_amp: heard.amp_bin,
      hearing_token: heard.token,
      hearing_bearing: heard.bearing,
      self_sang_token: self_sang
    }

    ObservationPacket.new(%{
      t: snap.t,
      channels: channels,
      world_run_id: snap.run_id,
      # Meadow has no terminal condition; episodes are time-bounded.
      terminal?: false,
      blanket: blanket
    })
  end

  @doc """
  `:near_wall` iff any of the four cardinal neighbours is out of bounds
  or a wall tile; `:open` otherwise. Pure helper exposed for tests.
  """
  @spec wall_sig(snapshot(), {non_neg_integer, non_neg_integer}) :: :open | :near_wall
  def wall_sig(%{width: w, height: h, walls: walls}, {c, r}) do
    neighbours = [{c, r - 1}, {c, r + 1}, {c - 1, r}, {c + 1, r}]

    near? =
      Enum.any?(neighbours, fn {nc, nr} ->
        nc < 0 or nr < 0 or nc >= w or nr >= h or MapSet.member?(walls, {nc, nr})
      end)

    if near?, do: :near_wall, else: :open
  end
end

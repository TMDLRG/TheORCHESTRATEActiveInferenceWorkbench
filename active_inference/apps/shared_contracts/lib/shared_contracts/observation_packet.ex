defmodule SharedContracts.ObservationPacket do
  @moduledoc """
  The only payload the world is allowed to send to the agent.

  Every channel exposed here is explicitly configured by the user in the
  workbench UI via `SharedContracts.Blanket`. The world MUST NOT write any
  fields except those listed in the blanket's `observation_channels`.

  ## Fields

    * `:t` — the integer time-step this packet describes. Monotonic per run.
    * `:channels` — map from channel name (atom) to its value. Every channel
      here must also appear in the blanket spec.
    * `:world_run_id` — run-scoped identifier (never the world's internal
      state). The agent may use this for telemetry only.
    * `:terminal?` — `true` iff the world has reached a terminal condition.
      This is the *single* exception to "observation channels only" — it is
      needed so the runtime can stop the agent cleanly without re-reading
      world state.

  No raw map coordinates, grid handles, or goal coordinates are transmitted
  unless the user explicitly opted the corresponding channel into the blanket.
  """

  @enforce_keys [:t, :channels, :world_run_id, :terminal?]
  defstruct [:t, :channels, :world_run_id, :terminal?]

  @type channel_name :: atom()
  @type channel_value :: term()

  @type t :: %__MODULE__{
          t: non_neg_integer(),
          channels: %{channel_name() => channel_value()},
          world_run_id: String.t(),
          terminal?: boolean()
        }

  @doc """
  Construct an observation packet, verifying that every channel it carries
  is allowed by the blanket spec. Raises if a disallowed channel appears.
  """
  @spec new(%{
          t: non_neg_integer(),
          channels: %{atom() => term()},
          world_run_id: String.t(),
          terminal?: boolean(),
          blanket: SharedContracts.Blanket.t()
        }) :: t()
  def new(%{t: t, channels: channels, world_run_id: id, terminal?: term, blanket: blanket}) do
    allowed = MapSet.new(blanket.observation_channels)

    Enum.each(Map.keys(channels), fn ch ->
      unless MapSet.member?(allowed, ch) do
        raise ArgumentError,
              "blanket violation: observation channel #{inspect(ch)} is not exposed by the blanket"
      end
    end)

    %__MODULE__{t: t, channels: channels, world_run_id: id, terminal?: term}
  end
end

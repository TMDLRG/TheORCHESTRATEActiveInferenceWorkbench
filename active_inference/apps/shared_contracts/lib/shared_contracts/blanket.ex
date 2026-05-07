defmodule SharedContracts.Blanket do
  @moduledoc """
  Declarative Markov-blanket specification.

  A blanket names exactly which world signals are exposed to the agent and
  which agent actions are accepted by the world. The workbench UI edits one
  of these and hands it to both planes; the planes use it to validate every
  packet they emit or receive.

  ## Fields

    * `:observation_channels` — ordered list of atoms; the world may emit
      these channels and only these.
    * `:action_vocabulary` — ordered list of atoms; the world will accept
      these actions and only these.
    * `:channel_specs` — `%{channel => spec}` where each spec describes how
      the agent should interpret the channel. The specs are opaque to the
      world; only the agent consumes them.

  The canonical channel specs used by the maze worlds are documented in
  `WorldPlane.ObservationEncoder` and `WorldPlane.Worlds`.
  """

  @enforce_keys [:observation_channels, :action_vocabulary, :channel_specs]
  defstruct [:observation_channels, :action_vocabulary, :channel_specs]

  @type channel_spec :: %{
          required(:kind) => :categorical | :scalar | :bool,
          required(:values) => [atom()] | {:int, pos_integer()} | nil,
          optional(:description) => String.t()
        }

  @type t :: %__MODULE__{
          observation_channels: [atom()],
          action_vocabulary: [atom()],
          channel_specs: %{atom() => channel_spec()}
        }

  @doc """
  The default blanket for the maze MVP. Exposes the four most useful channels
  from Chapter 7's discrete-time POMDP example and the four cardinal actions
  that match the controllable B1 transitions (eq. 7.2, figure 7.6).
  """
  @spec maze_default() :: t()
  def maze_default do
    %__MODULE__{
      observation_channels: [
        :wall_north,
        :wall_south,
        :wall_east,
        :wall_west,
        :goal_cue,
        :tile,
        :wall_hit
      ],
      action_vocabulary: [:move_north, :move_south, :move_east, :move_west],
      channel_specs: %{
        wall_north: %{
          kind: :categorical,
          values: [:wall, :open],
          description: "Wall indicator north of agent."
        },
        wall_south: %{
          kind: :categorical,
          values: [:wall, :open],
          description: "Wall indicator south of agent."
        },
        wall_east: %{
          kind: :categorical,
          values: [:wall, :open],
          description: "Wall indicator east of agent."
        },
        wall_west: %{
          kind: :categorical,
          values: [:wall, :open],
          description: "Wall indicator west of agent."
        },
        goal_cue: %{
          kind: :categorical,
          values: [:here, :north, :south, :east, :west, :unknown],
          description: "Bearing to the goal (coarse compass)."
        },
        tile: %{
          kind: :categorical,
          values: [:empty, :start, :goal, :wall],
          description: "Identity of the tile the agent currently stands on."
        },
        wall_hit: %{
          kind: :categorical,
          values: [:hit, :clear],
          description:
            "True if the agent's last action was blocked by a wall (stayed in place). " <>
              "Agents penalise `:hit` via C so they avoid repeatedly bumping walls."
        }
      }
    }
  end

  @doc """
  Default blanket for the multi-agent Bird Meadow world.

  Channels:
    * Wall signature reduced to a single 2-way `:near_wall` summary so the
      hearing factors (the scientifically interesting ones) dominate the
      observation space. Mazes already test wall localisation; the meadow
      is about song-driven inference.
    * Hearing factors expose only the LOUDEST audible song in range
      (aggregated, not per-source). This preserves the inter-agent
      Markov blanket: a listener cannot directly observe another bird's
      identity or hidden state — it must infer them from the song stream.
    * `:self_sang_token` is proprioceptive (the listener's own previous
      vocalisation) and is needed for the partner-modelling factor in
      higher-tier birds (the bird must distinguish "I sang" from "they sang").

  Action vocabulary: 9 atoms — one stay, four cardinal moves, four song
  tokens. Singing and moving are mutually exclusive on a single tick
  (matches the discrete-time POMDP's single-action-per-step contract;
  call/response timing then emerges from the constraint).
  """
  @spec meadow_default() :: t()
  def meadow_default do
    song_tokens = [:t1, :t2, :t3, :t4]
    sing_actions = Enum.map(song_tokens, fn t -> String.to_atom("sing_" <> Atom.to_string(t)) end)

    %__MODULE__{
      observation_channels: [
        :wall_sig,
        :hearing_amp,
        :hearing_token,
        :hearing_bearing,
        :self_sang_token
      ],
      action_vocabulary:
        [:stay, :move_north, :move_south, :move_east, :move_west] ++ sing_actions,
      channel_specs: %{
        wall_sig: %{
          kind: :categorical,
          values: [:open, :near_wall],
          description:
            "True iff at least one of the four cardinal neighbours is a wall (or out of bounds)."
        },
        hearing_amp: %{
          kind: :categorical,
          values: [:silence, :soft, :medium, :loud],
          description:
            "Amplitude bin of the LOUDEST audible song this tick after distance attenuation."
        },
        hearing_token: %{
          kind: :categorical,
          values: [:none | song_tokens],
          description:
            "Song token of the loudest audible source. `:none` iff `hearing_amp == :silence`."
        },
        hearing_bearing: %{
          kind: :categorical,
          values: [:none, :north, :east, :south, :west],
          description:
            "4-quadrant bearing to the loudest source. `:none` if same tile or no source."
        },
        self_sang_token: %{
          kind: :categorical,
          values: [:none | song_tokens],
          description:
            "Token the listener sang on the PREVIOUS tick (proprioceptive feedback). " <>
              "`:none` if the listener did not sing."
        }
      }
    }
  end

  @doc "Song-token alphabet used by `meadow_default/0`. Stable for callers that need the list."
  @spec meadow_song_tokens() :: [atom()]
  def meadow_song_tokens, do: [:t1, :t2, :t3, :t4]

  @doc "Replace the list of exposed observation channels."
  @spec with_observation_channels(t(), [atom()]) :: t()
  def with_observation_channels(%__MODULE__{} = blanket, channels) when is_list(channels) do
    %{blanket | observation_channels: channels}
  end

  @doc "Replace the action vocabulary."
  @spec with_action_vocabulary(t(), [atom()]) :: t()
  def with_action_vocabulary(%__MODULE__{} = blanket, actions) when is_list(actions) do
    %{blanket | action_vocabulary: actions}
  end
end

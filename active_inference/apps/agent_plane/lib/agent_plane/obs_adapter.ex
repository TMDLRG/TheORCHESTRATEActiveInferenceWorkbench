defmodule AgentPlane.ObsAdapter do
  @moduledoc """
  Adapter that maps a `SharedContracts.ObservationPacket` onto the
  agent's categorical observation vector.

  The observation space combines three factors into a single 64-way
  one-hot:

    * wall signature — a 4-bit code (N/S/E/W) identifying which sides
      of the current tile are walls. Unique per tile for maze worlds
      with irregular geometry, so the agent can localize itself from
      observations alone.
    * goal_here — 1 when the agent is on the goal tile.
    * wall_hit — 1 when the last action was blocked by a wall
      (penalised via C).

      obs_idx = wall_sig * 4 + goal * 2 + hit
      obs_idx ∈ 0..63

  The encoder lives here so the core math stays source-faithful and
  independent of channel choice.
  """

  alias ActiveInferenceCore.Math, as: M
  alias SharedContracts.ObservationPacket

  @n_obs 64

  @spec n_obs() :: non_neg_integer()
  def n_obs, do: @n_obs

  @doc "Derive the categorical observation vector from an observation packet."
  @spec to_obs_vector(ObservationPacket.t()) :: [float()]
  def to_obs_vector(%ObservationPacket{channels: channels}) do
    M.one_hot(@n_obs, combined_index(channels))
  end

  @doc """
  Pure-data helper — returns the combined-obs index for a (wall_sig,
  goal, hit) triple. Useful for `AgentPlane.BundleBuilder` to fill A
  without duplicating the encoding scheme.
  """
  @spec obs_index(0..15, boolean(), boolean()) :: 0..63
  def obs_index(wall_sig, goal?, hit?)
      when wall_sig in 0..15 and is_boolean(goal?) and is_boolean(hit?) do
    wall_sig * 4 + if(goal?, do: 2, else: 0) + if(hit?, do: 1, else: 0)
  end

  # -- Internals --------------------------------------------------------------

  defp combined_index(channels) do
    wall_sig =
      [
        {:wall_north, 0},
        {:wall_east, 1},
        {:wall_south, 2},
        {:wall_west, 3}
      ]
      |> Enum.reduce(0, fn {ch, bit}, acc ->
        case Map.get(channels, ch) do
          :wall -> Bitwise.bor(acc, Bitwise.bsl(1, bit))
          _ -> acc
        end
      end)

    goal_here? =
      Map.get(channels, :goal_cue) == :here or
        Map.get(channels, :tile) == :goal

    hit? = Map.get(channels, :wall_hit) == :hit

    obs_index(wall_sig, goal_here?, hit?)
  end
end

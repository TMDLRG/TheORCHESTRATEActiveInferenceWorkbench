defmodule AgentPlane.MeadowObsAdapter do
  @moduledoc """
  Observation adapter for the Bird Meadow world.

  Mirrors `AgentPlane.ObsAdapter` (the maze adapter) — same contract
  (`to_obs_vector/1`, `n_obs/0`, plus an `obs_index/5` helper used by
  `AgentPlane.BundleBuilder.Meadow` to fill A without duplicating the
  encoding scheme).

  ## Combined observation index

  The meadow observation factorises into five categorical channels:

  | factor          | cardinality | values                                  |
  |-----------------|-------------|-----------------------------------------|
  | `wall_sig`      | 2           | `:open`, `:near_wall`                   |
  | `hearing_amp`   | 4           | `:silence`, `:soft`, `:medium`, `:loud` |
  | `hearing_token` | 5           | `:none`, `:t1`, `:t2`, `:t3`, `:t4`     |
  | `hearing_bearing` | 5         | `:none`, `:north`, `:east`, `:south`, `:west` |
  | `self_sang_token` | 5         | `:none`, `:t1`, `:t2`, `:t3`, `:t4`     |

  Combined `n_obs = 2 · 4 · 5 · 5 · 5 = 1000` — small enough to keep a
  flat A matrix tractable for the experimental grid sizes (4×4 and 8×8)
  while still expressing all five channels independently.

  Index layout (lexicographic on the cardinality tuple above):

      idx = wall_sig·500 + amp·125 + token·25 + bearing·5 + self_sang

  This is the *only* place the encoding is defined — the bundle builder
  reuses `obs_index/5` to populate A so the encoding never drifts.
  """

  alias ActiveInferenceCore.Math, as: M
  alias SharedContracts.ObservationPacket

  # Cardinalities (frozen — must match `Blanket.meadow_default/0`).
  @wall_sig_values [:open, :near_wall]
  @amp_values [:silence, :soft, :medium, :loud]
  @token_values [:none, :t1, :t2, :t3, :t4]
  @bearing_values [:none, :north, :east, :south, :west]

  @n_wall length(@wall_sig_values)
  @n_amp length(@amp_values)
  @n_token length(@token_values)
  @n_bearing length(@bearing_values)
  @n_self length(@token_values)

  @n_obs @n_wall * @n_amp * @n_token * @n_bearing * @n_self

  # Per-axis strides — kept as compile-time constants so `obs_index/5`
  # is a single arithmetic expression with no runtime lookup.
  @stride_wall @n_amp * @n_token * @n_bearing * @n_self
  @stride_amp @n_token * @n_bearing * @n_self
  @stride_token @n_bearing * @n_self
  @stride_bearing @n_self

  @spec n_obs() :: pos_integer()
  def n_obs, do: @n_obs

  @spec wall_sig_values() :: [atom()]
  def wall_sig_values, do: @wall_sig_values

  @spec amp_values() :: [atom()]
  def amp_values, do: @amp_values

  @spec token_values() :: [atom()]
  def token_values, do: @token_values

  @spec bearing_values() :: [atom()]
  def bearing_values, do: @bearing_values

  @spec self_sang_values() :: [atom()]
  def self_sang_values, do: @token_values

  @doc "Compose a flat obs index from atom-valued channel components."
  @spec obs_index(atom(), atom(), atom(), atom(), atom()) :: 0..999
  def obs_index(wall_sig, amp, token, bearing, self_sang) do
    wi = idx_in(@wall_sig_values, wall_sig)
    ai = idx_in(@amp_values, amp)
    ti = idx_in(@token_values, token)
    bi = idx_in(@bearing_values, bearing)
    si = idx_in(@token_values, self_sang)

    wi * @stride_wall + ai * @stride_amp + ti * @stride_token + bi * @stride_bearing + si
  end

  @doc "Inverse of `obs_index/5`. Returns the 5-tuple of atom values."
  @spec decode_index(0..999) ::
          {atom(), atom(), atom(), atom(), atom()}
  def decode_index(idx) when idx in 0..(@n_obs - 1)//1 do
    {wi, rem1} = {div(idx, @stride_wall), rem(idx, @stride_wall)}
    {ai, rem2} = {div(rem1, @stride_amp), rem(rem1, @stride_amp)}
    {ti, rem3} = {div(rem2, @stride_token), rem(rem2, @stride_token)}
    {bi, si} = {div(rem3, @stride_bearing), rem(rem3, @stride_bearing)}

    {
      Enum.at(@wall_sig_values, wi),
      Enum.at(@amp_values, ai),
      Enum.at(@token_values, ti),
      Enum.at(@bearing_values, bi),
      Enum.at(@token_values, si)
    }
  end

  @doc "Project an `ObservationPacket` to its one-hot obs vector."
  @spec to_obs_vector(ObservationPacket.t()) :: [float()]
  def to_obs_vector(%ObservationPacket{channels: ch}) do
    M.one_hot(@n_obs, combined_index(ch))
  end

  defp combined_index(channels) do
    obs_index(
      Map.get(channels, :wall_sig, :open),
      Map.get(channels, :hearing_amp, :silence),
      Map.get(channels, :hearing_token, :none),
      Map.get(channels, :hearing_bearing, :none),
      Map.get(channels, :self_sang_token, :none)
    )
  end

  defp idx_in(list, value) do
    case Enum.find_index(list, &(&1 == value)) do
      nil ->
        raise ArgumentError,
              "MeadowObsAdapter: value #{inspect(value)} is not in #{inspect(list)}"

      i ->
        i
    end
  end
end

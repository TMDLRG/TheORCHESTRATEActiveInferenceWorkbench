defmodule AgentPlane.BirdsongObsAdapter do
  @moduledoc """
  Observation adapter for the Birdsong Call-Response lab.

  The lab exposes four categorical blanket channels and flattens them into one
  categorical observation for the existing discrete-time POMDP core:

      idx = heard * 60 + phase * 15 + self_sang * 3 + response_fit

  The factor cardinalities are 6 * 4 * 5 * 3 = 360.
  """

  alias ActiveInferenceCore.Math, as: M
  alias SharedContracts.ObservationPacket

  @heard_values [:silence, :a, :b, :c, :d, :unknown]
  @phase_values [:call, :gap, :response_due, :refractory]
  @self_values [:none, :a, :b, :c, :d]
  @fit_values [:none, :poor_fit, :good_fit]

  @n_heard length(@heard_values)
  @n_phase length(@phase_values)
  @n_self length(@self_values)
  @n_fit length(@fit_values)

  @n_obs @n_heard * @n_phase * @n_self * @n_fit
  @stride_heard @n_phase * @n_self * @n_fit
  @stride_phase @n_self * @n_fit
  @stride_self @n_fit

  @doc "Number of flat categorical observations."
  @spec n_obs() :: pos_integer()
  def n_obs, do: @n_obs

  @doc "Heard-motif observation alphabet."
  @spec heard_values() :: [atom()]
  def heard_values, do: @heard_values

  @doc "Turn-phase observation alphabet."
  @spec phase_values() :: [atom()]
  def phase_values, do: @phase_values

  @doc "Self-audition observation alphabet."
  @spec self_values() :: [atom()]
  def self_values, do: @self_values

  @doc "Response-fit observation alphabet."
  @spec fit_values() :: [atom()]
  def fit_values, do: @fit_values

  @doc "Compose a flat observation index from categorical channel values."
  @spec obs_index(atom(), atom(), atom(), atom()) :: 0..359
  def obs_index(heard, phase, self_sang, fit) do
    hi = idx_in(@heard_values, heard)
    pi = idx_in(@phase_values, phase)
    si = idx_in(@self_values, self_sang)
    fi = idx_in(@fit_values, fit)

    hi * @stride_heard + pi * @stride_phase + si * @stride_self + fi
  end

  @doc "Inverse of `obs_index/4`."
  @spec decode_index(0..359) :: {atom(), atom(), atom(), atom()}
  def decode_index(idx) when idx in 0..(@n_obs - 1)//1 do
    {hi, rem1} = {div(idx, @stride_heard), rem(idx, @stride_heard)}
    {pi, rem2} = {div(rem1, @stride_phase), rem(rem1, @stride_phase)}
    {si, fi} = {div(rem2, @stride_self), rem(rem2, @stride_self)}

    {
      Enum.at(@heard_values, hi),
      Enum.at(@phase_values, pi),
      Enum.at(@self_values, si),
      Enum.at(@fit_values, fi)
    }
  end

  @doc "Project an observation packet onto the POMDP one-hot observation vector."
  @spec to_obs_vector(ObservationPacket.t()) :: [float()]
  def to_obs_vector(%ObservationPacket{channels: channels}) do
    M.one_hot(@n_obs, combined_index(channels))
  end

  defp combined_index(channels) do
    obs_index(
      Map.get(channels, :heard_motif, :silence),
      Map.get(channels, :turn_phase, :call),
      Map.get(channels, :self_sang_motif, :none),
      Map.get(channels, :response_fit, :none)
    )
  end

  defp idx_in(values, value) do
    case Enum.find_index(values, &(&1 == value)) do
      nil ->
        raise ArgumentError,
              "BirdsongObsAdapter: value #{inspect(value)} is not in #{inspect(values)}"

      idx ->
        idx
    end
  end
end

defmodule WorldPlane.ContinuousWorlds do
  @moduledoc """
  Continuous-time generative processes for cookbook recipes that use
  `AgentPlane.Actions.ContinuousStep` + `AgentPlane.Skills.GeneralizedFilter`.

  G2 + G4 (RUNTIME_GAPS.md).  Discrete-time recipes use
  `WorldPlane.Worlds` (maze engine); continuous-time recipes reach for this
  module.  The continuous worlds here are *generative processes* only --
  time-indexed scalar trajectories + additive sensor noise.  The agent
  maintains beliefs over position + velocity (2 orders of motion) via the
  generalized filter and closes the loop by emitting a control signal that
  nudges the process.

  Shape is intentionally narrow: 1 hidden state, 1 sensor, 2 orders.  Wide
  enough to reproduce eq 8.1 dynamics for the cookbook's 3 continuous-time
  recipes, narrow enough to implement and test cleanly.
  """

  @enforce_keys [:id, :name, :signal_fn, :sensor_noise, :dt, :description]
  defstruct [:id, :name, :signal_fn, :sensor_noise, :dt, :description]

  @type t :: %__MODULE__{
          id: atom(),
          name: String.t(),
          # Generative-process trajectory: t (seconds) -> scalar position.
          signal_fn: (float() -> float()),
          # Additive Gaussian sensor noise standard deviation.
          sensor_noise: float(),
          # Integration step in seconds.
          dt: float(),
          description: String.t()
        }

  @doc "Return all prebuilt continuous worlds."
  @spec all() :: [t()]
  def all, do: [sinusoid_tracker()]

  @doc "Fetch by id; `nil` if unknown."
  @spec fetch(atom()) :: t() | nil
  def fetch(id), do: Enum.find(all(), &(&1.id == id))

  @doc "Observe the world at time `t` with additive noise."
  @spec sample(t(), float(), float()) :: float()
  def sample(%__MODULE__{signal_fn: f, sensor_noise: sigma}, t, noise_sample) do
    f.(t) + sigma * noise_sample
  end

  @doc """
  Canonical continuous-time fixture: sin(t) at 1 Hz, sensor noise 0.1,
  integration step 0.05s.  Used by the Continuous-Time Forge recipes and by
  unit tests of the generalized filter.
  """
  def sinusoid_tracker do
    %__MODULE__{
      id: :sinusoid_tracker,
      name: "Sinusoid Tracker (1 Hz)",
      signal_fn: &:math.sin/1,
      sensor_noise: 0.1,
      dt: 0.05,
      description:
        "1-D continuous-time signal: x(t) = sin(t) with sensor noise N(0, 0.1). " <>
          "Integration step dt = 0.05s.  Used by generalized-filter recipes."
    }
  end
end

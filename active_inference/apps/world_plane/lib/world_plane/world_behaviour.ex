defmodule WorldPlane.WorldBehaviour do
  @moduledoc """
  Canonical contract for any world that a Jido agent can be episode-attached to.

  S1 of the Studio plan.  Formalised as a behaviour so the future
  custom-world builder has a narrow target: implement these 8 callbacks and
  your world plugs into `WorkbenchWeb.Episode` + `/studio/run/:session_id`
  with no further glue.

  The contract is intentionally world-agnostic: it cares about dims, a
  blanket, and the generative-process step interface.  Mazes, continuous
  signal trackers, and future 2-D multi-agent arenas all fit.
  """

  alias SharedContracts.{ActionPacket, Blanket, ObservationPacket}

  @doc "Unique atom identifier for this world (e.g. `:tiny_open_goal`)."
  @callback id() :: atom()

  @doc "Human-readable name."
  @callback name() :: String.t()

  @doc "Blanket describing which channels the world publishes and accepts."
  @callback blanket() :: Blanket.t()

  @doc """
  Dimensional summary of the generative process surface.  Used by
  `Episode.check_compatibility/2` to reject mismatched agent bundles.
  """
  @callback dims() :: %{n_obs: pos_integer(), n_states: pos_integer()}

  @doc "Boot a new running instance.  Returns the process pid."
  @callback boot(keyword()) :: {:ok, pid()} | {:error, term()}

  @doc "Apply an action; return the next observation packet."
  @callback step(pid(), ActionPacket.t()) :: {:ok, ObservationPacket.t()} | {:error, term()}

  @doc "Is the current state terminal (episode should end)?"
  @callback terminal?(pid()) :: boolean()

  @doc "Reset the running instance to its initial state."
  @callback reset(pid()) :: :ok

  @doc "Stop the running instance."
  @callback stop(pid()) :: :ok
end

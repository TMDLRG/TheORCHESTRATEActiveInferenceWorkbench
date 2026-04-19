defmodule WorldPlane.World do
  @moduledoc """
  Lego-uplift Phase D — contract for plugging a non-maze world into the
  workbench.

  A world owns the **generative process** (eq. 8.2) — the ground truth of
  what observations arise from hidden states. It never reads the agent's
  beliefs, free energies, or policy posterior; the only thing it receives
  from the agent is a `SharedContracts.ActionPacket`, and the only thing
  it returns is a `SharedContracts.ObservationPacket`.

  Today `WorldPlane.Engine` is hard-coded to `WorldPlane.Maze`. This
  behaviour documents the surface a future pluggable world engine must
  implement. When Phase D+ refactors `Engine` to delegate, this
  contract becomes authoritative; until then, new worlds live in
  `WorldPlane.Worlds.*` as `Maze` structs and ride the existing engine.
  """

  alias SharedContracts.{ActionPacket, Blanket, ObservationPacket}

  @type state :: any()
  @type opts :: map()

  @doc "Build the initial world state."
  @callback init(opts()) :: {:ok, state()}

  @doc "Produce the current observation as an ObservationPacket."
  @callback observe(state(), Blanket.t()) :: {:ok, ObservationPacket.t(), state()}

  @doc "Apply an action and return the next state."
  @callback apply_action(state(), ActionPacket.t()) :: {:ok, state()}

  @doc "Has the episode reached a terminal state?"
  @callback terminal?(state()) :: boolean()

  @doc "Render a UI-friendly view (iodata / HEEx)."
  @callback viz(state()) :: any()

  @optional_callbacks viz: 1
end

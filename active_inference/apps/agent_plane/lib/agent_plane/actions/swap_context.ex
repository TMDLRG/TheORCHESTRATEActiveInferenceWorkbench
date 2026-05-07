defmodule AgentPlane.Actions.SwapContext do
  @moduledoc """
  JIDO action: replace the agent's `bundle.c` (log-preference vector) with
  a new vector and record which context label is now active.

  Used by the Bird Meadow Resonant tier to swap between `:explore` and
  `:duet` C-preferences without leaving the Jido-pure boundary. Calling
  `MeadowEpisode` previously mutated `agent.state.bundle.c` directly,
  which violated the cmd/2 purity contract documented in
  `knowledgebase/jido/00-philosophy.md` ("StateOps are applied by the
  strategy inside cmd/2 and never leave it"). Routing the swap through
  this action restores compliance.
  """

  use Jido.Action,
    name: "swap_context",
    description: "Atomically swap the agent's C-preference vector via the cmd/2 strategy.",
    schema: [
      c: [type: {:list, :float}, required: true]
    ]

  @impl true
  def run(%{c: new_c}, context) do
    state = context.state
    new_bundle = Map.put(state.bundle, :c, new_c)

    {:ok, %{bundle: new_bundle}}
  end
end

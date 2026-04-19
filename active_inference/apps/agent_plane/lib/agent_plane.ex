defmodule AgentPlane do
  @moduledoc """
  The *agent plane* of the Active Inference Workbench.

  This app owns the **generative model** (eq. 8.1 vocabulary in the book):
  hidden-state beliefs, policy-posterior computation, and action selection.
  It depends on `ActiveInferenceCore` for the pure math and `SharedContracts`
  for the Markov-blanket crossing. It has no dependency on `WorldPlane`.

  The agent is a *real* `Jido.Agent` — not a GenServer imitation. See
  `AgentPlane.ActiveInferenceAgent` and the three native JIDO actions in
  `AgentPlane.Actions`.
  """

  alias AgentPlane.{ActiveInferenceAgent, BundleBuilder, JidoInstance}

  @doc "Build a POMDP bundle tailored for a specific maze world + blanket."
  defdelegate build_maze_bundle(opts), to: BundleBuilder, as: :for_maze

  @doc "Start a real JIDO AgentServer for an Active Inference agent."
  @spec start_agent(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_agent(opts) do
    JidoInstance.start_agent(ActiveInferenceAgent, opts)
  end
end

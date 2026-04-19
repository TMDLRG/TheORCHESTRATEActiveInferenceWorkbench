defmodule AgentPlane.Actions.Perceive do
  @moduledoc """
  JIDO action: sweep state beliefs using eq. 4.13 / B.5.

  Takes the newly-arrived observation packet, appends its obs-vector to the
  agent's history, and sweeps `ActiveInferenceCore.DiscreteTime.sweep_state_beliefs/7`.
  """

  use Jido.Action,
    name: "perceive",
    description: "Update state beliefs via variational message passing (eq. 4.13 / B.5).",
    schema: [
      observation: [type: :any, required: true],
      n_iters: [type: :integer, default: 8]
    ]

  alias ActiveInferenceCore.DiscreteTime
  alias AgentPlane.ObsAdapter
  alias AgentPlane.Telemetry.Context

  @impl true
  def run(%{observation: obs_packet, n_iters: n_iters}, context) do
    state = context.state
    obs_vec = ObsAdapter.to_obs_vector(obs_packet)

    new_history = state.obs_history ++ [obs_vec]
    new_t = length(new_history) - 1

    # Plan §8.4 — stash the provenance tuple so DiscreteTime spans can be
    # turned into equation.evaluated events with full provenance.
    updated_beliefs =
      Context.with_agent_context(state, fn ->
        DiscreteTime.sweep_state_beliefs(
          ensure_beliefs_initialised(state),
          state.bundle.policies,
          state.bundle.b,
          state.bundle.a,
          new_history,
          state.bundle.d,
          n_iters
        )
      end)

    {:ok,
     %{
       beliefs: updated_beliefs,
       obs_history: new_history,
       t: new_t
     }}
  end

  defp ensure_beliefs_initialised(%{beliefs: b}) when map_size(b) > 0, do: b
  defp ensure_beliefs_initialised(%{bundle: bundle}), do: DiscreteTime.fresh_beliefs(bundle)
end

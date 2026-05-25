defmodule AgentPlane.Actions.Step do
  @moduledoc """
  Convenience JIDO action: run the full Perceive → Plan → Act sequence in
  one `cmd/2` call.

  This is purely sugar — internally it delegates to the three canonical
  actions via the agent's own `cmd/2`. We do not re-implement the math.

  When the bundle sets `:learning_enabled` (default `false`), a Dirichlet
  update to the A likelihood (`DirichletUpdateA`, eq. 7.10) runs *after* the
  Perceive→Plan→Act tick, so the model the agent planned and acted with this
  step is the one in force, and learning updates it for the next step. The
  posterior `q(s)` it conditions on is the one Plan just computed. For every
  bundle that leaves learning off this is a strict no-op — `/labs` is
  unaffected.
  """

  use Jido.Action,
    name: "step",
    description: "Run one full perception–planning–action tick.",
    schema: [
      observation: [type: :any, required: true],
      dispatch: [type: :any, default: nil]
    ]

  alias AgentPlane.Actions.{Act, DirichletUpdateA, Perceive, Plan}

  @impl true
  def run(%{observation: obs, dispatch: dispatch}, context) do
    # JIDO 2 records the subclass in `:agent_module`; the parent `__struct__`
    # is `Jido.Agent`, which has no `cmd/2`. Dispatch through the subclass so
    # the nested Perceive→Plan→Act→learn calls resolve.
    agent_module = context.agent.agent_module || context.agent.__struct__

    with {agent1, _dirs1} <- agent_module.cmd(context.agent, {Perceive, %{observation: obs}}),
         {agent2, _dirs2} <- agent_module.cmd(agent1, Plan),
         {agent3, dirs3} <- agent_module.cmd(agent2, {Act, %{dispatch: dispatch}}),
         {agent4, _dirs4} <- maybe_learn(agent_module, agent3) do
      {:ok, Map.drop(agent4.state, [:agent_module, :__struct__]), dirs3}
    end
  end

  # Online model learning, gated on the bundle flag. Off ⇒ identity.
  defp maybe_learn(agent_module, agent) do
    if Map.get(agent.state.bundle, :learning_enabled, false) do
      agent_module.cmd(agent, {DirichletUpdateA, %{}})
    else
      {agent, []}
    end
  end
end

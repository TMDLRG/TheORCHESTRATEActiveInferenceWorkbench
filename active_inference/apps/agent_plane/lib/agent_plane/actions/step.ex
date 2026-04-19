defmodule AgentPlane.Actions.Step do
  @moduledoc """
  Convenience JIDO action: run the full Perceive → Plan → Act sequence in
  one `cmd/2` call.

  This is purely sugar — internally it delegates to the three canonical
  actions via the agent's own `cmd/2`. We do not re-implement the math.
  """

  use Jido.Action,
    name: "step",
    description: "Run one full perception–planning–action tick.",
    schema: [
      observation: [type: :any, required: true],
      dispatch: [type: :any, default: nil]
    ]

  alias AgentPlane.Actions.{Act, Perceive, Plan}

  @impl true
  def run(%{observation: obs, dispatch: dispatch}, context) do
    agent_module = context.agent.__struct__

    with {agent1, _dirs1} <- agent_module.cmd(context.agent, {Perceive, %{observation: obs}}),
         {agent2, _dirs2} <- agent_module.cmd(agent1, Plan),
         {agent3, dirs3} <- agent_module.cmd(agent2, {Act, %{dispatch: dispatch}}) do
      {:ok, Map.drop(agent3.state, [:agent_module, :__struct__]), dirs3}
    end
  end
end

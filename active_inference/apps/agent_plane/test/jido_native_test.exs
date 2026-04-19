defmodule AgentPlane.JidoNativeTest do
  @moduledoc """
  T4 — Prove that `AgentPlane.ActiveInferenceAgent` is a *real* JIDO agent:
  it implements the `Jido.Agent` behaviour, exposes `new/1` and `cmd/2`,
  and returns `{agent, directives}` tuples with real `Jido.Agent.Directive`
  structs.
  """
  use ExUnit.Case, async: true

  alias AgentPlane.{ActiveInferenceAgent, BundleBuilder}
  alias AgentPlane.Actions.{Act, Perceive, Plan}
  alias SharedContracts.Blanket

  setup do
    blanket = Blanket.maze_default()

    bundle =
      BundleBuilder.for_maze(
        width: 3,
        height: 1,
        start_idx: 0,
        goal_idx: 2,
        walls: [],
        blanket: blanket,
        horizon: 2,
        policy_depth: 2
      )

    {:ok, blanket: blanket, bundle: bundle}
  end

  test "agent struct is created via Jido.Agent.new and its lineage points to ActiveInferenceAgent",
       %{bundle: bundle, blanket: blanket} do
    agent = ActiveInferenceAgent.fresh("a1", bundle, blanket, goal_idx: 2)
    # JIDO 2 returns a parent %Jido.Agent{} struct; the subclass is recorded
    # in :agent_module (see jido/lib/jido/agent.ex:764).
    assert agent.__struct__ == Jido.Agent
    assert agent.agent_module == ActiveInferenceAgent
    assert agent.name == "active_inference_agent"
    assert agent.id == "a1"
  end

  test "cmd/2 returns {agent, directives} with the JIDO contract", %{
    bundle: bundle,
    blanket: blanket
  } do
    agent = ActiveInferenceAgent.fresh("a2", bundle, blanket, goal_idx: 2)

    {agent1, dirs1} =
      ActiveInferenceAgent.cmd(agent, {Perceive, %{observation: fake_obs(blanket)}})

    assert agent1.__struct__ == Jido.Agent
    assert agent1.agent_module == ActiveInferenceAgent
    assert is_list(dirs1)
    assert agent1.state.t == 0

    {agent2, _dirs2} = ActiveInferenceAgent.cmd(agent1, Plan)
    assert is_list(agent2.state.policy_posterior)
    assert_in_delta Enum.sum(agent2.state.policy_posterior), 1.0, 1.0e-6

    {_agent3, dirs3} = ActiveInferenceAgent.cmd(agent2, Act)
    assert Enum.any?(dirs3, &match?(%Jido.Agent.Directive.Emit{}, &1))
  end

  defp fake_obs(blanket) do
    SharedContracts.ObservationPacket.new(%{
      t: 0,
      channels: %{goal_cue: :unknown, tile: :start},
      world_run_id: "r",
      terminal?: false,
      blanket: blanket
    })
  end

  test "action selection on a tiny corridor converges to move_east", %{blanket: blanket} do
    # Pin argmax + softmax_temperature=1.0 so the convergence is
    # deterministic. The default bundle as of the stuck-agent fix uses
    # sampling + temperature 2.0 for exploration, which would make this
    # single-step assertion flaky.
    bundle =
      BundleBuilder.for_maze(
        width: 3,
        height: 1,
        start_idx: 0,
        goal_idx: 2,
        walls: [],
        blanket: blanket,
        horizon: 2,
        policy_depth: 2
      )
      |> Map.put(:action_selection, :argmax)
      |> Map.put(:softmax_temperature, 1.0)

    agent = ActiveInferenceAgent.fresh("a3", bundle, blanket, goal_idx: 2)

    # No observation yet: give a neutral (not-here) obs and plan.
    obs =
      SharedContracts.ObservationPacket.new(%{
        t: 0,
        channels: %{goal_cue: :unknown, tile: :start, wall_hit: :clear},
        world_run_id: "r",
        terminal?: false,
        blanket: blanket
      })

    {a1, _} = ActiveInferenceAgent.cmd(agent, {Perceive, %{observation: obs}})
    {a2, _} = ActiveInferenceAgent.cmd(a1, Plan)

    assert a2.state.last_action == :move_east
  end
end

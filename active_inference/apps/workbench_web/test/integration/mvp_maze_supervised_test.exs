defmodule WorkbenchWeb.MVPMazeSupervisedTest do
  @moduledoc """
  Plan §12 Phase 3 — closes GAP-R4.

  End-to-end: an Active Inference agent running under a real
  `Jido.AgentServer` (not pure-struct cmd/2) solves `tiny_open_goal`.
  The bus must carry the full provenance-tagged event stream AND the
  JIDO-native `runtime.jido.agent_server.signal.stop` events that prove
  telemetry is flowing from the supervised runtime layer.
  """

  use WorldModels.MnesiaCase, async: false

  alias AgentPlane.{BundleBuilder, JidoInstance, Runtime}
  alias SharedContracts.Blanket
  alias WorkbenchWeb.Episode
  alias WorldModels.{Bus, EventLog}
  alias WorldModels.EventLog.Setup
  alias WorldPlane.Worlds

  setup _ do
    :ok = Setup.ensure_schema!()
    start_supervised!({Phoenix.PubSub, name: WorldModels.Bus})

    # Clean slate: kill any lingering AgentServers.
    JidoInstance.list_agents()
    |> Enum.each(fn {id, _pid} -> Runtime.stop_agent(id) end)

    :ok
  end

  test "supervised agent solves tiny_open_goal + emits runtime telemetry" do
    world = Worlds.tiny_open_goal()
    blanket = Blanket.maze_default()

    walls =
      world.grid
      |> Enum.filter(fn {_, t} -> t == :wall end)
      |> Enum.map(fn {{c, r}, _} -> r * world.width + c end)

    start_idx = elem(world.start, 1) * world.width + elem(world.start, 0)
    goal_idx = elem(world.goal, 1) * world.width + elem(world.goal, 0)

    bundle =
      BundleBuilder.for_maze(
        width: world.width,
        height: world.height,
        start_idx: start_idx,
        goal_idx: goal_idx,
        walls: walls,
        blanket: blanket,
        horizon: 3,
        policy_depth: 3,
        spec_id: "spec-supervised-mvp"
      )

    agent_id = "agent-supervised-mvp"
    :ok = Bus.subscribe_agent(agent_id)

    {:ok, pid} =
      Episode.start_link(
        session_id: "session-supervised-mvp",
        maze: world,
        blanket: blanket,
        bundle: bundle,
        agent_id: agent_id,
        max_steps: 8,
        goal_idx: goal_idx,
        mode: :supervised
      )

    # Run to completion.
    summary =
      Stream.repeatedly(fn -> Episode.step(pid) end)
      |> Enum.reduce_while(nil, fn
        {:ok, _entry}, _acc -> {:cont, nil}
        {:done, s}, _acc -> {:halt, s}
        {:error, _}, _acc -> {:halt, nil}
      end)

    assert summary, "episode did not finish"
    assert summary.goal_reached?, "agent failed to reach goal under AgentServer"
    assert summary.steps > 0

    # The Mnesia log holds the provenance-tagged event stream for this agent.
    events = EventLog.query(agent_id: agent_id)
    assert length(events) > 0

    types = events |> Enum.map(& &1.type) |> Enum.uniq()

    # Episode-level publishes:
    assert "agent.perceived" in types
    assert "agent.planned" in types
    assert "agent.action_emitted" in types
    assert "world.observation" in types
    assert "world.terminal" in types

    # JIDO runtime telemetry — only fires under :supervised mode, which is
    # the whole point of Phase 3.
    runtime_types = Enum.filter(types, &String.starts_with?(&1, "runtime."))
    assert length(runtime_types) > 0, "no runtime.* events seen; JIDO telemetry not flowing"

    assert "runtime.jido.agent_server.signal.stop" in types,
           "supervised mode should produce signal.stop telemetry; got: #{inspect(types)}"

    # Provenance join: every supervised-run event carries the spec_id.
    action_events = Enum.filter(events, &(&1.type == "agent.action_emitted"))
    assert length(action_events) > 0

    Enum.each(action_events, fn e ->
      assert e.provenance.spec_id == "spec-supervised-mvp"
      assert e.provenance.bundle_id == bundle.bundle_id
      assert e.provenance.equation_id == "eq_4_14_policy_posterior"
    end)

    :ok = Episode.stop(pid)
  end
end

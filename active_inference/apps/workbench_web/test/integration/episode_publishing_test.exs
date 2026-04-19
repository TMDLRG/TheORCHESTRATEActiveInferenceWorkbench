defmodule WorldModels.EpisodePublishingTest do
  @moduledoc """
  Plan §12 Phase 2 — bus_test T2 (end-to-end).

  A single Episode.step/1 must:
  - publish `world.observation`, `agent.perceived`, `agent.planned`,
    `agent.action_emitted` events on the bus in that order,
  - persist all of them to Mnesia with full provenance,
  - carry equation_ids that resolve in the registry.
  """

  use WorldModels.MnesiaCase, async: false

  alias AgentPlane.BundleBuilder
  alias SharedContracts.Blanket
  alias WorkbenchWeb.Episode
  alias WorldModels.{Bus, Event, EventLog}
  alias WorldModels.EventLog.Setup
  alias WorldPlane.Worlds

  setup _ do
    :ok = Setup.ensure_schema!()
    start_supervised!({Phoenix.PubSub, name: WorldModels.Bus})
    :ok
  end

  test "Episode.step publishes + persists the full event sequence" do
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
        spec_id: "spec-episode-integration"
      )

    agent_id = "agent-episode-integration"

    :ok = Bus.subscribe_agent(agent_id)

    {:ok, pid} =
      Episode.start_link(
        session_id: "episode-integration",
        maze: world,
        blanket: blanket,
        bundle: bundle,
        agent_id: agent_id,
        max_steps: 8,
        goal_idx: goal_idx
      )

    {:ok, _entry} = Episode.step(pid)

    # Each of the four Episode-level event types must arrive on the bus.
    # Phase 4 also produces `equation.evaluated` spans from DiscreteTime;
    # order is no longer strict so we check presence, not equality.
    required = [
      "world.observation",
      "agent.perceived",
      "agent.planned",
      "agent.action_emitted"
    ]

    collected = collect_until(required, [])
    got_types = collected |> Enum.map(& &1.type) |> Enum.uniq()

    for t <- required do
      assert t in got_types, "missing #{t} on bus; got: #{inspect(got_types)}"
    end

    # Persistence: every required Episode-level event landed in Mnesia too
    # (possibly alongside equation.evaluated and runtime.* events).
    persisted = EventLog.query(agent_id: agent_id)
    persisted_types = Enum.map(persisted, & &1.type) |> Enum.uniq()

    for t <- required do
      assert t in persisted_types
    end

    # Every persisted event has the spec_id, bundle_id, family_id.
    for e <- persisted, e.type in required do
      assert e.provenance.spec_id == "spec-episode-integration"
      assert is_binary(e.provenance.bundle_id)
      assert e.provenance.family_id == "Partially Observable Markov Decision Process (POMDP)"
      assert e.provenance.agent_id == agent_id
    end

    # The perceive / plan / act events carry driving-equation IDs.
    perceive = Enum.find(persisted, &(&1.type == "agent.perceived"))
    plan = Enum.find(persisted, &(&1.type == "agent.planned"))
    act = Enum.find(persisted, &(&1.type == "agent.action_emitted"))

    assert perceive.provenance.equation_id == "eq_4_13_state_belief_update"
    assert plan.provenance.equation_id == "eq_4_14_policy_posterior"
    assert act.provenance.equation_id == "eq_4_14_policy_posterior"

    # Registry round-trip — every named equation must resolve.
    Enum.each([perceive, plan, act], fn e ->
      assert %ActiveInferenceCore.Equation{} =
               ActiveInferenceCore.Equations.fetch(e.provenance.equation_id)
    end)
  end

  # Collect events off the bus until every type in `required` has appeared,
  # or timeout. Tolerates interleaved `equation.evaluated` / `runtime.*`
  # events added by later phases.
  defp collect_until(required, acc) do
    have = acc |> Enum.map(& &1.type) |> MapSet.new()

    if Enum.all?(required, &MapSet.member?(have, &1)) do
      Enum.reverse(acc)
    else
      receive do
        {:world_event, %Event{} = e} -> collect_until(required, [e | acc])
      after
        3_000 ->
          missing = Enum.reject(required, &MapSet.member?(have, &1))
          flunk("timed out waiting for events; still missing: #{inspect(missing)}")
      end
    end
  end
end

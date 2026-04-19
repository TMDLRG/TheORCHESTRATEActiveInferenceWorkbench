defmodule WorldModels.BusTest do
  @moduledoc """
  Plan §12 Phase 2 — PubSub topic family covering global, per-agent,
  per-world, per-spec subscriptions.
  """

  use ExUnit.Case, async: false

  alias WorldModels.Bus
  alias WorldModels.Event

  setup do
    # The test Phoenix.PubSub runs at :WorldModels.Bus (same name as in prod).
    start_supervised!({Phoenix.PubSub, name: WorldModels.Bus})
    :ok
  end

  describe "T1: publishing routes to the correct topics" do
    test "subscribing to events:agent:X receives events for agent X" do
      :ok = Bus.subscribe_agent("agent-bus-1")

      e =
        Event.new(%{
          type: "agent.action_emitted",
          provenance: %{
            agent_id: "agent-bus-1",
            spec_id: nil,
            bundle_id: nil,
            family_id: nil,
            world_run_id: nil,
            equation_id: "eq_4_14_policy_posterior"
          }
        })

      :ok = Bus.broadcast(e)

      assert_receive {:world_event, %Event{id: id}}, 1_000
      assert id == e.id
    end

    test "subscribing to a different agent does not receive events" do
      :ok = Bus.subscribe_agent("agent-bus-other")

      e =
        Event.new(%{
          type: "agent.action_emitted",
          provenance: %{
            agent_id: "agent-bus-first",
            spec_id: nil,
            bundle_id: nil,
            family_id: nil,
            world_run_id: nil,
            equation_id: nil
          }
        })

      :ok = Bus.broadcast(e)
      refute_receive {:world_event, _}, 100
    end

    test "events:global receives every event regardless of agent_id" do
      :ok = Bus.subscribe_global()

      e1 =
        Event.new(%{
          type: "x",
          provenance: %{
            agent_id: "a",
            spec_id: nil,
            bundle_id: nil,
            family_id: nil,
            world_run_id: nil,
            equation_id: nil
          }
        })

      e2 =
        Event.new(%{
          type: "x",
          provenance: %{
            agent_id: "b",
            spec_id: nil,
            bundle_id: nil,
            family_id: nil,
            world_run_id: nil,
            equation_id: nil
          }
        })

      :ok = Bus.broadcast(e1)
      :ok = Bus.broadcast(e2)

      assert_receive {:world_event, %Event{id: id1}}, 500
      assert_receive {:world_event, %Event{id: id2}}, 500
      assert Enum.sort([id1, id2]) == Enum.sort([e1.id, e2.id])
    end
  end
end

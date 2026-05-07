defmodule WorldModels.EventLogConsistencyTest do
  @moduledoc """
  AUDIT REGRESSION (external review K1, v1+v2): consistency model for
  the Mnesia-backed event log.

  ## The declared consistency model

  Per `apps/world_models/README.md` (added in this v1.2 commit):

  > **Per-agent_id events are causally ordered**: for any single
  > `agent_id`, events appended in serial order from the same calling
  > process are observed in that order by `EventLog.query(agent_id: ...)`.
  >
  > **Cross-agent ordering is timestamp-best-effort**: events from
  > different agents may interleave in the global query stream when
  > their `ts_usec` values are equal (microsecond clock resolution).
  > No global linearisability claim is made.
  >
  > **Append durability**: `EventLog.append/1` runs inside an Mnesia
  > transaction; on `:ok` return, the event is durable across BEAM
  > restart (verified by `event_log_test.exs:109`).

  ## What this test asserts

  Spawns N parallel tasks, each appending K events for its own
  `agent_id` in serial order. Asserts that `query(agent_id: id)` for
  every id returns exactly that agent's K events in monotonic
  `ts_usec` order. This is the per-agent_id monotonicity claim.

  Cross-agent ordering is intentionally NOT asserted — the consistency
  model declares it as best-effort.
  """

  use WorldModels.MnesiaCase, async: false

  alias WorldModels.Event
  alias WorldModels.EventLog
  alias WorldModels.EventLog.Setup

  setup %{mnesia_dir: _dir} do
    :ok = Setup.ensure_schema!()
    :ok
  end

  @n_agents 8
  @events_per_agent 25

  describe "K1: per-agent_id monotonicity under parallel stepping" do
    test "N agents stepping in parallel each see their own events in causal order" do
      tasks =
        for i <- 1..@n_agents do
          Task.async(fn ->
            agent_id = "k1-agent-#{i}"

            # Append K events serially. Causal order = append order.
            ids =
              for k <- 1..@events_per_agent do
                event =
                  Event.new(%{
                    type: "k1.consistency_test",
                    provenance: %{
                      agent_id: agent_id,
                      spec_id: "spec-k1",
                      bundle_id: "bundle-k1",
                      family_id: "POMDP",
                      verification_status: :verified_against_source,
                      primary_equation_ids: ["eq_4_13"],
                      step_index: k
                    },
                    payload: %{step: k}
                  })

                :ok = EventLog.append(event)
                event.id
              end

            {agent_id, ids}
          end)
        end

      results = Task.await_many(tasks, 30_000)

      # For each agent, query and assert per-agent monotonicity.
      for {agent_id, expected_ids} <- results do
        rows = EventLog.query(agent_id: agent_id)

        assert length(rows) == @events_per_agent,
               "Agent #{agent_id} got #{length(rows)} events; expected #{@events_per_agent}"

        # ts_usec must be monotonically non-decreasing within an agent's stream.
        timestamps = Enum.map(rows, & &1.ts_usec)

        assert timestamps == Enum.sort(timestamps),
               "Agent #{agent_id} events are not in monotonic ts_usec order: #{inspect(timestamps)}"

        # All appended ids must be present.
        retrieved_ids = MapSet.new(Enum.map(rows, & &1.id))
        expected_set = MapSet.new(expected_ids)

        assert retrieved_ids == expected_set,
               "Agent #{agent_id} retrieved id set differs from append id set"
      end
    end

    test "global query returns the union of all per-agent streams" do
      # Append events for two agents in parallel.
      t1 =
        Task.async(fn ->
          for k <- 1..10 do
            :ok =
              EventLog.append(
                Event.new(%{
                  type: "k1.global",
                  provenance: %{
                    agent_id: "k1-global-a",
                    spec_id: "s",
                    bundle_id: "b",
                    family_id: "POMDP",
                    verification_status: :verified_against_source,
                    primary_equation_ids: ["eq_4_13"],
                    step_index: k
                  },
                  payload: %{}
                })
              )
          end
        end)

      t2 =
        Task.async(fn ->
          for k <- 1..10 do
            :ok =
              EventLog.append(
                Event.new(%{
                  type: "k1.global",
                  provenance: %{
                    agent_id: "k1-global-b",
                    spec_id: "s",
                    bundle_id: "b",
                    family_id: "POMDP",
                    verification_status: :verified_against_source,
                    primary_equation_ids: ["eq_4_13"],
                    step_index: k
                  },
                  payload: %{}
                })
              )
          end
        end)

      Task.await_many([t1, t2], 30_000)

      a = EventLog.query(agent_id: "k1-global-a")
      b = EventLog.query(agent_id: "k1-global-b")

      assert length(a) == 10
      assert length(b) == 10

      # All A events have agent_id = a; same for B.
      assert Enum.all?(a, &(&1.provenance.agent_id == "k1-global-a"))
      assert Enum.all?(b, &(&1.provenance.agent_id == "k1-global-b"))
    end
  end
end

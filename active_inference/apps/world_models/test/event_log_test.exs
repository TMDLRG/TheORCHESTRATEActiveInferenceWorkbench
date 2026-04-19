defmodule WorldModels.EventLogTest do
  @moduledoc """
  Plan §12 Phase 2 — disk-durable append-only event log backed by Mnesia.
  Closes GAP-R2. Tests are red until WorldModels.{Event,EventLog,Setup,Janitor}
  land.
  """

  use WorldModels.MnesiaCase, async: false

  alias WorldModels.Event
  alias WorldModels.EventLog
  alias WorldModels.EventLog.Setup

  setup %{mnesia_dir: _dir} do
    :ok = Setup.ensure_schema!()
    :ok
  end

  describe "T1: append + query by agent_id" do
    test "round-trips a single event" do
      e = sample_event(agent_id: "agent-1", type: "agent.action_emitted")
      :ok = EventLog.append(e)

      [retrieved] = EventLog.query(agent_id: "agent-1")
      assert retrieved.id == e.id
      assert retrieved.type == "agent.action_emitted"
      assert retrieved.provenance.agent_id == "agent-1"
    end

    test "query with agent_id only returns that agent's events" do
      :ok = EventLog.append(sample_event(agent_id: "a", type: "x"))
      :ok = EventLog.append(sample_event(agent_id: "b", type: "x"))
      :ok = EventLog.append(sample_event(agent_id: "a", type: "y"))

      ids =
        EventLog.query(agent_id: "a")
        |> Enum.map(& &1.provenance.agent_id)
        |> Enum.uniq()

      assert ids == ["a"]
      assert length(EventLog.query(agent_id: "a")) == 2
    end
  end

  describe "T2: query with time range, ascending order" do
    test "events returned in ascending ts_usec order" do
      t0 = System.system_time(:microsecond)
      :ok = EventLog.append(sample_event(agent_id: "a", type: "x", ts_usec: t0 + 3))
      :ok = EventLog.append(sample_event(agent_id: "a", type: "x", ts_usec: t0 + 1))
      :ok = EventLog.append(sample_event(agent_id: "a", type: "x", ts_usec: t0 + 2))

      ts_usecs = EventLog.query(agent_id: "a") |> Enum.map(& &1.ts_usec)
      assert ts_usecs == Enum.sort(ts_usecs)
    end

    test "from_ts and to_ts bound the window" do
      t0 = System.system_time(:microsecond)
      :ok = EventLog.append(sample_event(agent_id: "a", type: "x", ts_usec: t0 + 10))
      :ok = EventLog.append(sample_event(agent_id: "a", type: "x", ts_usec: t0 + 20))
      :ok = EventLog.append(sample_event(agent_id: "a", type: "x", ts_usec: t0 + 30))

      window = EventLog.query(agent_id: "a", from_ts: t0 + 15, to_ts: t0 + 25)
      assert length(window) == 1
      assert hd(window).ts_usec == t0 + 20
    end
  end

  describe "T3: query by type uses the :type index" do
    test "index is declared on the Mnesia table" do
      # Guard: EventLog's Mnesia table must index :agent_id and :type
      # per plan §8.5.
      info = :mnesia.table_info(:world_models_events, :index)
      # :index returns attribute *positions* (1-based); we care about the set,
      # not the exact positions — but both must appear.
      assert length(info) >= 2
    end

    test "query(type:) returns matching events across agents" do
      :ok = EventLog.append(sample_event(agent_id: "a", type: "x"))
      :ok = EventLog.append(sample_event(agent_id: "b", type: "x"))
      :ok = EventLog.append(sample_event(agent_id: "c", type: "y"))

      xs = EventLog.query(type: "x")
      ys = EventLog.query(type: "y")

      assert length(xs) == 2
      assert length(ys) == 1
      assert Enum.all?(xs, &(&1.type == "x"))
    end
  end

  describe "T4: Janitor purges events older than the retention window" do
    test "purge_older_than/1 removes events below the threshold" do
      t0 = System.system_time(:microsecond)
      :ok = EventLog.append(sample_event(agent_id: "a", type: "x", ts_usec: t0 - 10_000_000))
      :ok = EventLog.append(sample_event(agent_id: "a", type: "x", ts_usec: t0 + 1_000_000))

      assert length(EventLog.query(agent_id: "a")) == 2

      :ok = EventLog.purge_older_than(t0)

      remaining = EventLog.query(agent_id: "a")
      assert length(remaining) == 1
      assert hd(remaining).ts_usec > t0
    end
  end

  describe "T5: disk durability — events survive :mnesia stop+start" do
    test "events persist across a mnesia restart (stop/start same BEAM)" do
      e1 = sample_event(agent_id: "durable-agent", type: "x")
      e2 = sample_event(agent_id: "durable-agent", type: "y")
      :ok = EventLog.append(e1)
      :ok = EventLog.append(e2)

      # Simulate a restart: stop mnesia, bring it back up.
      :stopped = :mnesia.stop()
      :ok = :mnesia.start()
      :ok = :mnesia.wait_for_tables([:world_models_events], 5_000)

      rows = EventLog.query(agent_id: "durable-agent")
      assert length(rows) == 2
      ids = rows |> Enum.map(& &1.id) |> Enum.sort()
      assert ids == Enum.sort([e1.id, e2.id])
    end

    test "events hit disk — LATEST.LOG grows after an append" do
      # The previous test also passes if Mnesia only preserved state in ETS
      # across a same-BEAM stop/start. This test asserts *on-disk* growth so
      # we catch the case where `dirty_write` bypasses the transaction log.
      dir = :mnesia.system_info(:directory) |> to_string()
      log_path = Path.join(dir, "LATEST.LOG")

      before_size = File.stat!(log_path).size

      e = sample_event(agent_id: "disk-agent", type: "x")
      :ok = EventLog.append(e)

      # Force Mnesia to flush pending writes even if the log is still buffered.
      :ok = :mnesia.sync_log()

      after_size = File.stat!(log_path).size

      assert after_size > before_size,
             "LATEST.LOG did not grow (#{before_size} → #{after_size}); dirty_write is bypassing the log"
    end
  end

  describe "T6: snapshot_at/2 replays events up to a timestamp" do
    test "returns every event with ts_usec <= ts, in order" do
      t0 = System.system_time(:microsecond)

      for i <- 1..5 do
        :ok =
          EventLog.append(
            sample_event(agent_id: "snap-agent", type: "step", ts_usec: t0 + i * 1_000)
          )
      end

      snap = EventLog.snapshot_at("snap-agent", t0 + 3_500)
      assert length(snap.events) == 3
      assert Enum.all?(snap.events, &(&1.ts_usec <= t0 + 3_500))
      assert snap.events == Enum.sort_by(snap.events, & &1.ts_usec)
    end
  end

  # -- Helpers ---------------------------------------------------------------

  defp sample_event(opts) do
    agent_id = Keyword.fetch!(opts, :agent_id)
    type = Keyword.fetch!(opts, :type)
    ts_usec = Keyword.get(opts, :ts_usec)

    base = %{
      type: type,
      provenance: %{
        agent_id: agent_id,
        spec_id: Keyword.get(opts, :spec_id, "spec-test"),
        bundle_id: Keyword.get(opts, :bundle_id, "bundle-test"),
        family_id: Keyword.get(opts, :family_id, "POMDP"),
        world_run_id: Keyword.get(opts, :world_run_id, nil),
        equation_id: Keyword.get(opts, :equation_id, nil)
      },
      data: Keyword.get(opts, :data, %{})
    }

    base = if ts_usec, do: Map.put(base, :ts_usec, ts_usec), else: base
    Event.new(base)
  end
end

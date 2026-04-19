defmodule AgentPlane.InstancesTest do
  @moduledoc """
  S14 -- lifecycle tests for `AgentPlane.Instances`.

  Covers:
    * create + get + list
    * every legal state transition (6)
    * invalid transition rejection
    * rename + set_pid
    * purge (trashed-only)
    * empty_trash
    * orphan reconciliation (live row without an alive pid demotes to stopped)
  """
  use ExUnit.Case, async: false

  alias AgentPlane.{Instance, Instances}

  setup do
    Instances.ensure_table!()
    # Wipe between tests.  ram_copies in the unnamed test node, so
    # `:mnesia.clear_table/1` is constant-time and gives us a clean slate
    # without dragging in the full `WorldModels.MnesiaCase` apparatus.
    {:atomic, :ok} = :mnesia.clear_table(:agent_plane_instances)
    :ok
  end

  describe "create + get + list" do
    test "creates a :live instance with defaults" do
      {:ok, %Instance{} = i} = Instances.create(agent_id: "a1", spec_id: "spec-1")
      assert i.agent_id == "a1"
      assert i.spec_id == "spec-1"
      assert i.source == :studio
      assert i.state == :live
      assert is_integer(i.started_at_usec)
      assert i.started_at_usec == i.updated_at_usec
    end

    test "list filters by state" do
      {:ok, _} = Instances.create(agent_id: "a-live", spec_id: "s", state: :live)
      {:ok, _} = Instances.create(agent_id: "a-stop", spec_id: "s", state: :stopped)

      ids = fn states -> Instances.list(states: states) |> Enum.map(& &1.agent_id) end
      assert "a-live" in ids.([:live])
      assert "a-stop" not in ids.([:live])
      assert "a-stop" in ids.([:stopped])
    end

    test "list hides :trashed by default" do
      {:ok, _} = Instances.create(agent_id: "a-ok", spec_id: "s")
      {:ok, _} = Instances.create(agent_id: "a-trash", spec_id: "s", state: :trashed)

      ids = Instances.list() |> Enum.map(& &1.agent_id)
      assert "a-ok" in ids
      refute "a-trash" in ids
    end
  end

  describe "state transitions" do
    setup do
      {:ok, i} = Instances.create(agent_id: "t1", spec_id: "s", state: :live)
      %{instance: i}
    end

    test ":live -> :stopped" do
      assert {:ok, %Instance{state: :stopped}} = Instances.transition("t1", :stopped)
    end

    test ":live -> :archived" do
      assert {:ok, %Instance{state: :archived}} = Instances.transition("t1", :archived)
    end

    test ":live -> :trashed" do
      assert {:ok, %Instance{state: :trashed}} = Instances.transition("t1", :trashed)
    end

    test ":stopped -> :live" do
      {:ok, _} = Instances.transition("t1", :stopped)
      assert {:ok, %Instance{state: :live}} = Instances.transition("t1", :live)
    end

    test ":archived -> :stopped (restore)" do
      {:ok, _} = Instances.transition("t1", :archived)
      assert {:ok, %Instance{state: :stopped}} = Instances.transition("t1", :stopped)
    end

    test ":trashed -> :stopped (restore)" do
      {:ok, _} = Instances.transition("t1", :trashed)
      assert {:ok, %Instance{state: :stopped}} = Instances.transition("t1", :stopped)
    end

    test "rejects invalid transitions" do
      # live -> live is invalid (already live)
      assert {:error, :invalid_transition} = Instances.transition("t1", :live)

      {:ok, _} = Instances.transition("t1", :trashed)
      # trashed -> live is invalid (must go through :stopped)
      assert {:error, :invalid_transition} = Instances.transition("t1", :live)
    end

    test "transition on unknown agent returns :not_found" do
      assert {:error, :not_found} = Instances.transition("ghost", :stopped)
    end
  end

  describe "rename + set_pid" do
    test "rename updates name" do
      {:ok, _} = Instances.create(agent_id: "r1", spec_id: "s")
      assert {:ok, %Instance{name: "nice-name"}} = Instances.rename("r1", "nice-name")
    end

    test "set_pid updates pid" do
      {:ok, _} = Instances.create(agent_id: "p1", spec_id: "s")
      pid = self()
      assert {:ok, %Instance{pid: ^pid}} = Instances.set_pid("p1", pid)
    end
  end

  describe "purge + empty_trash" do
    test "purge requires :trashed" do
      {:ok, _} = Instances.create(agent_id: "p1", spec_id: "s")
      assert {:error, :not_trashed} = Instances.purge("p1")
    end

    test "purge on trashed removes the row" do
      {:ok, _} = Instances.create(agent_id: "p2", spec_id: "s", state: :trashed)
      assert :ok = Instances.purge("p2")
      assert :error = Instances.get("p2")
    end

    test "empty_trash removes every :trashed row" do
      {:ok, _} = Instances.create(agent_id: "e1", spec_id: "s", state: :trashed)
      {:ok, _} = Instances.create(agent_id: "e2", spec_id: "s", state: :trashed)
      {:ok, _} = Instances.create(agent_id: "e3-keep", spec_id: "s", state: :stopped)

      {:ok, deleted} = Instances.empty_trash()
      assert Enum.sort(deleted) == ["e1", "e2"]
      assert :error = Instances.get("e1")
      assert :error = Instances.get("e2")
      assert {:ok, _} = Instances.get("e3-keep")
    end
  end

  describe "reconcile_orphans" do
    test "demotes :live rows whose pid is not alive" do
      dead_pid = spawn(fn -> :ok end)
      # Give it a moment to die.
      Process.sleep(20)
      refute Process.alive?(dead_pid)

      {:ok, _} = Instances.create(agent_id: "o1", spec_id: "s", state: :live, pid: dead_pid)

      {:ok, reconciled} = Instances.reconcile_orphans()
      assert "o1" in reconciled
      assert {:ok, %Instance{state: :stopped, pid: nil}} = Instances.get("o1")
    end

    test "leaves rows with live pids alone" do
      parent = self()
      live_pid = spawn_link(fn -> receive do: ({:stop, ^parent} -> :ok) end)

      {:ok, _} = Instances.create(agent_id: "o2", spec_id: "s", state: :live, pid: live_pid)

      {:ok, reconciled} = Instances.reconcile_orphans()
      refute "o2" in reconciled
      assert {:ok, %Instance{state: :live}} = Instances.get("o2")

      send(live_pid, {:stop, parent})
    end
  end
end

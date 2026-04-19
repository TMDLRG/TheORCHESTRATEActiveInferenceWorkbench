defmodule AgentPlane.RuntimeTest do
  @moduledoc """
  Plan §12 Phase 3 — closes GAP-R4.

  Validates the `AgentPlane.Runtime` façade over `Jido.AgentServer`. Agents
  run as supervised processes (not pure-struct transforms), which is the
  precondition for JIDO's built-in telemetry to flow through to the Glass
  Engine.
  """

  use ExUnit.Case, async: false

  alias AgentPlane.{BundleBuilder, JidoInstance, Runtime}
  alias SharedContracts.Blanket
  alias WorldPlane.Worlds

  setup do
    # Ensure no zombie agents from prior tests.
    JidoInstance.list_agents()
    |> Enum.each(fn {id, _pid} -> Runtime.stop_agent(id) end)

    :ok
  end

  describe "T1: start_agent spins up a supervised Jido.AgentServer" do
    test "returns {:ok, agent_id, pid} and the agent shows up in list_agents" do
      spec = sample_spec("agent-runtime-t1", "spec-t1")

      {:ok, agent_id, pid} = Runtime.start_agent(spec)

      assert agent_id == "agent-runtime-t1"
      assert is_pid(pid)
      assert Process.alive?(pid)

      entries = JidoInstance.list_agents()
      assert Enum.any?(entries, fn {id, p} -> id == agent_id and p == pid end)

      :ok = Runtime.stop_agent(agent_id)
    end
  end

  describe "T2: state introspection carries provenance" do
    test "Jido.AgentServer.state returns state with spec/bundle/family IDs" do
      spec = sample_spec("agent-runtime-t2", "spec-t2")

      {:ok, agent_id, _pid} = Runtime.start_agent(spec)

      {:ok, %Jido.AgentServer.State{} = state} = Runtime.state(agent_id)
      agent_state = state.agent.state

      assert agent_state.spec_id == "spec-t2"
      assert agent_state.bundle_id == spec.bundle.bundle_id
      assert agent_state.family_id == "Partially Observable Markov Decision Process (POMDP)"
      assert is_list(agent_state.primary_equation_ids)
      assert "eq_4_14_policy_posterior" in agent_state.primary_equation_ids

      :ok = Runtime.stop_agent(agent_id)
    end
  end

  describe "T3: JIDO built-in telemetry fires when a signal is processed" do
    test "the supervised agent emits [:jido, :agent_server, :signal, :stop]" do
      # Attach a temporary handler for this test.
      handler_id = "test-runtime-telemetry-#{System.unique_integer([:positive])}"
      parent = self()

      :ok =
        :telemetry.attach(
          handler_id,
          [:jido, :agent_server, :signal, :stop],
          fn _event, _measures, meta, _cfg ->
            send(parent, {:signal_stop, meta})
          end,
          nil
        )

      spec = sample_spec("agent-runtime-t3", "spec-t3")
      {:ok, agent_id, _pid} = Runtime.start_agent(spec)

      # Drive one Perceive via a real Jido.Signal routed through AgentServer.
      world = Worlds.tiny_open_goal()
      blanket = Blanket.maze_default()

      obs =
        SharedContracts.ObservationPacket.new(%{
          t: 0,
          channels: %{goal_cue: :not_here},
          world_run_id: "world-t3",
          terminal?: false,
          blanket: blanket
        })

      # Drive via Runtime.perceive, which resolves the string id to a
      # pid via Jido.whereis and sends the signal through AgentServer.
      {:ok, _} = Runtime.perceive(agent_id, obs)

      assert_receive {:signal_stop, _meta}, 2_000

      # Cleanup.
      :telemetry.detach(handler_id)
      :ok = Runtime.stop_agent(agent_id)

      # Touch world/blanket so the aliases aren't reported unused.
      _ = {world, blanket}
    end
  end

  describe "T4: stop_agent publishes agent.stopped on the bus" do
    test "agent.stopped event arrives with full provenance" do
      # Inline Mnesia + Bus harness (mirrors WorldModels.MnesiaCase, which is
      # only compiled inside workbench_web's test_support).
      dir =
        System.tmp_dir!()
        |> Path.join("wm_runtime_t4_#{System.unique_integer([:positive])}")

      File.rm_rf!(dir)
      File.mkdir_p!(dir)
      :stopped = :mnesia.stop()
      :ok = Application.put_env(:mnesia, :dir, String.to_charlist(dir))
      :ok = WorldModels.EventLog.Setup.ensure_schema!()

      on_exit(fn ->
        :stopped = :mnesia.stop()
        File.rm_rf!(dir)
      end)

      start_supervised!({Phoenix.PubSub, name: WorldModels.Bus})

      :ok = WorldModels.Bus.subscribe_global()

      spec = sample_spec("agent-runtime-t4", "spec-t4")
      {:ok, agent_id, _pid} = Runtime.start_agent(spec)

      :ok = Runtime.stop_agent(agent_id)

      # Drain until we see the stopped event, ignore earlier events.
      assert_receive {:world_event, %WorldModels.Event{type: "agent.stopped", provenance: p}},
                     1_000

      assert p.agent_id == "agent-runtime-t4"
      assert p.spec_id == "spec-t4"
      assert p.family_id == "Partially Observable Markov Decision Process (POMDP)"
    end
  end

  # -- Helpers ---------------------------------------------------------------

  defp sample_spec(agent_id, spec_id) do
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
        spec_id: spec_id
      )

    %{
      agent_id: agent_id,
      spec_id: spec_id,
      bundle: bundle,
      blanket: blanket,
      goal_idx: goal_idx
    }
  end
end

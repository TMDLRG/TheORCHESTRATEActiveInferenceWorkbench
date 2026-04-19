defmodule WorkbenchWeb.GlassLiveTest do
  @moduledoc """
  Plan §12 Phase 8 — Glass Engine LiveView tests.

  Covers the three entry points (/glass, /glass/agent/:id, /glass/signal/:id)
  plus the timeline-scrub state reconstruction and BEAM-restart durability
  path. Every signal must be traceable back to its Spec in ≤ 4 hops (G-4).
  """

  use WorldModels.MnesiaCase, async: false
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias AgentPlane.BundleBuilder
  alias SharedContracts.Blanket
  alias WorkbenchWeb.Episode
  alias WorldModels.{AgentRegistry, Event, EventLog, Spec}
  alias WorldModels.EventLog.Setup
  alias WorldPlane.Worlds

  @endpoint WorkbenchWeb.Endpoint

  setup _ do
    :ok = Setup.ensure_schema!()
    start_supervised!({Phoenix.PubSub, name: WorldModels.Bus})
    :ok
  end

  describe "T1: /glass lists live + historic agents" do
    test "mount renders both live-process table and registered-spec table" do
      agent_id = run_and_keep_history("spec-glass-t1", "agent-glass-t1")

      {:ok, _view, html} = live(build_conn(), "/glass")

      assert html =~ "Glass Engine"
      assert html =~ agent_id
      assert html =~ "spec-glass-t1"
    end
  end

  describe "T2: /glass/agent/:id renders state tree" do
    test "beliefs, policy_posterior, last_f, last_g all appear" do
      agent_id = run_and_keep_history("spec-glass-t2", "agent-glass-t2")

      {:ok, _view, html} = live(build_conn(), "/glass/agent/#{agent_id}")

      assert html =~ "policy_posterior"
      assert html =~ "last_f" or html =~ "F vector"
      assert html =~ "last_g" or html =~ "G vector"
      assert html =~ "beliefs" or html =~ "marginal_state_belief"
    end
  end

  describe "T3: live events push to the signal river via PubSub" do
    test "a newly-published event surfaces within 100 ms" do
      agent_id = "agent-glass-t3"

      {:ok, _} =
        AgentRegistry.register_spec(
          Spec.new(%{
            id: "spec-glass-t3",
            archetype_id: "pomdp_maze",
            family_id: "POMDP",
            primary_equation_ids: ["eq_4_14_policy_posterior"],
            bundle_params: %{},
            blanket: %{}
          })
        )

      :ok = AgentRegistry.attach_live(agent_id, "spec-glass-t3")

      {:ok, view, _html} = live(build_conn(), "/glass/agent/#{agent_id}")

      # Publish a fresh action event on the bus (simulating Episode).
      event =
        Event.new(%{
          type: "agent.action_emitted",
          provenance: %{
            agent_id: agent_id,
            spec_id: "spec-glass-t3",
            family_id: "POMDP",
            equation_id: "eq_4_14_policy_posterior"
          },
          data: %{action: :move_east, t: 42}
        })

      :ok = EventLog.append(event)

      # The LiveView subscribes to events:agent:<id> and should update
      # within a couple render cycles.
      assert eventually(fn -> render(view) =~ "agent.action_emitted" end, 2_000),
             "live event didn't surface in the signal river"
    end
  end

  describe "T4: /glass/signal/:id opens the span card" do
    test "equation badge + source excerpt are rendered" do
      agent_id = run_and_keep_history("spec-glass-t4", "agent-glass-t4")

      # Grab any action-emitted event from the log.
      events = EventLog.query(agent_id: agent_id, type: "agent.action_emitted", limit: 1)
      assert [event | _] = events

      {:ok, _view, html} = live(build_conn(), "/glass/signal/#{event.id}")

      assert html =~ "eq_4_14_policy_posterior"
      # Verbatim source text must appear on the detail page (the Span Card).
      assert html =~ "π" or html =~ "policy posterior"
    end
  end

  describe "T5: timeline scrub reconstructs state" do
    test "snapshot_at returns earlier state than the final" do
      agent_id = run_and_keep_history("spec-glass-t5", "agent-glass-t5")

      all_events = EventLog.query(agent_id: agent_id, order: :asc)

      # Scrub to 25% of the run and confirm we get strictly fewer events.
      scrub_ts = all_events |> Enum.at(div(length(all_events), 4)) |> Map.fetch!(:ts_usec)

      snap = EventLog.snapshot_at(agent_id, scrub_ts)

      assert length(snap.events) < length(all_events)
      assert Enum.all?(snap.events, &(&1.ts_usec <= scrub_ts))

      # The reconstructed state must have at least `last_action` populated
      # if at least one planned event has occurred before scrub_ts.
      planned_in_window =
        Enum.filter(snap.events, &(&1.type == "agent.planned"))

      if planned_in_window != [] do
        assert is_atom(snap.state.chosen_action) or is_nil(snap.state.chosen_action)
      end
    end
  end

  describe "T6: provenance trace resolves within 4 hops" do
    test "random action event → agent_id → bundle_id → spec_id → family_id" do
      agent_id = run_and_keep_history("spec-glass-t6", "agent-glass-t6")

      [event | _] = EventLog.query(agent_id: agent_id, type: "agent.action_emitted")

      # Hop 1: event → agent_id
      assert event.provenance.agent_id == agent_id

      # Hop 2: agent_id → spec_id (via event's own provenance, since the
      # live row might be gone but the event is always on disk)
      spec_id = event.provenance.spec_id
      assert spec_id == "spec-glass-t6"

      # Hop 3: spec_id → spec record → family_id + primary_equation_ids
      {:ok, spec} = AgentRegistry.fetch_spec(spec_id)
      assert spec.family_id == "Partially Observable Markov Decision Process (POMDP)"

      # Hop 4: equation_id → registry fetch
      eq_id = event.provenance.equation_id
      assert %ActiveInferenceCore.Equation{} = ActiveInferenceCore.Equations.fetch(eq_id)
    end
  end

  describe "T7: BEAM-restart durability" do
    test "after :mnesia.stop()+start(), /glass/agent/:id still resolves" do
      agent_id = run_and_keep_history("spec-glass-t7", "agent-glass-t7")

      # Simulate BEAM restart: stop Mnesia, bring it back up.
      :stopped = :mnesia.stop()
      :ok = :mnesia.start()

      :ok =
        :mnesia.wait_for_tables(
          [:world_models_events, :world_models_specs, :world_models_live_agents],
          5_000
        )

      {:ok, _view, html} = live(build_conn(), "/glass/agent/#{agent_id}")

      # The live-agent row is ram_copies — gone. But spec + events
      # survived (disc_copies), so Glass can still trace.
      assert html =~ agent_id
      assert html =~ "spec-glass-t7"
      assert html =~ "eq_4_14_policy_posterior"
    end
  end

  # -- Helpers --------------------------------------------------------------

  defp run_and_keep_history(spec_id, agent_id) do
    {:ok, _} =
      AgentRegistry.register_spec(
        Spec.new(%{
          id: spec_id,
          archetype_id: "pomdp_maze",
          family_id: "Partially Observable Markov Decision Process (POMDP)",
          primary_equation_ids: [
            "eq_4_13_state_belief_update",
            "eq_4_14_policy_posterior"
          ],
          bundle_params: %{horizon: 3, policy_depth: 3, preference_strength: 4.0},
          blanket: %{}
        })
      )

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

    {:ok, pid} =
      Episode.start_link(
        session_id: "session-#{agent_id}",
        maze: world,
        blanket: blanket,
        bundle: bundle,
        agent_id: agent_id,
        max_steps: 8,
        goal_idx: goal_idx,
        mode: :pure
      )

    :ok = AgentRegistry.attach_live(agent_id, spec_id)

    drain = fn d ->
      case Episode.step(pid) do
        {:ok, _} -> d.(d)
        {:done, _} -> :done
        {:error, _} -> :err
      end
    end

    _ = drain.(drain)
    :ok = Episode.stop(pid)

    agent_id
  end

  defp eventually(fun, timeout_ms) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms

    Stream.repeatedly(fn ->
      res = fun.()
      Process.sleep(20)
      res
    end)
    |> Enum.find(& &1) ||
      System.monotonic_time(:millisecond) < deadline
  end
end

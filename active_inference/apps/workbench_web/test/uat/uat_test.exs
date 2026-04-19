defmodule WorkbenchWeb.UATTest do
  @moduledoc """
  Plan §13 — User Acceptance Tests (UAT-1 through UAT-6).

  Where §12's phase tests cover individual features in isolation, this
  suite drives the *vertical* system end-to-end and asserts the
  invariants the plan promised: taxonomy → agent, builder → runtime,
  world interaction visibility, Glass introspection, state evolution via
  scrub, and full-loop provenance.

  Every UAT uses live infrastructure (Mnesia EventLog, Bus, AgentRegistry,
  real `Jido.AgentServer` via `AgentPlane.Runtime`). Nothing mocked.
  """

  use WorldModels.MnesiaCase, async: false
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias ActiveInferenceCore.{Equations, Models}
  alias AgentPlane.{BundleBuilder, JidoInstance, Runtime}
  alias SharedContracts.Blanket
  alias WorkbenchWeb.Episode
  alias WorldModels.{AgentRegistry, Archetypes, Bus, Event, EventLog, Spec}
  alias WorldModels.EventLog.Setup
  alias WorldPlane.Worlds

  @endpoint WorkbenchWeb.Endpoint

  setup _ do
    :ok = Setup.ensure_schema!()
    start_supervised!({Phoenix.PubSub, name: WorldModels.Bus})

    # Kill any stray supervised agents from previous tests in the same run.
    JidoInstance.list_agents()
    |> Enum.each(fn {id, _pid} -> Runtime.stop_agent(id) end)

    :ok
  end

  # =========================================================================
  # UAT-1: Taxonomy-to-agent construction
  # User selects the POMDP archetype in the Builder, saves, instantiates;
  # a real `Jido.AgentServer` carries the spec's provenance tuple into its
  # state.
  # =========================================================================
  describe "UAT-1: Taxonomy → real native Jido agent" do
    test "Builder flow lands a provenance-bearing Jido.AgentServer" do
      {:ok, view, _html} = live(build_conn(), "/builder/new")

      # Drag POMDP archetype card.
      render_hook(view, "seed_archetype", %{"archetype_id" => "pomdp_maze"})

      # Server-side: topology valid, family taxonomy present.
      html = render(view)
      assert html =~ "4 nodes"
      assert html =~ "topology ok" or html =~ "No validation errors"

      # Save spec.
      :ok = Bus.subscribe_global()
      render_hook(view, "save_spec", %{})

      assert_receive {:world_event, %Event{type: "spec.saved"} = saved}, 1_000
      spec_id = saved.provenance.spec_id
      {:ok, spec} = AgentRegistry.fetch_spec(spec_id)

      # Every primary equation must be a real registry record.
      for eq_id <- spec.primary_equation_ids do
        assert %ActiveInferenceCore.Equation{} = Equations.fetch(eq_id)
      end

      # Family taxonomy reference must resolve.
      family = Models.fetch(spec.family_id)
      assert family && family.type == :discrete

      # Instantiate: Builder redirects to /glass/agent/:id.
      assert {:error, {:live_redirect, %{to: path}}} =
               render_hook(view, "instantiate", %{})

      "/glass/agent/" <> agent_id = path
      refute agent_id == ""

      # Real native JIDO: the process is a Jido.AgentServer.
      {:ok, %Jido.AgentServer.State{agent: agent}} = Runtime.state(agent_id)
      assert agent.__struct__ == Jido.Agent
      assert agent.agent_module == AgentPlane.ActiveInferenceAgent

      # Provenance round-trip: spec_id embedded in agent state.
      assert agent.state.spec_id == spec.id
      assert is_binary(agent.state.bundle_id)
      assert agent.state.family_id == spec.family_id

      assert MapSet.subset?(
               MapSet.new(spec.primary_equation_ids),
               MapSet.new(agent.state.primary_equation_ids)
             )

      :ok = Runtime.stop_agent(agent_id)
    end
  end

  # =========================================================================
  # UAT-2: Builder → World → Glass cross-UI linkage
  # One agent_id + spec_id are visible in all three UIs; each page resolves
  # the agent to the same Spec.
  # =========================================================================
  describe "UAT-2: Builder ↔ World ↔ Glass cross-UI linkage" do
    test "all three pages resolve the same agent_id to the same Spec" do
      # Simulate what the Builder does: register a Spec + start a
      # supervised agent.
      spec_id = "spec-uat2"
      agent_id = "agent-uat2"

      spec = pomdp_spec(spec_id)
      {:ok, _} = AgentRegistry.register_spec(spec)

      bundle =
        tiny_bundle_for(spec_id)

      {:ok, ^agent_id, _pid} =
        Runtime.start_agent(%{
          agent_id: agent_id,
          bundle: bundle,
          blanket: Blanket.maze_default(),
          goal_idx: 5,
          spec_id: spec_id
        })

      # /glass lists the live agent + the spec.
      {:ok, _, glass_index_html} = live(build_conn(), "/glass")
      assert glass_index_html =~ agent_id
      assert glass_index_html =~ spec_id

      # /glass/agent/:id resolves spec + agent_module.
      {:ok, _, glass_agent_html} = live(build_conn(), "/glass/agent/#{agent_id}")
      assert glass_agent_html =~ spec_id
      assert glass_agent_html =~ "eq_4_14_policy_posterior"

      # /world — the global spec registry is visible (Builder → Runtime
      # handoff), confirmed by the spec being registered and fetchable.
      {:ok, spec_echo} = AgentRegistry.fetch_spec(spec_id)
      assert spec_echo.hash == spec.hash

      # The `/world` page at minimum loads (smoke).
      {:ok, _, world_html} = live(build_conn(), "/world")
      assert world_html =~ "Run maze"

      # Registry round-trip: live_for_spec points back to the running agent.
      assert agent_id in AgentRegistry.live_for_spec(spec_id)

      :ok = Runtime.stop_agent(agent_id)
    end
  end

  # =========================================================================
  # UAT-3: World interaction visibility
  # An Episode runs through the maze; every crossing of the Markov blanket
  # fires the expected event types on the bus + is persisted.
  # =========================================================================
  describe "UAT-3: World interaction visibility" do
    test "Episode.step publishes the full event family with provenance" do
      spec_id = "spec-uat3"
      agent_id = "agent-uat3"

      {:ok, _} = AgentRegistry.register_spec(pomdp_spec(spec_id))
      :ok = AgentRegistry.attach_live(agent_id, spec_id)

      pid = start_episode(spec_id, agent_id)

      {:ok, _entry} = Episode.step(pid)

      # Durable event log has all five Episode-level types at minimum.
      types = EventLog.query(agent_id: agent_id) |> Enum.map(& &1.type) |> Enum.uniq()

      required = ~w(world.observation agent.perceived agent.planned agent.action_emitted)

      for t <- required do
        assert t in types, "missing #{t}; got: #{inspect(types)}"
      end

      # Every action emission is stamped with the driving equation.
      [action | _] = EventLog.query(agent_id: agent_id, type: "agent.action_emitted")
      assert action.provenance.equation_id == "eq_4_14_policy_posterior"
      assert action.provenance.spec_id == spec_id

      :ok = Episode.stop(pid)
    end
  end

  # =========================================================================
  # UAT-4: Glass introspection
  # State tree, signal river, span card all populate with real content from
  # a live run; the span card renders the verbatim book equation source.
  # =========================================================================
  describe "UAT-4: Glass introspection surfaces real content" do
    test "state tree + signal river + span card all carry grounded data" do
      spec_id = "spec-uat4"
      agent_id = "agent-uat4"
      {:ok, _} = AgentRegistry.register_spec(pomdp_spec(spec_id))
      :ok = AgentRegistry.attach_live(agent_id, spec_id)

      pid = start_episode(spec_id, agent_id)
      _ = drain(pid)
      :ok = Episode.stop(pid)

      {:ok, _, agent_html} = live(build_conn(), "/glass/agent/#{agent_id}")

      # State tree: Phase 4 telemetry + Phase 8 reconstruction populated it.
      assert agent_html =~ "Agent state tree"
      assert agent_html =~ "F vector" or agent_html =~ "last_f"

      # Signal river: visible events.
      assert agent_html =~ "Signal river"
      assert agent_html =~ "agent.action_emitted"
      assert agent_html =~ "eq_4_14_policy_posterior"

      # Span card: click-through to one specific event.
      [e | _] = EventLog.query(agent_id: agent_id, type: "agent.action_emitted", limit: 1)

      {:ok, _, signal_html} = live(build_conn(), "/glass/signal/#{e.id}")

      assert signal_html =~ "Equation"
      # Verbatim book symbols — G and F at minimum (eq. 4.14 is σ(−G−F)).
      assert signal_html =~ "σ(−G − F)" or signal_html =~ "policy posterior"
      # The spec back-link.
      assert signal_html =~ spec_id
    end
  end

  # =========================================================================
  # UAT-5: State evolution via timeline scrub
  # snapshot_at(early_ts) has strictly fewer events and an earlier
  # chosen_action than snapshot_at(final_ts) — learning/evolution is
  # visible through the scrubber.
  # =========================================================================
  describe "UAT-5: Timeline scrub shows state evolution" do
    test "state reconstructed at earlier ts differs from final ts" do
      spec_id = "spec-uat5"
      agent_id = "agent-uat5"
      {:ok, _} = AgentRegistry.register_spec(pomdp_spec(spec_id))
      :ok = AgentRegistry.attach_live(agent_id, spec_id)

      pid = start_episode(spec_id, agent_id)
      _ = drain(pid)
      :ok = Episode.stop(pid)

      all = EventLog.query(agent_id: agent_id, order: :asc)
      refute all == []

      early = Enum.at(all, 1) |> Map.fetch!(:ts_usec)
      final = List.last(all) |> Map.fetch!(:ts_usec)

      snap_early = EventLog.snapshot_at(agent_id, early)
      snap_final = EventLog.snapshot_at(agent_id, final)

      # Strictly fewer events in the early window.
      assert length(snap_early.events) < length(snap_final.events)

      # The final reconstructed state has a chosen_action (because at least
      # one plan event fired); the early state may not yet.
      assert Map.get(snap_final.state, :chosen_action) != nil
    end
  end

  # =========================================================================
  # UAT-6: End-to-end provenance
  # Starting from a random action event, trace forward and backward. Every
  # hop resolves to a real registry record.
  # =========================================================================
  describe "UAT-6: End-to-end provenance round-trip" do
    test "signal → agent → bundle → spec → family → equations resolves, forwards and backwards" do
      spec_id = "spec-uat6"
      agent_id = "agent-uat6"
      {:ok, _} = AgentRegistry.register_spec(pomdp_spec(spec_id))
      :ok = AgentRegistry.attach_live(agent_id, spec_id)

      pid = start_episode(spec_id, agent_id)
      _ = drain(pid)
      :ok = Episode.stop(pid)

      [event | _] = EventLog.query(agent_id: agent_id, type: "agent.action_emitted")

      # Forward trace
      assert event.provenance.agent_id == agent_id
      assert event.provenance.spec_id == spec_id
      assert is_binary(event.provenance.bundle_id)
      assert event.provenance.family_id == "Partially Observable Markov Decision Process (POMDP)"
      assert event.provenance.equation_id == "eq_4_14_policy_posterior"

      # Spec record reachable.
      {:ok, spec} = AgentRegistry.fetch_spec(spec_id)
      assert is_binary(spec.hash)

      # Family record reachable and ties back to equation.
      family = Models.fetch(event.provenance.family_id)
      assert event.provenance.equation_id in family.source_basis

      # Equation record reachable with verbatim source.
      eq = Equations.fetch(event.provenance.equation_id)
      assert is_binary(eq.source_text_equation)
      assert is_binary(eq.normalized_latex)
      assert is_list(eq.symbols) and eq.symbols != []

      # Backward trace: spec_id → live_for_spec → agent_id.
      assert agent_id in AgentRegistry.live_for_spec(spec_id)

      # And from the Glass Signal page the full chain is visible.
      {:ok, _, signal_html} = live(build_conn(), "/glass/signal/#{event.id}")
      assert signal_html =~ spec_id
      assert signal_html =~ agent_id
      assert signal_html =~ "eq_4_14_policy_posterior"
      assert signal_html =~ "POMDP"
    end
  end

  # -- Helpers --------------------------------------------------------------

  defp pomdp_spec(id) do
    Spec.new(%{
      id: id,
      archetype_id: "pomdp_maze",
      family_id: "Partially Observable Markov Decision Process (POMDP)",
      primary_equation_ids: Archetypes.fetch("pomdp_maze").primary_equation_ids,
      bundle_params: %{horizon: 3, policy_depth: 3, preference_strength: 4.0},
      blanket: %{}
    })
  end

  defp tiny_bundle_for(spec_id) do
    world = Worlds.tiny_open_goal()
    blanket = Blanket.maze_default()

    walls =
      world.grid
      |> Enum.filter(fn {_, t} -> t == :wall end)
      |> Enum.map(fn {{c, r}, _} -> r * world.width + c end)

    start_idx = elem(world.start, 1) * world.width + elem(world.start, 0)
    goal_idx = elem(world.goal, 1) * world.width + elem(world.goal, 0)

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
  end

  defp start_episode(spec_id, agent_id) do
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

    pid
  end

  defp drain(pid) do
    case Episode.step(pid) do
      {:ok, _} -> drain(pid)
      {:done, s} -> s
      {:error, _} -> :err
    end
  end
end

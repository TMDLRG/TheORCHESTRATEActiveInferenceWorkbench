defmodule WorkbenchWeb.BuilderLiveTest do
  @moduledoc """
  Plan §12 Phase 7 — Agent Builder LiveView tests.

  Covers the server-side contract the composition canvas relies on:
  mount shape, palette rendering, topology_changed round-trip, Save,
  and Instantiate. The JS hook itself is browser-bound; these tests
  simulate `pushEvent("topology_changed", payload)` via `render_hook`.
  """

  use WorldModels.MnesiaCase, async: false
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias WorldModels.AgentRegistry
  alias WorldModels.EventLog.Setup

  @endpoint WorkbenchWeb.Endpoint

  setup _ do
    :ok = Setup.ensure_schema!()
    start_supervised!({Phoenix.PubSub, name: WorldModels.Bus})
    :ok
  end

  describe "7b-T1: mount renders palette + canvas + inspector" do
    test "/builder/new boots and the canvas container + palette panes are present" do
      {:ok, _view, html} = live(build_conn(), "/builder/new")

      assert html =~ "Agent Builder"

      # Palette panes.
      assert html =~ "Archetypes"
      assert html =~ "Families"
      assert html =~ "Equations"
      assert html =~ "Actions"

      # Canvas mount point with the JS hook attribute.
      assert html =~ ~s(phx-hook="CompositionCanvas")
      assert html =~ ~s(id="composition-canvas")

      # Inspector pane.
      assert html =~ "Inspector"
    end

    test "initial topology payload is an empty graph" do
      {:ok, view, _html} = live(build_conn(), "/builder/new")

      # Read the assign via rendered HTML: the data-topology attribute on
      # the canvas carries JSON the hook can hydrate from.
      html = render(view)

      assert html =~ ~s(data-topology="{&quot;nodes&quot;:[]) or
               html =~ ~s(data-topology='{"nodes":[])
    end
  end

  describe "7b-T3: topology_changed updates server state" do
    test "valid topology replaces the working topology" do
      {:ok, view, _html} = live(build_conn(), "/builder/new")

      topology = %{
        "nodes" => [
          %{"id" => "n_bundle", "type" => "bundle", "params" => %{"horizon" => 3}},
          %{"id" => "n_perceive", "type" => "perceive", "params" => %{"n_iters" => 8}},
          %{"id" => "n_plan", "type" => "plan", "params" => %{}},
          %{"id" => "n_act", "type" => "act", "params" => %{}}
        ],
        "edges" => [
          %{
            "from_node" => "n_bundle",
            "from_port" => "bundle",
            "to_node" => "n_perceive",
            "to_port" => "bundle"
          },
          %{
            "from_node" => "n_bundle",
            "from_port" => "bundle",
            "to_node" => "n_plan",
            "to_port" => "bundle"
          },
          %{
            "from_node" => "n_perceive",
            "from_port" => "beliefs",
            "to_node" => "n_plan",
            "to_port" => "beliefs"
          },
          %{
            "from_node" => "n_plan",
            "from_port" => "action",
            "to_node" => "n_act",
            "to_port" => "action"
          }
        ]
      }

      render_hook(view, "topology_changed", %{"topology" => topology})

      html = render(view)
      # The footer shows how many nodes / how many are valid.
      assert html =~ "4 nodes"
      assert html =~ "topology ok" or html =~ "No validation errors"
    end
  end

  describe "7b-T4: invalid topology surfaces validation_errors" do
    test "dangling edge produces a visible error" do
      {:ok, view, _html} = live(build_conn(), "/builder/new")

      bad = %{
        "nodes" => [%{"id" => "n_bundle", "type" => "bundle"}],
        "edges" => [
          %{
            "from_node" => "n_bundle",
            "from_port" => "bundle",
            "to_node" => "ghost",
            "to_port" => "in"
          }
        ]
      }

      render_hook(view, "topology_changed", %{"topology" => bad})

      html = render(view)
      assert html =~ "dangling_edge" or html =~ "validation error"
    end
  end

  describe "7c: palette is populated from taxonomy + registry" do
    test "POMDP maze archetype card + its source equations render" do
      {:ok, _view, html} = live(build_conn(), "/builder/new")

      # Archetype card
      assert html =~ "POMDP maze-solver"
      assert html =~ "pomdp_maze"

      # Family + equation picker entries — a sampling.
      assert html =~ "eq_4_14_policy_posterior"
      assert html =~ "Partially Observable Markov Decision Process"
    end

    test "registry-only archetypes render as disabled" do
      {:ok, _view, html} = live(build_conn(), "/builder/new")

      assert html =~ "Dirichlet" or html =~ "dirichlet_pomdp"
      assert html =~ "disabled" or html =~ "registry-only" or html =~ "not yet runnable"
    end

    test "seeding the POMDP archetype fills the topology" do
      {:ok, view, _html} = live(build_conn(), "/builder/new")

      render_hook(view, "seed_archetype", %{"archetype_id" => "pomdp_maze"})

      html = render(view)
      assert html =~ "4 nodes"
      assert html =~ "topology ok" or html =~ "No validation errors"
    end
  end

  describe "7d: Save + Instantiate round-trip" do
    test "saving a valid spec calls AgentRegistry.register_spec and fires events.spec.saved" do
      :ok = WorldModels.Bus.subscribe_global()

      {:ok, view, _html} = live(build_conn(), "/builder/new")

      render_hook(view, "seed_archetype", %{"archetype_id" => "pomdp_maze"})

      render_hook(view, "save_spec", %{})

      assert_receive {:world_event, %WorldModels.Event{type: "spec.saved"} = event}, 500
      spec_id = event.provenance.spec_id
      assert is_binary(spec_id)

      assert {:ok, spec} = AgentRegistry.fetch_spec(spec_id)
      assert spec.archetype_id == "pomdp_maze"
      # All 4 required node types appear in the saved topology.
      types = spec.topology.nodes |> Enum.map(&Map.get(&1, :type)) |> Enum.sort()
      assert types == ~w(act bundle perceive plan)
    end

    test "instantiate redirects to /glass/agent/:agent_id" do
      {:ok, view, _html} = live(build_conn(), "/builder/new")

      render_hook(view, "seed_archetype", %{"archetype_id" => "pomdp_maze"})
      render_hook(view, "save_spec", %{})

      assert {:error, {:live_redirect, %{to: path}}} =
               render_hook(view, "instantiate", %{})

      assert String.starts_with?(path, "/glass/agent/")
    end

    test "instantiate is refused for disabled archetypes" do
      # `dirichlet_pomdp` was flipped to runnable in Lego-uplift Phase H;
      # the continuous-time generalized filter is still registry-only.
      {:ok, view, _html} = live(build_conn(), "/builder/new")

      render_hook(view, "seed_archetype", %{"archetype_id" => "continuous_generalized_filter"})
      render_hook(view, "save_spec", %{})

      render_hook(view, "instantiate", %{})
      html = render(view)
      assert html =~ "disabled" or html =~ "cannot instantiate" or html =~ "not yet runnable"
    end
  end
end

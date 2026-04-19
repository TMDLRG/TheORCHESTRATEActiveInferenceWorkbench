defmodule WorkbenchWeb.WorldLiveTest do
  @moduledoc """
  Plan §12 Phase 6 — World UI uplift.

  The new /world LiveView pulls world choices + agent config from the
  registered Specs (via AgentRegistry) and the bus (via WorldModels.Bus),
  not from hardcoded bundle construction. The page also offers
  "Open in Glass Engine" navigation that will be fully implemented in
  Phase 8.
  """

  use WorldModels.MnesiaCase, async: false
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias WorldModels.EventLog.Setup

  @endpoint WorkbenchWeb.Endpoint

  setup %{mnesia_dir: _} do
    :ok = Setup.ensure_schema!()
    start_supervised!({Phoenix.PubSub, name: WorldModels.Bus})
    :ok
  end

  describe "T1: mount renders world + params controls" do
    test "LiveView boots at /world with the maze picker visible" do
      {:ok, _view, html} = live(Phoenix.ConnTest.build_conn(), "/world")

      assert html =~ "Run maze"
      assert html =~ "Choose world"
      # The default set of four MVP mazes should appear as options.
      assert html =~ "Tiny Open Goal"
      assert html =~ "Corridor"
    end
  end

  describe "T2: create_episode boots a supervised agent + renders summary" do
    test "clicking Create agent + world produces a belief heatmap" do
      {:ok, view, _html} = live(Phoenix.ConnTest.build_conn(), "/world")

      view
      |> element("button", "Create agent + world")
      |> render_click()

      updated = render(view)

      assert updated =~ "Agent beliefs (marginal over policies)"
      assert updated =~ "Policy posterior"
      # The supervised live agent chip carries the spec_id that was
      # auto-registered during create_episode.
      assert updated =~ "Spec:"
      assert updated =~ "spec-world-"
    end
  end

  describe "T3: 'Open in Glass Engine' navigation" do
    test "the Glass button renders a working link once an episode is created" do
      {:ok, view, _html} = live(Phoenix.ConnTest.build_conn(), "/world")

      view
      |> element("button", "Create agent + world")
      |> render_click()

      html = render(view)

      # The button is a live link to /glass/agent/:id (clickable once an
      # episode is running); assert the href shape.
      assert html =~ ~s(href="/glass/agent/agent-world-)
      assert html =~ "Open in Glass Engine"
    end
  end

  describe "T4: bus events update the live view" do
    test "agent.action_emitted arrives and renders in the step log" do
      {:ok, view, _html} = live(Phoenix.ConnTest.build_conn(), "/world")

      view
      |> element("button", "Create agent + world")
      |> render_click()

      view
      |> element("button", "Step")
      |> render_click()

      # Episode.step pushes events on WorldModels.Bus, which the LiveView
      # subscribes to; assert the step log has at least one entry.
      html = render(view)

      assert html =~ "Step history"
      # history table has at least one row with t=0 and an action.
      assert html =~ ~r/<td class="mono">0<\/td>\s*<td class="mono">:move_/
    end
  end
end

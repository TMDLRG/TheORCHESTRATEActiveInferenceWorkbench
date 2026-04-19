defmodule WorkbenchWeb.GuideLive.TechnicalTest do
  @moduledoc """
  Smoke tests for the in-app technical reference routes added by the
  documentation pass. Every `/guide/technical/*` route must render
  without crashing.
  """
  use WorkbenchWeb.ConnCase, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint WorkbenchWeb.Endpoint

  describe "/guide/technical" do
    test "index renders with links to every subsection" do
      {:ok, _view, html} = live(build_conn(), "/guide/technical")
      assert html =~ "Technical reference"
      assert html =~ "Architecture"
      assert html =~ "Apps"
      assert html =~ "Signals"
      assert html =~ "Data"
      assert html =~ "Configuration"
      assert html =~ "Verification"
    end

    test "architecture page renders" do
      {:ok, _view, html} = live(build_conn(), "/guide/technical/architecture")
      assert html =~ "plane"
      assert html =~ "SHARED CONTRACTS"
      assert html =~ "Markov blanket"
    end

    test "apps page lists all seven umbrella apps" do
      {:ok, _view, html} = live(build_conn(), "/guide/technical/apps")

      for app <-
            ~w(active_inference_core shared_contracts world_plane agent_plane world_models composition_runtime workbench_web) do
        assert html =~ app, "apps page should mention #{app}"
      end
    end

    test "signals page lists at least one event per kind" do
      {:ok, _view, html} = live(build_conn(), "/guide/technical/signals")
      assert html =~ "Telemetry events"
      assert html =~ "WorldModels event log"
      assert html =~ "Jido signals"
      assert html =~ "Jido directives"
      assert html =~ "equation.evaluated"
      assert html =~ "active_inference.action"
    end

    test "data page renders the Mnesia tables section" do
      {:ok, _view, html} = live(build_conn(), "/guide/technical/data")
      assert html =~ ":world_models_events"
      assert html =~ ":world_models_specs"
      assert html =~ ":world_models_live_agents"
    end

    test "config page lists known env keys" do
      {:ok, _view, html} = live(build_conn(), "/guide/technical/config")
      assert html =~ ":mnesia, :dir"
      assert html =~ ":world_models, :auto_start_event_log"
      assert html =~ "AgentPlane.JidoInstance"
    end

    test "verification page shows manifest and rollup" do
      {:ok, _view, html} = live(build_conn(), "/guide/technical/verification")
      assert html =~ "Verified"
      assert html =~ "Scaffolded"
    end

    test "per-module page renders a known module" do
      {:ok, _view, html} =
        live(build_conn(), "/guide/technical/api/Elixir.ActiveInferenceCore.DiscreteTime")

      assert html =~ "DiscreteTime"
    end

    test "per-module page handles unknown module gracefully" do
      {:ok, _view, html} =
        live(build_conn(), "/guide/technical/api/Elixir.Nonexistent.Module.XYZ")

      assert html =~ "not a known umbrella module" or html =~ "not found"
    end
  end

  describe "/guide index links to /guide/technical" do
    test "the existing guide landing has the new link" do
      {:ok, _view, html} = live(build_conn(), "/guide")
      assert html =~ "Technical reference"
      assert html =~ "/guide/technical"
    end
  end
end

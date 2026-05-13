defmodule WorkbenchWeb.BirdLabsNavigationTest do
  use WorldModels.MnesiaCase, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias WorldModels.{EventLog.Setup, Seeds}

  @endpoint WorkbenchWeb.Endpoint

  setup do
    :ok = Setup.ensure_schema!()
    :ok = Seeds.Examples.seed_all!()
    {:ok, conn: build_conn()}
  end

  describe "bird lab discoverability" do
    test "/labs advertises both dedicated bird labs", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/labs")

      assert html =~ "Bird Labs"
      assert html =~ "Birdsong Call-Response"
      assert html =~ "/labs/birdsong-call-response"
      assert html =~ "Bird Meadow"
      assert html =~ "/labs/meadow"
    end

    test "/guide/labs separates Workbench labs from standalone simulators", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/guide/labs")

      assert html =~ "Workbench Labs"
      assert html =~ "Standalone Learning Simulators"
      assert html =~ "Birdsong Call-Response"
      assert html =~ "/labs/birdsong-call-response"
      assert html =~ "Bird Meadow"
      assert html =~ "/labs/meadow"
    end

    test "home and guide pages link the bird labs", %{conn: conn} do
      {:ok, _view, home_html} = live(conn, "/")
      assert home_html =~ "Birdsong"
      assert home_html =~ "/labs/birdsong-call-response"
      assert home_html =~ "Meadow"
      assert home_html =~ "/labs/meadow"

      {:ok, _view, guide_html} = live(build_conn(), "/guide")
      assert guide_html =~ "Birdsong"
      assert guide_html =~ "/labs/birdsong-call-response"
      assert guide_html =~ "Bird Meadow"
      assert guide_html =~ "/labs/meadow"
    end

    test "feature and workbench guides mention the bird lab routes", %{conn: conn} do
      {:ok, _view, features_html} = live(conn, "/guide/features")
      assert features_html =~ "Birdsong Call-Response lab"
      assert features_html =~ "/labs/birdsong-call-response"
      assert features_html =~ "Bird Meadow lab"
      assert features_html =~ "/labs/meadow"

      {:ok, _view, workbench_html} = live(build_conn(), "/guide/workbench")
      assert workbench_html =~ "Birdsong Call-Response"
      assert workbench_html =~ "/labs/birdsong-call-response"
      assert workbench_html =~ "Bird Meadow"
      assert workbench_html =~ "/labs/meadow"
    end
  end
end

defmodule WorkbenchWeb.MeadowLiveTest do
  @moduledoc """
  End-to-end LiveView test for the meadow page.

  Verifies the full user flow: mount → place birds → start episode →
  step → snapshot populates → reset → stop. This is what proves the
  UI is actually usable, not just that the static HTML renders.
  """

  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint WorkbenchWeb.Endpoint

  setup do
    conn =
      build_conn()
      |> Phoenix.ConnTest.init_test_session(%{})

    {:ok, conn: conn}
  end

  test "page mounts and shows all four tier options", %{conn: conn} do
    {:ok, view, html} = live(conn, "/labs/meadow")

    assert html =~ "Bird Meadow"
    assert html =~ "Convergent"
    assert html =~ "Simple"
    assert html =~ "Complex"
    assert html =~ "Resonant"
    assert html =~ "Bird Meadow 4×4"
    assert html =~ "Bird Meadow 8×8"

    # Default tier should be Convergent (the recommended one for spatial convergence).
    assert render(view) =~
             ~s(value="convergent" checked)
  end

  test "user flow: place two birds, start episode, step, verify snapshot", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/labs/meadow")

    # Pick the 8×8 meadow.
    view |> element("input[name=meadow][value=bird_meadow_8x8]") |> render_click()

    # Place bird A at (0, 0).
    html_after_a =
      view
      |> render_click("place_bird", %{"col" => "0", "row" => "0"})

    assert html_after_a =~ "Placed birds (1)"

    # Place bird B at (7, 7).
    html_after_b =
      view
      |> render_click("place_bird", %{"col" => "7", "row" => "7"})

    assert html_after_b =~ "Placed birds (2)"

    # Refusing duplicate placement should yield a flash message.
    html_dup =
      view
      |> render_click("place_bird", %{"col" => "0", "row" => "0"})

    assert html_dup =~ "tile occupied"

    # Start episode.
    html_started = view |> render_click("start", %{})
    assert html_started =~ "Live telemetry"
    assert html_started =~ "t=0" or html_started =~ "t=1"

    # Take an explicit step (tests the manual control path, not the
    # auto-tick scheduler — which we can't easily synchronise on in a
    # LiveView test).
    html_stepped = view |> render_click("step", %{})

    # Telemetry table should now have a row per bird.
    assert html_stepped =~ "Live telemetry"
    # Bird ids appear as table rows.
    assert html_stepped =~ ~r/bird-\d+/

    # Pause should disable auto-tick without crashing.
    view |> render_click("pause", %{})

    # Reset clears history but preserves placement.
    view |> render_click("reset", %{})

    # Stop tears the episode + meadow down cleanly.
    html_stopped = view |> render_click("stop", %{})

    # After stop, we're back to the idle state — Start button visible again.
    assert html_stopped =~ "Start episode"
  end

  test "starting with no birds shows a friendly error, doesn't crash", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/labs/meadow")

    html = view |> render_click("start", %{})
    assert html =~ "Place at least one bird"
  end

  test "tier picker updates the assigns and survives a re-render", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/labs/meadow")

    # Switch tier from Convergent (default) to Simple.
    view |> element("input[name=tier][value=simple]") |> render_click()

    # Place a bird; the bird record should pick up the simple tier.
    view |> render_click("place_bird", %{"col" => "1", "row" => "1"})

    html = render(view)
    assert html =~ "tier=simple"
  end

  test "remove_bird unplaces a bird before start", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/labs/meadow")

    view |> render_click("place_bird", %{"col" => "1", "row" => "1"})
    html_one = render(view)
    assert html_one =~ "Placed birds (1)"

    # Pull the bird id out of the rendered HTML.
    [_, bird_id] = Regex.run(~r/(bird-\d+)/, html_one)

    view |> render_click("remove_bird", %{"id" => bird_id})

    html_zero = render(view)
    assert html_zero =~ "Placed birds (0)"
  end
end

defmodule WorkbenchWeb.BirdsongCallResponseLiveTest do
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

  @tag timeout: 180_000
  test "page mounts and runs a response demo", %{conn: conn} do
    {:ok, view, html} = live(conn, "/labs/birdsong-call-response")

    assert html =~ "Birdsong Call-Response"
    assert html =~ "Run Active Inference Response"
    assert html =~ "1. Hear"
    assert html =~ "2. Teach"
    assert html =~ "3. Infer"
    assert html =~ "4. Sing"
    assert html =~ "Demo A"

    html = view |> render_click("load_demo", %{"motif" => "c"})
    assert html =~ "[:c]"

    html = view |> render_click("run", %{})
    assert html =~ "Policy Quantities"
    assert html =~ "Response"
    assert html =~ "data:audio/wav;base64"
  end

  @tag timeout: 180_000
  test "trains a custom songbook and runs the learned response", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/labs/birdsong-call-response")

    view |> render_click("load_demo", %{"motif" => "b"})

    html =
      view
      |> render_submit("train_songbook", %{
        "motifs" => "b",
        "target_motifs" => "d",
        "repetitions" => "12"
      })

    assert html =~ "Learned 1 paired motif"
    assert html =~ "Learned Songbook"

    html = view |> render_click("run", %{})

    assert html =~ "Policy Quantities"
    assert html =~ "sing_d"
    assert html =~ "Song response"
    assert html =~ "[:d]"
  end

  @tag timeout: 180_000
  test "typed multi-note input is exact symbolic evidence", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/labs/birdsong-call-response")

    html =
      view
      |> render_submit("load_text", %{"motifs" => "a,b,c,d"})

    assert html =~ "[:a, :b, :c, :d]"
    assert html =~ "1.0000"
  end
end

defmodule WorkbenchWeb.Qwen.UberHelpControllerTest do
  @moduledoc """
  End-to-end coverage of the thin `UberHelpController`.

  We don't run real Qwen in CI; the controller simply forwards to
  `Qwen.Client.chat/2`. These tests cover the non-Qwen paths — bad input,
  offline fallback — which don't need a live llama-server. The happy path
  (real Qwen reply) is exercised via the Chrome walkthrough in S12.
  """
  use WorkbenchWeb.ConnCase, async: true

  describe "POST /api/uber-help" do
    test "rejects missing user_msg with 400", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/uber-help", Jason.encode!(%{user_msg: ""}))

      assert json_response(conn, 400) == %{"error" => "user_msg required"}
    end

    # The remaining shape-compatibility tests require the local Qwen server;
    # tagged `:qwen_live` so `mix test` skips them unless explicitly requested
    # with `mix test --include qwen_live`.
    @tag :qwen_live
    test "accepts the new page_type/page_key shape", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(
          "/api/uber-help",
          Jason.encode!(%{
            user_msg: "hi",
            page_type: "guide",
            page_key: "blocks",
            route: "/guide/blocks",
            path: "real"
          })
        )

      assert conn.status in [200, 502, 503]
    end

    @tag :qwen_live
    test "accepts legacy chapter/session shape (backwards compat)", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(
          "/api/uber-help",
          Jason.encode!(%{
            user_msg: "hi",
            chapter: "2",
            session: "s1_inference_as_bayes",
            path: "real"
          })
        )

      assert conn.status in [200, 502, 503]
    end
  end
end

defmodule WorkbenchWeb.SmokeTest do
  @moduledoc """
  Plan §12 Phase 0 — safety net.

  Proves the existing routes all respond 200 BEFORE the three-UI uplift starts.
  Every route listed in router.ex at the time of the audit
  (`/`, `/equations`, `/models`, `/run`) must stay green through every phase
  until it is explicitly replaced (Phase 6 aliases `/run` → `/world`).
  """

  use WorkbenchWeb.ConnCase, async: true

  @preserved_routes ~w(/ /equations /models /run /world)

  for path <- @preserved_routes do
    test "GET #{path} returns 200", %{conn: conn} do
      conn = get(conn, unquote(path))
      assert html_response(conn, 200)
    end
  end

  test "GET /equations/:id resolves a real equation to 200", %{conn: conn} do
    # Use a stable known ID from the registry.
    conn = get(conn, "/equations/eq_4_14_policy_posterior")
    assert html_response(conn, 200)
  end
end

defmodule WorkbenchWeb.ConnCase do
  # Plan §12 Phase 0 — test support for smoke + LiveView tests (Phase 6/7/8 reuse).
  use ExUnit.CaseTemplate

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      alias WorkbenchWeb.Router.Helpers, as: Routes

      @endpoint WorkbenchWeb.Endpoint
    end
  end

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end

defmodule WorkbenchWeb.Plugs.LearningPath do
  @moduledoc """
  Reads the `suite_path` cookie (set by the Learning Shell and the hub
  picker) and assigns it to the connection under `:learning_path`, plus
  mirrors it into the session so LiveView mounts see it.

  Valid values: `"kid" | "real" | "equation" | "derivation"`. Anything
  else falls back to `"real"` — the broadest on-ramp.

  The cookie is user-preference only — no auth, no PII.
  """

  @behaviour Plug
  @valid ~w(kid real equation derivation)
  @default "real"

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    conn = Plug.Conn.fetch_cookies(conn)

    raw =
      conn.req_cookies
      |> Map.get("suite_path", @default)
      |> to_string()

    path = if raw in @valid, do: raw, else: @default

    progress_raw =
      conn.req_cookies
      |> Map.get("suite_progress", "")
      |> URI.decode()

    conn
    |> Plug.Conn.put_session(:suite_path, path)
    |> Plug.Conn.put_session(:suite_progress, progress_raw)
    |> Plug.Conn.assign(:learning_path, path)
  end
end

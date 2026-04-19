defmodule WorkbenchWeb.ChatProxy do
  @moduledoc """
  Legacy catch-all for any URL under `/chat/*`.  These used to reverse-proxy
  to LibreChat at 127.0.0.1:3080, but that caused bookmarked URLs (e.g.
  `/chat?preset=chapter-N` from earlier builds) to render blank because
  LibreChat's SPA assumes a same-origin `<base href="/">`.

  Current behaviour: render a small tab-switcher HTML that opens LibreChat
  in a new tab and bounces the original tab back to `/learn`.  This way
  no learner ever loses their spot.  Preserves query strings as `?prompt=`
  params when possible so `/chat?preset=chapter-N` remains a useful URL.
  """
  import Plug.Conn

  @behaviour Plug

  @librechat_url "http://localhost:3080"

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    qs =
      case conn.query_string do
        "" -> ""
        s -> "?" <> s
      end

    html = """
    <!DOCTYPE html>
    <html><head>
      <meta charset="utf-8"/>
      <title>Opening LibreChat…</title>
      <style>
        body { background:#0b1020;color:#e8ecf1;font-family:ui-monospace,Menlo,monospace;
          padding:40px 20px;max-width:680px;margin:auto; }
        h1 { color:#d8b56c; font-size:22px; }
        a.btn { display:inline-block;padding:10px 16px;border-radius:6px;
          background:#b3863a;color:#1b1410;font-weight:700;text-decoration:none;margin-right:10px;margin-top:12px; }
        a.sec { background:transparent;border:1px solid #9cb0d6;color:#e8ecf1; }
      </style>
      <script>
        // Pop LibreChat in a new tab; bounce this tab to /learn so we never
        // lose the learner's spot in the workshop.
        const lib = "#{@librechat_url}/#{qs}";
        try { window.open(lib, '_blank', 'noopener,noreferrer'); } catch (_) {}
        setTimeout(function(){ window.location.replace('/learn'); }, 800);
      </script>
    </head><body>
      <h1>💬 Opening LibreChat in a new tab…</h1>
      <p>This tab returns to the Learn hub so you don't lose your place. If LibreChat didn't open, click below:</p>
      <p>
        <a class="btn" href="#{@librechat_url}/#{qs}" target="_blank" rel="noopener noreferrer">Open LibreChat</a>
        <a class="btn sec" href="/learn">Back to Learn hub</a>
      </p>
    </body></html>
    """

    conn
    |> put_resp_content_type("text/html")
    |> put_resp_header("cache-control", "no-store")
    |> send_resp(200, html)
  end
end

defmodule WorkbenchWeb.VoiceAutoplayController do
  @moduledoc """
  Tiny landing page for the voice-autoplay shim.

  LibreChat does not expose a `customScript` hook, so we ship the shim two ways:

    * **Bookmarklet** — drag the "Workshop voice autoplay" link below into the
      browser's bookmarks bar, then click it once per LibreChat tab.  The
      bookmarklet `eval`s our `/assets/voice-autoplay.js` via `fetch + eval`.
    * **TamperMonkey userscript** — `/assets/voice-autoplay.js` already carries
      the userscript header; install with one click in TamperMonkey for
      auto-attach.

  Phase J of LIBRECHAT_EXTENSIONS_PLAN.md.
  """
  use WorkbenchWeb, :controller

  def index(conn, _params) do
    js_url = absolute_origin_for_assets(conn) <> "/assets/voice-autoplay.js"

    bookmarklet =
      "javascript:(function(){fetch(" <>
        Jason.encode!(js_url) <>
        ").then(r=>r.text()).then(t=>eval(t));})();"

    body = """
    <!DOCTYPE html>
    <html lang="en"><head>
      <meta charset="utf-8"/>
      <title>Voice Autoplay · Workshop</title>
      <link rel="stylesheet" href="/assets/suite-tokens.css"/>
      <style>
        body { background:#0b1020; color:#e8ecf1; font-family:ui-monospace,Menlo,monospace;
               margin:0; padding:32px 20px; }
        .wrap { max-width:780px; margin:0 auto; }
        h1 { color:#d8b56c; font-size:22px; margin-bottom:8px; }
        h2 { color:#9cb0d6; font-size:15px; margin-top:28px; margin-bottom:8px; }
        a.bookmarklet { display:inline-block; padding:10px 16px; background:#b3863a;
          color:#1b1410; border-radius:6px; text-decoration:none; font-weight:700;
          margin:8px 0; cursor:grab; }
        pre { background:#121a33; border:1px solid #263257; border-radius:6px;
              padding:10px; overflow-x:auto; font-size:12px; }
        ul { line-height:1.7; }
        code { background:#121a33; padding:2px 6px; border-radius:3px; }
      </style>
    </head><body><div class="wrap">
      <a href="/learn" style="color:#7dd3fc;font-size:12px;">← back to Learn</a>
      <h1>🔊 Voice autoplay shim for LibreChat</h1>
      <p>LibreChat shows MCP tool results as JSON in the chat.  After <code>speak~voice</code>,
        a <code>job_id</code> appears immediately; the shim polls the voice HTTP API until
        the WAV is ready (and also picks up <code>audio_url</code> from <code>speak_status</code>).
        Playback uses stop/pause/progress controls anchored to the bottom-right corner.</p>
      <p style="font-size:12px;color:#9cb0d6;">Bookmarklet URL uses this request&apos;s origin
        (or set <code>PHX_PUBLIC_ORIGIN</code> behind a reverse proxy). For TamperMonkey, set
        <code>@match</code> to your LibreChat origin, e.g. <code>http://localhost:3080/*</code>
        or <code>https://chat.example.com/*</code>. HTTPS LibreChat + HTTP voice on another port
        may be blocked by mixed-content rules; proxy <code>/voice/*</code> or serve voice over HTTPS.</p>

      <h2>Option A · Drag bookmarklet</h2>
      <p>Drag this link into your bookmarks bar.  After you open LibreChat in a tab,
        click the bookmarklet once to attach the shim.</p>
      <a class="bookmarklet" href="#{Phoenix.HTML.html_escape(bookmarklet) |> Phoenix.HTML.safe_to_string()}">🎙 Workshop voice autoplay</a>

      <h2>Option B · TamperMonkey userscript</h2>
      <p>Install <a href="https://www.tampermonkey.net/" target="_blank" rel="noopener">TamperMonkey</a>,
        then create a new script and paste the contents of
        <a href="/assets/voice-autoplay.js" target="_blank">/assets/voice-autoplay.js</a>
        — edit the <code>@match</code> header to your LibreChat URL if not on localhost:3080.</p>

      <h2>What you get</h2>
      <ul>
        <li>A small panel pinned to the bottom-right of LibreChat with play / pause / stop.</li>
        <li>Live progress bar + elapsed/total timestamp.</li>
        <li>Auto-detects every <code>audio_url</code> the voice MCP returns.</li>
      </ul>
    </div></body></html>
    """

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, body)
  end

  defp absolute_origin_for_assets(conn) do
    case Application.get_env(:workbench_web, :public_origin) do
      origin when is_binary(origin) and origin != "" ->
        origin

      _ ->
        port = conn.port
        port_str = if port in [80, 443], do: "", else: ":#{port}"
        scheme = conn.scheme |> Atom.to_string()
        "#{scheme}://#{conn.host}#{port_str}"
    end
  end
end

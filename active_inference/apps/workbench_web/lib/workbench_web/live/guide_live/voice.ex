defmodule WorkbenchWeb.GuideLive.Voice do
  @moduledoc "C8 -- voice features guide."
  use WorkbenchWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Voice guide",
       qwen_page_type: :guide,
       qwen_page_key: "voice",
       qwen_page_title: "Voice guide"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <p><.link navigate={~p"/guide"}>&larr; Guide</.link></p>
    <h1>Voice -- TTS, narration, and autoplay</h1>
    <p style="color:#9cb0d6;max-width:900px;">
      The suite ships local speech synthesis via two engines, a browser TTS fallback, and a
      small shim that auto-plays `speak` tool-call results in LibreChat.  Everything here is
      server-side or in-browser -- no cloud TTS is required.
    </p>

    <div class="card">
      <h2>Two engines</h2>
      <table>
        <thead><tr><th>Engine</th><th>Latency</th><th>Quality</th><th>Notes</th></tr></thead>
        <tbody>
          <tr><td>Piper TTS</td><td>&lt; 1s</td><td>Good</td><td>Default; MIT license; real-time-safe.</td></tr>
          <tr><td>XTTS-v2</td><td>~70s on CPU</td><td>High</td><td>Coqui public model; use for long-form narration.</td></tr>
          <tr><td>Browser Web Speech</td><td>immediate</td><td>Varies</td><td>Fallback if the HTTP service is down.</td></tr>
        </tbody>
      </table>
    </div>

    <div class="card">
      <h2>HTTP endpoints</h2>
      <ul>
        <li><code class="inline">GET /speech/healthz</code> -- liveness check.</li>
        <li><code class="inline">GET /speech/voices</code> -- list installed voices.</li>
        <li><code class="inline">POST /speech/speak</code> -- body <code class="inline">{text, engine, voice_id}</code>, returns <code class="inline">audio/wav</code>.</li>
        <li><code class="inline">GET /speech/narrate/chapter/:num</code> -- stream a full-chapter narration.</li>
      </ul>
    </div>

    <div class="card">
      <h2>LibreChat voice-autoplay shim</h2>
      <p>
        Bookmarklet + TamperMonkey userscript that polls <code class="inline">speak~voice</code>
        tool-call results for <code class="inline">audio_url</code> and auto-plays them.
        Install from <.link navigate={~p"/learn/voice-autoplay"}>/learn/voice-autoplay</.link>.
      </p>
    </div>

    <div class="card">
      <h2>Honest state</h2>
      <p>
        Chapter narration works for chapters with podcast coverage and falls back to browser
        TTS otherwise.  Session-page narration uses the same endpoint.  Engine selection is
        server-wide, not per-session -- tracking this in the
        <.link navigate={~p"/guide/features"}>features table</.link>.
      </p>
    </div>
    """
  end
end

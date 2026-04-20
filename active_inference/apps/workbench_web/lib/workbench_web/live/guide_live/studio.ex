defmodule WorkbenchWeb.GuideLive.Studio do
  @moduledoc "S11 -- Studio how-to page."
  use WorkbenchWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Studio guide",
       qwen_page_type: :guide,
       qwen_page_key: "studio",
       qwen_page_title: "Studio guide"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <p><.link navigate={~p"/guide"}>&larr; Guide</.link></p>
    <h1>Studio -- flexible agent runner</h1>
    <p style="color:#9cb0d6;max-width:900px;">
      Complements <.link navigate={~p"/labs"}>/labs</.link>.  Labs is the stable
      "fresh agent + fresh world per click" runner; Studio is the workshop --
      attach an existing agent to any world, manage the agent lifecycle,
      soft-delete into trash, and restore.
    </p>

    <div class="card">
      <h2>Three ways to start a run</h2>
      <ol>
        <li>
          <strong>Attach existing agent.</strong> Pick any <code class="inline">:live</code>
          or <code class="inline">:stopped</code> agent and any world; Studio runs a
          preflight compatibility check then boots an Episode against the existing agent.
        </li>
        <li>
          <strong>Instantiate from spec.</strong> Pick a seeded spec + world; Studio
          spawns a tracked agent and attaches it.
        </li>
        <li>
          <strong>Build from cookbook recipe.</strong> Pick a recipe; Studio resolves
          the closest seeded spec (same mapping the cookbook's Run-in-Labs uses) and
          instantiates + attaches.
        </li>
      </ol>
      <p>
        <.link navigate={~p"/studio/new"} class="btn primary">Start a run &rarr;</.link>
      </p>
    </div>

    <div class="card">
      <h2>Agent lifecycle</h2>
      <p><strong>Transitions:</strong></p>
      <ul>
        <li><code class="inline">:live</code> &rarr; <code class="inline">:stopped</code> (stop) &rarr; <code class="inline">:live</code> (restart) OR <code class="inline">:archived</code> OR <code class="inline">:trashed</code></li>
        <li><code class="inline">:archived</code> &rarr; <code class="inline">:stopped</code> (restore) &rarr; <code class="inline">:live</code> (restart) OR <code class="inline">:trashed</code></li>
        <li><code class="inline">:trashed</code> &rarr; <code class="inline">:stopped</code> (restore) OR GONE (empty_trash)</li>
      </ul>
      <ul>
        <li><strong><code class="inline">:live</code></strong> -- Jido process running.</li>
        <li><strong><code class="inline">:stopped</code></strong> -- process gone, metadata kept.</li>
        <li><strong><code class="inline">:archived</code></strong> -- hidden from the dashboard.</li>
        <li><strong><code class="inline">:trashed</code></strong> -- soft-deleted; visible only in <.link navigate={~p"/studio/trash"}>/studio/trash</.link>.</li>
      </ul>
    </div>

    <div class="card">
      <h2>Studio vs. Labs</h2>
      <table>
        <thead><tr><th></th><th>/labs</th><th>/studio</th></tr></thead>
        <tbody>
          <tr><th>Agent origin</th><td>Fresh spawn per click</td><td>Attach existing OR fresh spawn</td></tr>
          <tr><th>Lifecycle tracking</th><td>None</td><td>Live / stopped / archived / trashed</td></tr>
          <tr><th>World</th><td>Any registered maze</td><td>Any registered world (via <code class="inline">WorldPlane.WorldRegistry</code>)</td></tr>
          <tr><th>Custom-world ready?</th><td>No (maze-only)</td><td>Yes -- any module implementing <code class="inline">WorldPlane.WorldBehaviour</code></td></tr>
          <tr><th>Non-regression promise</th><td><strong>Stable</strong></td><td>Evolving</td></tr>
        </tbody>
      </table>
    </div>

    <div class="card">
      <h2>Future: custom world builder</h2>
      <p>
        The <code class="inline">WorldPlane.WorldBehaviour</code> contract is narrow
        (8 callbacks: <code class="inline">id/0</code>, <code class="inline">name/0</code>,
        <code class="inline">blanket/0</code>, <code class="inline">dims/0</code>,
        <code class="inline">boot/1</code>, <code class="inline">step/2</code>,
        <code class="inline">terminal?/1</code>, <code class="inline">reset/1</code>,
        <code class="inline">stop/1</code>).  A future custom world builder will let
        users define their own worlds that plug into Studio without modifying the
        runtime.  All native Jido on the BEAM.
      </p>
    </div>
    """
  end
end

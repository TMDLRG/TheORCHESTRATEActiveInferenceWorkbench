defmodule WorkbenchWeb.GuideLive.Workbench do
  @moduledoc "C6 -- workbench surfaces guide."
  use WorkbenchWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Workbench surfaces",
       qwen_page_type: :guide,
       qwen_page_key: "workbench",
       qwen_page_title: "Workbench surfaces"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <p><.link navigate={~p"/guide"}>&larr; Guide</.link></p>
    <h1>Workbench surfaces</h1>
    <p style="color:#9cb0d6;max-width:900px;">
      Six surfaces where you do real Active Inference work.  Each one runs on real native
      Jido -- no mocks.
    </p>

    <div class="card">
      <h2>/builder -- compose a spec</h2>
      <ol>
        <li>Open <.link navigate={~p"/builder/new"}>/builder/new</.link>.</li>
        <li>Drag an archetype card from the palette onto the canvas.</li>
        <li>Click any node to inspect + edit parameters.  Validation runs server-side on every edit.</li>
        <li>Save to persist a <code class="inline">WorldModels.Spec</code>.  Instantiate to boot a supervised Jido agent.</li>
      </ol>
      <p style="color:#9cb0d6;font-size:12px;">
        Tip: a <code class="inline">?recipe=&lt;slug&gt;</code> parameter pops a banner with the
        target runtime -- the cookbook "Run in Builder" button uses this.
      </p>
    </div>

    <div class="card">
      <h2>/world -- run a maze agent</h2>
      <ol>
        <li>Open <.link navigate={~p"/world"}>/world</.link>.</li>
        <li>Pick a maze.  The page auto-builds a bundle tailored to that maze (via <code class="inline">AgentPlane.BundleBuilder.for_maze/1</code>).</li>
        <li>Boot a supervised agent and step through perception / planning / action.</li>
        <li>Toggle observation channels and actions on the Blanket; run 1-1000 episode repeats.</li>
      </ol>
    </div>

    <div class="card">
      <h2>/labs -- spec x maze matrix</h2>
      <ol>
        <li>Open <.link navigate={~p"/labs"}>/labs</.link>.</li>
        <li>Pick any saved spec + any registered maze.  <code class="inline">SpecCompiler.compile/3</code> derives a fresh bundle.</li>
        <li>Run / pause / reset / stop the episode.  Live policy-direction chart + trajectory overlay.</li>
      </ol>
      <p style="color:#9cb0d6;font-size:12px;">
        <code class="inline">?recipe=&lt;slug&gt;&amp;world=&lt;id&gt;</code> boots a cookbook recipe directly (G8).
      </p>
    </div>

    <div class="card">
      <h2>/glass -- equation provenance</h2>
      <p>
        Every signal emitted by a supervised agent is back-linked to the equation that produced
        it.  Open <.link navigate={~p"/glass"}>/glass</.link> to see the per-agent and
        per-signal provenance; drill into <code class="inline">/glass/agent/:agent_id</code>.
      </p>
    </div>

    <div class="card">
      <h2>/equations -- the registry</h2>
      <p>
        28 equations from Parr, Pezzulo &amp; Friston (2022) with source-traced LaTeX.  Filter by
        chapter, verification status, or family.  Open <.link navigate={~p"/equations"}>/equations</.link>.
      </p>
    </div>

    <div class="card">
      <h2>/models -- model taxonomy</h2>
      <p>
        Eight model families (Bayesian, VFE, EFE, HMM, POMDP, Dirichlet, continuous-time, hybrid).
        Each grounded in equation IDs.  Open <.link navigate={~p"/models"}>/models</.link>.
      </p>
    </div>

    <p>
      <.link navigate={~p"/guide/cookbook"} class="btn">Cookbook format &rarr;</.link>
      <.link navigate={~p"/cookbook"} class="btn primary">Open the cookbook &rarr;</.link>
    </p>
    """
  end
end

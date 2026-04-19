defmodule WorkbenchWeb.WorkbenchLive.Index do
  use WorkbenchWeb, :live_view

  alias ActiveInferenceCore.{Equations, Models}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Overview",
       equations_count: length(Equations.all()),
       models_count: length(Models.all()),
       discrete_count: length(Equations.by_type(:discrete)),
       continuous_count: length(Equations.by_type(:continuous)),
       general_count: length(Equations.by_type(:general))
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>The ORCHESTRATE Active Inference Learning Workbench</h1>
    <p style="color:#9cb0d6; margin-bottom: 16px; max-width: 900px;">
      Built with wisdom from
      <a href="https://www.amazon.com/ORCHESTRATE-Prompting-Professional-AI-Outputs-ebook/dp/B0G2B9LG6V"
         target="_blank" rel="noopener noreferrer">THE ORCHESTRATE METHOD™</a>
      and
      <a href="https://www.amazon.com/Level-Usage-Maturity-Model-Excellence-ebook/dp/B0GS4WDVFZ"
         target="_blank" rel="noopener noreferrer">LEVEL UP</a>
      by <a href="https://www.linkedin.com/in/mpolzin/" target="_blank" rel="noopener noreferrer">Michael Polzin</a>
      — running on pure <a href="https://github.com/agentjido/jido" target="_blank" rel="noopener noreferrer">Jido</a> v2.2.0 on the BEAM,
      teaching Active Inference from Parr, Pezzulo &amp; Friston (2022, MIT Press, CC BY-NC-ND).
    </p>
    <p style="color:#9cb0d6; margin-bottom: 20px;">
      Source material: <code class="inline">Parr, Pezzulo, Friston (2022) — Active Inference,
      MIT Press. ISBN 9780262045353.</code>
    </p>

    <div class="card" style="border-color:#d8b56c;background:linear-gradient(180deg,#1a1612,#121a33);">
      <h2 style="color:#d8b56c;">New here? Start at the Learn hub.</h2>
      <p style="max-width:780px;">
        The Learn hub points you at seven hands-on Learning Labs (Bayes chips, clockwork POMDPs, free-energy forges, predictive-coding towers, and more) and every live Workbench surface. Pick a learning path once; every page respects it.
      </p>
      <p>
        <.link navigate={~p"/learn"} class="btn primary" style="background:#b3863a;border-color:#b3863a;color:#1b1410;">Open Learn hub →</.link>
      </p>
    </div>

    <div class="card" style="border-color:#1d4ed8;">
      <h2>Or jump straight in</h2>
      <p style="max-width:780px;">
        A 10-minute drag-and-drop tutorial that assembles a real JIDO Active Inference
        agent from A, B, C, D matrices and watches it solve a 3×3 maze in Glass. No
        code. No LLMs. Pure Active Inference.
      </p>
      <p>
        <.link navigate={~p"/guide/build-your-first"} class="btn primary">Build your first agent →</.link>
        <.link navigate={~p"/guide/examples"} class="btn">Try the examples →</.link>
        <.link navigate={~p"/labs"} class="btn">Open Labs →</.link>
      </p>
    </div>

    <div class="grid-3">
      <div class="card">
        <h2>Equations</h2>
        <p><%= @equations_count %> records — each traceable to chapter, section, and equation number.</p>
        <p>
          <.tag value={:discrete} /> <%= @discrete_count %>
          &nbsp; <.tag value={:continuous} /> <%= @continuous_count %>
          &nbsp; <.tag value={:general} /> <%= @general_count %>
        </p>
        <.link navigate={~p"/equations"} class="btn">Browse equations →</.link>
      </div>

      <div class="card">
        <h2>Model families</h2>
        <p><%= @models_count %> families spanning foundational Bayesian, VFE, EFE, HMM, POMDP, Dirichlet-learning, continuous-time, and hybrid.</p>
        <.link navigate={~p"/models"} class="btn">Browse models →</.link>
      </div>

      <div class="card">
        <h2>Maze MVP</h2>
        <p>Create a real JIDO Active Inference agent and run it on a prebuilt maze. See beliefs, policies, F, G, and selected actions in real time.</p>
        <.link navigate={~p"/run"} class="btn primary">Run a maze →</.link>
      </div>
    </div>

    <div class="card">
      <h2>Architecture (Markov-blanket separation)</h2>
      <p>Two umbrella apps, no cross-dependency:</p>
      <ul>
        <li><strong>World plane</strong> (<code class="inline">:world_plane</code>) — owns the generative process (eq. 8.2): maze, collisions, terminal conditions.</li>
        <li><strong>Agent plane</strong> (<code class="inline">:agent_plane</code>) — owns the generative model (eq. 8.1): beliefs, F, G, policy posterior.</li>
      </ul>
      <p>The only symbols shared across the blanket come from <code class="inline">:shared_contracts</code>: <code class="inline">ObservationPacket</code>, <code class="inline">ActionPacket</code>, and <code class="inline">Blanket</code>.</p>
      <p>
        <strong>Non-negotiables verified:</strong>
        source-traceable math ✓ &nbsp;
        world/agent separation ✓ &nbsp;
        native JIDO agents ✓
      </p>
    </div>
    """
  end
end

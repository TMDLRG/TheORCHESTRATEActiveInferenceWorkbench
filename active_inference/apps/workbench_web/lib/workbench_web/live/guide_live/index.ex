defmodule WorkbenchWeb.GuideLive.Index do
  @moduledoc """
  Guide landing — orients a newcomer to the workbench in under a minute.

  Routes:
    /guide                  → this page
    /guide/blocks           → block catalogue (auto-generated)
    /guide/examples         → five prebuilt Active Inference examples
    /guide/examples/:slug   → annotated walkthrough per example
    /guide/build-your-first → click-by-click tutorial
  """
  use WorkbenchWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Guide")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Workbench guide</h1>
    <p style="color:#9cb0d6;max-width:780px;">
      A hands-on primer. Everything here runs on pure Elixir/BEAM with native JIDO agents
      — no LLMs, no external AI. Reasoning is done by Active Inference itself: policy
      search, epistemic value, Dirichlet learning, hierarchical generative models.
    </p>

    <div class="grid-3">
      <div class="card">
        <h2>Start here</h2>
        <p>A 10-minute tutorial that builds your first POMDP agent by dragging blocks onto the canvas — no code to write.</p>
        <.link navigate={~p"/guide/build-your-first"} class="btn primary">Build your first agent →</.link>
      </div>

      <div class="card">
        <h2>Five examples</h2>
        <p>A capability gradient in the maze: basic POMDP → epistemic explorer → sophisticated planner → Dirichlet learner → hierarchical composition.</p>
        <.link navigate={~p"/guide/examples"} class="btn">See the examples →</.link>
      </div>

      <div class="card">
        <h2>Block catalogue</h2>
        <p>Every block on the Builder palette with its Zoi-schema'd params and the book equations it implements.</p>
        <.link navigate={~p"/guide/blocks"} class="btn">Browse blocks →</.link>
      </div>
    </div>

    <div class="card" style="border-color:#b3863a;background:#1a1612;">
      <h2 style="color:#d8b56c;">Cookbook · 50 runnable Active Inference recipes</h2>
      <p style="max-width:900px;">
        Every card runs end-to-end on real native Jido.  Drop one into the builder for final tweaks, or send it straight
        to the labs for a one-click boot.  Each recipe ships pure math, four audience tiers (kid / real / equation / derivation),
        an AI-UMM level badge, and citations.
      </p>
      <p>
        <.link navigate={~p"/cookbook"} class="btn primary" style="background:#b3863a;border-color:#b3863a;color:#1b1410;">
          Open the cookbook →
        </.link>
        <.link navigate={~p"/guide/cookbook"} class="btn">How to read a recipe →</.link>
      </p>
    </div>

    <div class="card">
      <h2>Brand, author, method</h2>
      <div class="grid-3">
        <div>
          <h3><.link navigate={~p"/guide/creator"}>About the Creator</.link></h3>
          <p>Michael Polzin -- books, LinkedIn, how this suite carries his work.</p>
        </div>
        <div>
          <h3><.link navigate={~p"/guide/orchestrate"}>ORCHESTRATE primer</.link></h3>
          <p>The 11 letters.  How the suite applies O-R-C at the system level and H-E-S-T-R-A-T-E per prompt.</p>
        </div>
        <div>
          <h3><.link navigate={~p"/guide/level-up"}>Level Up primer</.link></h3>
          <p>AI-UMM's six maturity levels.  Path-to-level mapping.</p>
        </div>
      </div>
    </div>

    <div class="card">
      <h2>Honest surfaces</h2>
      <div class="grid-3">
        <div>
          <h3><.link navigate={~p"/guide/features"}>Features (honest state)</.link></h3>
          <p>Every feature with a badge: works / partial / scaffold.  Source of truth.</p>
        </div>
        <div>
          <h3><.link navigate={~p"/guide/learning"}>Learning system</.link></h3>
          <p>Paths, chapters, sessions, quizzes, progress.  How the Learn hub assembles.</p>
        </div>
        <div>
          <h3><.link navigate={~p"/guide/workbench"}>Workbench surfaces</.link></h3>
          <p>/builder, /world, /labs, /glass, /equations, /models -- three-step playbooks.</p>
        </div>
        <div>
          <h3><.link navigate={~p"/guide/labs"}>Labs detail</.link></h3>
          <p>Seven simulators with launch parameters and coach agents.</p>
        </div>
        <div>
          <h3><.link navigate={~p"/guide/voice"}>Voice &amp; narration</.link></h3>
          <p>Piper, XTTS-v2, autoplay shim, narrator UX.  Honest state.</p>
        </div>
        <div>
          <h3><.link navigate={~p"/guide/chat"}>Chat integration</.link></h3>
          <p>27 agents + 16 prompt groups.  All shaped by ORCHESTRATE.</p>
        </div>
      </div>
    </div>

    <div class="card">
      <h2>Credits &amp; deep refs</h2>
      <div class="grid-3">
        <div>
          <h3><.link navigate={~p"/guide/jido"}>Jido guide</.link></h3>
          <p>Framework credit + curated knowledgebase + upstream docs.</p>
        </div>
        <div>
          <h3><.link navigate={~p"/guide/credits"}>All credits</.link></h3>
          <p>Parr/Pezzulo/Friston, Jido, LibreChat, Qwen, Piper, XTTS-v2.</p>
        </div>
        <div>
          <h3><.link navigate={~p"/guide/cookbook"}>Cookbook format</.link></h3>
          <p>How to read a recipe card and what the Run buttons do.</p>
        </div>
      </div>
    </div>

    <div class="card">
      <h2>Technical reference</h2>
      <p>
        Full transparency over the running system: every module, function, signal,
        event, data schema, config key, and verification-status callout. Data is
        introspected live from the compiled BEAM files.
      </p>
      <.link navigate={~p"/guide/technical"} class="btn">Open technical reference →</.link>
    </div>

    <div class="card" style="border-color:#d8b56c;">
      <h2 style="color:#d8b56c;">Learning Labs · hands-on simulators</h2>
      <p style="max-width:780px;">
        Seven standalone teaching simulators — chip machines, clockwork POMDPs, forges, towers, atlases, jumping frogs.
        Each has a 4-path toggle (Story / Real-world / Equation / Derivation), glossary, analogies, and printable physical exercises.
        Browse them from the unified <.link navigate={~p"/learn"}>Learn hub</.link>.
      </p>
      <div class="grid-3" style="margin-top:12px;">
        <%= for lab <- WorkbenchWeb.LearningCatalog.labs() |> Enum.take(6) do %>
          <div style="border:1px solid #263257;border-radius:6px;padding:10px;background:#0f1a34;">
            <div style="font-size:11px;color:#9cb0d6;">Tier <%= lab.tier %> · <%= lab.time_min %> min</div>
            <div style="font-weight:700;margin:2px 0 4px;color:#e3f2ff;"><%= lab.icon %>&nbsp;<%= lab.title %></div>
            <div style="font-size:12px;color:#9cb0d6;line-height:1.4;"><%= lab.blurb %></div>
            <a href={"/learninglabs/" <> lab.file} target="_top" class="btn" style="margin-top:8px;background:#b3863a;border-color:#b3863a;color:#1b1410;">Launch →</a>
          </div>
        <% end %>
      </div>
    </div>

    <div class="card">
      <h2>What is Active Inference?</h2>
      <p>
        An agent that perceives the world by updating beliefs over hidden states
        (variational free energy, <code class="inline">eq 2.5</code> /
        <code class="inline">eq 4.13</code>), and acts by choosing the policy that
        minimises the expected free energy of future beliefs
        (<code class="inline">eq 4.14</code> / <code class="inline">eq 4.10</code>).
      </p>
      <p>
        The upshot: the same variational objective explains perception
        (infer causes of observations) and action (choose policies so future
        observations match preferences). Curiosity, goal-seeking, and learning
        fall out of one equation.
      </p>
      <p>
        Source: Parr, Pezzulo, Friston — <em>Active Inference</em>, MIT Press 2022.
        All equations visible in the workbench trace back to verbatim records in
        <.link navigate={~p"/equations"}>the registry</.link>.
      </p>
    </div>

    <div class="card">
      <h2>How the workbench is wired</h2>
      <ul>
        <li><strong>World plane</strong> (<code class="inline">:world_plane</code>) owns the generative process (eq. 8.2).</li>
        <li><strong>Agent plane</strong> (<code class="inline">:agent_plane</code>) owns the generative model (eq. 8.1).</li>
        <li><strong>Composition runtime</strong> (<code class="inline">:composition_runtime</code>) hosts multi-agent compositions and routes Jido signals between them — no raw <code class="inline">send/2</code>.</li>
        <li><strong>Glass Engine</strong> traces every signal back to the book equation that produced it.</li>
      </ul>
      <p>The Markov blanket between the two planes is enforced at the mix.exs level: <code class="inline">:shared_contracts</code> is the only symbol either can import from the other.</p>
    </div>
    """
  end
end

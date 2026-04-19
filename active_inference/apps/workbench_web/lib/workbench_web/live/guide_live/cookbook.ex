defmodule WorkbenchWeb.GuideLive.Cookbook do
  @moduledoc """
  /guide/cookbook -- how to read a recipe card, how audience tiers map to
  paths, and what the Run buttons do.  D11 of the cookbook workstream.
  """
  use WorkbenchWeb, :live_view

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, page_title: "Cookbook guide")}

  @impl true
  def render(assigns) do
    ~H"""
    <p><.link navigate={~p"/guide"}>&larr; Guide</.link></p>
    <h1>How to read a cookbook recipe</h1>
    <p style="color:#9cb0d6;max-width:900px;">
      Every card in <.link navigate={~p"/cookbook"}>the cookbook</.link> is a self-contained
      mini-experiment that runs end-to-end on real native Jido.  This page explains
      how the pieces fit together and how to get from reading to running.
    </p>

    <div class="card">
      <h2>Anatomy of a recipe</h2>
      <ol>
        <li><strong>Title + Level badge.</strong> Level 1-5 maps to the AI-UMM tier from
          LEVEL UP by Michael Polzin -- a rough orientation, not a gate.</li>
        <li><strong>Run buttons.</strong>
          <em>Run in Builder</em> drops you on /builder/new with a banner of the target
          runtime so you can shape the canvas to match.  <em>Run in Labs</em> opens /labs
          pre-selecting the recipe's world so you can boot an episode in one click.</li>
        <li><strong>Math block.</strong> The canonical equation from the recipe (LaTeX
          via MathJax in-browser) plus a symbol glossary.</li>
        <li><strong>Four audience tiers.</strong> Kid, Real-World, Equation, Derivation.
          Toggle buttons switch the explanation depth.  Matches the suite's learner
          paths (see <.link navigate={~p"/learn"}>the Learn hub</.link>).</li>
        <li><strong>Runtime block.</strong> Which Jido actions and skills the recipe uses,
          the world it runs against, and the horizon / policy depth / preference
          strength it expects.  Validator <code class="inline">mix cookbook.validate</code>
          checks every entry against the live modules -- a recipe cannot ship unless
          its runtime references resolve.</li>
        <li><strong>Cross-references.</strong> Equations from the registry, figures from
          the book, chapter sessions, and related labs.</li>
        <li><strong>ORCHESTRATE block.</strong> The recipe itself was authored with the
          O-R-C foundation from THE ORCHESTRATE METHOD™ (Polzin).  You can see the
          Objective, Role, and Context the author kept in mind.</li>
        <li><strong>Credits.</strong> Parr, Pezzulo &amp; Friston (2022) for the math;
          related papers where relevant.</li>
      </ol>
    </div>

    <div class="card">
      <h2>Audience tiers vs. learner paths</h2>
      <table>
        <thead><tr><th>Recipe tier</th><th>Suite learner path</th><th>AI-UMM level</th></tr></thead>
        <tbody>
          <tr><td>Kid</td><td><code class="inline">story</code></td><td>0-1 (Curious Dabbler -> Skeptical Supervisor)</td></tr>
          <tr><td>Real-World</td><td><code class="inline">real</code></td><td>2-3 (Quality Controller -> Team Lead)</td></tr>
          <tr><td>Equation</td><td><code class="inline">equation</code></td><td>3-4 (Team Lead -> Strategic Director)</td></tr>
          <tr><td>Derivation</td><td><code class="inline">derivation</code></td><td>4-5 (Strategic Director -> Amplified Human)</td></tr>
        </tbody>
      </table>
    </div>

    <div class="card">
      <h2>50 recipes in three waves</h2>
      <ul>
        <li><strong>Wave 1 (10 MVP):</strong> Bayes fundamentals + POMDP full trajectories + VFE / EFE decompositions + planning knobs.  All run on the stock discrete-time runtime.</li>
        <li><strong>Wave 2 (20):</strong> Perception robustness, epistemic planning, preference engineering, multi-modal fusion.  Uses the G6 bundle options and the G2 <code class="inline">frog_pond</code> world.</li>
        <li><strong>Wave 3 (20):</strong> Dirichlet learning (5), sophisticated planning (5), predictive-coding hierarchy (5), continuous-time (3), hierarchical composition (2).  Uses every new Jido action and skill added in Workstream G.</li>
      </ul>
    </div>

    <div class="card">
      <h2>Authoring your own recipe</h2>
      <p>See the schema at <code class="inline">priv/cookbook/_schema.yaml</code> and run
        <code class="inline">mix cookbook.validate</code> to check your draft.  The validator
        rejects a recipe whose <code class="inline">runtime.actions_used</code> or
        <code class="inline">runtime.skills_used</code> do not resolve against live modules
        under <code class="inline">AgentPlane.Actions.*</code> and
        <code class="inline">AgentPlane.Skills.*</code>.  This is the tripwire that keeps
        "everything runs on real Jido" honest.</p>
    </div>
    """
  end
end

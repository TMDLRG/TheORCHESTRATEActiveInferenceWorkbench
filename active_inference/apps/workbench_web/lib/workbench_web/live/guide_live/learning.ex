defmodule WorkbenchWeb.GuideLive.Learning do
  @moduledoc "C5 -- learning system guide."
  use WorkbenchWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Learning guide",
       qwen_page_type: :guide,
       qwen_page_key: "learning",
       qwen_page_title: "Learning guide"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <p><.link navigate={~p"/guide"}>&larr; Guide</.link></p>
    <h1>The learning system</h1>
    <p style="color:#9cb0d6;max-width:900px;">
      The suite's Learn hub (<.link navigate={~p"/learn"}>/learn</.link>) orients you through
      11 chapters, 39 sessions, 7 learning labs, and four path voices.  This page is the field
      guide.
    </p>

    <div class="card">
      <h2>Four paths</h2>
      <p>Pick once on the hub; every page respects the choice via cookie.</p>
      <ul>
        <li><strong>Story</strong> (<code class="inline">?path=kid</code>) -- 5th-grade vocabulary, everyday analogies.</li>
        <li><strong>Real-World</strong> (<code class="inline">?path=real</code>) -- default; grade-8 vocabulary, practical framings.</li>
        <li><strong>Equation</strong> (<code class="inline">?path=equation</code>) -- Unicode math + cited equation numbers.</li>
        <li><strong>Derivation</strong> (<code class="inline">?path=derivation</code>) -- proof sketches + book references.</li>
      </ul>
      <p style="color:#9cb0d6;font-size:12px;">
        Paths map to AI-UMM levels (see <.link navigate={~p"/guide/level-up"}>Level Up primer</.link>).
      </p>
    </div>

    <div class="card">
      <h2>Chapters (11)</h2>
      <p>Preface + Chapters 1-10.  Each chapter page has:</p>
      <ul>
        <li>Hero blurb, page range, prerequisites.</li>
        <li>Chapter-audio player (where podcast files exist).</li>
        <li>"Narrate this chapter" button (browser TTS fallback).</li>
        <li>Linked chapter-specialist agent (<code class="inline">aif-chNN-<em>slug</em></code>) -- deep-linked starter prompt into LibreChat.</li>
      </ul>
    </div>

    <div class="card">
      <h2>Sessions (39)</h2>
      <p>Fine-grained atomic lessons.  Each has:</p>
      <ul>
        <li>Four <code class="inline">path_text</code> variants (kid / real / equation / derivation).</li>
        <li>An attached quiz (Qwen-graded on submission).</li>
        <li>Linked labs and Workbench routes for hands-on practice.</li>
        <li>A hero concept + book excerpt for reading-mode.</li>
      </ul>
    </div>

    <div class="card">
      <h2>Learning labs (7)</h2>
      <p>See <.link navigate={~p"/guide/labs"}>the labs guide</.link> for subsystem details.</p>
      <ul>
        <li><strong>BayesChips</strong> (<code class="inline">/learn/lab/bayes</code>) -- single-step Bayes.</li>
        <li><strong>POMDP Machine</strong> -- belief + policy visualisation.</li>
        <li><strong>Free Energy Forge</strong> -- Eq 4.19 decomposition.</li>
        <li><strong>Laplace Tower</strong> -- multi-level predictive coding.</li>
        <li><strong>Anatomy Studio</strong> -- Figure 5.5 primitives.</li>
        <li><strong>Cortical Atlas</strong> -- neuromodulator + precision.</li>
        <li><strong>Jumping Frog</strong> -- multi-modal inference.</li>
      </ul>
    </div>

    <div class="card">
      <h2>Progress &amp; memory</h2>
      <p>
        Per-session completion is tracked in the browser (localStorage) and surfaced on
        <.link navigate={~p"/learn/progress"}>/learn/progress</.link>.  Server-side
        progress sync is scaffolded but not yet persisted.
      </p>
    </div>

    <p>
      <.link navigate={~p"/guide/labs"} class="btn">Labs detail &rarr;</.link>
      <.link navigate={~p"/guide/chat"} class="btn">Chat integration &rarr;</.link>
      <.link navigate={~p"/guide/voice"} class="btn">Voice detail &rarr;</.link>
    </p>
    """
  end
end

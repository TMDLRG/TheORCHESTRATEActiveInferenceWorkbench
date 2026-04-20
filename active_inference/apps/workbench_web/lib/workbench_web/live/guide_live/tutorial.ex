defmodule WorkbenchWeb.GuideLive.Tutorial do
  @moduledoc """
  Build-your-first-agent tutorial — walks a newcomer through assembling
  L1 (Hello POMDP) in the Builder canvas without writing code.
  """
  use WorkbenchWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Build your first agent",
       step: 1,
       qwen_page_type: :guide,
       qwen_page_key: "tutorial",
       qwen_page_title: "Build your first agent"
     )}
  end

  @impl true
  def handle_event("goto", %{"step" => step}, socket) do
    step = String.to_integer(step)
    {:noreply, assign(socket, step: max(1, min(step, 6)))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Build your first active-inference agent</h1>
    <p style="color:#9cb0d6;max-width:780px;">
      In ten minutes you'll assemble the canonical POMDP loop — A, B, C, D, perceive,
      plan, act — and watch it solve a 3×3 maze. No code. Every step maps to a block
      you drag onto the canvas.
    </p>

    <nav class="tutorial-nav">
      <%= for s <- 1..6 do %>
        <button class={"btn " <> if s == @step, do: "primary", else: ""}
                phx-click="goto" phx-value-step={s}>
          <%= step_label(s) %>
        </button>
      <% end %>
    </nav>

    <div class="card">
      <%= render_step(assigns) %>
    </div>

    <div class="card">
      <h3>Shortcut — skip the tutorial</h3>
      <p>
        Every step of this tutorial produces the same spec the seeded example ships with.
        If you'd rather jump in:
      </p>
      <.link navigate={~p"/guide/examples/l1-hello-pomdp"} class="btn">Open L1 walkthrough →</.link>
      <.link navigate={~p"/builder/new"} class="btn">Open Builder →</.link>
    </div>

    <style>
      .tutorial-nav {
        display: flex; gap: 8px; margin: 12px 0; flex-wrap: wrap;
      }
      .tutorial-nav .btn { font-size: 12px; }
    </style>
    """
  end

  defp step_label(1), do: "1. Pick a world"
  defp step_label(2), do: "2. Drop the matrices"
  defp step_label(3), do: "3. Wire the bundle"
  defp step_label(4), do: "4. Add Perceive/Plan/Act"
  defp step_label(5), do: "5. Save & Instantiate"
  defp step_label(6), do: "6. Watch in Glass"

  defp render_step(assigns) do
    case assigns.step do
      1 ->
        ~H"""
        <h2>Step 1 — Pick a world</h2>
        <p>Open the Builder and set the world to <code class="inline">tiny_open_goal</code>.</p>
        <ol>
          <li>Go to <.link navigate={~p"/builder/new"}>Builder</.link>.</li>
          <li>In the World picker (top-left of the canvas), select <code class="inline">tiny_open_goal (3×3)</code>.</li>
          <li>This is a single-corridor maze: one east step solves it. Small on purpose — perfect to verify the pipeline.</li>
        </ol>
        <p><strong>Why it matters:</strong> the world determines the blanket (which channels the agent sees, which actions it can emit). The Builder will auto-size A, B, C, D to match.</p>
        """

      2 ->
        ~H"""
        <h2>Step 2 — Drop the matrices</h2>
        <p>Drag four blocks from the palette onto the canvas:</p>
        <ul>
          <li><code class="inline">likelihood_matrix</code> (A) — maps hidden states to observations.</li>
          <li><code class="inline">transition_matrix</code> (B) — per-action state dynamics.</li>
          <li><code class="inline">preference_vector</code> (C) — log-odds preferences over observations. Goal cue gets high preference.</li>
          <li><code class="inline">prior_vector</code> (D) — starting belief distribution over states.</li>
        </ul>
        <p>Click any matrix to open the Inspector on the right; you can edit cells directly, paste CSV, or click "uniform"/"randomize" helpers.</p>
        <p><strong>Why four blocks?</strong> A POMDP generative model is exactly A, B, C, D (plus optional E for habit priors). Every learned quantity comes back to these.</p>
        """

      3 ->
        ~H"""
        <h2>Step 3 — Wire the bundle</h2>
        <p>Drop a <code class="inline">bundle_assembler</code> block. Connect each matrix's output port to the corresponding input on the assembler:</p>
        <ul>
          <li>A → <code class="inline">A</code></li>
          <li>B → <code class="inline">B</code></li>
          <li>C → <code class="inline">C</code></li>
          <li>D → <code class="inline">D</code></li>
        </ul>
        <p>The assembler produces a single <code class="inline">:bundle</code> output that the downstream blocks consume.</p>
        <p>The canvas shows <strong>topology ok</strong> in the header when every required port is wired; a red badge appears on any node with a shape mismatch.</p>
        """

      4 ->
        ~H"""
        <h2>Step 4 — Add Perceive, Plan, Act</h2>
        <p>Drop the three action blocks and wire them:</p>
        <ul>
          <li><code class="inline">perceive</code> — takes <code class="inline">:bundle</code> and <code class="inline">:obs</code>, emits beliefs. Implements <code class="inline">eq 4.13</code>.</li>
          <li><code class="inline">plan</code> — takes <code class="inline">:bundle</code> and <code class="inline">:beliefs</code>, emits the policy posterior and chosen action. Implements <code class="inline">eq 4.14</code>.</li>
          <li><code class="inline">act</code> — takes the action, emits a signal back to the world plane.</li>
        </ul>
        <p>Wire: <code class="inline">bundle_assembler → perceive → plan → act</code>.</p>
        """

      5 ->
        ~H"""
        <h2>Step 5 — Save & Instantiate</h2>
        <p>Click <strong>Save</strong> — the Builder persists a <code class="inline">WorldModels.Spec</code> to Mnesia and shows you its hash.</p>
        <p>Click <strong>Instantiate</strong>. The server:</p>
        <ol>
          <li>Starts a supervised <code class="inline">Jido.AgentServer</code> under <code class="inline">AgentPlane.JidoInstance</code>.</li>
          <li>Boots a <code class="inline">WorldPlane.Engine</code> for your maze.</li>
          <li>Attaches them through the shared blanket (<code class="inline">ObservationPacket</code>, <code class="inline">ActionPacket</code>).</li>
          <li>Navigates you to <code class="inline">/glass/agent/:agent_id</code>.</li>
        </ol>
        """

      6 ->
        ~H"""
        <h2>Step 6 — Watch it in Glass</h2>
        <p>The Glass Engine is live. You'll see:</p>
        <ul>
          <li>The <strong>signal river</strong> — every <code class="inline">agent.perceived</code>, <code class="inline">agent.planned</code>, <code class="inline">agent.action_emitted</code>, and <code class="inline">equation.evaluated</code> event, timestamped to microseconds.</li>
          <li>The <strong>primary equations</strong> that produced each signal — click one to jump to the registry.</li>
          <li>The <strong>spec provenance</strong> that hydrated this agent.</li>
        </ul>
        <p>Open <.link navigate={~p"/world"}>/world</.link> in a second tab to see the agent's <code class="inline">@</code> glyph move across the maze in real time (LiveView pushes to both tabs simultaneously).</p>
        <h3>Now run it</h3>
        <p>Skip the manual rebuild — the saved L1 spec is already in Mnesia:</p>
        <.link
          navigate={~p"/labs/run?spec_id=example-l1-hello-pomdp&world_id=tiny_open_goal"}
          class="btn primary">
          Run L1 on tiny_open_goal →
        </.link>
        <h3>Next</h3>
        <p>Four more examples teach epistemic drive, sophisticated planning, Dirichlet learning, and hierarchical composition:</p>
        <.link navigate={~p"/guide/examples"} class="btn primary">See the capability gradient →</.link>
        """
    end
  end
end

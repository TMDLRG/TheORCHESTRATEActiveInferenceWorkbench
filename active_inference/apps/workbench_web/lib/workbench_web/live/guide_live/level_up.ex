defmodule WorkbenchWeb.GuideLive.LevelUp do
  @moduledoc "C3 -- AI-UMM primer, copyright-safe."
  use WorkbenchWeb, :live_view

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, page_title: "Level Up primer")}

  @impl true
  def render(assigns) do
    ~H"""
    <p><.link navigate={~p"/guide"}>&larr; Guide</.link></p>
    <h1>LEVEL UP -- The AI Usage Maturity Model</h1>

    <p style="color:#9cb0d6;max-width:900px;">
      <a href="https://www.amazon.com/Level-Usage-Maturity-Model-Excellence-ebook/dp/B0GS4WDVFZ"
         target="_blank" rel="noopener noreferrer"><em>LEVEL UP</em></a> by Michael Polzin is
      a maturity framework for AI adoption.  This suite uses it as a gentle orientation overlay
      -- not a gate.  Every learner path, every lab, every cookbook recipe carries a Level 1-5
      badge so you can see where a given piece of content sits.
    </p>

    <div class="card">
      <h2>The six AI-UMM levels</h2>
      <table>
        <thead>
          <tr><th>Level</th><th>Name</th><th>Persona</th></tr>
        </thead>
        <tbody>
          <tr><td><strong>0</strong></td><td>None</td><td>The Curious Dabbler</td></tr>
          <tr><td><strong>1</strong></td><td>Initial</td><td>The Skeptical Supervisor</td></tr>
          <tr><td><strong>2</strong></td><td>Managed</td><td>The Quality Controller</td></tr>
          <tr><td><strong>3</strong></td><td>Defined</td><td>The Team Lead</td></tr>
          <tr><td><strong>4</strong></td><td>Quantitative</td><td>The Strategic Director</td></tr>
          <tr><td><strong>5</strong></td><td>Optimizing</td><td>The Amplified Human</td></tr>
        </tbody>
      </table>
    </div>

    <div class="card">
      <h2>Path-to-level mapping</h2>
      <p>The suite's learner paths (see <.link navigate={~p"/learn"}>the Learn hub</.link>) map
        loosely onto the AI-UMM levels:</p>
      <table>
        <thead>
          <tr><th>Suite path</th><th>Recommended AI-UMM levels</th></tr>
        </thead>
        <tbody>
          <tr><td><code class="inline">story</code></td><td>0-1 (Curious Dabbler -> Skeptical Supervisor)</td></tr>
          <tr><td><code class="inline">real</code></td><td>2-3 (Quality Controller -> Team Lead)</td></tr>
          <tr><td><code class="inline">equation</code></td><td>3-4 (Team Lead -> Strategic Director)</td></tr>
          <tr><td><code class="inline">derivation</code></td><td>4-5 (Strategic Director -> Amplified Human)</td></tr>
        </tbody>
      </table>
      <p style="color:#9cb0d6;font-size:12px;">
        This mapping is orientational only.  Levels are descriptive, not prescriptive -- you can
        read anything at any time.  The full AI-UMM framework includes an assessment instrument
        that is <strong>not</strong> shipped here; it lives in the book.
      </p>
    </div>

    <p>
      <.link navigate={~p"/guide/creator"} class="btn">About the author &rarr;</.link>
      <.link navigate={~p"/guide/orchestrate"} class="btn">ORCHESTRATE primer &rarr;</.link>
    </p>
    """
  end
end

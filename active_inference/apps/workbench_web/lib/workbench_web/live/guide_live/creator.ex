defmodule WorkbenchWeb.GuideLive.Creator do
  @moduledoc "C1 -- About Michael Polzin."
  use WorkbenchWeb, :live_view

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, page_title: "About the Creator")}

  @impl true
  def render(assigns) do
    ~H"""
    <p><.link navigate={~p"/guide"}>&larr; Guide</.link></p>
    <h1>About the Creator</h1>

    <div class="card">
      <h2>Michael Polzin</h2>
      <p>
        Michael Polzin is the author of <em>THE ORCHESTRATE METHOD™</em> and
        <em>LEVEL UP: The AI Usage Maturity Model</em>, and the creator of the
        AI-UMM Framework.  His books codify a systematic approach to prompting
        professional-grade AI outputs and to measuring the organisational
        maturity required to deploy AI well.  This workbench embodies both.
      </p>
      <p>
        <a href="https://www.linkedin.com/in/mpolzin/" target="_blank" rel="noopener noreferrer">
          Connect on LinkedIn &rarr;
        </a>
      </p>
    </div>

    <div class="card">
      <h2>Books</h2>
      <ul>
        <li>
          <a href="https://www.amazon.com/ORCHESTRATE-Prompting-Professional-AI-Outputs-ebook/dp/B0G2B9LG6V"
             target="_blank" rel="noopener noreferrer">
            <strong>THE ORCHESTRATE METHOD™</strong> -- Systematic Prompting for Professional AI Outputs
          </a>
          <br/>
          ISBN 9798274456920 -- the 11-letter framework this suite applies to every prompt (see
          <.link navigate={~p"/guide/orchestrate"}>the ORCHESTRATE primer</.link>).
        </li>
        <li style="margin-top:12px;">
          <a href="https://www.amazon.com/Level-Usage-Maturity-Model-Excellence-ebook/dp/B0GS4WDVFZ"
             target="_blank" rel="noopener noreferrer">
            <strong>LEVEL UP</strong> -- The AI Usage Maturity Model
          </a>
          <br/>
          ISBN 9798251618921 -- the 6-level maturity framework overlaid on the suite's learner paths
          (see <.link navigate={~p"/guide/level-up"}>the Level Up primer</.link>).
        </li>
        <li style="margin-top:12px;">
          <em>Run on Rhythm: Build a Business That Doesn't Run You</em> -- also by Polzin.
        </li>
      </ul>
    </div>

    <div class="card">
      <h2>How this suite carries his work</h2>
      <ul>
        <li>Every agent and saved prompt is shaped by O-R-C (see
          <code class="inline">tools/librechat_seed/PROMPT_DESIGN.md</code>).</li>
        <li>Every page in the guide honours the copyright-safe authoring rule --
          we <em>apply</em> the frameworks but never reproduce book prose.</li>
        <li>The cookbook's AI-UMM level badges (1-5) come from LEVEL UP.</li>
      </ul>
    </div>

    <p>
      <.link navigate={~p"/guide/orchestrate"} class="btn">ORCHESTRATE primer &rarr;</.link>
      <.link navigate={~p"/guide/level-up"} class="btn">Level Up primer &rarr;</.link>
      <.link navigate={~p"/guide/credits"} class="btn">All credits &rarr;</.link>
    </p>
    """
  end
end

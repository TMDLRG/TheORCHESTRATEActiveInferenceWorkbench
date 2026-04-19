defmodule WorkbenchWeb.GuideLive.Orchestrate do
  @moduledoc "C2 -- ORCHESTRATE primer, copyright-safe."
  use WorkbenchWeb, :live_view

  @impl true
  def mount(_params, _session, socket),
    do: {:ok, assign(socket, page_title: "ORCHESTRATE primer")}

  @impl true
  def render(assigns) do
    ~H"""
    <p><.link navigate={~p"/guide"}>&larr; Guide</.link></p>
    <h1>THE ORCHESTRATE METHOD -- how this suite applies it</h1>

    <p style="color:#9cb0d6;max-width:900px;">
      THE ORCHESTRATE METHOD™ is Michael Polzin's framework for systematic,
      professional-grade AI prompting.  This suite applies it in layers: every
      agent gets the O-R-C foundation; saved prompts add exactly the sub-letters
      they need.  The framework itself is below; for chapter-level detail,
      <a href="https://www.amazon.com/ORCHESTRATE-Prompting-Professional-AI-Outputs-ebook/dp/B0G2B9LG6V"
         target="_blank" rel="noopener noreferrer">read the book</a>.
    </p>

    <div class="card">
      <h2>The 11 letters</h2>
      <table>
        <thead>
          <tr><th>Letter</th><th>Element</th><th>Sub-framework</th><th>In one line</th></tr>
        </thead>
        <tbody>
          <tr><td><strong>O</strong></td><td>Objective</td><td>SMART</td><td>what must exist when done</td></tr>
          <tr><td><strong>R</strong></td><td>Role</td><td>PRO</td><td>who does it, from what perspective</td></tr>
          <tr><td><strong>C</strong></td><td>Context</td><td>WORLD</td><td>what facts constrain the approach</td></tr>
          <tr><td><strong>H</strong></td><td>Handoff</td><td>READY</td><td>how it's delivered / when to pause</td></tr>
          <tr><td><strong>E</strong></td><td>Examples</td><td>FIT</td><td>anchors the model can match</td></tr>
          <tr><td><strong>S</strong></td><td>Structure</td><td>FLOW</td><td>the shape the reply must take</td></tr>
          <tr><td><strong>T</strong></td><td>Tone</td><td>VIBE</td><td>voice, register, ceilings</td></tr>
          <tr><td><strong>R</strong></td><td>Review</td><td>DONE</td><td>self-check before sending</td></tr>
          <tr><td><strong>A</strong></td><td>Assure</td><td>VERIFY</td><td>guarantee of quality properties</td></tr>
          <tr><td><strong>T</strong></td><td>Test</td><td>PROVE</td><td>evidence the deliverable is correct</td></tr>
          <tr><td><strong>E</strong></td><td>Execute</td><td>RUN</td><td>cross-session / multi-agent coordination</td></tr>
        </tbody>
      </table>
      <p style="color:#9cb0d6;font-size:12px;">
        Rule of thumb: O-R-C delivers ~80% of gains; H-E-S-T adds ~15%; R-A-T adds the final ~5%.
      </p>
    </div>

    <div class="card">
      <h2>How the suite applies it</h2>
      <ul>
        <li><strong>System prompts</strong> (agents) -- O-R-C foundation + a one-line Tone anchor.</li>
        <li><strong>Saved prompts</strong> -- inherit the agent's O-R-C; add only the sub-letters the specific prompt needs.</li>
        <li><strong>Cookbook recipes</strong> -- authored with an explicit ORCHESTRATE block per recipe.</li>
        <li><strong>The Core Preamble</strong> -- prepended to every agent by the seeder; see <code class="inline">tools/librechat_seed/PROMPT_DESIGN.md</code>.</li>
      </ul>
    </div>

    <p>
      <.link navigate={~p"/guide/creator"} class="btn">About the author &rarr;</.link>
      <.link navigate={~p"/guide/level-up"} class="btn">Level Up primer &rarr;</.link>
    </p>
    """
  end
end

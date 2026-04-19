defmodule WorkbenchWeb.GuideLive.Credits do
  @moduledoc "C13 -- consolidated credits & attributions."
  use WorkbenchWeb, :live_view

  @impl true
  def mount(_params, _session, socket),
    do: {:ok, assign(socket, page_title: "Credits & Attributions")}

  @impl true
  def render(assigns) do
    ~H"""
    <p><.link navigate={~p"/guide"}>&larr; Guide</.link></p>
    <h1>Credits &amp; Attributions</h1>

    <div class="card">
      <h2>The book this suite teaches</h2>
      <p>
        <strong>Active Inference: The Free Energy Principle in Mind, Brain, and Behavior</strong>
        -- Thomas Parr, Giovanni Pezzulo, Karl J. Friston.  MIT Press, 2022.  ISBN 9780262045353.
      </p>
      <p>
        License: <strong>Creative Commons BY-NC-ND 4.0</strong>.  Committed derivative extracts
        under <code class="inline">priv/book/chapters/</code> and
        <code class="inline">priv/book/sessions/</code> are attributed per the CC license.
      </p>
      <p>
        <a href="https://mitpress.mit.edu/9780262045353/active-inference/" target="_blank"
           rel="noopener noreferrer">MIT Press page &rarr;</a>
      </p>
    </div>

    <div class="card">
      <h2>The books that shape this suite</h2>
      <ul>
        <li>
          <strong>THE ORCHESTRATE METHOD™</strong> -- Michael Polzin.  Action Based Consulting, Inc.,
          2025.  ISBN 9798274456920.
          <a href="https://www.amazon.com/ORCHESTRATE-Prompting-Professional-AI-Outputs-ebook/dp/B0G2B9LG6V"
             target="_blank" rel="noopener noreferrer">Amazon &rarr;</a>
        </li>
        <li style="margin-top:10px;">
          <strong>LEVEL UP -- The AI Usage Maturity Model</strong> -- Michael Polzin.
          Action Based Consulting, Inc., 2026.  ISBN 9798251618921.
          <a href="https://www.amazon.com/Level-Usage-Maturity-Model-Excellence-ebook/dp/B0GS4WDVFZ"
             target="_blank" rel="noopener noreferrer">Amazon &rarr;</a>
        </li>
        <li style="margin-top:10px;">
          <a href="https://www.linkedin.com/in/mpolzin/" target="_blank" rel="noopener noreferrer">
            Michael Polzin on LinkedIn
          </a>
        </li>
      </ul>
    </div>

    <div class="card">
      <h2>The framework that runs the agents</h2>
      <p>
        <strong>Jido</strong> -- the pure-Elixir agent framework.  Created and maintained by the
        <strong>agentjido</strong> organization.
      </p>
      <ul>
        <li>Version in use: <strong>v2.2.0</strong></li>
        <li>GitHub: <a href="https://github.com/agentjido/jido" target="_blank"
             rel="noopener noreferrer">github.com/agentjido/jido</a></li>
        <li>Homepage: <a href="https://jido.run" target="_blank" rel="noopener noreferrer">jido.run</a></li>
        <li>Curated knowledgebase: <.link navigate={~p"/guide/jido"}>/guide/jido</.link></li>
      </ul>
    </div>

    <div class="card">
      <h2>Third-party services and components</h2>
      <ul>
        <li><strong>LibreChat</strong> -- chat UI + agent runtime integration. MIT-licensed.</li>
        <li><strong>Qwen 3.6</strong> (Alibaba) -- on-device LLM used by the Uber-Help drawer.
          Apache 2.0 on the model weights we use.</li>
        <li><strong>Piper TTS</strong> -- fast neural text-to-speech.  MIT license.</li>
        <li><strong>XTTS-v2</strong> (Coqui) -- high-quality text-to-speech.  Coqui Public Model License.</li>
        <li><strong>Phoenix + LiveView</strong> -- MIT license.</li>
        <li><strong>Elixir + OTP</strong> -- Apache 2.0 / Erlang Public License.</li>
        <li><strong>litegraph.js</strong> -- node-editor component in the Builder.  MIT license.</li>
      </ul>
    </div>

    <div class="card">
      <h2>Copyright-safe authoring rule</h2>
      <p>
        Every shipped artifact <em>applies</em> the frameworks (the 11 ORCHESTRATE letters, the 6
        AI-UMM levels) but does not reproduce copyrighted book prose.  The Polzin book sources
        are gitignored (see <code class="inline">BOOK_SOURCES.md</code>).  Derivative extracts
        from the CC-licensed Active Inference book are committed with attribution.
      </p>
    </div>
    """
  end
end

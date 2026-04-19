defmodule WorkbenchWeb.GuideLive.Chat do
  @moduledoc "C9 -- chat integration guide."
  use WorkbenchWeb, :live_view

  @base_agents ~w(
    aif-tutor-story aif-tutor-real aif-tutor-equation aif-tutor-derivation
    aif-lab-bayes aif-lab-pomdp aif-lab-forge aif-lab-tower aif-lab-anatomy aif-lab-atlas aif-lab-frog
  )
  @chapter_agents ~w(
    aif-ch00-preface aif-ch01-overview aif-ch02-low-road aif-ch03-high-road
    aif-ch04-generative-models aif-ch05-message-passing aif-ch06-recipe
    aif-ch07-discrete-time aif-ch08-continuous-time aif-ch09-model-based-analysis
    aif-ch10-unified-theory
  )
  @role_coaches ~w(
    aif-coach-math aif-coach-intuition aif-coach-proof aif-coach-exam aif-coach-lab-debug
  )

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Chat guide",
       base_agents: @base_agents,
       chapter_agents: @chapter_agents,
       role_coaches: @role_coaches
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <p><.link navigate={~p"/guide"}>&larr; Guide</.link></p>
    <h1>Chat -- LibreChat integration</h1>
    <p style="color:#9cb0d6;max-width:900px;">
      LibreChat is reverse-proxied at <code class="inline">/chat</code>.  27 agents and
      ~60 saved prompts are pre-seeded by the scripts in
      <code class="inline">tools/librechat_seed/</code> -- all shaped by ORCHESTRATE
      (see <.link navigate={~p"/guide/orchestrate"}>primer</.link>).
    </p>

    <div class="card">
      <h2>How agents are assembled</h2>
      <ol>
        <li>The <strong>ORCHESTRATE Core Preamble</strong> is prepended to every agent's system instructions.</li>
        <li>Each agent's <code class="inline">instructions</code> field adds Role + Context + Tone specific to that agent.</li>
        <li>Saved prompts ride on top: the agent supplies O-R-C; the prompt adds only the sub-letters it needs (S for explainers, R+A for study workflow, H for quizzes...).</li>
        <li>Chat-bridge deep-links (<code class="inline">chat_links.ex</code>) pop LibreChat with an agent-id + starter prompt pre-filled.</li>
      </ol>
    </div>

    <div class="card">
      <h2>Path tutors (4)</h2>
      <ul>
        <%= for a <- @base_agents |> Enum.take(4) do %>
          <li><code class="inline"><%= a %></code></li>
        <% end %>
      </ul>
    </div>

    <div class="card">
      <h2>Lab coaches (7)</h2>
      <ul>
        <%= for a <- @base_agents |> Enum.drop(4) do %>
          <li><code class="inline"><%= a %></code> -- see <.link navigate={~p"/guide/labs"}>labs guide</.link>.</li>
        <% end %>
      </ul>
    </div>

    <div class="card">
      <h2>Chapter specialists (11)</h2>
      <ul>
        <%= for a <- @chapter_agents do %>
          <li><code class="inline"><%= a %></code></li>
        <% end %>
      </ul>
    </div>

    <div class="card">
      <h2>Role coaches (5)</h2>
      <ul>
        <%= for a <- @role_coaches do %>
          <li><code class="inline"><%= a %></code></li>
        <% end %>
      </ul>
    </div>

    <div class="card">
      <h2>Prompt authoring</h2>
      <p>
        Reference: <code class="inline">tools/librechat_seed/PROMPT_DESIGN.md</code>.  Re-seed
        the LibreChat instance after editing the yaml files under
        <code class="inline">tools/librechat_seed/</code> -- run
        <code class="inline">python tools/librechat_seed/seed.py</code> against a live LibreChat.
      </p>
    </div>
    """
  end
end

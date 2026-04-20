defmodule WorkbenchWeb.GuideLive.Features do
  @moduledoc "C4 -- honest feature inventory with state badges."
  use WorkbenchWeb, :live_view

  # Source of truth for the honest state labels.  Keep in sync with the
  # exploration report + RUNTIME_GAPS.md.  Update when features ship or
  # regress -- this page is the advertised contract with learners.
  @features [
    %{
      group: "Learning",
      name: "Learn hub",
      path: "/learn",
      state: :ok,
      note: "Landing page that orients learners and picks a path."
    },
    %{
      group: "Learning",
      name: "Chapters (11)",
      path: "/learn/chapter/:num",
      state: :ok,
      note: "Preface + Ch 1-10.  Full metadata, paths, hero, prerequisites."
    },
    %{
      group: "Learning",
      name: "Sessions (39)",
      path: "/learn/session/:num/:slug",
      state: :ok,
      note: "Every session has path_text, quiz, linked labs, and a hero idea."
    },
    %{
      group: "Learning",
      name: "Quiz grading",
      path: "/learn/session/:num/:slug",
      state: :partial,
      note: "Quizzes submit to Qwen for grading; no local rubric yet."
    },
    %{
      group: "Learning",
      name: "Progress tracker",
      path: "/learn/progress",
      state: :partial,
      note: "Heatmap renders; server-side persistence scaffolded."
    },
    %{
      group: "Learning",
      name: "Chapter narration (TTS)",
      path: "/learn/chapter/:num",
      state: :partial,
      note: "Button + HTTP endpoint live; not all chapters have podcast coverage."
    },
    %{
      group: "Workbench",
      name: "Equation registry",
      path: "/equations",
      state: :ok,
      note: "28 equations, source-traced LaTeX, chapter anchors."
    },
    %{
      group: "Workbench",
      name: "Model taxonomy",
      path: "/models",
      state: :ok,
      note: "8 model families grounded in equations."
    },
    %{
      group: "Workbench",
      name: "Agent builder",
      path: "/builder/new",
      state: :ok,
      note: "Drag-drop composition canvas; saves to the spec registry."
    },
    %{
      group: "Workbench",
      name: "World / mazes",
      path: "/world",
      state: :ok,
      note: "6 mazes including frog_pond (G2).  Live telemetry."
    },
    %{
      group: "Workbench",
      name: "Labs",
      path: "/labs",
      state: :ok,
      note: "Run any spec x any maze.  Accepts ?recipe= + ?world= (G8)."
    },
    %{
      group: "Workbench",
      name: "Glass Engine",
      path: "/glass",
      state: :ok,
      note: "Every signal traced to its source equation."
    },
    %{
      group: "Workbench",
      name: "Cookbook (50 recipes)",
      path: "/cookbook",
      state: :ok,
      note: "All 50 runnable on real Jido; validated by `mix cookbook.validate`."
    },
    %{
      group: "Agents (runtime)",
      name: "Discrete-time POMDP",
      path: "/builder/new",
      state: :ok,
      note: "Fully verified; Perceive/Plan/Act/Step actions."
    },
    %{
      group: "Agents (runtime)",
      name: "Sophisticated planning",
      path: "/labs",
      state: :ok,
      note: "Runs via Actions.SophisticatedPlan; cookbook Wave 3."
    },
    %{
      group: "Agents (runtime)",
      name: "Dirichlet learning (A, B)",
      path: "/labs",
      state: :ok,
      note: "DirichletUpdateA/B actions; learning_enabled via G6 bundle option."
    },
    %{
      group: "Agents (runtime)",
      name: "Predictive coding (G3)",
      path: "/cookbook",
      state: :ok,
      note: "Actions.PredictiveCodingPass; 2-level test covers convergence."
    },
    %{
      group: "Agents (runtime)",
      name: "Continuous-time (G4)",
      path: "/cookbook",
      state: :ok,
      note: "Skills.GeneralizedFilter + Actions.ContinuousStep; sinusoid fixture."
    },
    %{
      group: "Agents (runtime)",
      name: "Hierarchical (G5)",
      path: "/cookbook",
      state: :ok,
      note: "AgentPlane.Hierarchical composes two AIAs via context switch."
    },
    %{
      group: "Chat",
      name: "LibreChat integration",
      path: "/chat",
      state: :ok,
      note: "Reverse-proxy + deep links from Phoenix."
    },
    %{
      group: "Chat",
      name: "Chapter specialist agents (11)",
      path: "/chat",
      state: :ok,
      note: "aif-ch00-preface through aif-ch10-unified-theory."
    },
    %{
      group: "Chat",
      name: "Path tutors (4)",
      path: "/chat",
      state: :ok,
      note: "Story / real / equation / derivation; each shaped by ORCHESTRATE."
    },
    %{
      group: "Chat",
      name: "Lab coaches (7)",
      path: "/chat",
      state: :ok,
      note: "bayes / pomdp / forge / tower / anatomy / atlas / frog."
    },
    %{
      group: "Chat",
      name: "Role coaches (5)",
      path: "/chat",
      state: :ok,
      note: "math / intuition / proof / exam / lab-debug."
    },
    %{
      group: "Chat",
      name: "Saved prompts",
      path: "/chat",
      state: :ok,
      note: "ORCHESTRATE-shaped; 16 prompt groups, data-driven dropdowns."
    },
    %{
      group: "Chat",
      name: "Uber-Help drawer (Qwen)",
      path: "/",
      state: :ok,
      note: "Bottom-right drawer; context-aware local tutor."
    },
    %{
      group: "Voice",
      name: "Piper TTS (<1s)",
      path: "/speech/voices",
      state: :ok,
      note: "Local HTTP service; fastest engine."
    },
    %{
      group: "Voice",
      name: "XTTS-v2 (~70s CPU)",
      path: "/speech/voices",
      state: :ok,
      note: "High-quality local TTS; slower."
    },
    %{
      group: "Voice",
      name: "Voice-autoplay shim",
      path: "/learn/voice-autoplay",
      state: :ok,
      note: "Bookmarklet + TamperMonkey; auto-plays speak tool-call results."
    },
    %{
      group: "Voice",
      name: "Session narrator",
      path: "/learn/session/:num/:slug",
      state: :partial,
      note: "Button wired; voice-engine selection UI not exposed per-session."
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Features",
       features: @features,
       groups: groups(),
       qwen_page_type: :guide,
       qwen_page_key: "features",
       qwen_page_title: "Features"
     )}
  end

  defp groups, do: @features |> Enum.map(& &1.group) |> Enum.uniq()

  @impl true
  def render(assigns) do
    ~H"""
    <p><.link navigate={~p"/guide"}>&larr; Guide</.link></p>
    <h1>Features -- honest state</h1>
    <p style="color:#9cb0d6;max-width:900px;">
      Every user-visible feature of this suite with an honest state badge.  This page is the
      advertised contract: if a feature shows &check;, it works end-to-end; if it shows &deg;,
      part works and part does not (note explains which); if it shows &#x2717;, it is
      scaffolded-only and not yet running.  Update this module when ship-state changes.
    </p>

    <%= for g <- @groups do %>
      <div class="card">
        <h2><%= g %></h2>
        <table>
          <thead><tr><th>State</th><th>Feature</th><th>Path</th><th>Notes</th></tr></thead>
          <tbody>
            <%= for f <- Enum.filter(@features, & &1.group == g) do %>
              <tr>
                <td><%= badge(f.state) %></td>
                <td><strong><%= f.name %></strong></td>
                <td><code class="inline"><%= f.path %></code></td>
                <td><%= f.note %></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    <% end %>
    """
  end

  defp badge(:ok), do: Phoenix.HTML.raw(~s(<span style="color:#5eead4">&check; works</span>))
  defp badge(:partial), do: Phoenix.HTML.raw(~s(<span style="color:#fde68a">&deg; partial</span>))

  defp badge(:scaffold),
    do: Phoenix.HTML.raw(~s(<span style="color:#fb7185">&#x2717; scaffold</span>))
end

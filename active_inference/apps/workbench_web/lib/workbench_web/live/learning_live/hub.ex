defmodule WorkbenchWeb.LearningLive.Hub do
  @moduledoc """
  Hub landing for the comprehensive Active Inference learning suite.

  Entry-point surface that bridges the narrative **Learning Labs** (served
  as standalone HTML under `/learninglabs/*.html`) and the **Workbench**
  (Phoenix LiveView at `/equations`, `/builder`, `/world`, `/glass`, etc.).
  Every lab card shows persona chips, tier (L1–L5), estimated time, related
  equations, and follow-up labs; every Workbench card points at a live page.

  The current learning-path (from the `suite_path` cookie, set by the picker
  at `/learn/path`) is read into `@learning_path` and dims labs that are
  outside the learner's chosen tier without hiding them.
  """
  use WorkbenchWeb, :live_view

  alias WorkbenchWeb.LearningCatalog
  alias WorkbenchWeb.Book.{Chapters, Sessions}

  @impl true
  def mount(_params, session, socket) do
    path =
      session
      |> Map.get("suite_path", "real")
      |> then(fn
        v when is_binary(v) -> v
        v when is_atom(v) -> Atom.to_string(v)
        _ -> "real"
      end)

    {:ok,
     socket
     |> assign(
       page_title: "Learn",
       learning_path: path,
       labs: LearningCatalog.labs(),
       paths: LearningCatalog.paths(),
       chapters: Chapters.all(),
       total_sessions: Sessions.count(),
       qwen_page_type: :learning_hub,
       qwen_page_key: nil,
       qwen_page_title: "Learn hub"
     )}
  end

  @impl true
  def handle_event("set_path", %{"path" => path}, socket)
      when path in ~w(kid real equation derivation) do
    {:noreply,
     socket
     |> push_event("suite_set_cookie", %{name: "suite_path", value: path})
     |> push_event("suite_chip_update", %{label: LearningCatalog.path_label(path)})
     |> assign(learning_path: path)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Learn Active Inference</h1>
    <p style="color:#9cb0d6; max-width:860px; line-height:1.5;">
      Two ways in. The <strong>Learning Labs</strong> are hands-on narrative simulators — chip machines,
      clockwork, forges, towers. The <strong>Workbench</strong> is the live Jido-agent IDE where equations,
      models, and composed agents run against mazes. Pick your pace below and jump in.
    </p>

    <div class="card" style="border-color:#d8b56c;">
      <h2 style="color:#d8b56c;">Pick your learning path</h2>
      <p style="color:#9cb0d6; margin-top: 0;">
        The same math in four voices. You can switch anytime from the nav bar. Currently: <strong><%= LearningCatalog.path_label(@learning_path) %></strong>.
      </p>
      <div class="learn-path-grid">
        <%= for p <- @paths do %>
          <button
            phx-click="set_path"
            phx-value-path={p.id}
            class={"learn-path-opt #{if Atom.to_string(p.id) == @learning_path, do: "on", else: ""}"}
            aria-pressed={Atom.to_string(p.id) == @learning_path}
          >
            <div class="icon"><%= p.icon %></div>
            <div class="t"><%= p.title %></div>
            <div class="d"><%= p.desc %></div>
          </button>
        <% end %>
      </div>
    </div>

    <h2 style="color:#d8b56c;">The book · 10 chapters · <%= @total_sessions %> sessions</h2>
    <p style="color:#9cb0d6; margin-top:0;">
      A chapter-by-chapter workshop over Parr/Pezzulo/Friston (2022). Each chapter has 3–5 learning sessions; each session has a book excerpt, podcast segment, narrator, linked lab, linked Workbench surface, concept chips, micro-quiz, and a Qwen chat drawer.
    </p>
    <div class="chapter-grid">
      <%= for ch <- @chapters do %>
        <% sessions = Sessions.for_chapter(ch.num) %>
        <.link navigate={~p"/learn/chapter/#{ch.num}"} class="chapter-card" style="text-decoration:none;">
          <div class="chapter-icon"><%= ch.icon %></div>
          <div class="chapter-part">
            <%= Chapters.part_label(ch.part) %>
            <%= if ch.num > 0, do: " · Ch #{ch.num}" %>
          </div>
          <div class="chapter-title"><%= ch.title %></div>
          <div class="chapter-hero"><%= ch.hero %></div>
          <div class="chapter-meta">
            <%= length(sessions) %> sessions ·
            <%= length(ch.podcasts) %> podcast<%= if length(ch.podcasts) == 1, do: "", else: "s" %>
            <%= if length(ch.equations) > 0 do %> · <%= length(ch.equations) %> equations<% end %>
          </div>
        </.link>
      <% end %>
    </div>

    <h2 style="color:#d8b56c; margin-top:28px;">Labs · 7 standalone simulators</h2>
    <p style="color:#9cb0d6; margin-top:0;">
      Each lab is a hands-on simulator with its own path toggle, glossary, analogies, and physical exercises. Sessions in the chapters above link directly to specific lab beats.
    </p>
    <div class="grid-3">
      <%= for lab <- @labs do %>
        <div class={"card lab-card #{if in_path?(lab, @learning_path), do: "in-path", else: "out-of-path"}"}>
          <h3 style="margin:0 0 4px; color:#d8b56c;"><%= lab.icon %>&nbsp;&nbsp;<%= lab.title %></h3>
          <div style="font-size:12px;color:#9cb0d6;margin-bottom:6px;">
            Tier <%= lab.tier %> · <%= lab.time_min %> min · <%= Enum.map_join(lab.levels, " ", fn l -> persona_chip(l) end) |> Phoenix.HTML.raw() %>
          </div>
          <p style="font-size:13px;line-height:1.45;color:#e8ecf1;margin:0 0 8px;"><%= lab.hero %></p>
          <p style="font-size:12px;color:#9cb0d6;margin:0 0 12px;"><%= lab.blurb %></p>
          <%= if lab.equations != [] do %>
            <div style="font-size:11px;color:#9cb0d6;margin-bottom:10px;">
              <span style="color:#b1e4ff;">Equations:</span>
              <%= for eq <- lab.equations do %>
                <span style="color:#c4b5fd;">&nbsp;<%= eq %></span>
              <% end %>
            </div>
          <% end %>
          <a href={"/learninglabs/" <> lab.file} class="btn primary" target="_top" style="background:#b3863a;border-color:#b3863a;color:#1b1410;">
            Launch lab →
          </a>
        </div>
      <% end %>
    </div>

    <h2 style="color:#7dd3fc; margin-top:28px;">Workbench · live Jido agent surfaces</h2>
    <div class="grid-3">
      <div class="card"><h3><.link navigate={~p"/guide"}>Guide</.link></h3>
        <p style="font-size:13px;line-height:1.45;">User guide hub — 10-min tutorial, five prebuilt examples, block catalogue, technical reference.</p></div>
      <div class="card"><h3><.link navigate={~p"/equations"}>Equations</.link></h3>
        <p style="font-size:13px;line-height:1.45;">Every equation from Parr, Pezzulo, Friston (2022) with chapter anchors and type tags.</p></div>
      <div class="card"><h3><.link navigate={~p"/models"}>Models</.link></h3>
        <p style="font-size:13px;line-height:1.45;">Taxonomy of generative models — discrete, continuous, hybrid, foundational.</p></div>
      <div class="card"><h3><.link navigate={~p"/builder/new"}>Builder</.link></h3>
        <p style="font-size:13px;line-height:1.45;">Drag-and-drop composition canvas. Wire A, B, C, D blocks; save specs.</p></div>
      <div class="card"><h3><.link navigate={~p"/world"}>World</.link></h3>
        <p style="font-size:13px;line-height:1.45;">Run a saved spec against a registered maze. Live belief updates, EFE search.</p></div>
      <div class="card"><h3><.link navigate={~p"/glass"}>Glass</.link></h3>
        <p style="font-size:13px;line-height:1.45;">Signal-provenance tracer. Every agent action links back to the equation that produced it.</p></div>
    </div>

    <style>
      .learn-path-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(170px, 1fr)); gap: 10px; margin-top: 10px; }
      .learn-path-opt { text-align: left; padding: 10px 12px; border-radius: 8px;
        background: #1a2342; border: 1px solid #3d4c77; color: #e8ecf1;
        cursor: pointer; font-family: inherit; font-size: 12px; line-height: 1.4; }
      .learn-path-opt:hover { filter: brightness(1.15); }
      .learn-path-opt.on { background: linear-gradient(180deg, rgba(216,181,108,0.25), rgba(216,181,108,0.08));
        border-color: #d8b56c; color: #fff8e6; }
      .learn-path-opt .icon { font-size: 22px; margin-bottom: 4px; }
      .learn-path-opt .t { font-weight: 700; font-size: 14px; margin-bottom: 3px; color: #e3f2ff; }
      .learn-path-opt.on .t { color: #fff8e6; }
      .learn-path-opt .d { color: #9cb0d6; font-size: 11px; }
      .lab-card.out-of-path { opacity: 0.6; }
      .persona-chip { display: inline-block; font-size: 9px; padding: 2px 5px;
        border-radius: 3px; margin-right: 2px; background: #1b263a; color: #93c5fd; }

      .chapter-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
        gap: 12px; margin-top: 12px; }
      .chapter-card { background: linear-gradient(180deg, #1a1612, #121a33);
        border: 1px solid rgba(216,181,108,0.35); border-radius: 10px; padding: 14px 16px;
        color: #e8ecf1; cursor: pointer; transition: transform .12s ease, border-color .12s ease; }
      .chapter-card:hover { transform: translateY(-2px); border-color: #d8b56c; }
      .chapter-icon { font-size: 28px; margin-bottom: 6px; }
      .chapter-part { font-size: 10px; color: #9cb0d6; text-transform: uppercase;
        letter-spacing: 0.5px; margin-bottom: 4px; }
      .chapter-title { font-weight: 700; color: #d8b56c; font-size: 15px; margin-bottom: 6px;
        line-height: 1.3; }
      .chapter-hero { font-size: 13px; color: #e8ecf1; line-height: 1.45; margin-bottom: 10px; }
      .chapter-meta { font-size: 11px; color: #9cb0d6; }
    </style>
    """
  end

  defp in_path?(%{levels: levels}, path) when is_binary(path),
    do: in_path?(%{levels: levels}, String.to_atom(path))

  defp in_path?(%{levels: levels}, :kid), do: :P1 in levels or :P2 in levels
  defp in_path?(%{levels: levels}, :real), do: :P3 in levels
  defp in_path?(%{levels: levels}, :equation), do: :P4 in levels
  defp in_path?(%{levels: levels}, :derivation), do: :P5 in levels
  defp in_path?(_, _), do: true

  defp persona_chip(level) do
    "<span class=\"persona-chip\">#{level}</span>"
  end
end

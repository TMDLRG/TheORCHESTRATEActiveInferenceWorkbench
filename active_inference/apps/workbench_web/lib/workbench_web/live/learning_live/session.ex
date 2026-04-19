defmodule WorkbenchWeb.LearningLive.Session do
  @moduledoc """
  Session page — the atomic unit of workshop learning.

  Renders, top to bottom:
    * breadcrumb + path chip,
    * title + hero + estimated minutes,
    * path-specific narration block (swaps in place when the learner changes path),
    * book excerpt (from `priv/book/sessions/*.txt`, chunked at boot),
    * figure strip (static images from `priv/static/book/figures/`),
    * podcast player (segment-clamped to `podcast: {file, {start, end}}`),
    * narrator ("🔊 Narrate this session") that calls the local speech endpoint,
    * linked-lab buttons (open lab at pre-seeded beat),
    * linked-Workbench buttons,
    * concepts strip (clickable glossary chips),
    * micro-quiz,
    * prev / next session navigation,
    * uber-help drawer trigger (the drawer itself lives in the root layout).

  Route: `/learn/session/:num/:slug`
  """
  use WorkbenchWeb, :live_view

  alias WorkbenchWeb.Book.{Chapters, Sessions, Glossary}

  @impl true
  def mount(%{"num" => num_str, "slug" => slug}, session, socket) do
    chapter = Chapters.get(num_str)
    s = chapter && Sessions.find(chapter.num, slug)

    cond do
      is_nil(chapter) ->
        {:ok, push_navigate(socket, to: ~p"/learn")}

      is_nil(s) ->
        {:ok, push_navigate(socket, to: ~p"/learn/chapter/#{chapter.num}")}

      true ->
        path = session |> Map.get("suite_path", "real") |> to_string()
        excerpt = read_excerpt(chapter.slug, s.slug)

        {:ok,
         socket
         |> assign(
           page_title: s.title,
           chapter: chapter,
           session: s,
           learning_path: path,
           excerpt: excerpt,
           prev_session: Sessions.prev(s),
           next_session: Sessions.next(s),
           quiz_state: %{},
           show_quiz_feedback: false
         )}
    end
  end

  @impl true
  def handle_event("quiz_answer", %{"q" => qidx, "choice" => cidx}, socket) do
    qidx = String.to_integer(qidx)
    cidx = String.to_integer(cidx)
    state = Map.put(socket.assigns.quiz_state, qidx, cidx)
    {:noreply, assign(socket, quiz_state: state, show_quiz_feedback: true)}
  end

  @impl true
  def handle_event("mark_complete", _params, socket) do
    s = socket.assigns.session
    ch = socket.assigns.chapter

    {:noreply,
     socket
     |> push_event("progress_mark", %{chapter: ch.num, session: s.slug, done: true})
     |> put_flash(:info, "Session marked complete.")}
  end

  @impl true
  def handle_event("open_lab", %{"slug" => slug, "beat" => beat}, socket) do
    path = socket.assigns.learning_path
    file = lab_file(slug)

    {:noreply,
     push_event(socket, "navigate_external", %{
       url: "/learninglabs/#{file}?path=#{path}&beat=#{beat}"
     })}
  end

  @impl true
  def handle_event("uber_open", %{"seed" => seed} = params, socket) do
    session_slug = Map.get(params, "session", socket.assigns.session.slug)
    chapter = socket.assigns.chapter.num

    {:noreply,
     push_event(socket, "uber_open", %{
       seed: seed,
       session: session_slug,
       chapter: chapter
     })}
  end

  @impl true
  def handle_event("set_path", %{"path" => path}, socket)
      when path in ~w(kid real equation derivation) do
    {:noreply,
     socket
     |> push_event("suite_set_cookie", %{name: "suite_path", value: path})
     |> push_event("suite_chip_update", %{label: WorkbenchWeb.LearningCatalog.path_label(path)})
     |> assign(learning_path: path)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="display:flex;flex-wrap:wrap;align-items:center;gap:10px;margin-bottom:8px;font-size:12px;color:#9cb0d6;">
      <.link navigate={~p"/learn"} style="color:#7dd3fc;">Learn</.link>
      <span>›</span>
      <.link navigate={~p"/learn/chapter/#{@chapter.num}"} style="color:#7dd3fc;">
        <%= @chapter.icon %> <%= @chapter.title %>
      </.link>
      <span>›</span>
      <span>Session <%= @session.ordinal %></span>
      <span style="margin-left:auto;padding:3px 8px;border-radius:999px;background:rgba(216,181,108,0.18);border:1px solid rgba(216,181,108,0.4);color:#fff8e6;">
        <%= WorkbenchWeb.LearningCatalog.path_label(@learning_path) %>
      </span>
    </div>

    <h1 style="margin-bottom:4px;"><%= @session.title %></h1>
    <div style="color:#9cb0d6;font-size:13px;margin-bottom:16px;">
      <%= @session.minutes %> min · <%= length(@session.concepts) %> concepts
      <%= if @session.figures != [] do %> · Figure <%= Enum.join(@session.figures, ", ") %><% end %>
    </div>

    <div class="card" style="background:linear-gradient(180deg,#1a1612,#121a33);border-color:#d8b56c;">
      <div style="display:flex;flex-wrap:wrap;align-items:center;justify-content:space-between;gap:10px;margin-bottom:8px;">
        <h2 style="color:#d8b56c;margin:0;">Narration · <%= WorkbenchWeb.LearningCatalog.path_label(@learning_path) %></h2>
        <div class="session-path-switch">
          <%= for p <- ~w(kid real equation derivation) do %>
            <button
              phx-click="set_path"
              phx-value-path={p}
              class={"btn #{if @learning_path == p, do: "active", else: ""}"}
              title={"Switch to " <> WorkbenchWeb.LearningCatalog.path_label(p)}
            >
              <%= WorkbenchWeb.LearningCatalog.path_label(p) %>
            </button>
          <% end %>
        </div>
      </div>
      <p id="session-narration" style="font-size:15px;line-height:1.6;color:#e8ecf1;margin:0;">
        <%= path_narration(@session, @learning_path) %>
      </p>
      <div style="margin-top:12px;display:flex;flex-wrap:wrap;gap:8px;">
        <button
          phx-hook="Narrator"
          id="narrate-session-btn"
          data-target="#session-narration"
          class="btn"
          style="background:#d8b56c;border-color:#d8b56c;color:#1b1410;"
        >🔊 Narrate this session</button>
        <button class="btn" phx-click={JS.toggle(to: "#excerpt-card")}>📖 Show book excerpt</button>
        <%= if @session.figures != [] do %>
          <button class="btn" phx-click={JS.toggle(to: "#figures-card")}>🖼 Figures</button>
        <% end %>
        <%= if @session.podcast do %>
          <button class="btn" phx-click={JS.toggle(to: "#podcast-card")}>🎧 Podcast</button>
        <% end %>
      </div>
    </div>

    <div id="excerpt-card" class="card" style="display:none;">
      <h3 style="margin:0 0 10px;color:#b1e4ff;">Book excerpt · Ch <%= @chapter.num %>, lines <%= elem(@session.txt_lines, 0) %>–<%= elem(@session.txt_lines, 1) %></h3>
      <pre style="white-space:pre-wrap;font-size:13px;line-height:1.55;color:#cbd5e1;background:#0a1226;padding:14px;border-radius:6px;max-height:420px;overflow:auto;"><%= @excerpt %></pre>
    </div>

    <%= if @session.figures != [] do %>
      <div id="figures-card" class="card" style="display:none;">
        <h3 style="margin:0 0 10px;color:#b1e4ff;">Figures</h3>
        <div style="display:grid;grid-template-columns:repeat(auto-fit, minmax(260px, 1fr));gap:12px;">
          <%= for fig <- @session.figures do %>
            <figure style="margin:0;background:#0a1226;border:1px solid #263257;padding:10px;border-radius:6px;">
              <img src={"/book/figures/fig_" <> String.replace(fig, ".", "_") <> ".png"}
                   alt={"Figure " <> fig}
                   loading="lazy"
                   onerror="this.style.display='none';this.nextElementSibling.style.display='block';" />
              <div style="display:none;color:#9cb0d6;font-size:12px;padding:20px;text-align:center;">
                Figure <%= fig %> — PDF extraction pending.
              </div>
              <figcaption style="color:#9cb0d6;font-size:11px;margin-top:6px;">Figure <%= fig %></figcaption>
            </figure>
          <% end %>
        </div>
      </div>
    <% end %>

    <%= if @session.podcast do %>
      <% {file, {start_s, end_s}} = @session.podcast %>
      <div id="podcast-card" class="card">
        <h3 style="margin:0 0 8px;color:#b1e4ff;">🎧 Podcast segment</h3>
        <div style="font-size:12px;color:#9cb0d6;margin-bottom:6px;">
          <%= file %> · seconds <%= start_s %>–<%= if end_s == :end, do: "end", else: end_s %>
        </div>
        <audio
          phx-hook="PodcastSegment"
          id={"podcast-" <> @session.slug}
          data-start={start_s}
          data-end={if end_s == :end, do: "", else: end_s}
          controls preload="none" style="width:100%;">
          <source src={"/book/audio/" <> file} type="audio/mpeg" />
        </audio>
      </div>
    <% end %>

    <%= if @session.labs != [] do %>
      <div class="card" style="border-color:#d8b56c;">
        <h3 style="margin:0 0 8px;color:#d8b56c;">Hands-on lab</h3>
        <p style="margin:0 0 10px;color:#9cb0d6;font-size:13px;">
          Opens in place with your current path and jumps the Shell to the beat that matches this session.
          <br/>🎓 <strong>Ask coach</strong> opens LibreChat pre-tuned to the lab's specialist agent with the current session as context.
        </p>
        <%= for lab <- @session.labs do %>
          <button
            phx-click="open_lab"
            phx-value-slug={lab.slug}
            phx-value-beat={lab.beat}
            class="btn"
            style="background:#b3863a;border-color:#b3863a;color:#1b1410;margin-right:8px;margin-bottom:8px;"
          >
            🧪 Open <%= WorkbenchWeb.LibreChatAgents.lab_short(lab.slug) %> (beat <%= lab.beat %>) →
          </button>
          <.link
            navigate={"/learn/chat-bridge/session/#{@chapter.num}/#{@session.slug}?agent=#{WorkbenchWeb.LibreChatAgents.agent_for_lab(lab.slug) || "aif-tutor-real"}&lab=#{lab.slug}&beat=#{lab.beat}"}
            class="btn"
            style="background:transparent;border:1px solid #d8b56c;color:#d8b56c;margin-right:8px;margin-bottom:8px;"
          >
            🎓 Ask <%= WorkbenchWeb.LibreChatAgents.lab_short(lab.slug) %> coach →
          </.link>
        <% end %>
      </div>
    <% end %>

    <%= if @session.workbench != [] do %>
      <div class="card" style="border-color:#1d4ed8;">
        <h3 style="margin:0 0 8px;color:#7dd3fc;">Workbench surfaces</h3>
        <%= for wb <- @session.workbench do %>
          <.link navigate={wb.route} class="btn" style="margin-right:8px;margin-bottom:8px;">
            🔬 <%= wb.label %> →
          </.link>
        <% end %>
      </div>
    <% end %>

    <%= if @session.concepts != [] do %>
      <div class="card">
        <h3 style="margin:0 0 8px;color:#b1e4ff;">Concepts in this session</h3>
        <div style="display:flex;flex-wrap:wrap;gap:6px;">
          <%= for key <- @session.concepts do %>
            <% entry = Glossary.get(key) %>
            <%= if entry do %>
              <span
                class="concept-chip"
                title={entry.name <> " — hover to read definition; click to ask Qwen"}
                data-concept={key}
              >
                <%= entry.name %>
              </span>
            <% else %>
              <span class="concept-chip" style="opacity:0.5;"><%= key %></span>
            <% end %>
          <% end %>
        </div>
      </div>
    <% end %>

    <%= if @session.quiz != [] do %>
      <div class="card">
        <h3 style="margin:0 0 8px;color:#b1e4ff;">Quick check</h3>
        <%= for {q, qidx} <- Enum.with_index(@session.quiz) do %>
          <div style="margin-bottom:14px;">
            <div style="font-weight:600;margin-bottom:6px;"><%= q.q %></div>
            <div style="display:flex;flex-direction:column;gap:6px;">
              <%= for {choice, cidx} <- Enum.with_index(q.choices) do %>
                <% selected = @quiz_state[qidx] == cidx %>
                <% correct = @show_quiz_feedback and selected and cidx == q.a %>
                <% wrong = @show_quiz_feedback and selected and cidx != q.a %>
                <button
                  phx-click="quiz_answer"
                  phx-value-q={qidx}
                  phx-value-choice={cidx}
                  class="btn"
                  style={
                    cond do
                      correct -> "background:#13352a;border-color:#34d399;color:#86efac;text-align:left;"
                      wrong -> "background:#3a1b1b;border-color:#f87171;color:#fb7185;text-align:left;"
                      selected -> "background:#1a2342;border-color:#7dd3fc;text-align:left;"
                      true -> "text-align:left;"
                    end
                  }
                >
                  <%= choice %>
                </button>
              <% end %>
            </div>
            <%= if @show_quiz_feedback and @quiz_state[qidx] != nil do %>
              <div style="font-size:12px;color:#9cb0d6;margin-top:6px;"><em><%= q.why %></em></div>
            <% end %>
          </div>
        <% end %>
      </div>
    <% end %>

    <div class="card" style="border-color:#5eead4;">
      <div style="display:flex;flex-wrap:wrap;gap:8px;align-items:center;">
        <button phx-click="mark_complete" class="btn primary" style="background:#0e7c6b;border-color:#0e7c6b;">
          ✓ Mark session complete
        </button>
        <a
          href={WorkbenchWeb.ChatLinks.session_url(@chapter.num, @session.slug)}
          target="_blank"
          rel="noopener noreferrer"
          class="btn"
          title="Opens a bridge page with the on-page excerpt and a starter prompt, then LibreChat in a new tab."
        >
          💬 Full chat (with this session's context)
        </a>
        <button
          class="btn"
          phx-click="uber_open"
          phx-value-seed={@session.qwen_seed}
          phx-value-session={@session.slug}
        >
          ✨ Ask Qwen about this session
        </button>
      </div>
    </div>

    <div style="margin-top:24px;display:flex;justify-content:space-between;gap:12px;">
      <%= if @prev_session do %>
        <.link navigate={~p"/learn/session/#{@prev_session.chapter}/#{@prev_session.slug}"} class="btn">
          ◀ <%= @prev_session.title %>
        </.link>
      <% else %>
        <span></span>
      <% end %>
      <%= if @next_session do %>
        <.link navigate={~p"/learn/session/#{@next_session.chapter}/#{@next_session.slug}"} class="btn primary">
          <%= @next_session.title %> ▶
        </.link>
      <% end %>
    </div>

    <style>
      .concept-chip { display:inline-block; padding: 4px 10px; border-radius:999px;
        background: rgba(125,211,252,0.10); border:1px solid rgba(125,211,252,0.35);
        color:#b1e4ff; cursor:pointer; font-size:12px; font-family: ui-monospace, monospace; }
      .concept-chip:hover { background: rgba(125,211,252,0.22); color: #e3f2ff; }
      .session-path-switch { display: inline-flex; flex-wrap: wrap; gap: 4px; }
      .session-path-switch .btn { font-size: 11px; padding: 4px 8px; }
      .session-path-switch .btn.active { background: linear-gradient(180deg, rgba(216,181,108,0.35), rgba(216,181,108,0.15));
        border-color: #d8b56c; color: #fff8e6; }
    </style>
    """
  end

  defp path_narration(s, path) when is_binary(path), do: path_narration(s, String.to_atom(path))

  defp path_narration(s, path) do
    Map.get(s.path_text, path) || s.path_text.real
  end

  defp read_excerpt(chapter_slug, session_slug) do
    path =
      Path.join([
        Application.app_dir(:workbench_web, "priv"),
        "book/sessions",
        "#{chapter_slug}__#{session_slug}.txt"
      ])

    case File.read(path) do
      {:ok, content} -> content
      _ -> "(excerpt not yet chunked — run `mix workbench_web.chunk_book`)"
    end
  end

  # Map lab slug → standalone HTML filename under /learninglabs.
  defp lab_file("bayes-chips"), do: "BayesChips.html"
  defp lab_file("pomdp-machine"), do: "active_inference_pomdp_machine.html"
  defp lab_file("free-energy-forge"), do: "free_energy_forge_eq419.html"
  defp lab_file("laplace-tower"), do: "laplace_tower_predictive_coding_builder.html"
  defp lab_file("anatomy-studio"), do: "anatomy_of_inference_studio.html"
  defp lab_file("atlas"), do: "active_inference_atlas_educational_sim.html"
  defp lab_file("jumping-frog"), do: "jumping_frog_generative_model_lab.html"
  defp lab_file(_), do: nil
end

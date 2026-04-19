defmodule WorkbenchWeb.LearningLive.Chapter do
  @moduledoc """
  Chapter landing — lists the 3-5 sessions inside a chapter with per-session
  path-appropriate previews, podcast availability, linked labs, and progress
  markers.

  Route: `/learn/chapter/:num`  (num = 0 for the preface).
  """
  use WorkbenchWeb, :live_view

  alias WorkbenchWeb.Book.{Chapters, Sessions}

  @impl true
  def mount(%{"num" => num_str}, session, socket) do
    chapter = Chapters.get(num_str)

    if chapter do
      path =
        session
        |> Map.get("suite_path", "real")
        |> to_string()

      sessions = Sessions.for_chapter(chapter.num)

      {:ok,
       socket
       |> assign(
         page_title: chapter.title,
         chapter: chapter,
         sessions: sessions,
         learning_path: path,
         prev_chapter: prev_chapter(chapter.num),
         next_chapter: next_chapter(chapter.num)
       )}
    else
      {:ok, push_navigate(socket, to: ~p"/learn")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="display:flex;align-items:center;gap:10px;margin-bottom:8px;">
      <.link navigate={~p"/learn"} style="color:#7dd3fc;font-size:12px;">← Learn</.link>
      <span style="color:#9cb0d6;font-size:12px;">·</span>
      <span style="color:#9cb0d6;font-size:12px;"><%= Chapters.part_label(@chapter.part) %></span>
    </div>
    <h1>
      <span style="color:#d8b56c;"><%= @chapter.icon %></span>&nbsp;
      <%= if @chapter.num > 0, do: "Chapter #{@chapter.num} · " %><%= @chapter.title %>
    </h1>
    <p style="color:#e8ecf1;max-width:860px;line-height:1.55;font-size:15px;">
      <%= @chapter.hero %>
    </p>
    <p style="color:#9cb0d6;max-width:860px;line-height:1.5;font-size:13px;">
      <%= @chapter.blurb %>
    </p>

    <div class="card" style="display:flex;flex-wrap:wrap;gap:18px;align-items:center;border-color:#d8b56c;">
      <div style="flex:1 1 300px;">
        <div style="font-size:12px;color:#9cb0d6;margin-bottom:4px;">Listen to the full chapter</div>
        <audio controls preload="none" style="width:100%;">
          <%= for src <- @chapter.podcasts do %>
            <source src={"/book/audio/" <> src} type="audio/mpeg" />
          <% end %>
          Your browser does not support audio.
        </audio>
      </div>
      <div style="flex:0 0 auto;">
        <button
          phx-click="narrate_chapter"
          phx-value-num={@chapter.num}
          class="btn"
          style="background:#d8b56c;border-color:#d8b56c;color:#1b1410;"
        >
          🔊 Narrate this chapter
        </button>
      </div>
      <div style="flex:0 0 auto;display:flex;gap:8px;flex-wrap:wrap;">
        <a
          href={WorkbenchWeb.ChatLinks.chapter_url(@chapter.num)}
          target="_blank"
          rel="noopener noreferrer"
          class="btn"
          title="Opens LibreChat in a new tab with this chapter's context."
        >
          💬 Full chat about this chapter
        </a>
        <a
          href={WorkbenchWeb.ChatLinks.chapter_url(@chapter.num, agent: "aif-ch" <> pad2(@chapter.num) <> "-" <> @chapter.slug)}
          target="_blank"
          rel="noopener noreferrer"
          class="btn"
          style="background:transparent;border:1px solid #d8b56c;color:#d8b56c;"
          title="Deep-links to the chapter-specific specialist agent."
        >
          🎓 Ask Ch <%= @chapter.num %> specialist
        </a>
      </div>
    </div>

    <h2 style="color:#d8b56c;"><%= length(@sessions) %> learning sessions</h2>
    <div class="grid-3">
      <%= for s <- @sessions do %>
        <div class="card" style="border-color:#263257;">
          <div style="font-size:11px;color:#9cb0d6;margin-bottom:3px;">
            Session <%= s.ordinal %> · <%= s.minutes %> min
          </div>
          <h3 style="margin:0 0 6px; color:#e3f2ff;"><%= s.title %></h3>
          <p style="font-size:12px;line-height:1.5;color:#e8ecf1;margin:0 0 10px;">
            <%= path_preview(s, @learning_path) %>
          </p>
          <%= if s.labs != [] do %>
            <div style="font-size:11px;color:#9cb0d6;margin-bottom:4px;">
              <span style="color:#d8b56c;">Labs:</span>
              <%= Enum.map_join(s.labs, ", ", & &1.slug) %>
            </div>
          <% end %>
          <%= if s.workbench != [] do %>
            <div style="font-size:11px;color:#9cb0d6;margin-bottom:8px;">
              <span style="color:#7dd3fc;">Workbench:</span>
              <%= for {wb, idx} <- Enum.with_index(s.workbench) do %><%= if idx > 0, do: ", " %><.link navigate={wb.route} style="color:#7dd3fc;text-decoration:underline;"><%= wb.label %></.link><% end %>
            </div>
          <% end %>
          <.link
            navigate={~p"/learn/session/#{@chapter.num}/#{s.slug}"}
            class="btn primary"
            style="background:#1d4ed8;border-color:#1d4ed8;color:white;font-size:12px;"
          >
            Open session →
          </.link>
        </div>
      <% end %>
    </div>

    <div style="margin-top:24px;display:flex;justify-content:space-between;gap:12px;">
      <%= if @prev_chapter do %>
        <.link navigate={~p"/learn/chapter/#{@prev_chapter.num}"} class="btn">
          ◀ <%= @prev_chapter.icon %> <%= @prev_chapter.title %>
        </.link>
      <% else %>
        <span></span>
      <% end %>
      <%= if @next_chapter do %>
        <.link navigate={~p"/learn/chapter/#{@next_chapter.num}"} class="btn primary">
          <%= @next_chapter.icon %> <%= @next_chapter.title %> ▶
        </.link>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("narrate_chapter", %{"num" => num}, socket) do
    {:noreply, push_event(socket, "narrate_chapter", %{num: String.to_integer(num)})}
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

  defp path_preview(session, path) when is_binary(path),
    do: path_preview(session, String.to_atom(path))

  defp path_preview(session, path) when is_atom(path) do
    Map.get(session.path_text, path) || session.path_text.real || ""
  end

  defp prev_chapter(0), do: nil
  defp prev_chapter(n), do: Chapters.get(n - 1)

  defp next_chapter(10), do: nil
  defp next_chapter(n), do: Chapters.get(n + 1)

  # Two-digit chapter number for building the per-chapter specialist slug
  # (`aif-ch03-high-road`, `aif-ch10-unified-theory`).
  defp pad2(n) when n < 10, do: "0#{n}"
  defp pad2(n), do: Integer.to_string(n)
end

defmodule WorkbenchWeb.LearningLive.Progress do
  @moduledoc """
  `/learn/progress` — a grid of completion across chapters × sessions.

  Reads the `suite_progress` cookie (URL-encoded JSON) and renders a
  compact heatmap.  Clicking a cell navigates to that session.
  """
  use WorkbenchWeb, :live_view

  alias WorkbenchWeb.Book.{Chapters, Sessions}

  @impl true
  def mount(_params, session, socket) do
    progress = parse_progress(session["suite_progress"])

    {:ok,
     socket
     |> assign(
       page_title: "Progress",
       chapters: Chapters.all(),
       progress: progress,
       total: Sessions.count(),
       done: count_done(progress),
       qwen_page_type: :learn_progress,
       qwen_page_key: nil,
       qwen_page_title: "Learning progress"
     )}
  end

  @impl true
  def handle_event("clear_progress", _params, socket) do
    {:noreply,
     socket
     |> push_event("progress_clear", %{})
     |> assign(progress: %{}, done: 0)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="display:flex;align-items:center;gap:10px;margin-bottom:8px;">
      <.link navigate={~p"/learn"} style="color:#7dd3fc;font-size:12px;">← Learn</.link>
    </div>

    <h1>Your progress</h1>
    <p style="color:#9cb0d6;font-size:14px;">
      <%= @done %> of <%= @total %> sessions complete.
      <%= if @done > 0 do %>
        <button phx-click="clear_progress" class="btn" style="margin-left:12px;">Reset</button>
      <% end %>
    </p>

    <div class="progress-grid">
      <%= for ch <- @chapters do %>
        <% sessions = Sessions.for_chapter(ch.num) %>
        <%= if sessions != [] do %>
          <div class="progress-row">
            <div class="progress-ch">
              <div style="font-size:18px;"><%= ch.icon %></div>
              <div class="progress-ch-num"><%= if ch.num == 0, do: "Preface", else: "Ch #{ch.num}" %></div>
              <div class="progress-ch-title"><%= ch.title %></div>
            </div>
            <div class="progress-cells">
              <%= for s <- sessions do %>
                <% done = get_in(@progress, [to_string(ch.num), s.slug, "done"]) == true %>
                <.link
                  navigate={~p"/learn/session/#{ch.num}/#{s.slug}"}
                  class={"progress-cell #{if done, do: "done", else: ""}"}
                  title={"Session #{s.ordinal}: #{s.title}"}
                >
                  <span class="ord">S<%= s.ordinal %></span>
                  <span class="ck"><%= if done, do: "✓", else: "◯" %></span>
                </.link>
              <% end %>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>

    <style>
      .progress-grid { display:flex; flex-direction:column; gap: 12px; margin-top: 16px; }
      .progress-row { display: grid; grid-template-columns: 220px 1fr; gap: 16px; align-items: center;
        background: #121a33; border: 1px solid #263257; padding: 10px 14px; border-radius: 8px; }
      .progress-ch-num { font-size: 11px; color: #9cb0d6; text-transform: uppercase; letter-spacing:0.5px; }
      .progress-ch-title { font-size: 13px; color: #d8b56c; margin-top: 2px; }
      .progress-cells { display: flex; flex-wrap: wrap; gap: 8px; }
      .progress-cell { display: inline-flex; flex-direction: column; align-items: center; gap: 2px;
        padding: 8px 10px; min-width: 54px; border-radius: 6px;
        background: rgba(125,211,252,0.06); border: 1px solid rgba(125,211,252,0.2);
        color: #cbd5e1; text-decoration: none; font-family: ui-monospace, monospace; font-size: 11px; }
      .progress-cell:hover { background: rgba(125,211,252,0.14); text-decoration: none; }
      .progress-cell.done { background: rgba(52,211,153,0.15); border-color: rgba(52,211,153,0.4); color: #86efac; }
      .progress-cell .ord { font-weight:700; }
      .progress-cell .ck { font-size: 13px; }
    </style>
    """
  end

  defp parse_progress(nil), do: %{}

  defp parse_progress(s) when is_binary(s) do
    case Jason.decode(s) do
      {:ok, m} when is_map(m) -> m
      _ -> %{}
    end
  end

  defp parse_progress(m) when is_map(m), do: m
  defp parse_progress(_), do: %{}

  defp count_done(progress) do
    progress
    |> Enum.flat_map(fn {_, sessions} -> Map.values(sessions) end)
    |> Enum.count(fn
      %{"done" => true} -> true
      _ -> false
    end)
  end
end

defmodule WorkbenchWeb.CookbookLive.Index do
  @moduledoc """
  Cookbook landing — filterable grid of every recipe loaded by
  `WorkbenchWeb.Cookbook.Loader`.  D3 (plan).

  50 recipes planned in waves (D7: 10, D8: 20, D9: 20).  Every recipe
  runs end-to-end on real native Jido -- see `RUNTIME_GAPS.md` for the
  coverage map.
  """
  use WorkbenchWeb, :live_view

  alias WorkbenchWeb.Cookbook.Loader

  @impl true
  def mount(_params, _session, socket) do
    recipes = Loader.list()
    all_tags = recipes |> Enum.flat_map(&Map.get(&1, "tags", [])) |> Enum.uniq() |> Enum.sort()

    {:ok,
     socket
     |> assign(
       page_title: "Cookbook",
       level_filter: nil,
       tag_filter: nil,
       recipes: recipes,
       all_tags: all_tags,
       qwen_page_type: :cookbook_index,
       qwen_page_key: nil,
       qwen_page_title: "Cookbook"
     )}
  end

  @impl true
  def handle_event("filter_level", %{"level" => ""}, socket),
    do: {:noreply, socket |> assign(level_filter: nil) |> refresh()}

  def handle_event("filter_level", %{"level" => lvl}, socket) do
    {:noreply, socket |> assign(level_filter: String.to_integer(lvl)) |> refresh()}
  end

  def handle_event("filter_tag", %{"tag" => ""}, socket),
    do: {:noreply, socket |> assign(tag_filter: nil) |> refresh()}

  def handle_event("filter_tag", %{"tag" => tag}, socket) do
    {:noreply, socket |> assign(tag_filter: tag) |> refresh()}
  end

  defp refresh(socket) do
    recipes =
      Loader.list()
      |> maybe_filter_level(socket.assigns.level_filter)
      |> maybe_filter_tag(socket.assigns.tag_filter)

    assign(socket, recipes: recipes)
  end

  defp maybe_filter_level(list, nil), do: list
  defp maybe_filter_level(list, l), do: Enum.filter(list, &(Map.get(&1, "level") == l))

  defp maybe_filter_tag(list, nil), do: list
  defp maybe_filter_tag(list, tag), do: Enum.filter(list, fn r -> tag in (r["tags"] || []) end)

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Cookbook</h1>
    <p style="color:#9cb0d6;max-width:900px;">
      50 runnable Active Inference recipes.  Every card runs end-to-end on real native Jido
      -- drop it into <.link navigate={~p"/builder/new"}>the builder</.link> for tweaks or
      send it straight to <.link navigate={~p"/labs"}>the labs</.link>.  Each recipe ships
      with pure math, four audience tiers (kid / real / equation / derivation), and an
      AI-UMM level badge.
    </p>

    <div class="card" style="background:#0f1730;border-color:#1e2a48;">
      <form phx-change="filter_level" style="display:inline-block;margin-right:16px;">
        <label>AI-UMM level</label>
        <select name="level">
          <option value="">All levels</option>
          <option value="1" selected={@level_filter == 1}>1 -- Skeptical Supervisor</option>
          <option value="2" selected={@level_filter == 2}>2 -- Quality Controller</option>
          <option value="3" selected={@level_filter == 3}>3 -- Team Lead</option>
          <option value="4" selected={@level_filter == 4}>4 -- Strategic Director</option>
          <option value="5" selected={@level_filter == 5}>5 -- Amplified Human</option>
        </select>
      </form>

      <form phx-change="filter_tag" style="display:inline-block;">
        <label>Tag</label>
        <select name="tag">
          <option value="">All tags</option>
          <%= for t <- @all_tags do %>
            <option value={t} selected={@tag_filter == t}><%= t %></option>
          <% end %>
        </select>
      </form>
    </div>

    <%= if @recipes == [] do %>
      <div class="card">
        <p>No recipes match the current filters.  The cookbook ships in waves (D7/D8/D9 of the plan).  Wave 1 MVP recipes are authored first.</p>
      </div>
    <% end %>

    <div class="grid-3">
      <%= for r <- @recipes do %>
        <div class="card">
          <h3 style="margin:0 0 4px;"><%= r["title"] %></h3>
          <p style="color:#9cb0d6;margin:0 0 6px;font-size:12px;">
            Level <%= r["level"] %> · <%= r["tier_label"] %> · <%= r["minutes"] %>min
          </p>
          <p style="margin:6px 0;">
            <%= for tag <- (r["tags"] || []) do %>
              <span class="tag general"><%= tag %></span>
            <% end %>
          </p>
          <p style="font-size:13px;color:#cbd5e1;">
            <%= short_excerpt(r) %>
          </p>
          <.link navigate={~p"/cookbook/#{r["slug"]}"} class="btn primary">Open recipe →</.link>
        </div>
      <% end %>
    </div>
    """
  end

  defp short_excerpt(recipe) do
    recipe
    |> Map.get("audiences", %{})
    |> Map.get("real", Map.get(recipe, "orchestrate", %{}) |> Map.get("objective", ""))
    |> String.slice(0, 140)
  end
end

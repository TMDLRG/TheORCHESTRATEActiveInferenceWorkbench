defmodule WorkbenchWeb.CookbookLive.Show do
  @moduledoc """
  Cookbook recipe detail page.  D4 (plan).

  Renders title, tier badge, math block (LaTeX via MathJax), four-audience
  tabs, "Run in Builder" + "Run in Labs" buttons, cross-refs, credits,
  and the authoring-time ORCHESTRATE block.
  """
  use WorkbenchWeb, :live_view

  alias WorkbenchWeb.Cookbook.Loader

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    case Loader.get(slug) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Recipe not found: #{slug}")
         |> assign(recipe: nil, slug: slug, path: "real", page_title: "Not found")}

      recipe ->
        {:ok,
         assign(socket,
           recipe: recipe,
           slug: slug,
           path: "real",
           page_title: recipe["title"] || slug
         )}
    end
  end

  @impl true
  def handle_event("set_path", %{"path" => p}, socket)
      when p in ~w(kid real equation derivation) do
    {:noreply, assign(socket, path: p)}
  end

  def handle_event(_, _, socket), do: {:noreply, socket}

  @impl true
  def render(%{recipe: nil} = assigns) do
    ~H"""
    <h1>Recipe not found</h1>
    <p style="color:#9cb0d6;">The slug <code class="inline"><%= @slug %></code> is not in the cookbook.</p>
    <p><.link navigate={~p"/cookbook"} class="btn">Back to cookbook</.link></p>
    """
  end

  def render(assigns) do
    ~H"""
    <p><.link navigate={~p"/cookbook"}>&larr; Cookbook</.link></p>
    <h1><%= @recipe["title"] %></h1>
    <p style="color:#9cb0d6;">
      Level <%= @recipe["level"] %> &middot; <%= @recipe["tier_label"] %> &middot; <%= @recipe["minutes"] %>min
      <%= for tag <- (@recipe["tags"] || []) do %>
        <span class="tag general" style="margin-left:6px;"><%= tag %></span>
      <% end %>
    </p>

    <div class="card" style="border-color:#b3863a;">
      <h2 style="margin-top:0;">Run this recipe</h2>
      <p>
        <a href={builder_url(@recipe)} class="btn primary">Run in Builder &rarr;</a>
        &nbsp;
        <a href={labs_url(@recipe)} class="btn primary">Run in Labs &rarr;</a>
        &nbsp;
        <a href={studio_url(@recipe)} class="btn primary">Run in Studio &rarr;</a>
      </p>
      <p style="font-size:12px;color:#9cb0d6;margin:6px 0 0;">
        <strong>Builder</strong> loads the spec into the composition canvas so you can tweak before running.
        <strong>Labs</strong> boots the episode immediately (fresh agent per click, stable).
        <strong>Studio</strong> instantiates a tracked agent with a lifecycle panel, then you attach it to a world explicitly.
      </p>
      <p style="font-size:13px;margin-top:10px;">
        <strong>Expected outcome:</strong> <%= runtime_field(@recipe, "expected_outcome") %>
      </p>
    </div>

    <div class="card">
      <h2>Math</h2>
      <pre class="mono"><%= math_latex(@recipe) %></pre>
      <%= if symbols = math_symbols(@recipe) do %>
        <table>
          <thead><tr><th>Symbol</th><th>Meaning</th></tr></thead>
          <tbody>
            <%= for {sym, gloss} <- symbols do %>
              <tr><td><code class="inline"><%= sym %></code></td><td><%= gloss %></td></tr>
            <% end %>
          </tbody>
        </table>
      <% end %>
    </div>

    <div class="card">
      <h2>Explain it at my level</h2>
      <p>
        <%= for p <- ~w(kid real equation derivation) do %>
          <button phx-click="set_path" phx-value-path={p}
                  class={"btn #{if @path == p, do: "primary"}"}
                  style="margin-right:6px;">
            <%= path_label(p) %>
          </button>
        <% end %>
      </p>
      <p style="margin-top:12px;white-space:pre-wrap;"><%= audience_text(@recipe, @path) %></p>
    </div>

    <div class="grid-2">
      <div class="card">
        <h2>Runtime</h2>
        <ul>
          <li><strong>Agent:</strong> <code class="inline"><%= runtime_field(@recipe, "agent_module") %></code></li>
          <li><strong>World:</strong> <code class="inline"><%= runtime_field(@recipe, "world") %></code></li>
          <li><strong>Horizon:</strong> <%= runtime_field(@recipe, "horizon") %></li>
          <li><strong>Policy depth:</strong> <%= runtime_field(@recipe, "policy_depth") %></li>
          <li><strong>Preference strength:</strong> <%= runtime_field(@recipe, "preference_strength") %></li>
          <li><strong>Actions used:</strong> <%= comma(runtime_field(@recipe, "actions_used")) %></li>
          <li><strong>Skills used:</strong> <%= comma(runtime_field(@recipe, "skills_used")) %></li>
        </ul>
      </div>

      <div class="card">
        <h2>Cross-references</h2>
        <ul>
          <%= for eq <- (@recipe["equation_refs"] || []) do %>
            <li>Equation <code class="inline"><%= eq %></code></li>
          <% end %>
          <%= for fig <- (@recipe["figure_refs"] || []) do %>
            <li>Figure <code class="inline"><%= fig %></code></li>
          <% end %>
          <%= for s <- (@recipe["session_refs"] || []) do %>
            <li>Session <code class="inline"><%= s %></code></li>
          <% end %>
          <%= for l <- (@recipe["labs"] || []) do %>
            <li>Lab <code class="inline"><%= l %></code></li>
          <% end %>
        </ul>
      </div>
    </div>

    <div class="card">
      <h2>Authored with ORCHESTRATE</h2>
      <p style="color:#9cb0d6;font-size:12px;">
        Every recipe card is itself shaped by THE ORCHESTRATE METHOD™ (Polzin, 2025).
      </p>
      <dl>
        <dt><strong>Objective (O/SMART):</strong></dt>
        <dd><%= orchestrate_field(@recipe, "objective") %></dd>
        <dt><strong>Role (R/PRO):</strong></dt>
        <dd><%= orchestrate_field(@recipe, "role") %></dd>
        <dt><strong>Context (C/WORLD):</strong></dt>
        <dd><%= orchestrate_field(@recipe, "context") %></dd>
      </dl>
    </div>

    <div class="card">
      <h2>Credits</h2>
      <ul>
        <%= for c <- (@recipe["credits"] || []) do %>
          <li><%= c %></li>
        <% end %>
      </ul>
    </div>
    """
  end

  # -- helpers --------------------------------------------------------------

  defp builder_url(r), do: "/builder/new?recipe=" <> (r["slug"] || "")

  defp labs_url(r) do
    world = runtime_field(r, "world") || "tiny_open_goal"
    "/labs?recipe=#{r["slug"]}&world=#{world}"
  end

  defp studio_url(r) do
    world = runtime_field(r, "world") || "tiny_open_goal"
    # Direct controller endpoint -- single click = tracked agent + episode.
    "/studio/run_recipe?recipe=#{r["slug"]}&world=#{world}"
  end

  defp runtime_field(r, k), do: (r["runtime"] || %{})[k]
  defp orchestrate_field(r, k), do: (r["orchestrate"] || %{})[k]

  defp math_latex(r), do: (r["math"] || %{})["latex"] || ""

  defp math_symbols(r) do
    case (r["math"] || %{})["symbols"] do
      m when is_map(m) and map_size(m) > 0 -> Enum.sort(m)
      _ -> nil
    end
  end

  defp audience_text(r, path), do: (r["audiences"] || %{})[path] || ""

  defp path_label("kid"), do: "Kid (Story)"
  defp path_label("real"), do: "Real-World"
  defp path_label("equation"), do: "Equation"
  defp path_label("derivation"), do: "Derivation"

  defp comma(nil), do: "(none)"
  defp comma(list) when is_list(list), do: Enum.join(list, ", ")
  defp comma(other), do: to_string(other)
end

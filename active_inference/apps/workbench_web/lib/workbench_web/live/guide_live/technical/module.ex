defmodule WorkbenchWeb.GuideLive.Technical.Module do
  @moduledoc """
  `/guide/technical/api/:module` — per-module page. Pulls module doc + every
  public function's `@doc` / `@spec` via `WorkbenchWeb.Docs.ApiCatalog.fetch/1`.
  """
  use WorkbenchWeb, :live_view

  alias WorkbenchWeb.Docs.ApiCatalog

  @impl true
  def mount(%{"module" => module_name}, _session, socket) do
    case ApiCatalog.fetch(module_name) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Module #{module_name} not found or has no docs.")
         |> assign(page_title: "Module not found", module: nil, module_name: module_name)}

      entry ->
        {:ok,
         assign(socket,
           page_title: Atom.to_string(entry.module),
           module: entry,
           module_name: module_name
         )}
    end
  end

  @impl true
  def render(%{module: nil} = assigns) do
    ~H"""
    <h1>Module not found</h1>
    <p><code class="inline"><%= @module_name %></code> is not a known umbrella module, or has no docs loaded.</p>
    <p>
      <.link navigate={~p"/guide/technical/apps"}>← Back to apps</.link>
    </p>
    """
  end

  def render(assigns) do
    ~H"""
    <h1><%= display_name(@module.module) %></h1>

    <%= if @module.doc do %>
      <div class="card">
        <h2>Module docs</h2>
        <pre style="white-space:pre-wrap;color:#cfd8ea;"><%= @module.doc %></pre>
      </div>
    <% end %>

    <div class="card">
      <h2>Public functions (<%= length(@module.functions) %>)</h2>
      <%= if @module.functions == [] do %>
        <p style="color:#9cb0d6;">No public functions with docs loaded.</p>
      <% end %>
      <%= for fun <- @module.functions do %>
        <div style="margin:16px 0;">
          <h3 style="font-family:monospace;margin-bottom:4px;">
            <%= fun.name %>/<%= fun.arity %>
          </h3>
          <%= if fun.spec do %>
            <div style="font-family:monospace;font-size:12px;color:#82c7ff;margin:4px 0;">
              @spec <%= fun.spec %>
            </div>
          <% end %>
          <%= if fun.doc do %>
            <pre style="white-space:pre-wrap;color:#cfd8ea;font-size:13px;"><%= fun.doc %></pre>
          <% else %>
            <div style="color:#9cb0d6;font-size:12px;">
              (no <code class="inline">@doc</code> — see source)
            </div>
          <% end %>
        </div>
      <% end %>
    </div>

    <p>
      <.link navigate={~p"/guide/technical/apps"}>← All apps</.link>
    </p>
    """
  end

  defp display_name(module) do
    Atom.to_string(module) |> String.replace_prefix("Elixir.", "")
  end
end

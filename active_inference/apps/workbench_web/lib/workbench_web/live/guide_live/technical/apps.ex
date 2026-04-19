defmodule WorkbenchWeb.GuideLive.Technical.Apps do
  @moduledoc """
  `/guide/technical/apps` — per-umbrella-app public module tables.

  Data-driven from `WorkbenchWeb.Docs.ApiCatalog.all/0`; each module's
  `@doc` + `@spec` are fetched at render time via `Code.fetch_docs/1`.
  """
  use WorkbenchWeb, :live_view

  alias WorkbenchWeb.Docs.ApiCatalog

  @impl true
  def mount(_params, _session, socket) do
    catalog = ApiCatalog.all()
    {:ok, assign(socket, page_title: "Apps", catalog: catalog)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Umbrella apps</h1>
    <p style="color:#9cb0d6;max-width:780px;">
      Every public module in every umbrella app, introspected live from the loaded BEAM
      files. Click a module to see its functions, docs, and specs.
    </p>

    <%= for {app, modules} <- @catalog do %>
      <div class="card">
        <h2><%= app %></h2>
        <p style="color:#9cb0d6;"><%= length(modules) %> public modules loaded.</p>
        <table class="table">
          <thead><tr><th>Module</th><th>Public fns</th><th>Doc?</th></tr></thead>
          <tbody>
            <%= for mod <- modules do %>
              <tr>
                <td>
                  <.link navigate={~p"/guide/technical/api/#{Atom.to_string(mod.module)}"}>
                    <code class="inline"><%= Atom.to_string(mod.module) |> String.replace_prefix("Elixir.", "") %></code>
                  </.link>
                </td>
                <td><%= length(mod.functions) %></td>
                <td><%= doc_badge(mod.doc) %></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    <% end %>

    <p>
      <.link navigate={~p"/guide/technical"}>← Technical reference</.link>
    </p>
    """
  end

  defp doc_badge(nil), do: "—"
  defp doc_badge(_), do: "✓"
end

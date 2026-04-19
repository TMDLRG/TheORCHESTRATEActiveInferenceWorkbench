defmodule WorkbenchWeb.GuideLive.Technical.Signals do
  @moduledoc """
  `/guide/technical/signals` — every telemetry event, Jido signal,
  Jido directive, and WorldModels event-log type the system emits.
  """
  use WorkbenchWeb, :live_view

  alias WorkbenchWeb.Docs.EventCatalog

  @impl true
  def mount(_params, _session, socket) do
    groups = [
      {:telemetry, "Telemetry events"},
      {:event_log, "WorldModels event log"},
      {:jido_signal, "Jido signals"},
      {:jido_directive, "Jido directives"}
    ]

    entries_by_kind =
      Enum.map(groups, fn {k, label} -> {k, label, EventCatalog.by_kind(k)} end)

    {:ok, assign(socket, page_title: "Signals & events", groups: entries_by_kind)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Signals &amp; events</h1>
    <p style="color:#9cb0d6;max-width:780px;">
      Every event the system emits, grouped by kind. Each row cites the source file and
      line where the emitter is defined.
    </p>

    <%= for {_kind, label, entries} <- @groups do %>
      <div class="card">
        <h2><%= label %> (<%= length(entries) %>)</h2>
        <table class="table">
          <thead>
            <tr><th>Name</th><th>Emitter</th><th>Purpose</th><th>Payload</th><th>Source</th></tr>
          </thead>
          <tbody>
            <%= for e <- entries do %>
              <tr>
                <td><code class="inline"><%= e.name %></code></td>
                <td><code class="inline"><%= e.emitter %></code></td>
                <td><%= e.purpose %></td>
                <td style="font-size:11px;"><code class="inline"><%= e.payload %></code></td>
                <td style="font-size:11px;"><code class="inline"><%= e.file %></code></td>
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
end

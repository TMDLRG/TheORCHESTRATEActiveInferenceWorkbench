defmodule WorkbenchWeb.StudioLive.Index do
  @moduledoc """
  Studio S6 -- agent-lifecycle dashboard.

  Dashboard cards for live / stopped / archived / trash counts + a
  "Start new run" CTA.  Every agent row links into
  `/studio/agents/:agent_id` for its lifecycle panel.

  Kept intentionally separate from `/labs` so this page never breaks the
  canonical single-spec x single-world episode flow.
  """
  use WorkbenchWeb, :live_view

  alias AgentPlane.{Instance, Instances}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign_all(socket, page_title: "Studio")}
  end

  defp assign_all(socket, extra) do
    live = Instances.list(state: :live)
    stopped = Instances.list(state: :stopped)
    archived = Instances.list(state: :archived)
    trashed = Instances.list(states: [:trashed])

    socket
    |> assign(extra)
    |> assign(
      live: live,
      stopped: stopped,
      archived: archived,
      trash_count: length(trashed)
    )
  end

  @impl true
  def handle_event("refresh", _, socket), do: {:noreply, assign_all(socket, [])}

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Studio</h1>
    <p style="color:#9cb0d6;max-width:900px;">
      Run any agent in any world, track its lifecycle, archive what you want to keep,
      trash the rest.  Complements <.link navigate={~p"/labs"}>/labs</.link> -- Labs stays
      the stable "fresh agent + fresh world per click" runner; Studio is the flexible
      workshop.  Both run on real native Jido.
    </p>

    <div class="card">
      <h2>Start a run</h2>
      <p>
        <.link navigate={~p"/studio/new"} class="btn primary">New run +</.link>
        <.link navigate={~p"/studio/trash"} class="btn">Trash (<%= @trash_count %>)</.link>
        <button phx-click="refresh" class="btn">Refresh</button>
      </p>
    </div>

    <div class="grid-3">
      <.state_card state={:live} label="Live" color="#5eead4" instances={@live} />
      <.state_card state={:stopped} label="Stopped" color="#9cb0d6" instances={@stopped} />
      <.state_card state={:archived} label="Archived" color="#fde68a" instances={@archived} />
    </div>
    """
  end

  attr :state, :atom, required: true
  attr :label, :string, required: true
  attr :color, :string, required: true
  attr :instances, :list, required: true

  defp state_card(assigns) do
    ~H"""
    <div class="card">
      <h2 style={"color:#{@color};"}><%= @label %> (<%= length(@instances) %>)</h2>
      <%= if @instances == [] do %>
        <p style="color:#556478;font-size:12px;">No agents in this state.</p>
      <% else %>
        <table>
          <thead><tr><th>Name</th><th>Spec</th><th>Source</th></tr></thead>
          <tbody>
            <%= for %Instance{} = i <- Enum.take(@instances, 10) do %>
              <tr>
                <td><.link navigate={~p"/studio/agents/#{i.agent_id}"}>
                  <%= i.name || i.agent_id %>
                </.link></td>
                <td style="font-size:11px;"><%= i.spec_id %></td>
                <td style="font-size:11px;"><%= i.source %></td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if length(@instances) > 10 do %>
          <p style="font-size:11px;color:#556478;">+ <%= length(@instances) - 10 %> more</p>
        <% end %>
      <% end %>
    </div>
    """
  end
end

defmodule WorkbenchWeb.GlassLive.Index do
  @moduledoc """
  Plan §6 — Glass Engine landing page.

  Two tables:
  - Live agents (from `AgentRegistry.list_live_agents/0`): currently
    running `Jido.AgentServer` processes, joinable to the Spec that
    produced them.
  - Historic agents (scanned from `WorldModels.EventLog`): every agent
    the system has *ever* seen. Survives BEAM restarts because events
    are Mnesia `disc_copies`.
  """
  use WorkbenchWeb, :live_view

  alias WorldModels.{AgentRegistry, EventLog}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: WorldModels.Bus.subscribe_global()

    {:ok, load(socket)}
  end

  @impl true
  def handle_info({:world_event, _e}, socket), do: {:noreply, load(socket)}

  defp load(socket) do
    live = AgentRegistry.list_live_agents()
    specs = AgentRegistry.list_specs()

    # Historic: distinct (agent_id, spec_id) pairs ever seen in the log,
    # minus ones that are currently live (to avoid double-listing).
    historic =
      EventLog.query(order: :desc, limit: 500)
      |> Enum.map(fn e ->
        {Map.get(e.provenance, :agent_id), Map.get(e.provenance, :spec_id), e.ts_usec}
      end)
      |> Enum.reject(fn {aid, _, _} -> is_nil(aid) end)
      |> Enum.uniq_by(fn {aid, _, _} -> aid end)

    live_ids = MapSet.new(live, fn {aid, _} -> aid end)
    historic_only = Enum.reject(historic, fn {aid, _, _} -> MapSet.member?(live_ids, aid) end)

    assign(socket,
      page_title: "Glass Engine",
      live_agents: live,
      historic_agents: historic_only,
      specs: specs
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Glass Engine</h1>
    <p style="color:#9cb0d6;">
      Every live event resolves back to a Spec, a Family, and the book equations
      that produced it. Start from a running agent, a historic run, or a registered
      composition.
    </p>

    <div class="grid-2">
      <div>
        <div class="card">
          <h2>Live agents (<%= length(@live_agents) %>)</h2>
          <%= if @live_agents == [] do %>
            <p style="color:#9cb0d6;">No supervised agents running right now.</p>
          <% else %>
            <table>
              <thead><tr><th>agent_id</th><th>spec_id</th><th></th></tr></thead>
              <tbody>
                <%= for {agent_id, spec_id} <- @live_agents do %>
                  <tr>
                    <td class="mono"><%= agent_id %></td>
                    <td class="mono"><%= spec_id %></td>
                    <td>
                      <.link class="btn" navigate={~p"/glass/agent/#{agent_id}"}>inspect</.link>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          <% end %>
        </div>

        <div class="card">
          <h2>Historic agents (<%= length(@historic_agents) %>)</h2>
          <p style="color:#9cb0d6; font-size: 12px;">
            From the event log (Mnesia disc_copies). Includes agents whose
            BEAM process has exited.
          </p>
          <%= if @historic_agents == [] do %>
            <p style="color:#9cb0d6;">No historic runs recorded.</p>
          <% else %>
            <table>
              <thead><tr><th>agent_id</th><th>spec_id</th><th>last seen</th><th></th></tr></thead>
              <tbody>
                <%= for {agent_id, spec_id, ts} <- @historic_agents do %>
                  <tr>
                    <td class="mono"><%= agent_id %></td>
                    <td class="mono"><%= spec_id || "—" %></td>
                    <td class="mono"><%= ts %></td>
                    <td>
                      <.link class="btn" navigate={~p"/glass/agent/#{agent_id}"}>trace</.link>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          <% end %>
        </div>
      </div>

      <div>
        <div class="card">
          <h2>Registered specs (<%= length(@specs) %>)</h2>
          <%= if @specs == [] do %>
            <p style="color:#9cb0d6;">No specs registered yet.</p>
          <% else %>
            <table>
              <thead><tr><th>id</th><th>archetype</th><th>family</th><th>hash</th></tr></thead>
              <tbody>
                <%= for s <- @specs do %>
                  <tr>
                    <td class="mono"><%= s.id %></td>
                    <td class="mono"><%= s.archetype_id %></td>
                    <td><%= s.family_id %></td>
                    <td class="mono"><%= String.slice(s.hash, 0, 10) %>…</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end

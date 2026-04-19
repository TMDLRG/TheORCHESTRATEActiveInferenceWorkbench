defmodule WorkbenchWeb.GlassLive.Agent do
  @moduledoc """
  Plan §6 + §12 Phase 8 — per-agent Glass Engine view.

  Six panels:
  1. Live agent row (from AgentRegistry).
  2. Spec (resolved via live row or via fallback from the newest recorded event).
  3. AgentServer state snapshot (from Jido.AgentServer.state/1 if alive).
  4. Signal river (most recent first, filterable by equation_id / type).
  5. Provenance trace (follow signal → agent → bundle → spec → family → equations).
  6. Timeline scrub (slider over ts_usec; renders the reconstructed state
     at that instant via `EventLog.snapshot_at/2`).

  Every new event on `events:agent:<id>` re-loads the snapshot.
  """
  use WorkbenchWeb, :live_view

  alias AgentPlane.Runtime
  alias WorldModels.{AgentRegistry, Bus, EventLog}

  @impl true
  def mount(%{"agent_id" => agent_id}, _session, socket) do
    if connected?(socket) do
      Bus.subscribe_agent(agent_id)
    end

    {:ok,
     socket
     |> assign(
       page_title: "Glass · #{agent_id}",
       agent_id: agent_id,
       filter_equation: nil,
       filter_type: nil,
       scrub_ts: nil
     )
     |> load_snapshot()}
  end

  @impl true
  def handle_info({:world_event, _event}, socket), do: {:noreply, load_snapshot(socket)}

  @impl true
  def handle_event("filter_equation", %{"equation_id" => eq}, socket) do
    {:noreply,
     assign(socket, filter_equation: if(eq == "", do: nil, else: eq)) |> load_snapshot()}
  end

  def handle_event("filter_type", %{"type" => t}, socket) do
    {:noreply, assign(socket, filter_type: if(t == "", do: nil, else: t)) |> load_snapshot()}
  end

  def handle_event("scrub", %{"ts" => ts_str}, socket) do
    case Integer.parse(ts_str) do
      {ts, _} -> {:noreply, assign(socket, scrub_ts: ts) |> load_snapshot()}
      _ -> {:noreply, socket}
    end
  end

  def handle_event("scrub_reset", _, socket) do
    {:noreply, assign(socket, scrub_ts: nil) |> load_snapshot()}
  end

  def handle_event(_, _, socket), do: {:noreply, socket}

  # -- Data loading ---------------------------------------------------------

  defp load_snapshot(socket) do
    agent_id = socket.assigns.agent_id

    live_row =
      case AgentRegistry.fetch_live(agent_id) do
        {:ok, row} -> row
        :error -> nil
      end

    all_events = EventLog.query(agent_id: agent_id, order: :asc)

    spec_id =
      cond do
        live_row && live_row.spec_id -> live_row.spec_id
        true -> fallback_spec_id(all_events)
      end

    spec =
      case spec_id && AgentRegistry.fetch_spec(spec_id) do
        {:ok, s} -> s
        _ -> nil
      end

    srv_state =
      case Runtime.state(agent_id) do
        {:ok, state} -> state
        _ -> nil
      end

    # Timeline: latest 50 events unless scrubbing.
    visible_events = filter_events(all_events, socket.assigns)

    scrub_state =
      case socket.assigns.scrub_ts do
        nil -> nil
        ts -> EventLog.snapshot_at(agent_id, ts)
      end

    # Reconstructed "latest" state fallback for when the AgentServer is
    # gone (e.g., Episode used :pure mode, or BEAM was restarted).
    latest_state =
      case all_events do
        [] -> nil
        _ -> EventLog.snapshot_at(agent_id, List.last(all_events).ts_usec)
      end

    by_type = all_events |> Enum.frequencies_by(& &1.type)

    by_equation =
      all_events
      |> Enum.map(&Map.get(&1.provenance, :equation_id))
      |> Enum.reject(&is_nil/1)
      |> Enum.frequencies()

    ts_range =
      case all_events do
        [] -> nil
        _ -> {hd(all_events).ts_usec, List.last(all_events).ts_usec}
      end

    assign(socket,
      live_row: live_row,
      spec: spec,
      srv_state: srv_state,
      all_events: all_events,
      visible_events: Enum.reverse(visible_events) |> Enum.take(100),
      by_type: by_type,
      by_equation: by_equation,
      ts_range: ts_range,
      scrub_state: scrub_state,
      latest_state: latest_state
    )
  end

  defp filter_events(events, %{filter_equation: eq, filter_type: ty}) do
    events
    |> then(fn es ->
      if eq, do: Enum.filter(es, &(Map.get(&1.provenance, :equation_id) == eq)), else: es
    end)
    |> then(fn es -> if ty, do: Enum.filter(es, &(&1.type == ty)), else: es end)
  end

  defp fallback_spec_id(events) do
    events
    |> Enum.reverse()
    |> Enum.find_value(fn e ->
      case e.provenance do
        %{spec_id: sid} when is_binary(sid) -> sid
        _ -> nil
      end
    end)
  end

  # -- Render ---------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Glass &middot; <span class="mono"><%= @agent_id %></span></h1>
    <p style="color:#9cb0d6;">
      Trace any signal to the book equation that produced it and back to the
      builder spec that hydrated the agent.
    </p>

    <%= if tracked_in_studio?(@agent_id) do %>
      <div class="card" style="border-color:#b3863a;background:#1a1612;">
        <p>
          This agent is tracked in Studio.  Manage its lifecycle (stop / archive / trash)
          or attach it to a world.
        </p>
        <p>
          <.link navigate={~p"/studio/agents/#{@agent_id}"} class="btn primary"
                 style="background:#b3863a;border-color:#b3863a;color:#1b1410;">
            Open in Studio &rarr;
          </.link>
          <.link navigate={~p"/studio/new?agent=#{@agent_id}"} class="btn">
            Attach to a world &rarr;
          </.link>
        </p>
      </div>
    <% end %>

    <div class="grid-2">
      <div>
        <.live_row live={@live_row} />
        <.spec_card spec={@spec} />
        <.state_tree
          srv_state={@srv_state}
          scrub_state={@scrub_state}
          latest_state={@latest_state} />
        <.provenance_trace events={@all_events} spec={@spec} />
      </div>

      <div>
        <.signal_river
          visible_events={@visible_events}
          by_type={@by_type}
          by_equation={@by_equation}
          filter_type={@filter_type}
          filter_equation={@filter_equation}
          agent_id={@agent_id} />

        <.timeline
          ts_range={@ts_range}
          scrub_ts={@scrub_ts}
          scrub_state={@scrub_state} />
      </div>
    </div>
    """
  end

  # -- Sub-components -------------------------------------------------------

  attr :live, :any, required: true

  defp live_row(assigns) do
    ~H"""
    <div class="card">
      <h2>Live agent</h2>
      <%= if @live do %>
        <p>spec_id: <code class="inline"><%= @live.spec_id %></code></p>
        <p>pid: <code class="inline"><%= inspect(@live.pid) %></code></p>
        <p>started_at_usec: <code class="inline"><%= @live.started_at_usec %></code></p>
      <% else %>
        <p style="color:#9cb0d6;">
          Agent not in live registry (process stopped or BEAM restarted).
          History below is reconstructed from the durable event log.
        </p>
      <% end %>
    </div>
    """
  end

  attr :spec, :any, required: true

  defp spec_card(assigns) do
    ~H"""
    <div class="card">
      <h2>Spec</h2>
      <%= if @spec do %>
        <p>id: <code class="inline"><%= @spec.id %></code></p>
        <p>archetype: <code class="inline"><%= @spec.archetype_id %></code></p>
        <p>family: <code class="inline"><%= @spec.family_id %></code></p>
        <p>hash: <code class="inline"><%= String.slice(@spec.hash, 0, 16) %>…</code></p>
        <p><strong>primary_equation_ids</strong></p>
        <ul>
          <%= for eq_id <- @spec.primary_equation_ids do %>
            <li>
              <code class="inline"><%= eq_id %></code>
              <.link navigate={~p"/equations/#{eq_id}"}>&rarr;</.link>
            </li>
          <% end %>
        </ul>
      <% else %>
        <p style="color:#9cb0d6;">No spec resolvable for this agent.</p>
      <% end %>
    </div>
    """
  end

  attr :srv_state, :any, required: true
  attr :scrub_state, :any, required: true
  attr :latest_state, :any, required: true

  defp state_tree(assigns) do
    ~H"""
    <div class="card">
      <h2>Agent state tree</h2>
      <%= cond do %>
        <% @scrub_state -> %>
          <p style="color:#ffd59e; font-size:12px;">
            [scrubbed] replay from event log — events ≤ scrub_ts
          </p>
          <.reconstructed_state_dl snap={@scrub_state} />

        <% @srv_state -> %>
          <p style="color:#9cb0d6; font-size:12px;">
            [live] Jido.AgentServer.state/1
          </p>
          <% s = @srv_state.agent.state %>
          <dl class="state-dl">
            <dt class="mono">t</dt>
            <dd class="mono"><%= s.t %></dd>
            <dt class="mono">last_action</dt>
            <dd class="mono"><%= inspect(s.last_action) %></dd>
            <dt class="mono">policy_posterior (first 5)</dt>
            <dd class="mono"><%= format_list(s.policy_posterior, 5) %></dd>
            <dt class="mono">last_f (first 5 — F vector)</dt>
            <dd class="mono"><%= format_list(s.last_f, 5) %></dd>
            <dt class="mono">last_g (first 5 — G vector)</dt>
            <dd class="mono"><%= format_list(s.last_g, 5) %></dd>
            <dt class="mono">marginal_state_belief (first 5 — beliefs)</dt>
            <dd class="mono"><%= format_list(s.marginal_state_belief, 5) %></dd>
          </dl>

        <% @latest_state -> %>
          <p style="color:#9cb0d6; font-size:12px;">
            [reconstructed] no live AgentServer — state rebuilt by
            folding the event log (latest planned/action event).
          </p>
          <.reconstructed_state_dl snap={@latest_state} />

        <% true -> %>
          <p style="color:#9cb0d6;">
            No events, no live agent, nothing to show.
          </p>
      <% end %>
    </div>
    """
  end

  attr :snap, :any, required: true

  defp reconstructed_state_dl(assigns) do
    ~H"""
    <dl class="state-dl">
      <dt class="mono">t</dt>
      <dd class="mono"><%= Map.get(@snap.state, :t, "—") %></dd>
      <dt class="mono">chosen_action</dt>
      <dd class="mono"><%= inspect(Map.get(@snap.state, :chosen_action)) %></dd>
      <dt class="mono">last_f (F vector, first 5)</dt>
      <dd class="mono"><%= format_list(Map.get(@snap.state, :f, []), 5) %></dd>
      <dt class="mono">last_g (G vector, first 5)</dt>
      <dd class="mono"><%= format_list(Map.get(@snap.state, :g, []), 5) %></dd>
      <dt class="mono">policy_posterior (first 5)</dt>
      <dd class="mono"><%= format_list(Map.get(@snap.state, :policy_posterior, []), 5) %></dd>
      <dt class="mono">marginal_state_belief (beliefs)</dt>
      <dd class="mono"><%= format_list(Map.get(@snap.state, :marginal_state_belief, []), 5) %></dd>
      <dt class="mono">best_policy_index</dt>
      <dd class="mono"><%= inspect(Map.get(@snap.state, :best_policy_index)) %></dd>
    </dl>
    <p style="color:#9cb0d6; font-size:12px;">
      (<%= length(@snap.events) %> events in window)
    </p>
    """
  end

  attr :events, :list, required: true
  attr :spec, :any, required: true

  defp provenance_trace(assigns) do
    assigns =
      assign(
        assigns,
        :action_events,
        Enum.filter(assigns.events, &(&1.type == "agent.action_emitted"))
      )

    ~H"""
    <div class="card">
      <h2>Provenance trace</h2>
      <p style="color:#9cb0d6; font-size: 12px;">
        Pick any action event → follow agent_id → bundle_id → spec_id →
        family_id → primary_equation_ids. Every hop is server-verified.
      </p>
      <%= case @action_events do %>
        <% [] -> %>
          <p style="color:#9cb0d6;">No action events recorded for this agent.</p>
        <% [sample | _] -> %>
          <ol>
            <li>event: <code class="inline"><%= sample.id %></code>
              (<%= sample.type %>)</li>
            <li>agent_id:
              <code class="inline"><%= Map.get(sample.provenance, :agent_id) || "—" %></code></li>
            <li>bundle_id:
              <code class="inline"><%= Map.get(sample.provenance, :bundle_id) || "—" %></code></li>
            <li>spec_id:
              <code class="inline"><%= Map.get(sample.provenance, :spec_id) || "—" %></code></li>
            <li>family_id:
              <code class="inline"><%= Map.get(sample.provenance, :family_id) || "—" %></code></li>
            <li>equation_id:
              <% eq = Map.get(sample.provenance, :equation_id) %>
              <code class="inline"><%= eq || "—" %></code>
              <%= if eq do %>
                <.link navigate={~p"/equations/#{eq}"}>open</.link>
              <% end %>
            </li>
          </ol>
          <%= if @spec do %>
            <p style="font-size:12px;color:#9cb0d6;">
              ✓ spec hash <code class="inline"><%= String.slice(@spec.hash, 0, 10) %>…</code>
              resolves the composition.
            </p>
          <% end %>
      <% end %>
    </div>
    """
  end

  attr :visible_events, :list, required: true
  attr :by_type, :map, required: true
  attr :by_equation, :map, required: true
  attr :filter_type, :any, required: true
  attr :filter_equation, :any, required: true
  attr :agent_id, :any, required: true

  defp signal_river(assigns) do
    ~H"""
    <div class="card">
      <h2>Signal river</h2>
      <div class="river-filters">
        <form phx-change="filter_type">
          <label>type</label>
          <select name="type">
            <option value="">(all)</option>
            <%= for {t, _} <- Enum.sort(@by_type) do %>
              <option value={t} selected={@filter_type == t}><%= t %></option>
            <% end %>
          </select>
        </form>
        <form phx-change="filter_equation">
          <label>equation</label>
          <select name="equation_id">
            <option value="">(all)</option>
            <%= for {eq, _} <- Enum.sort(@by_equation) do %>
              <option value={eq} selected={@filter_equation == eq}><%= eq %></option>
            <% end %>
          </select>
        </form>
      </div>
      <%= if @visible_events == [] do %>
        <p style="color:#9cb0d6;">No events match the current filters.</p>
      <% else %>
        <table>
          <thead>
            <tr><th>ts</th><th>type</th><th>equation</th><th></th></tr>
          </thead>
          <tbody>
            <%= for e <- @visible_events do %>
              <tr>
                <td class="mono"><%= e.ts_usec %></td>
                <td class="mono"><%= e.type %></td>
                <td class="mono"><%= Map.get(e.provenance, :equation_id) || "—" %></td>
                <td>
                  <.link class="btn" navigate={~p"/glass/signal/#{e.id}"}>open</.link>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      <% end %>
    </div>
    """
  end

  attr :ts_range, :any, required: true
  attr :scrub_ts, :any, required: true
  attr :scrub_state, :any, required: true

  defp timeline(assigns) do
    ~H"""
    <div class="card">
      <h2>Timeline scrub</h2>
      <%= case @ts_range do %>
        <% nil -> %>
          <p style="color:#9cb0d6;">No events recorded; nothing to scrub.</p>
        <% {from_ts, to_ts} -> %>
          <form phx-change="scrub">
            <label>
              ts (<%= from_ts %> → <%= to_ts %>)
              <%= if @scrub_ts do %>
                — scrubbed to <code class="inline"><%= @scrub_ts %></code>
              <% end %>
            </label>
            <input type="range"
                   name="ts"
                   min={from_ts}
                   max={to_ts}
                   step="1"
                   value={@scrub_ts || to_ts}
                   style="width:100%;" />
          </form>
          <button class="btn" phx-click="scrub_reset">reset to live</button>
          <%= if @scrub_state do %>
            <p style="color:#9cb0d6; font-size: 12px;">
              Scrubbing to ts <code class="inline"><%= @scrub_ts %></code> replays
              <strong><%= length(@scrub_state.events) %></strong> events.
            </p>
          <% end %>
      <% end %>
    </div>

    <style>
      .state-dl dt { color:#ffd59e; font-size: 12px; margin-top: 6px; }
      .state-dl dd { margin: 0 0 0 12px; }
      .river-filters { display:flex; gap: 12px; margin-bottom: 8px; }
      .river-filters form { display:inline-flex; flex-direction: column; }
    </style>
    """
  end

  attr :v, :any, required: true

  defp render_value(assigns) do
    ~H"""
    <code class="inline"><%= inspect(@v, limit: 8, printable_limit: 80) %></code>
    """
  end

  defp format_list(list, n) when is_list(list) do
    head = Enum.take(list, n)

    head
    |> Enum.map(fn
      v when is_float(v) -> :erlang.float_to_binary(v, decimals: 4)
      v -> inspect(v)
    end)
    |> Enum.join(", ")
    |> then(&"[#{&1}#{if length(list) > n, do: ", …", else: ""}]")
  end

  defp format_list(_, _), do: "—"

  # Studio S13 -- show the Studio banner when this agent is tracked in
  # `AgentPlane.Instances`.  Cheap lookup; safe to call on every render.
  defp tracked_in_studio?(agent_id) when is_binary(agent_id) do
    match?({:ok, _}, AgentPlane.Instances.get(agent_id))
  end

  defp tracked_in_studio?(_), do: false
end

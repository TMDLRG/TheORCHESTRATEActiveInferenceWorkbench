defmodule WorkbenchWeb.GlassLive.Signal do
  @moduledoc """
  Plan §6 Span card — /glass/signal/:signal_id.

  Renders:
  - the raw event envelope + provenance tuple,
  - the driving equation (verbatim source + LaTeX + verification status)
    fetched from `ActiveInferenceCore.Equations`,
  - the composition spec (via provenance.spec_id → AgentRegistry.fetch_spec),
  - the family (via provenance.family_id → Models.fetch/1).
  """
  use WorkbenchWeb, :live_view

  alias ActiveInferenceCore.{Equations, Models}
  alias WorldModels.{AgentRegistry, EventLog}

  @impl true
  def mount(%{"signal_id" => id}, _session, socket) do
    case EventLog.fetch_event(id) do
      {:ok, event} ->
        equation =
          case event.provenance.equation_id do
            nil -> nil
            eq_id -> Equations.fetch(eq_id)
          end

        spec =
          case event.provenance.spec_id do
            nil ->
              nil

            sid ->
              case AgentRegistry.fetch_spec(sid) do
                {:ok, s} -> s
                _ -> nil
              end
          end

        family =
          case event.provenance.family_id do
            nil -> nil
            fid -> Models.fetch(fid)
          end

        {:ok,
         socket
         |> assign(
           page_title: "Signal · #{id}",
           event: event,
           equation: equation,
           spec: spec,
           family: family
         )}

      :error ->
        {:ok,
         socket
         |> assign(
           page_title: "Signal not found",
           event: nil,
           equation: nil,
           spec: nil,
           family: nil
         )}
    end
  end

  @impl true
  def render(%{event: nil} = assigns) do
    ~H"""
    <h1>Signal not found</h1>
    <p>
      No event matched that id. Events may have been purged by the Janitor
      or never landed on disk. <.link navigate={~p"/glass"}>back to Glass</.link>
    </p>
    """
  end

  def render(assigns) do
    ~H"""
    <h1>Signal &middot; <span class="mono"><%= @event.id %></span></h1>
    <p style="color:#9cb0d6;">
      One event, traced to the book equation that produced it and to the
      composition spec that hydrated the agent.
    </p>

    <div class="grid-2">
      <div>
        <div class="card">
          <h2>Event</h2>
          <p>type: <code class="inline"><%= @event.type %></code></p>
          <p>ts_usec: <code class="inline"><%= @event.ts_usec %></code></p>
          <p>version: <code class="inline"><%= @event.version %></code></p>
          <pre><%= Jason.encode!(@event.data, pretty: true) %></pre>
        </div>

        <div class="card">
          <h2>Provenance tuple</h2>
          <dl class="state-dl">
            <%= for {k, v} <- @event.provenance, not is_nil(v) do %>
              <dt class="mono"><%= k %></dt>
              <dd class="mono"><%= inspect(v) %></dd>
            <% end %>
          </dl>
          <p>
            <.link class="btn" navigate={~p"/glass/agent/#{@event.provenance.agent_id}"}>
              open agent
            </.link>
          </p>
        </div>
      </div>

      <div>
        <div class="card">
          <h2>Equation</h2>
          <%= if @equation do %>
            <p>id: <code class="inline"><%= @equation.id %></code>
               <.link navigate={~p"/equations/#{@equation.id}"}>open full record</.link>
            </p>
            <p>source: <%= @equation.source_title %>
                      — chapter <%= @equation.chapter %></p>
            <p>number: <code class="inline">eq. <%= @equation.equation_number %></code></p>
            <p>verification:
              <span class="tag verified"><%= @equation.verification_status %></span>
            </p>

            <h3>source text (verbatim — "π" for policy posterior etc.)</h3>
            <pre><%= @equation.source_text_equation %></pre>

            <h3>normalized LaTeX</h3>
            <pre><%= @equation.normalized_latex %></pre>

            <h3>symbols</h3>
            <ul>
              <%= for sym <- @equation.symbols do %>
                <li>
                  <code class="inline"><%= sym.name %></code>
                  — <%= sym.meaning %>
                </li>
              <% end %>
            </ul>
          <% else %>
            <p style="color:#9cb0d6;">
              No equation_id on this event (e.g., a JIDO-level telemetry
              lifecycle event). See the provenance tuple for what's known.
            </p>
          <% end %>
        </div>

        <div class="card">
          <h2>Spec</h2>
          <%= if @spec do %>
            <p>id: <code class="inline"><%= @spec.id %></code></p>
            <p>archetype: <code class="inline"><%= @spec.archetype_id %></code></p>
            <p>hash: <code class="inline"><%= String.slice(@spec.hash, 0, 16) %>…</code></p>
            <p>
              <.link class="btn" navigate={~p"/builder/#{@spec.id}"}>view in builder</.link>
            </p>
          <% else %>
            <p style="color:#9cb0d6;">No spec on this event's provenance.</p>
          <% end %>
        </div>

        <%= if @family do %>
          <div class="card">
            <h2>Family</h2>
            <p>model_name: <%= @family.model_name %></p>
            <p>type: <span class={"tag " <> Atom.to_string(@family.type)}>
              <%= @family.type %></span></p>
            <p>source_basis:
              <%= length(@family.source_basis) %> equations</p>
            <ul>
              <%= for eq_id <- @family.source_basis do %>
                <li><code class="inline"><%= eq_id %></code></li>
              <% end %>
            </ul>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end

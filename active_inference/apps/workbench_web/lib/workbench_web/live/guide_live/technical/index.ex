defmodule WorkbenchWeb.GuideLive.Technical.Index do
  @moduledoc """
  Landing page for the in-app technical reference (`/guide/technical`).
  """
  use WorkbenchWeb, :live_view

  alias WorkbenchWeb.Docs.{ApiCatalog, EventCatalog, VerificationManifest}

  @impl true
  def mount(_params, _session, socket) do
    counts = VerificationManifest.counts()
    app_count = length(ApiCatalog.apps())
    event_count = length(EventCatalog.all())

    {:ok,
     assign(socket,
       page_title: "Technical reference",
       counts: counts,
       app_count: app_count,
       event_count: event_count
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Technical reference</h1>
    <p style="color:#9cb0d6;max-width:780px;">
      Full transparency over the running system. Every page on this track is
      data-driven from the source — modules, specs, events, config, and
      verification status are read from the code itself, not hand-maintained
      prose.
    </p>

    <div class="grid-3">
      <div class="card">
        <h2>Architecture</h2>
        <p>Three planes, the Markov blanket, event flow, dependency graph.</p>
        <.link navigate={~p"/guide/technical/architecture"} class="btn primary">Open →</.link>
      </div>
      <div class="card">
        <h2>Apps (<%= @app_count %>)</h2>
        <p>Per-umbrella-app public module + function tables, with <code class="inline">@doc</code> and <code class="inline">@spec</code> introspected at render time.</p>
        <.link navigate={~p"/guide/technical/apps"} class="btn">Open →</.link>
      </div>
      <div class="card">
        <h2>Signals &amp; events (<%= @event_count %>)</h2>
        <p>Every telemetry event, Jido signal, Jido directive, and event-log type the system emits.</p>
        <.link navigate={~p"/guide/technical/signals"} class="btn">Open →</.link>
      </div>
    </div>

    <div class="grid-3">
      <div class="card">
        <h2>Data &amp; schemas</h2>
        <p>Structs, typespecs, Mnesia tables, Phoenix.PubSub topics — with field lists and file:line.</p>
        <.link navigate={~p"/guide/technical/data"} class="btn">Open →</.link>
      </div>
      <div class="card">
        <h2>Configuration</h2>
        <p>Every Application env key, every <code class="inline">config/*.exs</code> entry, per-environment overrides, defaults.</p>
        <.link navigate={~p"/guide/technical/config"} class="btn">Open →</.link>
      </div>
      <div class="card">
        <h2>Verification (<strong><%= @counts.verified %></strong> verified / <strong><%= @counts.scaffolded %></strong> scaffolded / <strong><%= @counts.uncertain %></strong> uncertain)</h2>
        <p>The "real honesty" page: what is tested end-to-end vs what is scaffolded.</p>
        <.link navigate={~p"/guide/technical/verification"} class="btn">Open →</.link>
      </div>
    </div>

    <div class="card">
      <h2>Equation registry</h2>
      <p>
        Already lives at <.link navigate={~p"/equations"}>/equations</.link>. Every entry
        is cited verbatim from Parr, Pezzulo, Friston (MIT Press 2022) with verification
        status per equation.
      </p>
    </div>
    """
  end
end

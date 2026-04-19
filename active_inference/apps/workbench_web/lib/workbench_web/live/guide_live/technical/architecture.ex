defmodule WorkbenchWeb.GuideLive.Technical.Architecture do
  @moduledoc """
  `/guide/technical/architecture` — plane separation, Markov blanket
  invariant, event flow, dependency graph.

  This page is hand-authored (architecture doesn't change on every
  compile), but every claim cites a real `file:line`.
  """
  use WorkbenchWeb, :live_view

  @three_planes """
   ┌────────────────────────────┐        ┌────────────────────────────┐
   │       AGENT PLANE          │        │       WORLD PLANE          │
   │ (generative model)         │        │ (generative process)       │
   │                            │        │                            │
   │ AgentPlane.Runtime         │        │ WorldPlane.Engine          │
   │ ActiveInferenceAgent       │        │ Maze, Worlds               │
   │ Actions (Perceive/Plan/    │        │ ObservationEncoder         │
   │   Act/Step/Dirichlet…)     │        │                            │
   │ BundleBuilder, ObsAdapter  │        │                            │
   │ Telemetry.Bus              │        │                            │
   └──────────────┬─────────────┘        └──────────────┬─────────────┘
                  │                                     │
                  │ ActionPacket                        │ ObservationPacket
                  │                                     │
                  └──────────────┬──────────────────────┘
                                 │
                   ┌─────────────▼─────────────┐
                   │    SHARED CONTRACTS       │
                   │  (Markov blanket border)  │
                   │  Blanket + packets        │
                   └───────────────────────────┘
  """

  @dep_graph """
                  ┌──────────────────────┐
                  │ active_inference_core│  (pure math — zero deps)
                  └──────────┬───────────┘
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
   ┌──────▼──────┐    ┌──────▼──────┐    ┌──────▼──────┐
   │shared_contr.│    │ agent_plane │    │ world_plane │
   └──────┬──────┘    └──────┬──────┘    └──────┬──────┘
          │                  │                  │
          └──────────┬───────┴──────────────────┘
                     │
              ┌──────▼────────┐
              │ world_models  │  (Phoenix.PubSub + Mnesia + Spec)
              └──────┬────────┘
                     │
          ┌──────────┴──────────┐
          │                     │
   ┌──────▼──────┐        ┌─────▼────────┐
   │composition_ │        │ workbench_web│
   │  runtime    │        │ (LiveView UI)│
   └─────────────┘        └──────────────┘
  """

  @event_flow """
    Jido.AgentServer ──┐
                       ├─ :telemetry ──► AgentPlane.Telemetry.Bus ──┐
    ActiveInference-   │                 (bus.ex:17)                 │
       Core.Discrete-  │                                             │
       Time          ──┘                                             │
                                                                     ▼
    WorkbenchWeb.Episode ───────────────► WorldModels.Bus ─► Phoenix.PubSub
                                          (bus.ex)            │
                                                              ├► EventLog.append/1 (Mnesia)
                                                              ├► GlassLive.*
                                                              ├► WorldLive.Index
                                                              └► LabsLive.Run
  """

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Architecture",
       three_planes: @three_planes,
       dep_graph: @dep_graph,
       event_flow: @event_flow
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Architecture</h1>
    <p style="color:#9cb0d6;max-width:780px;">
      The workbench separates the generative <em>process</em> (world) from the generative
      <em>model</em> (agent) at the code level. The Markov blanket between them is the
      only typed channel — enforced at <code class="inline">mix.exs</code> level.
    </p>

    <div class="card">
      <h2>The three planes</h2>
      <pre style="font-size:12px;line-height:1.4;"><%= @three_planes %></pre>
      <p>
        Enforced by <code class="inline">apps/world_plane/test/plane_separation_test.exs</code> and
        <code class="inline">apps/agent_plane/test/plane_separation_test.exs</code>.
        The world plane's <code class="inline">mix.exs</code> does not depend on
        <code class="inline">:agent_plane</code> or <code class="inline">:active_inference_core</code>.
        The agent plane's <code class="inline">mix.exs</code> does not depend on <code class="inline">:world_plane</code>.
      </p>
    </div>

    <div class="card">
      <h2>Umbrella dependency graph</h2>
      <pre style="font-size:12px;line-height:1.4;"><%= @dep_graph %></pre>
    </div>

    <div class="card">
      <h2>One episode tick</h2>
      <ol>
        <li><code class="inline">WorldPlane.Engine.current_observation/1</code> → <code class="inline">ObservationPacket</code> (event: <code class="inline">world.observation</code>)</li>
        <li><code class="inline">AgentPlane.Runtime.perceive/2</code> → <code class="inline">Actions.Perceive</code> (eq. 4.13 / B.5; event: <code class="inline">agent.perceived</code>)</li>
        <li><code class="inline">AgentPlane.Runtime.plan/1</code> → <code class="inline">Actions.Plan</code> (eq. 4.11, 4.10, 4.14 / B.9; event: <code class="inline">agent.planned</code>)</li>
        <li><code class="inline">AgentPlane.Runtime.act/2</code> → <code class="inline">Actions.Act</code> (emits <code class="inline">Jido.Signal</code> "active_inference.action" + <code class="inline">Directive.Emit</code>; event: <code class="inline">agent.action_emitted</code>)</li>
        <li><code class="inline">WorldPlane.Engine.apply_action/2</code> → next obs + terminal? (events: <code class="inline">world.observation</code> or <code class="inline">world.terminal</code>)</li>
        <li>(optional) Dirichlet A / B updates on bundle (eq. 7.10 / B.10–B.12)</li>
      </ol>
      <p>Orchestrator: <code class="inline">apps/workbench_web/lib/workbench_web/episode.ex</code>.</p>
    </div>

    <div class="card">
      <h2>Event flow</h2>
      <pre style="font-size:12px;line-height:1.4;"><%= @event_flow %></pre>
      <p>
        Topics: <code class="inline">events:global</code>, <code class="inline">events:agent:&lt;id&gt;</code>,
        <code class="inline">events:world:&lt;id&gt;</code>, <code class="inline">events:spec:&lt;id&gt;</code>.
      </p>
    </div>

    <p>
      <.link navigate={~p"/guide/technical"}>← Technical reference</.link>
    </p>
    """
  end
end

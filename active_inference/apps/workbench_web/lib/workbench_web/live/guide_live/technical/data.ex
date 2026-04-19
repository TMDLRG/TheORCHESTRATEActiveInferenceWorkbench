defmodule WorkbenchWeb.GuideLive.Technical.Data do
  @moduledoc """
  `/guide/technical/data` — structs, typespecs, Mnesia tables,
  Phoenix.PubSub topics, with field lists and file:line citations.

  Hand-authored reference (data shape doesn't change on every compile);
  cited against source. If a table here drifts from the code, update
  this file.
  """
  use WorkbenchWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Data & schemas")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Data &amp; schemas</h1>

    <div class="card">
      <h2>Markov-blanket packets</h2>
      <table class="table">
        <thead><tr><th>Type</th><th>Fields</th><th>Source</th></tr></thead>
        <tbody>
          <tr>
            <td><code class="inline">SharedContracts.ActionPacket.t/0</code></td>
            <td><code class="inline">:t :: non_neg_integer, :action :: atom, :agent_id :: String.t</code></td>
            <td><code class="inline">apps/shared_contracts/lib/shared_contracts/action_packet.ex:18</code></td>
          </tr>
          <tr>
            <td><code class="inline">SharedContracts.ObservationPacket.t/0</code></td>
            <td><code class="inline">:t :: non_neg_integer, :channels :: map, :world_run_id :: String.t, :terminal? :: boolean</code></td>
            <td><code class="inline">apps/shared_contracts/lib/shared_contracts/observation_packet.ex:31</code></td>
          </tr>
          <tr>
            <td><code class="inline">SharedContracts.Blanket.t/0</code></td>
            <td><code class="inline">:observation_channels :: [atom], :action_vocabulary :: [atom], :channel_specs :: %{atom =&gt; channel_spec}</code></td>
            <td><code class="inline">apps/shared_contracts/lib/shared_contracts/blanket.ex:33</code></td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="card">
      <h2>Agent state</h2>
      <table class="table">
        <thead><tr><th>Type</th><th>Fields</th><th>Source</th></tr></thead>
        <tbody>
          <tr>
            <td><code class="inline">AgentPlane.ActiveInferenceAgent.State</code></td>
            <td style="font-size:11px;"><code class="inline">:agent_id, :bundle, :blanket, :beliefs, :obs_history, :t, :policy_posterior, :last_action, :last_policy_best_idx, :last_f, :last_g, :marginal_state_belief, :best_policy_chain, :goal_idx, :telemetry, :spec_id, :bundle_id, :family_id, :primary_equation_ids, :verification_status</code></td>
            <td><code class="inline">apps/agent_plane/lib/agent_plane/active_inference_agent.ex:44-69</code></td>
          </tr>
          <tr>
            <td>Bundle (map)</td>
            <td><code class="inline">:a, :b, :c, :d, :e, :actions, :policies, :horizon, :spec_id, :bundle_id, :family_id</code></td>
            <td><code class="inline">apps/agent_plane/lib/agent_plane/bundle_builder.ex:35-44</code></td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="card">
      <h2>World state</h2>
      <table class="table">
        <thead><tr><th>Type</th><th>Fields</th><th>Source</th></tr></thead>
        <tbody>
          <tr>
            <td><code class="inline">WorldPlane.Engine.t/0</code></td>
            <td><code class="inline">:maze, :pos :: Maze.coord, :t, :blanket, :run_id, :terminal?, :last_action_blocked?, :history</code></td>
            <td><code class="inline">apps/world_plane/lib/world_plane/engine.ex:31</code></td>
          </tr>
          <tr>
            <td><code class="inline">WorldPlane.Maze.t/0</code></td>
            <td><code class="inline">:id, :name, :width, :height, :grid :: %{coord =&gt; tile}, :start, :goal, :description</code></td>
            <td><code class="inline">apps/world_plane/lib/world_plane/maze.ex:19</code></td>
          </tr>
          <tr>
            <td><code class="inline">WorldPlane.Maze.tile/0</code></td>
            <td><code class="inline">:empty | :wall | :start | :goal</code></td>
            <td><code class="inline">apps/world_plane/lib/world_plane/maze.ex:15</code></td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="card">
      <h2>Events &amp; specs</h2>
      <table class="table">
        <thead><tr><th>Type</th><th>Fields</th><th>Source</th></tr></thead>
        <tbody>
          <tr>
            <td><code class="inline">WorldModels.Event.t/0</code></td>
            <td><code class="inline">:id, :ts, :ts_usec, :version, :type, :provenance, :data</code></td>
            <td><code class="inline">apps/world_models/lib/world_models/event.ex:36</code></td>
          </tr>
          <tr>
            <td><code class="inline">WorldModels.Event.provenance/0</code></td>
            <td><code class="inline">:agent_id, :spec_id, :bundle_id, :family_id, :world_run_id, :equation_id, :trace_id, :span_id</code></td>
            <td><code class="inline">apps/world_models/lib/world_models/event.ex:25</code></td>
          </tr>
          <tr>
            <td><code class="inline">WorldModels.Spec.t/0</code></td>
            <td style="font-size:11px;"><code class="inline">:id, :archetype_id, :family_id, :primary_equation_ids, :bundle_params, :blanket, :hash, :created_at, :created_by, :version, :topology</code></td>
            <td><code class="inline">apps/world_models/lib/world_models/spec.ex:31</code></td>
          </tr>
          <tr>
            <td><code class="inline">WorldModels.Archetypes.t/0</code></td>
            <td><code class="inline">:id, :name, :description, :family_id, :primary_equation_ids, :mvp_suitability, :disabled?, :required_types, :default_params</code></td>
            <td><code class="inline">apps/world_models/lib/world_models/archetypes.ex:28</code></td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="card">
      <h2>Mnesia tables</h2>
      <p>All created by <code class="inline">WorldModels.EventLog.Setup.ensure_schema!/0</code>
      (<code class="inline">apps/world_models/lib/world_models/event_log/setup.ex</code>).</p>
      <table class="table">
        <thead><tr><th>Table</th><th>Type</th><th>Copies</th><th>Key</th><th>Indices</th><th>Purpose</th></tr></thead>
        <tbody>
          <tr>
            <td><code class="inline">:world_models_events</code></td>
            <td><code class="inline">ordered_set</code></td>
            <td><code class="inline">disc_copies</code></td>
            <td><code class="inline">{ts_usec, id}</code></td>
            <td><code class="inline">:agent_id, :type</code></td>
            <td>Append-only event log</td>
          </tr>
          <tr>
            <td><code class="inline">:world_models_specs</code></td>
            <td><code class="inline">set</code></td>
            <td><code class="inline">disc_copies</code></td>
            <td><code class="inline">:id</code></td>
            <td><code class="inline">:archetype_id, :family_id, :hash</code></td>
            <td>Content-addressed spec registry</td>
          </tr>
          <tr>
            <td><code class="inline">:world_models_live_agents</code></td>
            <td><code class="inline">set</code></td>
            <td><code class="inline">ram_copies</code></td>
            <td><code class="inline">:agent_id</code></td>
            <td><code class="inline">:spec_id</code></td>
            <td>Live-agent map (ephemeral)</td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="card">
      <h2>Phoenix.PubSub topics</h2>
      <p>Facade: <code class="inline">WorldModels.Bus</code> (<code class="inline">apps/world_models/lib/world_models/bus.ex</code>).</p>
      <table class="table">
        <thead><tr><th>Topic</th><th>Scope</th><th>Subscribe fn</th></tr></thead>
        <tbody>
          <tr><td><code class="inline">events:global</code></td><td>All events</td><td><code class="inline">Bus.subscribe_global/0</code></td></tr>
          <tr><td><code class="inline">events:agent:&lt;agent_id&gt;</code></td><td>One live agent</td><td><code class="inline">Bus.subscribe_agent/1</code></td></tr>
          <tr><td><code class="inline">events:world:&lt;world_run_id&gt;</code></td><td>One world run</td><td><code class="inline">Bus.subscribe_world/1</code></td></tr>
          <tr><td><code class="inline">events:spec:&lt;spec_id&gt;</code></td><td>All agents running a spec</td><td><code class="inline">Bus.subscribe_spec/1</code></td></tr>
        </tbody>
      </table>
    </div>

    <p>
      <.link navigate={~p"/guide/technical"}>← Technical reference</.link>
    </p>
    """
  end
end

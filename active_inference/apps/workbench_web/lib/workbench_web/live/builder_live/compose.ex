defmodule WorkbenchWeb.BuilderLive.Compose do
  @moduledoc """
  Plan §5 + §12 Phase 7 + Lego-uplift Phase B — Agent Builder composition page.

  Three panes, left-to-right:
  - Palette: draggable cards (archetypes + block types). HTML5 drag-and-drop
    from card → canvas emits `add_node`.
  - Canvas: `litegraph.js` node editor mounted via the `CompositionCanvas`
    JS hook. Topology JSON round-trips between the hook and the server on
    every drag/connect/param edit. Clicking a node emits `select_node`.
  - Inspector: schema-bound form for the selected node, backed by
    `WorldModels.Spec.BlockSchema`. Every edit is validated server-side;
    errors surface inline.

  Save persists a `WorldModels.Spec`; Instantiate spins up a supervised
  `Jido.AgentServer` via `AgentPlane.Runtime.start_agent/1` and redirects
  to `/glass/agent/:agent_id`.
  """
  use WorkbenchWeb, :live_view

  alias ActiveInferenceCore.{Equations, Models}
  alias AgentPlane.{BundleBuilder, Runtime}
  alias SharedContracts.Blanket
  alias WorldModels.{AgentRegistry, Archetypes, Event, EventLog, Spec}
  alias WorldModels.Spec.{BlockSchema, Topology}

  @impl true
  def mount(params, _session, socket) do
    archetypes = Archetypes.all()
    families = Models.all()
    equations = Equations.all()

    {topology, selected_archetype_id, loaded_spec} = load_spec_or_empty(params)

    # D5 -- Run in Builder hydration.  When the URL carries `?recipe=<slug>`,
    # look up the recipe via the cookbook loader and surface its runtime spec
    # as a banner so the builder user sees the target configuration.
    recipe_banner = recipe_hint(params)

    {:ok,
     socket
     |> assign(
       page_title: "Builder",
       archetypes: archetypes,
       families: families,
       equations: equations,
       selected_archetype_id: selected_archetype_id,
       selected_node_id: nil,
       topology: topology,
       validation_errors: [],
       param_errors: %{},
       spec: loaded_spec,
       recipe_banner: recipe_banner,
       query: "",
       block_types: block_palette(),
       node_types_json: Jason.encode!(topology_node_types_for_js()),
       qwen_page_type: :builder,
       qwen_page_key:
         (recipe_banner && recipe_banner["slug"]) ||
           (loaded_spec && Map.get(loaded_spec, :id)),
       qwen_page_title:
         "Builder" <>
           if(recipe_banner, do: " · " <> (recipe_banner["title"] || ""), else: "")
     )
     |> assign_topology(topology)}
  end

  defp recipe_hint(%{"recipe" => slug}) when is_binary(slug) do
    case WorkbenchWeb.Cookbook.Loader.get(slug) do
      nil -> nil
      recipe -> recipe
    end
  end

  defp recipe_hint(_), do: nil

  # When the URL carries `?recipe=<slug>`, hydrate the canvas from the
  # closest seeded example spec (L1-L5).  Learner then tweaks + Saves +
  # Instantiates, giving the full cookbook -> Builder -> Jido -> World ->
  # Glass pipeline.  Drop "recipe" before recursing so the spec_id clause
  # fires (not this one again -- would be infinite).
  defp load_spec_or_empty(%{"recipe" => slug} = params)
       when is_binary(slug) and not is_map_key(params, "spec_id") do
    spec_id = WorkbenchWeb.Cookbook.Loader.spec_id_for(slug)
    params |> Map.delete("recipe") |> Map.put("spec_id", spec_id) |> load_spec_or_empty()
  end

  defp load_spec_or_empty(%{"spec_id" => spec_id}) when is_binary(spec_id) do
    case AgentRegistry.fetch_spec(spec_id) do
      {:ok, %Spec{} = spec} ->
        topology = spec.topology || %{nodes: [], edges: [], required_types: []}
        {topology, spec.archetype_id, spec}

      :error ->
        {%{nodes: [], edges: [], required_types: []}, nil, nil}
    end
  end

  defp load_spec_or_empty(_params), do: {%{nodes: [], edges: [], required_types: []}, nil, nil}

  # -- Hook events -----------------------------------------------------------

  @impl true
  def handle_event("topology_changed", %{"topology" => topology_json}, socket) do
    topology = normalize_topology(topology_json)
    socket = assign_topology(socket, topology)
    {:noreply, socket}
  end

  def handle_event("seed_archetype", %{"archetype_id" => id}, socket) do
    case Archetypes.fetch(id) do
      nil ->
        {:noreply, socket}

      %Archetypes{} = a ->
        topology = Archetypes.seed_topology(a)

        socket =
          socket
          |> assign(selected_archetype_id: a.id, selected_node_id: nil)
          |> assign_topology(topology)

        {:noreply, socket}
    end
  end

  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, assign(socket, query: q)}
  end

  def handle_event("select_node", %{"id" => id}, socket) do
    {:noreply, assign(socket, selected_node_id: id)}
  end

  def handle_event("add_node", params, socket) do
    x = Map.get(params, "x", 80) |> to_i(80)
    y = Map.get(params, "y", 80) |> to_i(80)

    cond do
      archetype_id = params["archetype_id"] ->
        # Archetype drop on empty canvas → seed the whole topology; otherwise
        # insert an `archetype` reference node (lightweight scaffold).
        case Archetypes.fetch(archetype_id) do
          nil ->
            {:noreply, socket}

          %Archetypes{} = a ->
            topology =
              if socket.assigns.topology.nodes == [] do
                Archetypes.seed_topology(a)
              else
                add_node(socket.assigns.topology, "archetype", x, y, %{"archetype_id" => a.id})
              end

            socket =
              socket
              |> assign(selected_archetype_id: a.id)
              |> assign_topology(topology)

            {:noreply, socket}
        end

      type = params["type"] ->
        case Topology.node_types()[type] do
          nil ->
            {:noreply, socket}

          _ ->
            topology = add_node(socket.assigns.topology, type, x, y, %{})
            {:noreply, assign_topology(socket, topology)}
        end

      true ->
        {:noreply, socket}
    end
  end

  def handle_event("update_node_params", %{"_target" => _tgt} = params, socket) do
    do_update_node_params(socket, params)
  end

  def handle_event("update_node_params", params, socket) do
    do_update_node_params(socket, params)
  end

  def handle_event("delete_node", %{"id" => id}, socket) do
    topology = %{
      socket.assigns.topology
      | nodes: Enum.reject(socket.assigns.topology.nodes, &(&1.id == id)),
        edges:
          Enum.reject(socket.assigns.topology.edges, fn e ->
            e.from_node == id or e.to_node == id
          end)
    }

    socket =
      socket
      |> (fn s ->
            if s.assigns.selected_node_id == id, do: assign(s, selected_node_id: nil), else: s
          end).()
      |> assign_topology(topology)

    {:noreply, socket}
  end

  # -- Save + Instantiate ----------------------------------------------------

  def handle_event("save_spec", _params, socket) do
    archetype_id = socket.assigns.selected_archetype_id || "pomdp_maze"
    archetype = Archetypes.fetch(archetype_id) || Archetypes.fetch("pomdp_maze")

    spec_id =
      "spec-builder-" <> (:crypto.strong_rand_bytes(4) |> Base.url_encode64(padding: false))

    spec =
      Spec.new(%{
        id: spec_id,
        archetype_id: archetype.id,
        family_id: archetype.family_id,
        primary_equation_ids: archetype.primary_equation_ids,
        bundle_params: archetype.default_params,
        blanket: default_blanket_params(),
        topology: socket.assigns.topology,
        created_by: "/builder"
      })

    case AgentRegistry.register_spec(spec) do
      {:ok, stored} ->
        :ok =
          EventLog.append(
            Event.new(%{
              type: "spec.saved",
              provenance: %{
                spec_id: stored.id,
                archetype_id: stored.archetype_id,
                family_id: stored.family_id
              },
              data: %{hash: stored.hash}
            })
          )

        {:noreply, assign(socket, spec: stored)}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def handle_event("instantiate", _params, %{assigns: %{spec: nil}} = socket) do
    {:noreply, assign(socket, validation_errors: [:no_spec_saved])}
  end

  def handle_event("instantiate", _params, %{assigns: %{spec: spec}} = socket) do
    archetype = Archetypes.fetch(spec.archetype_id) || %{disabled?: false}

    if archetype.disabled? do
      {:noreply, assign(socket, validation_errors: [:archetype_disabled])}
    else
      agent_id =
        "agent-builder-" <> (:crypto.strong_rand_bytes(4) |> Base.url_encode64(padding: false))

      blanket = Blanket.maze_default()

      bundle =
        BundleBuilder.for_maze(
          width: 3,
          height: 3,
          start_idx: 3,
          goal_idx: 5,
          walls: [],
          blanket: blanket,
          horizon: Map.get(spec.bundle_params, :horizon, 3),
          policy_depth: Map.get(spec.bundle_params, :policy_depth, 3),
          preference_strength: Map.get(spec.bundle_params, :preference_strength, 4.0),
          spec_id: spec.id
        )

      # Studio S13 -- track the Instantiated agent in the Studio registry
      # so the new `/studio/agents/:id` panel can manage its lifecycle.
      # The canonical Glass redirect is preserved (non-regression with
      # existing tests + the `/glass/*` promise); a flash advertises the
      # new Studio option as an alternative entry point.
      case Runtime.start_tracked_agent(
             %{
               agent_id: agent_id,
               bundle: bundle,
               blanket: blanket,
               goal_idx: 5,
               spec_id: spec.id
             },
             source: :builder,
             name: spec.id
           ) do
        {:ok, _instance, _pid} ->
          {:noreply,
           socket
           |> put_flash(
             :info,
             "Agent #{agent_id} running.  Manage its lifecycle in Studio."
           )
           |> push_navigate(to: ~p"/glass/agent/#{agent_id}")}

        {:error, reason} ->
          {:noreply, assign(socket, validation_errors: [{:start_agent_failed, reason}])}
      end
    end
  end

  def handle_event(_, _, socket), do: {:noreply, socket}

  # -- Bus echo for the saved-specs history ---------------------------------

  @impl true
  def handle_info({:world_event, _e}, socket), do: {:noreply, socket}

  # -- Node-param helpers ----------------------------------------------------

  defp do_update_node_params(socket, params) do
    case socket.assigns.selected_node_id do
      nil ->
        {:noreply, socket}

      node_id ->
        form_params = Map.get(params, node_id, %{})
        topology = socket.assigns.topology

        case Enum.find(topology.nodes, &(&1.id == node_id)) do
          nil ->
            {:noreply, socket}

          node ->
            merged = Map.merge(node.params || %{}, form_params)
            {validated, errs} = BlockSchema.validate(node.type, merged)

            new_nodes =
              Enum.map(topology.nodes, fn n ->
                if n.id == node_id, do: %{n | params: validated}, else: n
              end)

            new_topology = %{topology | nodes: new_nodes}

            socket =
              socket
              |> assign(param_errors: Map.put(socket.assigns.param_errors, node_id, errs))
              |> assign_topology(new_topology)

            {:noreply, socket}
        end
    end
  end

  defp add_node(topology, type, x, y, extra_params) do
    node_id = "n_" <> (:crypto.strong_rand_bytes(3) |> Base.url_encode64(padding: false))
    defaults = BlockSchema.defaults(type)
    params = Map.merge(defaults, extra_params)

    node = %{id: node_id, type: type, params: params, position: %{x: x, y: y}}
    %{topology | nodes: topology.nodes ++ [node]}
  end

  defp to_i(n, _) when is_integer(n), do: n
  defp to_i(n, _) when is_float(n), do: trunc(n)

  defp to_i(s, default) when is_binary(s) do
    case Integer.parse(s) do
      {n, _} -> n
      :error -> default
    end
  end

  defp to_i(_, default), do: default

  # -- Topology helpers ------------------------------------------------------

  defp normalize_topology(%{"nodes" => nodes, "edges" => edges} = topology) do
    %{
      nodes: Enum.map(nodes || [], &normalize_node/1),
      edges: Enum.map(edges || [], &normalize_edge/1),
      required_types: Map.get(topology, "required_types", []) |> Enum.map(&to_string/1)
    }
  end

  defp normalize_topology(_), do: %{nodes: [], edges: [], required_types: []}

  defp normalize_node(%{"id" => id, "type" => type} = n) do
    %{
      id: to_string(id),
      type: to_string(type),
      params: stringify(Map.get(n, "params", %{})),
      position: Map.get(n, "position"),
      equation_ids: Map.get(n, "equation_ids", [])
    }
  end

  defp normalize_edge(%{
         "from_node" => fn_,
         "from_port" => fp,
         "to_node" => tn_,
         "to_port" => tp
       }) do
    %{
      from_node: to_string(fn_),
      from_port: to_string(fp),
      to_node: to_string(tn_),
      to_port: to_string(tp)
    }
  end

  defp stringify(%{} = m), do: Enum.into(m, %{}, fn {k, v} -> {to_string(k), v} end)

  defp assign_topology(socket, topology) do
    required =
      case socket.assigns[:selected_archetype_id] do
        nil -> Map.get(topology, :required_types, [])
        aid -> Map.get(topology, :required_types, []) ++ required_for(aid)
      end

    t_with_required = Map.put(topology, :required_types, Enum.uniq(required))

    case Topology.validate(t_with_required) do
      :ok ->
        assign(socket, topology: t_with_required, validation_errors: [])

      {:error, errors} ->
        assign(socket, topology: t_with_required, validation_errors: errors)
    end
  end

  defp required_for(archetype_id) do
    case Archetypes.fetch(archetype_id) do
      %{required_types: req} -> req
      _ -> []
    end
  end

  defp default_blanket_params do
    b = Blanket.maze_default()
    %{observation_channels: b.observation_channels, action_vocabulary: b.action_vocabulary}
  end

  # The palette — grouped draggable cards in authoring order.
  defp block_palette do
    [
      {"Generative model (A/B/C/D)",
       [
         "likelihood_matrix",
         "transition_matrix",
         "preference_vector",
         "prior_vector",
         "bundle_assembler"
       ]},
      {"Action loop (Perceive/Plan/Act)", ["perceive", "plan", "act", "sophisticated_planner"]},
      {"Learning", ["dirichlet_a_learner", "dirichlet_b_learner"]},
      {"Skills / workflows", ["skill", "workflow", "epistemic_preference"]},
      {"Composition", ["meta_agent", "sub_agent"]},
      {"Reference", ["archetype", "equation"]}
    ]
  end

  # Trim the node-types registry down to the in/out shape the JS hook needs.
  defp topology_node_types_for_js do
    Topology.node_types()
    |> Enum.into(%{}, fn {type, %{ports: ports}} ->
      {type,
       %{
         in: Map.new(Map.get(ports, :in, %{}), fn {k, v} -> {k, to_string(v)} end),
         out: Map.new(Map.get(ports, :out, %{}), fn {k, v} -> {k, to_string(v)} end)
       }}
    end)
  end

  # -- Render ----------------------------------------------------------------

  @impl true
  def render(assigns) do
    assigns = assign(assigns, selected_node: selected_node(assigns))

    ~H"""
    <h1>Agent Builder</h1>
    <p style="color:#9cb0d6;">
      Drag a block from the palette onto the canvas. Click a node to edit its
      params in the Inspector. Every edit round-trips through server-side
      validation.
    </p>

    <%= if @recipe_banner do %>
      <div class="card" style="border-color:#b3863a;background:#1a1612;">
        <h3 style="margin-top:0;color:#d8b56c;">
          Building recipe: <%= @recipe_banner["title"] %>
        </h3>
        <p style="color:#9cb0d6;font-size:13px;">
          Target runtime below.  Configure the canvas to match, then Save + Instantiate.
        </p>
        <ul style="font-size:13px;">
          <li>World: <code class="inline"><%= get_in(@recipe_banner, ["runtime", "world"]) %></code></li>
          <li>Horizon: <%= get_in(@recipe_banner, ["runtime", "horizon"]) %> · Policy depth: <%= get_in(@recipe_banner, ["runtime", "policy_depth"]) %></li>
          <li>Preference strength: <%= get_in(@recipe_banner, ["runtime", "preference_strength"]) %></li>
          <li>Actions used: <code class="inline"><%= Enum.join(get_in(@recipe_banner, ["runtime", "actions_used"]) || [], ", ") %></code></li>
          <li>Skills used: <code class="inline"><%= Enum.join(get_in(@recipe_banner, ["runtime", "skills_used"]) || [], ", ") %></code></li>
        </ul>
        <p style="font-size:12px;margin:6px 0 0;">
          <a href={"/cookbook/" <> (@recipe_banner["slug"] || "")}>Open recipe page &rarr;</a>
        </p>
      </div>
    <% end %>

    <div class="builder-grid">
      <aside class="palette">
        <form phx-change="search">
          <input type="text" name="q" value={@query} placeholder="search palette…" />
        </form>

        <h3>Archetypes</h3>
        <%= for a <- @archetypes, match_query?(a.name, @query) do %>
          <div class={"archetype-card " <> if a.disabled?, do: "disabled", else: ""}
               draggable={if a.disabled?, do: "false", else: "true"}
               phx-click="seed_archetype"
               phx-value-archetype_id={a.id}
               data-archetype-id={a.id}
               ondragstart="event.dataTransfer.setData('application/x-archetype-id', this.dataset.archetypeId)">
            <div class="card-title"><%= a.name %></div>
            <div class="card-meta">
              <code class="inline"><%= a.id %></code>
              <%= if a.disabled? do %>
                <span class="tag uncertain">not yet runnable</span>
              <% end %>
            </div>
            <p class="card-desc"><%= a.description %></p>
          </div>
        <% end %>

        <%= for {group, types} <- @block_types do %>
          <h3><%= group %></h3>
          <%= for t <- types do %>
            <div class="block-card"
                 draggable="true"
                 data-node-type={t}
                 ondragstart="event.dataTransfer.setData('application/x-node-type', this.dataset.nodeType)"
                 title={(WorldModels.Spec.BlockSchema.fetch(t) || %{description: ""}).description}>
              <code class="inline"><%= t %></code>
            </div>
          <% end %>
        <% end %>

        <h3>Families</h3>
        <%= for f <- @families, match_query?(f.model_name, @query) do %>
          <div class="family-card" title={"Grounded in " <> Integer.to_string(length(f.source_basis)) <> " equations"}>
            <div class="card-title"><%= f.model_name %></div>
            <div class="card-meta">
              <span class={"tag " <> Atom.to_string(f.type)}><%= f.type %></span>
              <span class="tag verified"><%= length(f.source_basis) %> eqs</span>
            </div>
          </div>
        <% end %>

        <h3>Equations</h3>
        <div class="equation-list">
          <%= for e <- @equations, match_query?(e.id, @query) or match_query?(e.equation_number, @query) do %>
            <div class="equation-chip">
              <code class="inline"><%= e.id %></code>
              <span class="tag verified"><%= e.equation_number %></span>
            </div>
          <% end %>
        </div>

        <h3>Actions (reference)</h3>
        <div class="action-list">
          <div class="equation-chip"><code class="inline">perceive</code> eq.4.13/B.5</div>
          <div class="equation-chip"><code class="inline">plan</code> eq.4.14/B.9</div>
          <div class="equation-chip"><code class="inline">act</code> blanket emit</div>
          <div class="equation-chip"><code class="inline">sophisticated_plan</code> Ch 7</div>
          <div class="equation-chip"><code class="inline">dirichlet_update_a</code> eq.7.10</div>
          <div class="equation-chip"><code class="inline">dirichlet_update_b</code> eq.7.10</div>
        </div>
      </aside>

      <section class="canvas-pane">
        <div class="canvas-header">
          <strong>Composition canvas</strong>
          <span class="card-meta">
            <%= length(@topology.nodes) %> nodes · <%= length(@topology.edges) %> edges
          </span>
          <%= if @validation_errors == [] do %>
            <span class="tag verified">topology ok — No validation errors</span>
          <% else %>
            <span class="tag uncertain"><%= length(@validation_errors) %> validation error(s)</span>
          <% end %>
        </div>

        <div id="composition-canvas"
             phx-hook="CompositionCanvas"
             phx-update="ignore"
             data-topology={Jason.encode!(@topology)}
             data-node-types={@node_types_json}>
          <noscript>
            <p>The canvas requires JavaScript. Use the palette cards and form below to compose.</p>
          </noscript>
        </div>

        <%= if @validation_errors != [] do %>
          <div class="card" style="border-color:#7a1d1d;">
            <h3>Validation errors</h3>
            <ul>
              <%= for err <- @validation_errors do %>
                <li><code class="inline"><%= inspect(err) %></code></li>
              <% end %>
            </ul>
          </div>
        <% end %>

        <div class="save-bar">
          <button class="btn" phx-click="save_spec">Save</button>
          <button class="btn primary" phx-click="instantiate" disabled={is_nil(@spec)}>
            Instantiate
          </button>
          <%= if @spec do %>
            <span class="card-meta">
              spec: <code class="inline"><%= @spec.id %></code>
              <span class="tag verified">hash <%= String.slice(@spec.hash, 0, 10) %>…</span>
            </span>
          <% end %>
        </div>
      </section>

      <aside class="inspector">
        <h3>Inspector</h3>
        <%= cond do %>
          <% @topology.nodes == [] -> %>
            <p style="color:#9cb0d6;">Empty canvas — drag a block or archetype to seed.</p>

          <% is_nil(@selected_node) -> %>
            <p style="color:#9cb0d6; font-size: 12px;">
              Click a node on the canvas to edit its params. Or pick one:
            </p>
            <ul>
              <%= for n <- @topology.nodes do %>
                <li>
                  <button class="btn" style="font-size:11px;padding:2px 6px;"
                          phx-click="select_node" phx-value-id={n.id}>
                    <%= n.type %> · <%= String.slice(n.id, 0, 10) %>
                  </button>
                </li>
              <% end %>
            </ul>

          <% true -> %>
            <.inspector_form node={@selected_node}
                             schema={BlockSchema.fetch(@selected_node.type)}
                             errors={Map.get(@param_errors, @selected_node.id, %{})} />
        <% end %>

        <%= if @selected_archetype_id do %>
          <h3>Archetype provenance</h3>
          <% a = Archetypes.fetch(@selected_archetype_id) %>
          <p><strong>Family:</strong> <%= a.family_id %></p>
          <p><strong>Primary equations:</strong></p>
          <ul>
            <%= for eq_id <- a.primary_equation_ids do %>
              <li><code class="inline"><%= eq_id %></code></li>
            <% end %>
          </ul>
        <% end %>
      </aside>
    </div>

    <style>
      .builder-grid {
        display: grid;
        grid-template-columns: 260px 1fr 300px;
        gap: 12px;
        align-items: start;
        margin-top: 16px;
      }
      .palette, .inspector, .canvas-pane {
        background: #121a33;
        border: 1px solid #263257;
        border-radius: 8px;
        padding: 12px;
      }
      .palette { max-height: 78vh; overflow-y: auto; }
      .canvas-pane { padding: 0; }
      .canvas-header {
        display: flex; align-items: center; gap: 8px;
        padding: 10px 14px; border-bottom: 1px solid #263257;
      }
      #composition-canvas {
        position: relative;
        width: 100%;
        height: 520px;
        background: #0a1226;
      }
      .save-bar {
        display: flex; align-items: center; gap: 10px;
        padding: 10px 14px; border-top: 1px solid #263257;
      }
      .archetype-card, .family-card {
        padding: 8px; border: 1px solid #24314f; border-radius: 6px;
        margin: 6px 0; cursor: grab; background: #0f1a34;
      }
      .archetype-card:active, .block-card:active { cursor: grabbing; }
      .archetype-card.disabled { opacity: 0.55; cursor: not-allowed; }
      .archetype-card:hover:not(.disabled) { border-color: #5ba3ef; }
      .block-card {
        padding: 6px 8px; border: 1px solid #24314f; border-radius: 4px;
        margin: 4px 0; cursor: grab; background: #0f1a34; font-size: 12px;
      }
      .block-card:hover { border-color: #5ba3ef; }
      .card-title { font-weight: 600; color: #cbd5e1; font-size: 13px; }
      .card-meta { font-size: 11px; color: #9cb0d6; margin-top: 2px; }
      .card-desc { font-size: 11px; color: #8a9cc0; margin: 4px 0 0; }
      .equation-list, .action-list {
        display: flex; flex-direction: column; gap: 4px; max-height: 200px; overflow-y: auto;
      }
      .equation-chip {
        font-size: 11px; padding: 4px 6px; background: #0a1226;
        border: 1px solid #24314f; border-radius: 4px;
      }
      .inspector form { margin-top: 6px; }
      .inspector form .field { margin-bottom: 10px; }
      .inspector .field label { display: block; font-size: 12px; margin-bottom: 3px; color: #9cb0d6; }
      .inspector .field input, .inspector .field select {
        width: 100%; box-sizing: border-box;
      }
      .inspector .field .err { color: #fca5a5; font-size: 11px; margin-top: 2px; }
      .inspector .field .hint { color: #7a8cb3; font-size: 11px; margin-top: 2px; }
      .inspector .actions { display: flex; gap: 6px; margin-top: 10px; }
    </style>
    """
  end

  # Inspector form component — renders one field per schema entry.
  attr :node, :map, required: true
  attr :schema, :map, default: nil
  attr :errors, :map, default: %{}

  defp inspector_form(assigns) do
    ~H"""
    <div>
      <p style="font-size:12px;color:#9cb0d6;">
        <strong><%= @node.type %></strong>
        &middot; <code class="inline"><%= String.slice(@node.id, 0, 14) %></code>
      </p>
      <%= if @schema do %>
        <p class="hint" style="font-size:11px;color:#7a8cb3;"><%= @schema.description %></p>

        <form phx-change="update_node_params" phx-submit="update_node_params">
          <%= for field <- @schema.fields do %>
            <div class="field">
              <label><%= field.name %>
                <%= if Map.get(field, :required?, false), do: raw("<span style='color:#fca5a5'>*</span>") %>
              </label>
              <%= render_field(field, Map.get(@node.params || %{}, to_string(field.name)), @node.id) %>
              <%= if msg = Map.get(@errors, to_string(field.name)) do %>
                <div class="err"><%= msg %></div>
              <% end %>
              <%= if d = Map.get(field, :description) do %>
                <div class="hint"><%= d %></div>
              <% end %>
            </div>
          <% end %>
        </form>
      <% else %>
        <p style="color:#9cb0d6;">No schema registered for this block type.</p>
      <% end %>

      <div class="actions">
        <button class="btn" phx-click="delete_node" phx-value-id={@node.id}>Delete node</button>
        <button class="btn" phx-click="select_node" phx-value-id="">Deselect</button>
      </div>
    </div>
    """
  end

  # Per-type field rendering — name attribute is `node_id[field_name]` so the
  # phx-change event carries a keyed map we can destructure server-side.
  defp render_field(%{type: t} = f, value, node_id) when t in [:integer, :float] do
    input_type = if t == :integer, do: "number", else: "number"
    step = if t == :integer, do: "1", else: "any"
    v = value || f.default
    assigns = %{f: f, node_id: node_id, input_type: input_type, step: step, v: v}

    ~H"""
    <input type={@input_type} step={@step}
           min={Map.get(@f, :min)} max={Map.get(@f, :max)}
           name={"#{@node_id}[#{@f.name}]"} value={@v} />
    """
  end

  defp render_field(%{type: :boolean} = f, value, node_id) do
    v = if is_nil(value), do: f.default, else: value
    assigns = %{f: f, node_id: node_id, v: v}

    ~H"""
    <input type="hidden" name={"#{@node_id}[#{@f.name}]"} value="false" />
    <input type="checkbox" name={"#{@node_id}[#{@f.name}]"} value="true"
           checked={@v == true or @v == "true"} />
    """
  end

  defp render_field(%{type: :choice, choices: choices} = f, value, node_id) do
    v = value || f.default
    assigns = %{f: f, node_id: node_id, v: v, choices: choices}

    ~H"""
    <select name={"#{@node_id}[#{@f.name}]"}>
      <%= for c <- @choices do %>
        <option value={c} selected={to_string(c) == to_string(@v)}><%= c %></option>
      <% end %>
    </select>
    """
  end

  defp render_field(%{type: :string} = f, value, node_id) do
    v = value || f.default
    assigns = %{f: f, node_id: node_id, v: v}

    ~H"""
    <input type="text" name={"#{@node_id}[#{@f.name}]"} value={@v} />
    """
  end

  defp render_field(%{type: t} = f, _value, node_id) when t in [:matrix, :vector] do
    assigns = %{f: f, node_id: node_id}

    ~H"""
    <div class="hint">
      <%= @f.type %> editor ships in a later phase —
      defaults from <code class="inline"><%= @f.name %></code> are used.
    </div>
    <input type="hidden" name={"#{@node_id}[#{@f.name}]"} value="" />
    """
  end

  defp selected_node(%{selected_node_id: nil}), do: nil

  defp selected_node(%{selected_node_id: id, topology: %{nodes: nodes}}) do
    Enum.find(nodes, &(&1.id == id))
  end

  defp selected_node(_), do: nil

  defp match_query?(_, ""), do: true

  defp match_query?(text, q) when is_binary(text) and is_binary(q) do
    String.contains?(String.downcase(text), String.downcase(q))
  end

  defp match_query?(_, _), do: false
end

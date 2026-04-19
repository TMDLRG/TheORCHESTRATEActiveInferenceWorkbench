defmodule WorkbenchWeb.StudioLive.New do
  @moduledoc """
  Studio S7 -- new-run picker with full Labs-parity spec+world picker +
  compilation preview.  Three flows on top:

    1. **Attach existing agent** -- pick an `:live` or `:stopped` tracked
        agent + a world; preflight compatibility check; attach via
        `Episode.attach/1`.
    2. **Instantiate from spec** -- pick a seeded spec + world; compile
        via `SpecCompiler.compile/3` with a live preview; then spawn a
        tracked agent via `Runtime.start_tracked_agent/2` and attach.
    3. **Build from recipe** -- pick a cookbook slug; the recipe-to-spec
        mapping resolves to a seeded spec and the flow above runs.

  All three land on `/studio/run/:session_id` after booting a
  `WorkbenchWeb.Episode` via `attach/1`.
  """
  use WorkbenchWeb, :live_view

  require Logger

  alias AgentPlane.{Instance, Instances, Runtime}
  alias SharedContracts.Blanket
  alias WorkbenchWeb.{Cookbook.Loader, Episode, SpecCompiler}
  alias WorldModels.AgentRegistry
  alias WorldPlane.{Worlds, WorldRegistry}

  @impl true
  def mount(params, _session, socket) do
    default_recipe = params["recipe"]
    default_agent = params["agent"]

    default_world =
      case params["world"] do
        w when is_binary(w) ->
          try do
            String.to_existing_atom(w)
          rescue
            ArgumentError -> nil
          end

        _ ->
          nil
      end

    specs = AgentRegistry.list_specs()
    mazes = Worlds.all()
    agents = Instances.list(states: [:live, :stopped])
    recipes = Loader.list()

    # If the URL names an agent, switch to the :attach flow and preselect.
    # The common origin is Builder -> post-Instantiate flash link, but any
    # /studio/agents/:id "New run with this agent" link lands here too.
    flow = initial_flow(default_recipe, default_agent)

    {:ok,
     socket
     |> assign(
       page_title: "New Studio run",
       flow: flow,
       worlds: WorldRegistry.all(),
       mazes: mazes,
       specs: specs,
       agents: agents,
       recipes: recipes,
       selected_agent_id: default_agent,
       selected_spec_id:
         cond do
           default_recipe -> Loader.spec_id_for(default_recipe)
           true -> (List.first(specs) || %{id: nil}).id
         end,
       selected_recipe: default_recipe,
       selected_world_id: default_world || (List.first(mazes) || %{id: nil}).id,
       compile_preview: nil,
       preflight: nil,
       error: nil
     )
     |> refresh_preview()
     |> maybe_run_preflight()}
  end

  defp initial_flow(_recipe, agent) when is_binary(agent), do: :attach
  defp initial_flow(nil, _), do: :attach
  defp initial_flow(_recipe, _), do: :recipe

  # -- Events ---------------------------------------------------------------

  @impl true
  def handle_event("set_flow", %{"flow" => f}, socket) do
    {:noreply,
     assign(socket, flow: String.to_existing_atom(f), preflight: nil, error: nil)
     |> maybe_run_preflight()
     |> refresh_preview()}
  end

  def handle_event("select_agent", %{"agent_id" => id}, socket) do
    id = if id == "", do: nil, else: id
    {:noreply, socket |> assign(selected_agent_id: id) |> maybe_run_preflight()}
  end

  def handle_event("select_spec", %{"spec_id" => id}, socket) do
    id = if id == "", do: nil, else: id
    {:noreply, socket |> assign(selected_spec_id: id) |> refresh_preview()}
  end

  def handle_event("select_recipe", %{"recipe" => slug}, socket) do
    slug = if slug == "", do: nil, else: slug

    spec_id =
      if is_binary(slug) do
        Loader.spec_id_for(slug)
      else
        socket.assigns.selected_spec_id
      end

    {:noreply,
     socket
     |> assign(selected_recipe: slug, selected_spec_id: spec_id)
     |> refresh_preview()}
  end

  def handle_event("select_world", %{"world_id" => w}, socket) do
    atom =
      if w == "" do
        nil
      else
        try do
          String.to_existing_atom(w)
        rescue
          ArgumentError -> nil
        end
      end

    {:noreply,
     socket
     |> assign(selected_world_id: atom)
     |> maybe_run_preflight()
     |> refresh_preview()}
  end

  def handle_event("start_attach", _, socket) do
    aid = socket.assigns.selected_agent_id
    wid = socket.assigns.selected_world_id

    cond do
      not is_binary(aid) ->
        {:noreply, assign(socket, error: "Pick an agent.")}

      is_nil(wid) ->
        {:noreply, assign(socket, error: "Pick a world.")}

      true ->
        try do
          case Episode.attach(agent_id: aid, world_id: wid, max_steps: 36) do
            {:ok, _pid, session_id} ->
              {:noreply, push_navigate(socket, to: ~p"/studio/run/#{session_id}")}

            {:error, reason} ->
              {:noreply, assign(socket, error: humanise(reason))}
          end
        rescue
          e -> {:noreply, assign(socket, error: "Crash: #{Exception.message(e)}")}
        catch
          k, r -> {:noreply, assign(socket, error: "#{k}: #{inspect(r)}")}
        end
    end
  end

  def handle_event("start_from_spec", _, socket) do
    Logger.info(
      "[studio.new] start_from_spec spec=#{inspect(socket.assigns.selected_spec_id)} world=#{inspect(socket.assigns.selected_world_id)}"
    )

    do_start_from_spec(socket, socket.assigns.flow)
  end

  def handle_event("start_from_recipe", _, socket) do
    Logger.info(
      "[studio.new] start_from_recipe slug=#{inspect(socket.assigns.selected_recipe)}"
    )

    slug = socket.assigns.selected_recipe

    cond do
      not is_binary(slug) ->
        {:noreply, assign(socket, error: "Pick a recipe.")}

      true ->
        spec_id = Loader.spec_id_for(slug)

        socket
        |> assign(selected_spec_id: spec_id)
        |> refresh_preview()
        |> do_start_from_spec(:recipe)
    end
  end

  def handle_event(_, _, socket), do: {:noreply, socket}

  defp do_start_from_spec(socket, flow) do
    try do
      wid = socket.assigns.selected_world_id
      preview = socket.assigns.compile_preview

      cond do
        is_nil(wid) ->
          {:noreply, assign(socket, error: "Pick a world.")}

        not match?(%{status: :ok}, preview) ->
          {:noreply,
           assign(socket,
             error: "Compile preview is not ready.  Pick a spec + world first."
           )}

        true ->
          %{spec: spec, bundle: bundle, maze: maze} = preview
          goal_idx = bundle.dims.n_states - 1

          source = if flow == :recipe, do: :cookbook, else: :studio

          agent_id =
            "agent-" <> Atom.to_string(source) <> "-" <>
              (:crypto.strong_rand_bytes(6) |> Base.url_encode64(padding: false))

          lifecycle_opts =
            [source: source, name: "#{flow}: #{spec.id}"]
            |> then(fn opts ->
              if flow == :recipe,
                do: Keyword.put(opts, :recipe_slug, socket.assigns.selected_recipe),
                else: opts
            end)

          with {:ok, %Instance{}, _pid} <-
                 Runtime.start_tracked_agent(
                   %{
                     agent_id: agent_id,
                     spec_id: spec.id,
                     bundle: bundle,
                     blanket: Blanket.maze_default(),
                     goal_idx: goal_idx
                   },
                   lifecycle_opts
                 ),
               {:ok, _ep_pid, session_id} <-
                 Episode.attach(
                   agent_id: agent_id,
                   world_id: maze.id,
                   max_steps: max_steps(maze)
                 ) do
            {:noreply, push_navigate(socket, to: ~p"/studio/run/#{session_id}")}
          else
            {:error, reason} ->
              Logger.warning("[studio.new] start error: #{inspect(reason)}")
              {:noreply, assign(socket, error: humanise(reason))}

            other ->
              Logger.warning("[studio.new] start fallthrough: #{inspect(other)}")
              {:noreply, assign(socket, error: "Unexpected: #{inspect(other)}")}
          end
      end
    rescue
      e ->
        Logger.error("[studio.new] crash: #{Exception.format(:error, e, __STACKTRACE__)}")
        {:noreply, assign(socket, error: "Crash: #{Exception.message(e)}")}
    catch
      k, r ->
        Logger.error("[studio.new] catch #{k}: #{inspect(r)}")
        {:noreply, assign(socket, error: "#{k}: #{inspect(r)}")}
    end
  end

  defp refresh_preview(%{assigns: %{selected_spec_id: nil}} = socket),
    do: assign(socket, compile_preview: nil)

  defp refresh_preview(
         %{assigns: %{selected_spec_id: spec_id, selected_world_id: world_id}} = socket
       )
       when is_binary(spec_id) and not is_nil(world_id) do
    with {:ok, spec} <- AgentRegistry.fetch_spec(spec_id),
         maze when not is_nil(maze) <- Worlds.fetch(world_id),
         {:ok, bundle, agent_opts} <-
           SpecCompiler.compile(spec, maze, blanket: Blanket.maze_default()) do
      preview = %{
        status: :ok,
        spec: spec,
        maze: maze,
        bundle: bundle,
        dims: bundle.dims,
        planner: Keyword.get(agent_opts, :planner, :naive),
        extra_actions: Keyword.get(agent_opts, :extra_actions, [])
      }

      assign(socket, compile_preview: preview, error: nil)
    else
      {:error, reason} ->
        assign(socket, compile_preview: %{status: :error, reason: reason})

      :error ->
        assign(socket, compile_preview: %{status: :error, reason: :unknown_spec})

      nil ->
        assign(socket, compile_preview: %{status: :error, reason: :unknown_world})
    end
  end

  defp refresh_preview(socket), do: assign(socket, compile_preview: nil)

  defp maybe_run_preflight(socket) do
    cond do
      socket.assigns.flow == :attach and is_binary(socket.assigns.selected_agent_id) and
          not is_nil(socket.assigns.selected_world_id) ->
        assign(socket,
          preflight:
            Episode.check_compatibility(
              socket.assigns.selected_agent_id,
              socket.assigns.selected_world_id
            )
        )

      true ->
        assign(socket, preflight: nil)
    end
  end

  defp humanise({:unknown_agent, _}), do: "Selected agent is not registered."
  defp humanise({:unknown_world, _}), do: "World is not registered."

  defp humanise({:dims, %{agent: a, world: w}}),
    do: "Dim mismatch. Agent: #{inspect(a)}. World: #{inspect(w)}."

  defp humanise({:invalid_state, s}), do: "Agent is in invalid state #{inspect(s)}."
  defp humanise(other), do: inspect(other)

  defp max_steps(maze), do: maze.width * maze.height * 4

  # -- Render ---------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <p><.link navigate={~p"/studio"}>&larr; Studio</.link></p>
    <h1>New run</h1>
    <p style="color:#9cb0d6;max-width:900px;">
      Three ways to start a run.  All three land on the live episode viewer
      (<code class="inline">/studio/run/:session_id</code>) with full maze,
      belief heatmap, policy bars, and trajectory overlay -- the same visuals
      as <.link navigate={~p"/labs"}>/labs</.link>.
    </p>

    <div class="card">
      <p>
        <button phx-click="set_flow" phx-value-flow="attach" class={"btn #{if @flow == :attach, do: "primary"}"}>
          1. Attach existing agent
        </button>
        <button phx-click="set_flow" phx-value-flow="spec" class={"btn #{if @flow == :spec, do: "primary"}"}>
          2. Instantiate from spec
        </button>
        <button phx-click="set_flow" phx-value-flow="recipe" class={"btn #{if @flow == :recipe, do: "primary"}"}>
          3. Build from cookbook recipe
        </button>
      </p>
    </div>

    <%= if @error do %>
      <div class="card" style="border-color:#fb7185;background:#2a1619;">
        <p style="color:#fb7185;"><%= @error %></p>
      </div>
    <% end %>

    <div class="grid-2">
      <div>
        <%= case @flow do %>
          <% :attach -> %>
            <div class="card">
              <h2>1. Pick tracked agent</h2>
              <%= if @agents == [] do %>
                <p style="color:#9cb0d6;">
                  No tracked agents yet.  Use "Instantiate from spec" or "Build from recipe"
                  first, or see <.link navigate={~p"/builder/new"}>the Builder</.link>.
                </p>
              <% else %>
                <form phx-change="select_agent">
                  <select name="agent_id">
                    <option value="">(select)</option>
                    <%= for a <- @agents do %>
                      <option value={a.agent_id} selected={a.agent_id == @selected_agent_id}>
                        <%= (a.name || a.agent_id) %> &middot; <%= a.state %> &middot; <%= a.spec_id %>
                      </option>
                    <% end %>
                  </select>
                </form>
              <% end %>
            </div>

          <% :spec -> %>
            <div class="card">
              <h2>1. Pick agent spec</h2>
              <form phx-change="select_spec">
                <select name="spec_id">
                  <option value="">(select)</option>
                  <%= for s <- @specs do %>
                    <option value={s.id} selected={s.id == @selected_spec_id}>
                      <%= spec_label(s) %>
                    </option>
                  <% end %>
                </select>
              </form>
            </div>

          <% :recipe -> %>
            <div class="card">
              <h2>1. Pick cookbook recipe</h2>
              <form phx-change="select_recipe">
                <select name="recipe">
                  <option value="">(select)</option>
                  <%= for r <- @recipes do %>
                    <option value={r["slug"]} selected={r["slug"] == @selected_recipe}>
                      L<%= r["level"] %> &middot; <%= r["title"] %>
                    </option>
                  <% end %>
                </select>
              </form>
              <%= if @selected_spec_id do %>
                <p style="font-size:12px;color:#9cb0d6;margin-top:8px;">
                  Resolves to spec: <code class="inline"><%= @selected_spec_id %></code>
                </p>
              <% end %>
            </div>
        <% end %>

        <div class="card">
          <h2>2. Pick world</h2>
          <form phx-change="select_world">
            <select name="world_id">
              <option value="">(select)</option>
              <%= for m <- @mazes do %>
                <option value={Atom.to_string(m.id)} selected={m.id == @selected_world_id}>
                  <%= m.name %>
                </option>
              <% end %>
            </select>
          </form>
        </div>

        <%= if @flow != :attach do %>
          <div class="card">
            <h2>3. Compilation preview</h2>
            <%= case @compile_preview do %>
              <% %{status: :ok} = p -> %>
                <p>
                  <strong>Spec:</strong> <code class="inline"><%= p.spec.id %></code>
                  &middot; archetype <code class="inline"><%= p.spec.archetype_id %></code>
                </p>
                <p>
                  <strong>World:</strong> <%= p.maze.name %>
                  &middot; <%= p.maze.width %>&times;<%= p.maze.height %> tiles
                </p>
                <p>
                  <strong>Bundle dims:</strong>
                  n_states=<%= p.dims.n_states %>, n_obs=<%= p.dims.n_obs %>
                </p>
                <p>
                  <strong>Planner:</strong>
                  <span class={"tag " <> planner_tag(p.planner)}><%= p.planner %></span>
                  <%= if p.extra_actions != [] do %>
                    &middot; <strong>learners:</strong>
                    <%= for m <- p.extra_actions do %>
                      <span class="tag verified">
                        <%= inspect(m) |> String.replace("Elixir.", "") %>
                      </span>
                    <% end %>
                  <% end %>
                </p>

              <% %{status: :error, reason: reason} -> %>
                <p style="color:#fb7185;">
                  Compile failed: <code class="inline"><%= inspect(reason) %></code>
                </p>

              <% _ -> %>
                <p style="color:#9cb0d6;">Pick a spec and a world.</p>
            <% end %>
          </div>
        <% else %>
          <div class="card">
            <h2>3. Compatibility preflight</h2>
            <%= case @preflight do %>
              <% :ok -> %>
                <p style="color:#5eead4;">
                  &check; Preflight OK -- agent bundle matches world dims.
                </p>

              <% {:error, reason} -> %>
                <p style="color:#fb7185;">
                  &#x2717; <%= humanise(reason) %>
                </p>

              <% _ -> %>
                <p style="color:#9cb0d6;">Pick an agent and a world.</p>
            <% end %>
          </div>
        <% end %>

        <div class="card">
          <h2>4. Start</h2>
          <%= case @flow do %>
            <% :attach -> %>
              <button class="btn primary" phx-click="start_attach"
                      disabled={@preflight != :ok or is_nil(@selected_agent_id) or is_nil(@selected_world_id)}>
                Attach + run &rarr;
              </button>

            <% :spec -> %>
              <button class="btn primary" phx-click="start_from_spec"
                      disabled={not match?(%{status: :ok}, @compile_preview)}>
                Instantiate + run &rarr;
              </button>

            <% :recipe -> %>
              <button class="btn primary" phx-click="start_from_recipe"
                      disabled={not match?(%{status: :ok}, @compile_preview) or is_nil(@selected_recipe)}>
                Build from recipe + run &rarr;
              </button>
          <% end %>
        </div>
      </div>

      <div>
        <div class="card">
          <h2>Studio vs. Labs</h2>
          <p style="font-size:13px;color:#9cb0d6;">
            <strong>Labs</strong> (<.link navigate={~p"/labs"}>/labs</.link>) is the stable
            "fresh agent + fresh world per click" runner.  Studio does everything Labs does
            plus:
          </p>
          <ul style="font-size:13px;">
            <li>Attach an already-running agent to any world</li>
            <li>Tracked agent lifecycle (live / stopped / archived / trashed)</li>
            <li>Soft-delete to trash + Restore + Empty trash</li>
            <li>Per-agent panel with full metadata + transitions</li>
            <li>Forward-compat with future custom worlds (via <code class="inline">WorldPlane.WorldBehaviour</code>)</li>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  # -- View helpers (parity with LabsLive.Run) ------------------------------

  defp spec_label(%{id: id, archetype_id: arch}) do
    friendly =
      cond do
        String.starts_with?(id, "example-l1") -> "Example — L1 Hello POMDP"
        String.starts_with?(id, "example-l2") -> "Example — L2 Epistemic explorer"
        String.starts_with?(id, "example-l3") -> "Example — L3 Sophisticated planner"
        String.starts_with?(id, "example-l4") -> "Example — L4 Dirichlet learner"
        String.starts_with?(id, "example-l5") -> "Example — L5 Hierarchical"
        true -> id
      end

    "#{friendly}  ·  #{arch}"
  end

  defp planner_tag(:sophisticated), do: "verified"
  defp planner_tag(:naive), do: "discrete"
  defp planner_tag(_), do: "uncertain"
end

defmodule WorkbenchWeb.LabsLive.Run do
  @moduledoc """
  Expansion Phase K — run ANY saved spec against ANY registered maze.

  Orthogonal to `/world`:

  - `/world` is the *express novice* flow: pick a maze; the page auto-
    builds a bundle tailored to that maze and boots a supervised agent.
  - `/labs/run` is the *workbench matrix*: pick a spec (one of the five
    seeded examples or any user-saved composition) and a maze, compile
    via `WorkbenchWeb.SpecCompiler.compile/3`, and run the resulting
    agent inside the existing `WorkbenchWeb.Episode` machinery.

  The LV owns the episode lifecycle (Run/Pause/Reset/Stop) and renders
  the same live visuals as `/world`, plus the policy-direction bar chart
  and the planned-trajectory overlay introduced in Phase L.
  """
  use WorkbenchWeb, :live_view

  alias SharedContracts.Blanket
  alias WorkbenchWeb.Components.PolicyVisual
  alias WorkbenchWeb.{Episode, SpecCompiler}
  alias WorldModels.{AgentRegistry, Bus}
  alias WorldPlane.Worlds

  @impl true
  def mount(params, _session, socket) do
    specs = AgentRegistry.list_specs()
    mazes = Worlds.all()

    # D6 / G8 -- accept `?recipe=<slug>` and `?world=<id>` so the cookbook
    # "Run in Labs" button boots a recipe directly.  Also show a banner so
    # the user sees which recipe they are running.
    recipe_banner = recipe_hint(params)

    selected_spec_id =
      cond do
        is_binary(params["spec_id"]) ->
          params["spec_id"]

        # D6 -- when `?recipe=` is present, auto-select the closest seeded
        # spec for that recipe so the learner can immediately hit
        # "Create agent + world" and see a real Jido run + /glass traces.
        is_binary(params["recipe"]) ->
          WorkbenchWeb.Cookbook.Loader.spec_id_for(params["recipe"])

        true ->
          (List.first(specs) || %{id: nil}).id
      end

    selected_world_id =
      cond do
        is_binary(params["world"]) ->
          # `?world=<id>` is the cookbook-friendly form; force-load mazes
          # so the atom exists.
          _ = Worlds.all()

          try do
            String.to_existing_atom(params["world"])
          rescue
            ArgumentError -> (List.first(mazes) || %{id: nil}).id
          end

        is_binary(params["world_id"]) ->
          String.to_existing_atom(params["world_id"])

        true ->
          (List.first(mazes) || %{id: nil}).id
      end

    {:ok,
     socket
     |> assign(
       page_title: "Labs",
       specs: specs,
       mazes: mazes,
       selected_spec_id: selected_spec_id,
       selected_world_id: selected_world_id,
       compile_preview: nil,
       episode_pid: nil,
       session_id: nil,
       agent_id: nil,
       spec_id: nil,
       running?: false,
       auto_running?: false,
       summary: nil,
       history: [],
       recent_events: [],
       recipe_banner: recipe_banner,
       error: nil
     )
     |> refresh_preview()}
  end

  defp recipe_hint(%{"recipe" => slug}) when is_binary(slug) do
    case WorkbenchWeb.Cookbook.Loader.get(slug) do
      nil -> nil
      recipe -> recipe
    end
  end

  defp recipe_hint(_), do: nil

  # -- Events ----------------------------------------------------------------

  @impl true
  def handle_event("select_spec", %{"spec_id" => id}, socket) do
    {:noreply, socket |> assign(selected_spec_id: id) |> refresh_preview()}
  end

  def handle_event("select_world", %{"world_id" => id}, socket) do
    world_id = String.to_existing_atom(id)

    {:noreply, socket |> assign(selected_world_id: world_id) |> refresh_preview()}
  end

  def handle_event("create_episode", _params, socket) do
    case socket.assigns.compile_preview do
      %{status: :ok, bundle: bundle, maze: maze, spec: spec} ->
        do_create_episode(socket, spec, maze, bundle)

      %{status: :error, reason: reason} ->
        {:noreply, assign(socket, error: "Compile failed: #{inspect(reason)}")}

      nil ->
        {:noreply, socket}
    end
  end

  def handle_event("step", _params, %{assigns: %{episode_pid: pid}} = socket)
      when not is_nil(pid) do
    {:noreply, elem(do_step(socket), 0)}
  end

  def handle_event("run_all", _params, %{assigns: %{episode_pid: pid}} = socket)
      when not is_nil(pid) do
    send(self(), :tick)
    {:noreply, assign(socket, auto_running?: true)}
  end

  def handle_event("pause", _params, socket), do: {:noreply, assign(socket, auto_running?: false)}

  def handle_event("reset", _params, %{assigns: %{episode_pid: pid}} = socket)
      when not is_nil(pid) do
    Episode.reset(pid)

    {:noreply,
     assign(socket,
       history: [],
       summary: Episode.inspect_state(pid),
       running?: true,
       auto_running?: false,
       recent_events: []
     )}
  end

  def handle_event("stop", _params, %{assigns: %{episode_pid: pid}} = socket)
      when not is_nil(pid) do
    Episode.stop(pid)

    {:noreply,
     assign(socket,
       episode_pid: nil,
       running?: false,
       auto_running?: false
     )}
  end

  def handle_event(_, _, socket), do: {:noreply, socket}

  # -- Tick + bus -----------------------------------------------------------

  @impl true
  def handle_info(:tick, %{assigns: %{auto_running?: false}} = socket), do: {:noreply, socket}
  def handle_info(:tick, %{assigns: %{episode_pid: nil}} = socket), do: {:noreply, socket}

  def handle_info(:tick, socket) do
    {socket, done?} = do_step(socket)
    if not done? and socket.assigns.auto_running?, do: Process.send_after(self(), :tick, 150)
    {:noreply, socket}
  end

  def handle_info({:world_event, event}, socket) do
    {:noreply,
     assign(socket, recent_events: [event | socket.assigns.recent_events] |> Enum.take(20))}
  end

  # -- Helpers ---------------------------------------------------------------

  defp refresh_preview(%{assigns: %{selected_spec_id: nil}} = socket), do: socket

  defp refresh_preview(
         %{assigns: %{selected_spec_id: spec_id, selected_world_id: world_id}} = socket
       ) do
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
        assign(socket, compile_preview: %{status: :error, reason: reason}, error: nil)

      :error ->
        assign(socket,
          compile_preview: %{status: :error, reason: :unknown_spec},
          error: nil
        )

      nil ->
        assign(socket,
          compile_preview: %{status: :error, reason: :unknown_world},
          error: nil
        )
    end
  end

  defp do_create_episode(socket, spec, maze, bundle) do
    blanket = Blanket.maze_default()
    {gc, gr} = maze.goal
    goal_idx = gr * maze.width + gc

    # Pull the SpecCompiler's planner choice + learner modules off the
    # compilation preview so Episode can dispatch the right `Plan` /
    # `SophisticatedPlan` and any post-Act learners (Dirichlet).
    {planner_mode, extra_actions} =
      case socket.assigns.compile_preview do
        %{planner: p, extra_actions: ex} -> {p, ex}
        %{planner: p} -> {p, []}
        _ -> {:naive, []}
      end

    session_id = "labs-session-" <> short_id()
    agent_id = "agent-labs-" <> short_id()
    mode = Application.get_env(:workbench_web, :labs_mode, :pure)

    # Unlinked start so the running episode survives when the user
    # clicks Guide / Credits / any global nav link.  Return via the
    # "Running sessions" chip in the global nav or by URL.
    {:ok, pid} =
      Episode.start_detached(
        session_id: session_id,
        maze: maze,
        blanket: blanket,
        bundle: bundle,
        agent_id: agent_id,
        max_steps: max_steps(maze),
        goal_idx: goal_idx,
        mode: mode,
        planner_mode: planner_mode,
        extra_actions: extra_actions
      )

    if connected?(socket), do: Bus.subscribe_agent(agent_id)

    if mode == :pure, do: _ = AgentRegistry.attach_live(agent_id, spec.id)

    {:noreply,
     assign(socket,
       episode_pid: pid,
       session_id: session_id,
       agent_id: agent_id,
       spec_id: spec.id,
       running?: true,
       auto_running?: false,
       history: [],
       recent_events: [],
       summary: Episode.inspect_state(pid)
     )}
  end

  defp do_step(%{assigns: %{episode_pid: pid}} = socket) do
    case Episode.step(pid) do
      {:ok, entry} ->
        summary = Episode.inspect_state(pid)
        {assign(socket, history: socket.assigns.history ++ [entry], summary: summary), false}

      {:done, summary} ->
        {assign(socket, summary: summary, auto_running?: false, running?: false), true}

      {:error, _} ->
        {assign(socket, auto_running?: false), true}
    end
  end

  defp max_steps(maze), do: maze.width * maze.height * 4
  defp short_id, do: :crypto.strong_rand_bytes(6) |> Base.url_encode64(padding: false)

  # -- Render ----------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Labs — run any agent in any world</h1>

    <%= if @recipe_banner do %>
      <div class="card" style="border-color:#b3863a;background:#1a1612;">
        <h3 style="margin-top:0;color:#d8b56c;">
          Running recipe: <%= @recipe_banner["title"] %>
        </h3>
        <p style="color:#9cb0d6;font-size:13px;margin:0 0 6px;">
          Expected: <%= get_in(@recipe_banner, ["runtime", "expected_outcome"]) %>
        </p>
        <p style="font-size:12px;margin:0;">
          Recipe page: <a href={"/cookbook/" <> (@recipe_banner["slug"] || "")}>
            /cookbook/<%= @recipe_banner["slug"] %> &rarr;
          </a>
        </p>
      </div>
    <% end %>

    <p style="color:#9cb0d6; max-width:780px;">
      Pick a saved spec and a maze. The <code class="inline">SpecCompiler</code>
      derives a bundle tailored to the world, boots a supervised episode,
      and wires it through Glass. Every saved spec (seeded examples + anything
      you save in the Builder) is runnable on every maze.
    </p>

    <div class="grid-2">
      <div>
        <div class="card">
          <h2>1. Pick agent spec</h2>
          <form phx-change="select_spec">
            <select name="spec_id">
              <%= for s <- @specs do %>
                <option value={s.id} selected={@selected_spec_id == s.id}>
                  <%= spec_label(s) %>
                </option>
              <% end %>
            </select>
          </form>
        </div>

        <div class="card">
          <h2>2. Pick world</h2>
          <form phx-change="select_world">
            <select name="world_id">
              <%= for m <- @mazes do %>
                <option value={m.id} selected={@selected_world_id == m.id}>
                  <%= m.name %>
                </option>
              <% end %>
            </select>
          </form>
        </div>

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
                &middot; <%= p.maze.width %>×<%= p.maze.height %> tiles
              </p>
              <p>
                <strong>Bundle dims:</strong>
                n_states=<%= p.dims.n_states %>, n_obs=<%= p.dims.n_obs %>
              </p>
              <p>
                <strong>Planner:</strong> <span class={"tag " <> planner_tag(p.planner)}><%= p.planner %></span>
                <%= if p.extra_actions != [] do %>
                  &middot; <strong>learners:</strong>
                  <%= for m <- p.extra_actions do %>
                    <span class="tag verified"><%= inspect(m) |> String.replace("Elixir.", "") %></span>
                  <% end %>
                <% end %>
              </p>

            <% %{status: :error, reason: reason} -> %>
              <p style="color:#fca5a5;">Compile failed: <code class="inline"><%= inspect(reason) %></code></p>

            <% _ -> %>
              <p style="color:#9cb0d6;">Pick a spec and a world.</p>
          <% end %>
        </div>

        <div class="card">
          <h2>4. Control</h2>
          <button class="btn primary" phx-click="create_episode"
                  disabled={not match?(%{status: :ok}, @compile_preview)}>
            Create agent + world
          </button>
          <button class="btn" phx-click="step" disabled={is_nil(@episode_pid)}>Step</button>
          <button class="btn" phx-click="run_all" disabled={is_nil(@episode_pid) or @auto_running?}>
            Run
          </button>
          <button class="btn" phx-click="pause" disabled={not @auto_running?}>Pause</button>
          <button class="btn" phx-click="reset" disabled={is_nil(@episode_pid)}>Reset</button>
          <button class="btn" phx-click="stop" disabled={is_nil(@episode_pid)}>Stop</button>
        </div>

        <%= if @agent_id do %>
          <div class="card">
            <h2>Live agent</h2>
            <p>Agent: <code class="inline"><%= @agent_id %></code></p>
            <p>Spec: <code class="inline"><%= @spec_id %></code></p>
            <a class="btn" href={"/glass/agent/#{@agent_id}"}>Open in Glass Engine</a>
          </div>
        <% end %>
      </div>

      <div>
        <%= if @summary do %>
          <div class="card">
            <h2>World state</h2>
            <.maze_view maze={@summary.world.maze} pos={@summary.world.pos} />
            <p>
              Position: <code class="inline"><%= inspect(@summary.world.pos) %></code>
              <%= if @summary.terminal? do %>
                &nbsp; <span class="tag verified">goal reached</span>
              <% end %>
            </p>
            <p>Steps: <%= @summary.steps %> / <%= @summary.max_steps %></p>
          </div>

          <div class="card">
            <h2>Agent beliefs (marginal over policies)</h2>
            <.belief_heatmap maze={@summary.world.maze}
                              beliefs={@summary.agent.marginal_state_belief} />
          </div>

          <div class="card">
            <h2>Policy posterior — by direction</h2>
            <PolicyVisual.policy_bars summary={@summary} />
          </div>

          <div class="card">
            <h2>Predicted trajectory</h2>
            <PolicyVisual.trajectory_overlay maze={@summary.world.maze} summary={@summary} />
          </div>

          <div class="card">
            <h2>Telemetry</h2>
            <p>Last action: <code class="inline"><%= inspect(@summary.agent.last_action) %></code></p>
            <p>
              Min F = <%= min_fmt(@summary.agent.last_f) %>
              &nbsp; Min G = <%= min_fmt(@summary.agent.last_g) %>
            </p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # -- View helpers ---------------------------------------------------------

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

  attr :maze, :any, required: true
  attr :pos, :any, required: true

  defp maze_view(assigns) do
    ~H"""
    <div class="maze-grid" style={"grid-template-columns: repeat(#{@maze.width}, 24px);"}>
      <%= for r <- 0..(@maze.height - 1), c <- 0..(@maze.width - 1) do %>
        <.cell tile={Map.get(@maze.grid, {c, r}, :empty)} agent?={@pos == {c, r}} />
      <% end %>
    </div>
    """
  end

  attr :tile, :atom, required: true
  attr :agent?, :boolean, required: true

  defp cell(assigns) do
    ~H"""
    <div class={"maze-cell " <> Atom.to_string(@tile) <> if @agent? do " agent" else "" end}>
      <%= cell_glyph(@tile, @agent?) %>
    </div>
    """
  end

  defp cell_glyph(_, true), do: "@"
  defp cell_glyph(:wall, _), do: ""
  defp cell_glyph(:start, _), do: "S"
  defp cell_glyph(:goal, _), do: "G"
  defp cell_glyph(_, _), do: ""

  attr :maze, :any, required: true
  attr :beliefs, :list, required: true

  defp belief_heatmap(assigns) do
    peak = assigns.beliefs |> Enum.max(fn -> 0.0 end) |> max(1.0e-6)
    assigns = assign(assigns, :peak, peak)

    ~H"""
    <div class="maze-grid" style={"grid-template-columns: repeat(#{@maze.width}, 24px);"}>
      <%= for r <- 0..(@maze.height - 1), c <- 0..(@maze.width - 1) do %>
        <.belief_cell
           p={Enum.at(@beliefs, r * @maze.width + c, 0.0)}
           peak={@peak}
           tile={Map.get(@maze.grid, {c, r}, :empty)} />
      <% end %>
    </div>
    """
  end

  attr :p, :float, required: true
  attr :peak, :float, required: true
  attr :tile, :atom, required: true

  defp belief_cell(assigns) do
    rel = assigns.p / max(assigns.peak, 1.0e-6)

    assigns =
      assigns
      |> assign(:alpha, min(1.0, max(0.04, rel)))
      |> assign(:rel, rel)

    ~H"""
    <div class="maze-cell" style={"background: rgba(52,211,153,#{@alpha});"}>
      <%= if @tile == :wall do "" else (if @rel > 0.25, do: "●", else: "") end %>
    </div>
    """
  end

  defp fmt(x) when is_float(x), do: :erlang.float_to_binary(x, decimals: 3)
  defp fmt(x), do: to_string(x)
  defp min_fmt([]), do: "—"
  defp min_fmt(l), do: l |> Enum.min() |> fmt()
end

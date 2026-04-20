defmodule WorkbenchWeb.StudioLive.Run do
  @moduledoc """
  Studio S8 -- full-parity attached episode runner.

  Reproduces every user-visible element of `LabsLive.Run` (maze view,
  belief heatmap, policy-direction bar chart, predicted-trajectory
  overlay, full telemetry, Step / Run / Pause / Reset / Stop) and
  additionally exposes:

    * Detach (keeps agent `:live`, ends the episode only)
    * Archive / Trash shortcuts (ends episode + transitions agent)
    * Per-agent lifecycle panel link (`/studio/agents/:agent_id`)
    * Glass trace link
    * State badge + source + spec + recipe metadata

  The episode is already attached before the LV mounts -- callers
  reach this route via `StudioController.run_recipe/2` or
  `StudioLive.New`.  The session_id in the URL locates the
  `WorkbenchWeb.Episode` GenServer via `Registry`.
  """
  use WorkbenchWeb, :live_view

  alias AgentPlane.Instances
  alias WorkbenchWeb.Components.PolicyVisual
  alias WorkbenchWeb.Episode
  alias WorldModels.Bus

  @impl true
  def mount(%{"session_id" => session_id}, _session, socket) do
    {summary, episode_alive?} =
      try do
        {Episode.inspect_state(session_id), true}
      rescue
        ArgumentError -> {nil, false}
      end

    agent_id =
      case summary do
        %{agent: %{agent_id: aid}} when is_binary(aid) -> aid
        _ -> nil
      end

    instance =
      case agent_id && Instances.get(agent_id) do
        {:ok, inst} -> inst
        _ -> nil
      end

    if connected?(socket) and is_binary(agent_id) do
      Bus.subscribe_agent(agent_id)
    end

    {:ok,
     assign(socket,
       page_title: "Studio run",
       session_id: session_id,
       episode_alive?: episode_alive?,
       summary: summary,
       history: [],
       recent_events: [],
       agent_id: agent_id,
       instance: instance,
       auto_running?: false,
       error: nil,
       qwen_page_type: :studio_run,
       qwen_page_key: session_id,
       qwen_page_title: "Studio run · " <> session_id
     )}
  end

  # -- Events ---------------------------------------------------------------

  @impl true
  def handle_event("step", _params, socket) do
    {:noreply, elem(do_step(socket), 0)}
  end

  def handle_event("run_all", _params, socket) do
    if socket.assigns.episode_alive? do
      send(self(), :tick)
      {:noreply, assign(socket, auto_running?: true)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("pause", _params, socket) do
    {:noreply, assign(socket, auto_running?: false)}
  end

  def handle_event("reset", _params, %{assigns: %{session_id: sid}} = socket) do
    try do
      Episode.reset(sid)

      {:noreply,
       assign(socket,
         history: [],
         summary: Episode.inspect_state(sid),
         auto_running?: false,
         recent_events: []
       )}
    rescue
      _ -> {:noreply, assign(socket, error: "Episode no longer running.")}
    end
  end

  def handle_event("stop_episode", _params, socket) do
    sid = socket.assigns.session_id
    aid = socket.assigns.agent_id

    try do
      Episode.stop_attached(sid)
    catch
      _, _ -> :ok
    end

    if is_binary(aid) do
      _ = AgentPlane.Runtime.stop_tracked(aid)
    end

    {:noreply, assign(socket, episode_alive?: false, auto_running?: false)}
  end

  def handle_event("detach", _params, socket) do
    try do
      Episode.stop_attached(socket.assigns.session_id)
    catch
      _, _ -> :ok
    end

    {:noreply, push_navigate(socket, to: ~p"/studio")}
  end

  def handle_event("archive", _, socket), do: lifecycle(socket, &AgentPlane.Runtime.archive/1)
  def handle_event("trash", _, socket), do: lifecycle(socket, &AgentPlane.Runtime.trash/1)

  def handle_event(_, _, socket), do: {:noreply, socket}

  defp lifecycle(socket, fun) do
    aid = socket.assigns.agent_id

    if is_binary(aid) do
      try do
        Episode.stop_attached(socket.assigns.session_id)
      catch
        _, _ -> :ok
      end

      case fun.(aid) do
        {:ok, _} -> {:noreply, push_navigate(socket, to: ~p"/studio/agents/#{aid}")}
        {:error, reason} -> {:noreply, assign(socket, error: inspect(reason))}
      end
    else
      {:noreply, socket}
    end
  end

  # -- Tick + bus -----------------------------------------------------------

  @impl true
  def handle_info(:tick, %{assigns: %{auto_running?: false}} = socket), do: {:noreply, socket}
  def handle_info(:tick, %{assigns: %{episode_alive?: false}} = socket), do: {:noreply, socket}

  def handle_info(:tick, socket) do
    {socket, done?} = do_step(socket)
    if not done? and socket.assigns.auto_running?, do: Process.send_after(self(), :tick, 150)
    {:noreply, socket}
  end

  def handle_info({:world_event, event}, socket) do
    {:noreply,
     assign(socket, recent_events: [event | socket.assigns.recent_events] |> Enum.take(20))}
  end

  # -- Helpers --------------------------------------------------------------

  defp do_step(%{assigns: %{session_id: sid}} = socket) do
    try do
      case Episode.step(sid) do
        {:ok, entry} ->
          summary = Episode.inspect_state(sid)

          {assign(socket,
             history: socket.assigns.history ++ [entry],
             summary: summary,
             episode_alive?: true
           ), false}

        {:done, summary} ->
          {assign(socket,
             summary: summary,
             auto_running?: false,
             episode_alive?: false
           ), true}

        {:error, _} ->
          {assign(socket, auto_running?: false, episode_alive?: false), true}
      end
    rescue
      _ ->
        {assign(socket,
           auto_running?: false,
           episode_alive?: false,
           error: "Episode ended."
         ), true}
    catch
      _, _ ->
        {assign(socket,
           auto_running?: false,
           episode_alive?: false,
           error: "Episode ended."
         ), true}
    end
  end

  # -- Render ---------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <p><.link navigate={~p"/studio"}>&larr; Studio</.link></p>
    <h1>Run <code class="inline"><%= @session_id %></code></h1>

    <%= if @instance do %>
      <p style="color:#9cb0d6;">
        <.state_badge state={@instance.state} />
        &middot; <code class="inline"><%= @instance.agent_id %></code>
        &middot; spec: <code class="inline"><%= @instance.spec_id %></code>
        <%= if @instance.recipe_slug do %>
          &middot; recipe:
          <.link navigate={~p"/cookbook/#{@instance.recipe_slug}"}><%= @instance.recipe_slug %></.link>
        <% end %>
        &middot; source: <%= @instance.source %>
      </p>
    <% end %>

    <%= if @error do %>
      <div class="card" style="border-color:#fb7185;background:#2a1619;">
        <p style="color:#fb7185;"><%= @error %></p>
      </div>
    <% end %>

    <div class="grid-2">
      <div>
        <div class="card">
          <h2>Control</h2>
          <button class="btn" phx-click="step" disabled={not @episode_alive?}>Step</button>
          <button class="btn" phx-click="run_all" disabled={not @episode_alive? or @auto_running?}>
            Run
          </button>
          <button class="btn" phx-click="pause" disabled={not @auto_running?}>Pause</button>
          <button class="btn" phx-click="reset" disabled={not @episode_alive?}>Reset</button>
          <button class="btn" phx-click="stop_episode" disabled={not @episode_alive?}>Stop</button>
        </div>

        <div class="card">
          <h2>Session</h2>
          <%= if @agent_id do %>
            <p>Agent: <code class="inline"><%= @agent_id %></code></p>
          <% end %>
          <%= if @instance do %>
            <p>
              <.link navigate={~p"/studio/agents/#{@agent_id}"} class="btn">
                Lifecycle panel &rarr;
              </.link>
              <a class="btn" href={"/glass/agent/#{@agent_id}"} target="_blank" rel="noopener noreferrer">
                Open in Glass
              </a>
            </p>
          <% end %>
        </div>

        <div class="card">
          <h2>Attach lifecycle</h2>
          <button class="btn" phx-click="detach" disabled={is_nil(@agent_id)}>
            Detach (keep agent live)
          </button>
          <button class="btn" phx-click="archive" disabled={is_nil(@agent_id)}>Archive</button>
          <button class="btn" phx-click="trash" disabled={is_nil(@agent_id)}>Trash</button>
          <p style="font-size:12px;color:#9cb0d6;margin-top:8px;">
            <strong>Detach</strong> leaves the agent <code class="inline">:live</code>.
            <strong>Stop</strong> (above) terminates the agent.
            <strong>Archive / Trash</strong> also end the episode.
          </p>
        </div>

        <%= if @summary do %>
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
            <h2>Policy posterior &mdash; by direction</h2>
            <PolicyVisual.policy_bars summary={@summary} />
          </div>

          <div class="card">
            <h2>Predicted trajectory</h2>
            <PolicyVisual.trajectory_overlay maze={@summary.world.maze} summary={@summary} />
          </div>
        <% else %>
          <div class="card">
            <p style="color:#9cb0d6;">
              Session not found.  It may have been detached or the episode terminated.
              <.link navigate={~p"/studio"}>Back to Studio.</.link>
            </p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # -- View helpers (copied from LabsLive.Run for parity) -------------------

  attr :state, :atom, required: true

  defp state_badge(assigns) do
    color =
      case assigns.state do
        :live -> "#5eead4"
        :stopped -> "#9cb0d6"
        :archived -> "#fde68a"
        :trashed -> "#fb7185"
      end

    assigns = assign(assigns, :color, color)

    ~H"""
    <span style={"display:inline-block;padding:2px 8px;border-radius:4px;background:rgba(0,0,0,0.2);color:#{@color};border:1px solid #{@color};font-size:11px;font-weight:600;"}>
      <%= @state %>
    </span>
    """
  end

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
      <%= if @tile == :wall, do: "", else: (if @rel > 0.25, do: "\u25CF", else: "") %>
    </div>
    """
  end

  defp fmt(x) when is_float(x), do: :erlang.float_to_binary(x, decimals: 3)
  defp fmt(x), do: to_string(x)
  defp min_fmt([]), do: "—"
  defp min_fmt(l), do: l |> Enum.min() |> fmt()
end

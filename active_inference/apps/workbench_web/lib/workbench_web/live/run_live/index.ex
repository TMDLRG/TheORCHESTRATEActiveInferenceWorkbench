defmodule WorkbenchWeb.RunLive.Index do
  use WorkbenchWeb, :live_view

  alias AgentPlane.BundleBuilder
  alias SharedContracts.Blanket
  alias WorkbenchWeb.Components.PolicyVisual
  alias WorkbenchWeb.Episode
  alias WorldPlane.Worlds

  @impl true
  def mount(_params, _session, socket) do
    worlds = Worlds.all()
    first_world = hd(worlds)
    blanket = Blanket.maze_default()

    socket =
      socket
      |> assign(
        page_title: "Run Maze",
        worlds: worlds,
        selected_world_id: first_world.id,
        selected_world: first_world,
        blanket: blanket,
        selected_observation_channels: blanket.observation_channels,
        selected_action_vocabulary: blanket.action_vocabulary,
        horizon: 5,
        policy_depth: 5,
        preference_strength: 4.0,
        episode_pid: nil,
        session_id: nil,
        running?: false,
        history: [],
        summary: nil,
        auto_running?: false,
        qwen_page_type: :labs_run,
        qwen_page_key: nil,
        qwen_page_title: "Run Maze"
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("select_world", %{"world" => id}, socket) do
    world_id = String.to_existing_atom(id)
    world = Enum.find(socket.assigns.worlds, &(&1.id == world_id))
    {:noreply, assign(socket, selected_world_id: world_id, selected_world: world)}
  end

  def handle_event("toggle_channel", %{"channel" => ch}, socket) do
    ch_atom = String.to_existing_atom(ch)
    current = socket.assigns.selected_observation_channels

    new =
      if ch_atom in current do
        List.delete(current, ch_atom)
      else
        current ++ [ch_atom]
      end

    blanket = Blanket.with_observation_channels(socket.assigns.blanket, new)
    {:noreply, assign(socket, blanket: blanket, selected_observation_channels: new)}
  end

  def handle_event("toggle_action", %{"action" => act}, socket) do
    act_atom = String.to_existing_atom(act)
    current = socket.assigns.selected_action_vocabulary

    new =
      if act_atom in current do
        List.delete(current, act_atom)
      else
        current ++ [act_atom]
      end

    blanket = Blanket.with_action_vocabulary(socket.assigns.blanket, new)
    {:noreply, assign(socket, blanket: blanket, selected_action_vocabulary: new)}
  end

  def handle_event(
        "update_params",
        %{"horizon" => h, "policy_depth" => d, "preference_strength" => p},
        socket
      ) do
    {:noreply,
     assign(socket,
       horizon: String.to_integer(h),
       policy_depth: String.to_integer(d),
       preference_strength: String.to_float(p) |> guard_float()
     )}
  end

  def handle_event("create_episode", _params, socket) do
    world = socket.assigns.selected_world
    blanket = socket.assigns.blanket

    walls =
      world.grid
      |> Enum.filter(fn {_k, t} -> t == :wall end)
      |> Enum.map(fn {{c, r}, _} -> r * world.width + c end)

    start_idx = elem(world.start, 1) * world.width + elem(world.start, 0)
    goal_idx = elem(world.goal, 1) * world.width + elem(world.goal, 0)

    bundle =
      BundleBuilder.for_maze(
        width: world.width,
        height: world.height,
        start_idx: start_idx,
        goal_idx: goal_idx,
        walls: walls,
        blanket: blanket,
        horizon: socket.assigns.horizon,
        policy_depth: socket.assigns.policy_depth,
        preference_strength: socket.assigns.preference_strength
      )

    session_id = "session-" <> (:crypto.strong_rand_bytes(6) |> Base.url_encode64(padding: false))
    agent_id = "agent-" <> session_id

    {:ok, pid} =
      Episode.start_link(
        session_id: session_id,
        maze: world,
        blanket: blanket,
        bundle: bundle,
        agent_id: agent_id,
        max_steps: max_steps(world),
        goal_idx: goal_idx
      )

    if connected?(socket), do: AgentPlane.Telemetry.subscribe(agent_id)

    {:noreply,
     assign(socket,
       episode_pid: pid,
       session_id: session_id,
       history: [],
       summary: Episode.inspect_state(pid),
       running?: true,
       auto_running?: false
     )}
  end

  def handle_event("step", _params, %{assigns: %{episode_pid: pid}} = socket)
      when not is_nil(pid) do
    {socket, _} = do_step(socket)
    {:noreply, socket}
  end

  def handle_event("run_all", _params, %{assigns: %{episode_pid: pid}} = socket)
      when not is_nil(pid) do
    send(self(), :tick)
    {:noreply, assign(socket, auto_running?: true)}
  end

  def handle_event("pause", _params, socket) do
    {:noreply, assign(socket, auto_running?: false)}
  end

  def handle_event("reset", _params, %{assigns: %{episode_pid: pid}} = socket)
      when not is_nil(pid) do
    Episode.reset(pid)

    {:noreply,
     assign(socket,
       history: [],
       summary: Episode.inspect_state(pid),
       running?: true,
       auto_running?: false
     )}
  end

  def handle_event("stop", _params, %{assigns: %{episode_pid: pid}} = socket)
      when not is_nil(pid) do
    Episode.stop(pid)
    {:noreply, assign(socket, episode_pid: nil, running?: false, auto_running?: false)}
  end

  def handle_event(_, _, socket), do: {:noreply, socket}

  @impl true
  def handle_info(:tick, %{assigns: %{auto_running?: false}} = socket), do: {:noreply, socket}
  def handle_info(:tick, %{assigns: %{episode_pid: nil}} = socket), do: {:noreply, socket}

  def handle_info(:tick, socket) do
    {socket, done?} = do_step(socket)

    if not done? and socket.assigns.auto_running? do
      Process.send_after(self(), :tick, 150)
    end

    {:noreply, socket}
  end

  def handle_info({:agent_telemetry, _, _}, socket) do
    # Telemetry already captured in history; this is a heartbeat.
    {:noreply, socket}
  end

  defp do_step(%{assigns: %{episode_pid: pid}} = socket) do
    case Episode.step(pid) do
      {:ok, entry} ->
        summary = Episode.inspect_state(pid)

        {assign(socket,
           history: socket.assigns.history ++ [entry],
           summary: summary
         ), false}

      {:done, summary} ->
        {assign(socket, summary: summary, auto_running?: false, running?: false), true}

      {:error, _} ->
        {assign(socket, auto_running?: false), true}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Run maze</h1>
    <p style="color:#9cb0d6;">Pick a maze, configure the Markov blanket, create a native JIDO agent, and run an episode.</p>

    <div class="grid-2">
      <div>
        <div class="card">
          <h2>1. Choose world</h2>
          <form phx-change="select_world">
            <select name="world">
              <%= for w <- @worlds do %>
                <option value={w.id} selected={@selected_world_id == w.id}><%= w.name %></option>
              <% end %>
            </select>
          </form>
          <p style="color:#9cb0d6; font-size: 13px; margin-top: 8px;"><%= @selected_world.description %></p>
          <.maze_view maze={@selected_world} pos={@selected_world.start} />
        </div>

        <div class="card">
          <h2>2. Configure blanket</h2>
          <h3>Observation channels</h3>
          <%= for ch <- default_observation_channels() do %>
            <label class="checkbox-row">
              <input type="checkbox" phx-click="toggle_channel" phx-value-channel={ch}
                     checked={ch in @selected_observation_channels} />
              <%= ch %>
            </label>
          <% end %>
          <h3>Action vocabulary</h3>
          <%= for a <- [:move_north, :move_south, :move_east, :move_west] do %>
            <label class="checkbox-row">
              <input type="checkbox" phx-click="toggle_action" phx-value-action={a}
                     checked={a in @selected_action_vocabulary} />
              <%= a %>
            </label>
          <% end %>
        </div>

        <div class="card">
          <h2>3. Model parameters</h2>
          <form phx-change="update_params">
            <label>Planning horizon (T)</label>
            <input type="number" name="horizon" value={@horizon} min="1" max="10" />
            <label style="margin-top: 8px;">Policy depth</label>
            <input type="number" name="policy_depth" value={@policy_depth} min="1" max="7" />
            <label style="margin-top: 8px;">Preference strength (log odds on goal)</label>
            <input type="text" name="preference_strength" value={@preference_strength} />
          </form>
          <p style="color:#9cb0d6; font-size:12px; margin-top:6px;">
            Policies = <%= Integer.to_string(:math.pow(length(@selected_action_vocabulary), @policy_depth) |> trunc()) %>
          </p>
        </div>

        <div class="card">
          <h2>4. Control</h2>
          <button class="btn primary" phx-click="create_episode">Create agent + world</button>
          <button class="btn" phx-click="step" disabled={is_nil(@episode_pid)}>Step</button>
          <button class="btn" phx-click="run_all" disabled={is_nil(@episode_pid) or @auto_running?}>Run</button>
          <button class="btn" phx-click="pause" disabled={not @auto_running?}>Pause</button>
          <button class="btn" phx-click="reset" disabled={is_nil(@episode_pid)}>Reset</button>
          <button class="btn" phx-click="stop" disabled={is_nil(@episode_pid)}>Stop</button>
        </div>
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
            <p style="color:#9cb0d6; font-size:12px;">
              From eq. 4.13 / B.5. One entry per state = one tile. Darker = higher probability.
            </p>
            <.belief_heatmap maze={@summary.world.maze}
                              beliefs={@summary.agent.marginal_state_belief} />
          </div>

          <div class="card">
            <h2>Policy posterior — by direction</h2>
            <p style="color:#9cb0d6; font-size:12px;">
              π aggregated by first action (↑/↓/→/←). The winning direction is highlighted.
            </p>
            <PolicyVisual.policy_bars summary={@summary} />
          </div>

          <div class="card">
            <h2>Predicted trajectory</h2>
            <PolicyVisual.trajectory_overlay maze={@summary.world.maze} summary={@summary} />
          </div>

          <div class="card">
            <h2>Policy posterior — top 5 policies</h2>
            <p style="color:#9cb0d6; font-size:12px;">
              π = σ(ln E − F − G)  (eq. 4.14 / B.9)  —  raw top-5 (debug).
            </p>
            <.policy_top summary={@summary} />
          </div>

          <div class="card">
            <h2>Telemetry</h2>
            <p>
              Last action:
              <code class="inline"><%= inspect(@summary.agent.last_action) %></code>
            </p>
            <p>
              Min F = <%= min_fmt(@summary.agent.last_f) %>
              &nbsp; Min G = <%= min_fmt(@summary.agent.last_g) %>
            </p>
          </div>
        <% end %>

        <div class="card">
          <h2>Step history</h2>
          <%= if @history == [] do %>
            <p style="color:#9cb0d6;">No steps yet.</p>
          <% else %>
            <table>
              <thead><tr><th>t</th><th>action</th><th>terminal</th></tr></thead>
              <tbody>
                <%= for {entry, idx} <- Enum.with_index(@history) do %>
                  <tr>
                    <td class="mono"><%= idx %></td>
                    <td class="mono"><%= inspect(entry.action) %></td>
                    <td><%= if entry.terminal?, do: "yes", else: "" %></td>
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

  attr :summary, :any, required: true

  defp policy_top(assigns) do
    zipped =
      assigns.summary.agent.policy_posterior
      |> Enum.with_index()
      |> Enum.sort_by(fn {p, _} -> -p end)
      |> Enum.take(5)

    assigns = assign(assigns, :top, zipped)

    ~H"""
    <table>
      <thead><tr><th>policy #</th><th>π</th><th>F</th><th>G</th></tr></thead>
      <tbody>
        <%= for {p, i} <- @top do %>
          <tr>
            <td class="mono">#<%= i %></td>
            <td class="mono"><%= fmt(p) %>&nbsp;<span class="bar" style={"width:#{trunc(120 * p)}px"}></span></td>
            <td class="mono"><%= fmt(Enum.at(@summary.agent.last_f, i, 0.0)) %></td>
            <td class="mono"><%= fmt(Enum.at(@summary.agent.last_g, i, 0.0)) %></td>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end

  defp max_steps(maze), do: maze.width * maze.height * 4

  defp default_observation_channels do
    [:wall_north, :wall_south, :wall_east, :wall_west, :goal_cue, :tile]
  end

  defp fmt(x) when is_float(x), do: :erlang.float_to_binary(x, decimals: 3)
  defp fmt(x), do: to_string(x)
  defp min_fmt([]), do: "—"
  defp min_fmt(l), do: l |> Enum.min() |> fmt()
  defp guard_float(x) when is_float(x), do: x
  defp guard_float(x) when is_integer(x), do: x * 1.0
end

defmodule WorkbenchWeb.WorldLive.Index do
  @moduledoc """
  Plan §12 Phase 6 — World UI.

  The operations plane for running supervised Active Inference agents in
  a world. Composition lives in `/builder` (Phase 7); this page lets a
  user pick a world, configure the blanket + params, boot a real
  `Jido.AgentServer`, and watch state + events flow through in real time.

  Key differences vs. the legacy /run page:
  - drives the agent in `:supervised` mode (so JIDO telemetry flows),
  - auto-registers a `WorldModels.Spec` per run so Glass Engine can
    back-trace every emitted event,
  - subscribes to `WorldModels.Bus` for agent-specific events,
  - exposes an "Open in Glass Engine" link scoped to the live agent.
  """
  use WorkbenchWeb, :live_view

  alias AgentPlane.BundleBuilder
  alias SharedContracts.Blanket
  alias WorkbenchWeb.Components.PolicyVisual
  alias WorkbenchWeb.Episode
  alias WorldModels.{AgentRegistry, Bus, Spec}
  alias WorldPlane.Worlds

  @impl true
  def mount(_params, _session, socket) do
    worlds = Worlds.all()
    first_world = hd(worlds)
    blanket = Blanket.maze_default()

    socket =
      socket
      |> assign(
        page_title: "World",
        worlds: worlds,
        selected_world_id: first_world.id,
        selected_world: first_world,
        blanket: blanket,
        selected_observation_channels: blanket.observation_channels,
        selected_action_vocabulary: blanket.action_vocabulary,
        # horizon × policy_depth drives policy count = |A| ^ policy_depth,
        # which in turn drives per-step span volume (~2 × policies). The
        # /world defaults keep the live-click → render loop snappy; the
        # user can bump these for deeper planning.
        horizon: 3,
        policy_depth: 3,
        preference_strength: 4.0,
        wall_hit_penalty: 4.0,
        episode_target: 1,
        episodes_completed: 0,
        episodes_solved: 0,
        episode_history: [],
        episode_pid: nil,
        session_id: nil,
        agent_id: nil,
        spec_id: nil,
        spec_hash: nil,
        running?: false,
        history: [],
        summary: nil,
        auto_running?: false,
        recent_events: [],
        qwen_page_type: :world,
        qwen_page_key: to_string(first_world.id),
        qwen_page_title: "World playground"
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
      if ch_atom in current,
        do: List.delete(current, ch_atom),
        else: current ++ [ch_atom]

    blanket = Blanket.with_observation_channels(socket.assigns.blanket, new)
    {:noreply, assign(socket, blanket: blanket, selected_observation_channels: new)}
  end

  def handle_event("toggle_action", %{"action" => act}, socket) do
    act_atom = String.to_existing_atom(act)
    current = socket.assigns.selected_action_vocabulary

    new =
      if act_atom in current,
        do: List.delete(current, act_atom),
        else: current ++ [act_atom]

    blanket = Blanket.with_action_vocabulary(socket.assigns.blanket, new)
    {:noreply, assign(socket, blanket: blanket, selected_action_vocabulary: new)}
  end

  def handle_event("update_params", params, socket) do
    target =
      params
      |> Map.get("episode_target", "1")
      |> to_int(1)
      |> max(1)
      |> min(1000)

    {:noreply,
     assign(socket,
       horizon: params |> Map.get("horizon", "3") |> to_int(3),
       policy_depth: params |> Map.get("policy_depth", "3") |> to_int(3),
       preference_strength: params |> Map.get("preference_strength", "4.0") |> to_float(4.0),
       wall_hit_penalty: params |> Map.get("wall_hit_penalty", "4.0") |> to_float(4.0),
       episode_target: target
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

    # Plan §7.1 — auto-register a Spec so Glass Engine can resolve any
    # event back to the composition that produced it. A content hash
    # dedupes reruns with identical parameters.
    spec_id = "spec-world-" <> short_id()

    spec =
      Spec.new(%{
        id: spec_id,
        archetype_id: "pomdp_maze",
        family_id: "Partially Observable Markov Decision Process (POMDP)",
        primary_equation_ids: [
          "eq_4_5_pomdp_likelihood",
          "eq_4_6_pomdp_prior_over_states",
          "eq_4_10_efe_linear_algebra",
          "eq_4_11_vfe_linear_algebra",
          "eq_4_13_state_belief_update",
          "eq_4_14_policy_posterior"
        ],
        bundle_params: %{
          world_id: world.id,
          horizon: socket.assigns.horizon,
          policy_depth: socket.assigns.policy_depth,
          preference_strength: socket.assigns.preference_strength
        },
        blanket: %{
          observation_channels: blanket.observation_channels,
          action_vocabulary: blanket.action_vocabulary
        },
        created_by: "/world"
      })

    {:ok, registered} = AgentRegistry.register_spec(spec)

    # Couple the wall_hit channel toggle to the penalty: unchecking the
    # channel from the blanket config should genuinely disable the
    # penalty (otherwise the agent's predicted `:hit` observations still
    # show up in C's risk term and bias policies even though the world
    # never emits `:hit`).
    effective_wall_hit_penalty =
      if :wall_hit in blanket.observation_channels,
        do: socket.assigns.wall_hit_penalty,
        else: 0.0

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
        preference_strength: socket.assigns.preference_strength,
        wall_hit_penalty: effective_wall_hit_penalty,
        spec_id: registered.id
      )

    session_id = "session-world-" <> short_id()
    agent_id = "agent-world-" <> short_id()

    # :pure gives deterministic latency — supervised mode fans out to
    # AgentServer + per-step JIDO telemetry + 150+ equation spans, which
    # pushes live-click-to-render past 5s on a slow disk. Phase 7's
    # Builder will drive :supervised when needed; for Phase 6 the goal
    # is the full wiring (spec registry + bus + Glass link), which is
    # mode-agnostic.
    mode = Application.get_env(:workbench_web, :world_live_mode, :pure)

    {:ok, pid} =
      Episode.start_link(
        session_id: session_id,
        maze: world,
        blanket: blanket,
        bundle: bundle,
        agent_id: agent_id,
        max_steps: max_steps(world),
        goal_idx: goal_idx,
        mode: mode
      )

    if connected?(socket) do
      Bus.subscribe_agent(agent_id)
    end

    # In :pure mode Runtime.start_agent isn't called, so the live-agent row
    # would be missing from AgentRegistry; attach it manually so Glass can
    # resolve the agent_id back to the Spec.
    if mode == :pure do
      _ = AgentRegistry.attach_live(agent_id, registered.id)
    end

    # Autorun on create when the user asked for more than one episode.
    # Matches the "set it to autorun as many loops as you want when
    # creating the agent" UX — a single Create click kicks off the full
    # batch without a separate Run click.
    autostart? = socket.assigns.episode_target > 1

    if autostart?, do: send(self(), :tick)

    {:noreply,
     assign(socket,
       episode_pid: pid,
       session_id: session_id,
       agent_id: agent_id,
       spec_id: registered.id,
       spec_hash: registered.hash,
       history: [],
       summary: Episode.inspect_state(pid),
       running?: true,
       auto_running?: autostart?,
       recent_events: [],
       episodes_completed: 0,
       episodes_solved: 0,
       episode_history: []
     )}
  end

  def handle_event("step", _params, %{assigns: %{episode_pid: pid}} = socket)
      when not is_nil(pid) do
    {socket, _} = do_step(socket)
    {:noreply, socket}
  end

  def handle_event("run_all", _params, %{assigns: %{episode_pid: pid}} = socket)
      when not is_nil(pid) do
    # Each click on Run starts a **fresh batch** of `@episode_target`
    # episodes while **keeping the agent's bundle / beliefs / Dirichlet
    # counts intact**. If the agent has already completed a batch, we
    # zero the counters so a new batch of the current target size can
    # begin; the prior history list is preserved for comparison.
    # If the world is already at a terminal tile (last batch ended on
    # the goal), `reset_world/1` moves the agent back to the start
    # without touching the agent's state.
    if socket.assigns.summary && socket.assigns.summary.terminal? do
      :ok = Episode.reset_world(pid)
    end

    send(self(), :tick)

    {:noreply,
     assign(socket,
       auto_running?: true,
       running?: true,
       episodes_completed: 0,
       episodes_solved: 0,
       history: [],
       summary: Episode.inspect_state(pid)
     )}
  end

  def handle_event("clear_history", _params, socket) do
    # Reset only the cross-batch episode history so the table shows the
    # next run cleanly. Agent state and current-batch counters are
    # untouched.
    {:noreply, assign(socket, episode_history: [])}
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

  # -- Bus + tick handlers ---------------------------------------------------

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

  def handle_info({:world_event, %WorldModels.Event{} = event}, socket) do
    # Glass Engine gets the authoritative stream from WorldModels.EventLog;
    # here we just carry the last handful of events as a live running
    # indicator. Keeps the page alive even if no UI click is happening.
    recents =
      [event | socket.assigns.recent_events]
      |> Enum.take(20)

    {:noreply, assign(socket, recent_events: recents)}
  end

  # -- Step driver ----------------------------------------------------------

  defp do_step(%{assigns: %{episode_pid: pid}} = socket) do
    case Episode.step(pid) do
      {:ok, entry} ->
        summary = Episode.inspect_state(pid)
        {assign(socket, history: socket.assigns.history ++ [entry], summary: summary), false}

      {:done, summary} ->
        handle_episode_done(socket, summary)

      {:error, _} ->
        {assign(socket, auto_running?: false), true}
    end
  end

  # Multi-episode handler. When the agent finishes an episode we record
  # the outcome, and if the user requested more runs we reset the world
  # to the start (keeping agent bundle + beliefs intact) so the next
  # episode starts with everything learned so far. Stops when the
  # requested count is hit.
  defp handle_episode_done(socket, summary) do
    episodes_completed = socket.assigns.episodes_completed + 1

    episodes_solved =
      socket.assigns.episodes_solved + if summary.goal_reached?, do: 1, else: 0

    run_record = %{
      episode: episodes_completed,
      steps: summary.steps,
      goal_reached?: summary.goal_reached?
    }

    history_tail = [run_record | socket.assigns.episode_history] |> Enum.take(25)

    target = socket.assigns.episode_target
    pid = socket.assigns.episode_pid

    cond do
      episodes_completed >= target or not socket.assigns.auto_running? ->
        {assign(socket,
           summary: summary,
           auto_running?: false,
           running?: false,
           episodes_completed: episodes_completed,
           episodes_solved: episodes_solved,
           episode_history: history_tail
         ), true}

      true ->
        :ok = Episode.reset_world(pid)

        {assign(socket,
           summary: Episode.inspect_state(pid),
           episodes_completed: episodes_completed,
           episodes_solved: episodes_solved,
           episode_history: history_tail,
           history: []
         ), false}
    end
  end

  # -- Render ---------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Run maze</h1>
    <p style="color:#9cb0d6;">
      Pick a maze, configure the Markov blanket, boot a supervised native JIDO agent,
      and watch it solve.
    </p>

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
          <p style="color:#9cb0d6; font-size: 13px; margin-top: 8px;">
            <%= @selected_world.description %>
          </p>
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
            <label style="margin-top: 8px;">
              Wall-hit penalty (log odds against bumping walls)
            </label>
            <input type="text" name="wall_hit_penalty"
                   value={@wall_hit_penalty}
                   disabled={:wall_hit not in @selected_observation_channels} />
            <label style="margin-top: 8px;">
              Run again (episodes — agent keeps everything it has learned)
            </label>
            <input type="number" name="episode_target"
                   value={@episode_target} min="1" max="1000" />
            <p style="color:#7a8cb3; font-size: 11px; margin: 4px 0 0;">
              After each goal, the world resets to the start tile and the agent
              replays with its updated A/B/Dirichlet counts. Set to 1 for a
              single run; up to 1000 to observe learning across episodes.
            </p>
            <p style="color:#7a8cb3; font-size: 11px; margin: 4px 0 0;">
              <%= if :wall_hit in @selected_observation_channels do %>
                Set to 0 to disable the wall-hit preference in C; negative
                values would actually <em>encourage</em> wall bumps (useful
                as a control experiment).
              <% else %>
                <span style="color:#fde68a;">
                  The <code class="inline">wall_hit</code> observation channel is
                  disabled above — the penalty has no effect. Re-enable the
                  channel to use this slider.
                </span>
              <% end %>
            </p>
          </form>
          <p style="color:#9cb0d6; font-size:12px; margin-top:6px;">
            Policies = <%= Integer.to_string(
              :math.pow(length(@selected_action_vocabulary), @policy_depth) |> trunc()
            ) %>
          </p>
        </div>

        <div class="card">
          <h2>4. Control</h2>
          <button class="btn primary" phx-click="create_episode">Create agent + world</button>
          <button class="btn" phx-click="step" disabled={is_nil(@episode_pid)}>Step</button>
          <button class="btn primary" phx-click="run_all"
                  disabled={is_nil(@episode_pid) or @auto_running?}>
            <%= run_button_label(@episodes_completed, @episode_target) %>
          </button>
          <button class="btn" phx-click="pause" disabled={not @auto_running?}>Pause</button>
          <button class="btn" phx-click="reset" disabled={is_nil(@episode_pid)}
                  title="Reset world AND wipe the agent's bundle and beliefs — start over from scratch.">
            Reset (fresh agent)
          </button>
          <button class="btn" phx-click="stop" disabled={is_nil(@episode_pid)}>Stop</button>
          <p style="color:#7a8cb3; font-size: 11px; margin: 8px 0 0;">
            <strong>Run</strong> keeps all of the agent's learning across episodes;
            <strong>Reset (fresh agent)</strong> wipes beliefs and Dirichlet counts.
            Use Run to watch the agent improve; Reset to start a new experiment.
          </p>
        </div>

        <%= if @agent_id do %>
          <div class="card">
            <h2>Agent spec</h2>
            <p>
              Spec: <code class="inline"><%= @spec_id %></code>
              <br />
              Hash: <code class="inline"><%= String.slice(@spec_hash || "", 0, 16) %>…</code>
              <br />
              Agent: <code class="inline"><%= @agent_id %></code>
            </p>
            <a class="btn primary" href={"/glass/agent/#{@agent_id}"}>Open in Glass Engine</a>
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

          <div class="card">
            <h2>Recent bus events</h2>
            <%= if @recent_events == [] do %>
              <p style="color:#9cb0d6;">Waiting for events…</p>
            <% else %>
              <table>
                <thead><tr><th>type</th><th>eq</th><th>t</th></tr></thead>
                <tbody>
                  <%= for e <- @recent_events do %>
                    <tr>
                      <td class="mono"><%= e.type %></td>
                      <td class="mono"><%= e.provenance.equation_id || "—" %></td>
                      <td class="mono"><%= e.ts_usec %></td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            <% end %>
          </div>
        <% end %>

        <%= if @episode_target > 1 or @episodes_completed > 0 or @episode_history != [] do %>
          <div class="card">
            <h2>
              Episodes (keep-learning runs)
              <%= if @episode_history != [] do %>
                <button class="btn"
                        style="float:right;font-size:11px;padding:2px 8px;"
                        phx-click="clear_history">clear history</button>
              <% end %>
            </h2>
            <p>
              <strong><%= @episodes_completed %></strong> / <%= @episode_target %> completed
              &middot; <strong><%= @episodes_solved %></strong> solved
              <%= if length(@episode_history) > @episodes_completed do %>
                &middot; <em>history spans <%= length(@episode_history) %> episodes across batches</em>
              <% end %>
            </p>
            <%= if @episode_history != [] do %>
              <table>
                <thead><tr><th>episode</th><th>steps</th><th>result</th></tr></thead>
                <tbody>
                  <%= for record <- @episode_history do %>
                    <tr>
                      <td class="mono"><%= record.episode %></td>
                      <td class="mono"><%= record.steps %></td>
                      <td>
                        <%= if record.goal_reached? do %>
                          <span class="tag verified">goal</span>
                        <% else %>
                          <span class="tag uncertain">timeout</span>
                        <% end %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
              <p style="color:#7a8cb3; font-size:11px; margin-top: 6px;">
                Agent keeps bundle (A / B / C / D, Dirichlet counts if any)
                and beliefs across episodes. Watch the steps column fall as
                the agent gets better at this maze.
              </p>
            <% end %>
          </div>
        <% end %>

        <div class="card">
          <h2>Step history (current episode)</h2>
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

  # -- View components ------------------------------------------------------

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
    # Scale alpha to the current max of the marginal so on large mazes
    # (11×11 = 121 tiles → uniform ~0.008 per tile) we still see the
    # strongest-belief tiles instead of a uniformly dim grid.
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
    # Normalise against the peak so the brightest tile is always ~1.0;
    # a floor of 0.04 keeps walls/empty tiles legible as a backdrop.
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

  # -- Utilities ------------------------------------------------------------

  defp max_steps(maze), do: maze.width * maze.height * 4

  defp default_observation_channels do
    [:wall_north, :wall_south, :wall_east, :wall_west, :goal_cue, :tile, :wall_hit]
  end

  defp fmt(x) when is_float(x), do: :erlang.float_to_binary(x, decimals: 3)
  defp fmt(x), do: to_string(x)
  defp min_fmt([]), do: "—"
  defp min_fmt(l), do: l |> Enum.min() |> fmt()
  # Numeric coercion helpers used by update_params; replaced the old
  # pattern-matching-only handle_event to allow optional form fields
  # (new `wall_hit_penalty` slider).
  defp to_int(s, d) when is_binary(s) do
    case Integer.parse(s) do
      {n, _} -> n
      :error -> d
    end
  end

  defp to_int(n, _) when is_integer(n), do: n
  defp to_int(_, d), do: d

  defp to_float(s, d) when is_binary(s) do
    case Float.parse(s) do
      {f, _} -> f
      :error -> d
    end
  end

  defp to_float(f, _) when is_float(f), do: f
  defp to_float(i, _) when is_integer(i), do: i * 1.0
  defp to_float(_, d), do: d

  # Run button label. Makes it obvious that every click starts a fresh
  # batch of `target` episodes, keeping the agent's learning.
  defp run_button_label(0, 1), do: "Run"
  defp run_button_label(0, target), do: "Run (#{target} episodes)"
  defp run_button_label(_completed, 1), do: "Run again"
  defp run_button_label(_completed, target), do: "Run again (#{target} more)"

  defp short_id do
    :crypto.strong_rand_bytes(6) |> Base.url_encode64(padding: false)
  end
end

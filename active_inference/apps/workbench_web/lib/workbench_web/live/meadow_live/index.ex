defmodule WorkbenchWeb.MeadowLive.Index do
  @moduledoc """
  Single-page LiveView for the Bird Meadow.

  Lets the user:
    1. Pick a meadow size (4×4 or 8×8).
    2. Click on a tile to place a bird with the currently-selected
       tier (Simple / Complex / Resonant) and preferred token.
    3. Press "Start" — the meadow + episode boot, the page begins
       ticking, and live state (positions, actions, song ripples,
       per-bird telemetry) renders.
    4. Step / Pause / Reset / Stop.

  Intentionally minimal — the audit-anchor and experiment tests are
  the scientific surface; this LiveView is the user-facing
  interaction surface.
  """

  use WorkbenchWeb, :live_view

  alias AgentPlane.BundleBuilder.Meadow
  alias WorkbenchWeb.Episode.MeadowEpisode
  alias WorldPlane.Meadows

  @tick_interval_ms 600

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:meadow_id, :bird_meadow_8x8)
     |> assign(:meadow_pid, nil)
     |> assign(:episode_pid, nil)
     |> assign(:tier, :convergent)
     |> assign(:preferred_token, :t1)
     |> assign(:auto_running?, false)
     |> assign(:placed, [])
     |> assign(:snapshot, nil)
     |> assign(:tick_ms, @tick_interval_ms)
     |> assign(:status, :idle)
     |> assign(:flash_msg, nil)
     # Step is run in a Task so the LiveView stays responsive while heavy
     # tiers (Complex/Resonant ×N birds) compute. `step_task` carries the
     # %Task{} when an inference is in flight; `computing_at_ms` lets the
     # ticker render a live "Computing tick N… (Xs)" indicator.
     |> assign(:step_task, nil)
     |> assign(:computing_at_ms, nil)
     |> assign(:computing_now_ms, nil)}
  end

  @impl true
  def handle_event("select_meadow", %{"id" => id}, socket) do
    {:noreply, assign(socket, :meadow_id, String.to_existing_atom(id))}
  end

  def handle_event("select_tier", %{"tier" => t}, socket) do
    {:noreply, assign(socket, :tier, String.to_existing_atom(t))}
  end

  def handle_event("select_token", %{"token" => t}, socket) do
    {:noreply, assign(socket, :preferred_token, String.to_existing_atom(t))}
  end

  def handle_event("place_bird", %{"col" => c, "row" => r}, socket) do
    pos = {String.to_integer(c), String.to_integer(r)}

    cond do
      socket.assigns.status != :idle ->
        {:noreply,
         assign(socket, :flash_msg, "Stop the running episode before placing more birds.")}

      Enum.any?(socket.assigns.placed, fn b -> b.position == pos end) ->
        {:noreply, assign(socket, :flash_msg, "Tile already occupied. Pick another cell.")}

      true ->
        # Use max-index + 1 instead of length + 1 so removing a middle
        # bird doesn't cause the next placement to reuse its index.
        next_index =
          (socket.assigns.placed |> Enum.map(& &1.index) |> Enum.max(fn -> 0 end)) + 1

        bird = %{
          # Stable, human-readable id — survives across renders so the
          # rendered cell never reshuffles when a sibling is added/removed.
          agent_id: "bird-#{next_index}-#{:erlang.unique_integer([:positive])}",
          # Monotonic placement index — used as the on-cell glyph so two
          # birds with the same preferred_token are still visually distinct.
          index: next_index,
          tier: socket.assigns.tier,
          preferred_token: socket.assigns.preferred_token,
          position: pos
        }

        {:noreply,
         socket
         |> update(:placed, &(&1 ++ [bird]))
         |> assign(:flash_msg, nil)}
    end
  end

  def handle_event("remove_bird", %{"id" => id}, socket) do
    {:noreply, update(socket, :placed, fn list -> Enum.reject(list, &(&1.agent_id == id)) end)}
  end

  def handle_event("start", _, %{assigns: %{placed: []}} = socket) do
    {:noreply, assign(socket, :flash_msg, "Place at least one bird before starting.")}
  end

  def handle_event("start", _, socket) do
    spec = Meadows.fetch(socket.assigns.meadow_id)

    {:ok, meadow_pid} =
      Meadows.start(socket.assigns.meadow_id, run_id: "ui-#{:erlang.unique_integer([:positive])}")

    birds =
      Enum.map(socket.assigns.placed, fn b ->
        bundle = build_bundle(b, spec)
        %{agent_id: b.agent_id, position: b.position, bundle: bundle}
      end)

    {:ok, ep_pid} =
      MeadowEpisode.start_link(
        meadow_pid: meadow_pid,
        birds: birds,
        max_steps: 1_000_000
      )

    Process.send_after(self(), :tick, socket.assigns.tick_ms)

    {:noreply,
     socket
     |> assign(:meadow_pid, meadow_pid)
     |> assign(:episode_pid, ep_pid)
     |> assign(:auto_running?, true)
     |> assign(:status, :running)
     |> assign(:snapshot, MeadowEpisode.snapshot(ep_pid))}
  end

  def handle_event("step", _, socket) do
    {:noreply, kick_step(socket)}
  end

  def handle_event("pause", _, socket) do
    {:noreply, socket |> assign(:auto_running?, false) |> assign(:status, :paused)}
  end

  def handle_event("resume", _, socket) do
    if socket.assigns.episode_pid do
      Process.send_after(self(), :tick, socket.assigns.tick_ms)
      {:noreply, socket |> assign(:auto_running?, true) |> assign(:status, :running)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("reset", _, socket) do
    if socket.assigns.episode_pid do
      MeadowEpisode.reset(socket.assigns.episode_pid)
    end

    {:noreply, refresh(socket)}
  end

  def handle_event("stop", _, socket) do
    cancel_step_task(socket.assigns.step_task)
    safe_stop(socket.assigns.episode_pid)
    safe_stop(socket.assigns.meadow_pid)

    {:noreply,
     socket
     |> assign(:meadow_pid, nil)
     |> assign(:episode_pid, nil)
     |> assign(:auto_running?, false)
     |> assign(:status, :idle)
     |> assign(:snapshot, nil)
     |> assign(:placed, [])
     |> assign(:step_task, nil)
     |> assign(:computing_at_ms, nil)
     |> assign(:computing_now_ms, nil)}
  end

  @impl true
  def handle_info(:tick, %{assigns: %{auto_running?: true, episode_pid: ep}} = socket)
      when is_pid(ep) do
    {:noreply, kick_step(socket)}
  end

  def handle_info(:tick, socket), do: {:noreply, socket}

  # 100ms heartbeat refreshes the "Computing tick N… (Xs)" elapsed counter
  # while a step Task is in flight. Skipped when no step is computing.
  def handle_info(:compute_tick, %{assigns: %{step_task: %Task{}}} = socket) do
    Process.send_after(self(), :compute_tick, 100)
    {:noreply, assign(socket, :computing_now_ms, System.monotonic_time(:millisecond))}
  end

  def handle_info(:compute_tick, socket), do: {:noreply, socket}

  # Step Task completed normally — ignore the actual reply payload (we read
  # state via snapshot), demonitor, refresh, schedule the next auto tick.
  def handle_info({ref, _result}, %{assigns: %{step_task: %Task{ref: ref}}} = socket) do
    Process.demonitor(ref, [:flush])
    schedule_next_tick(socket)

    {:noreply,
     socket
     |> refresh()
     |> assign(:step_task, nil)
     |> assign(:computing_at_ms, nil)
     |> assign(:computing_now_ms, nil)}
  end

  # Step Task crashed (raise/exit/throw inside MeadowEpisode.step). Surface
  # it to the user instead of silently swallowing — they need to know the
  # episode is in an inconsistent state and click Stop to recover.
  def handle_info(
        {:DOWN, ref, :process, _, reason},
        %{assigns: %{step_task: %Task{ref: ref}}} = socket
      ) do
    msg =
      "Step inference crashed: #{inspect(reason)}. The episode may be in an inconsistent state — click Stop to reset."

    {:noreply,
     socket
     |> assign(:step_task, nil)
     |> assign(:auto_running?, false)
     |> assign(:status, :paused)
     |> assign(:computing_at_ms, nil)
     |> assign(:computing_now_ms, nil)
     |> assign(:flash_msg, msg)}
  end

  # Trailing late `{ref, _}` from a Task we already demonitored — ignore.
  def handle_info({ref, _}, socket) when is_reference(ref), do: {:noreply, socket}

  def handle_info({:DOWN, ref, :process, _, _}, socket) when is_reference(ref),
    do: {:noreply, socket}

  # Spawn a step Task if the episode is up and no step is already in flight.
  # Returns the updated socket. Idempotent — auto-ticks may fire while a
  # step is computing; we just skip them.
  defp kick_step(%{assigns: %{episode_pid: nil}} = socket), do: socket
  defp kick_step(%{assigns: %{step_task: %Task{}}} = socket), do: socket

  defp kick_step(%{assigns: %{episode_pid: ep}} = socket) when is_pid(ep) do
    if Process.alive?(ep) do
      task =
        Task.async(fn ->
          # 5-minute timeout — heavy multi-bird Resonant inference legitimately
          # takes tens of seconds. The LiveView itself stays responsive because
          # the call happens in a separate process.
          MeadowEpisode.step(ep, 300_000)
        end)

      now = System.monotonic_time(:millisecond)
      Process.send_after(self(), :compute_tick, 100)

      socket
      |> refresh()
      |> assign(:step_task, task)
      |> assign(:computing_at_ms, now)
      |> assign(:computing_now_ms, now)
    else
      socket
    end
  end

  defp schedule_next_tick(%{assigns: %{auto_running?: true, tick_ms: ms}}),
    do: Process.send_after(self(), :tick, ms)

  defp schedule_next_tick(_), do: :ok

  defp cancel_step_task(nil), do: :ok

  defp cancel_step_task(%Task{} = task) do
    # Task.shutdown also demonitors and flushes the inbox.
    _ = Task.shutdown(task, :brutal_kill)
    :ok
  end

  defp safe_stop(nil), do: :ok

  defp safe_stop(pid) when is_pid(pid) do
    if Process.alive?(pid) do
      try do
        GenServer.stop(pid, :normal, 1_000)
      catch
        :exit, _ -> :ok
        _, _ -> :ok
      end
    end

    :ok
  end

  # The episode GenServer serialises :step (heavy inference) and :snapshot.
  # With 2+ heavy-tier birds a step can outlive both the LiveView's 60s step
  # timeout AND the snapshot's default 5s — `take_one_step` catches the step
  # exit, then refresh races against the still-running step. A timeout here
  # (or a transient :noproc on shutdown) must not crash the LiveView; we
  # just keep the previous snapshot for this tick.
  defp refresh(socket) do
    case socket.assigns.episode_pid do
      pid when is_pid(pid) ->
        try do
          snap = MeadowEpisode.snapshot(pid, 5_000)
          assign(socket, :snapshot, snap)
        catch
          :exit, _ -> socket
          _, _ -> socket
        end

      _ ->
        socket
    end
  end

  defp build_bundle(bird, spec) do
    opts = [
      width: spec.width,
      height: spec.height,
      preferred_token: bird.preferred_token,
      walls: spec.walls
    ]

    case bird.tier do
      :convergent -> Meadow.convergent(opts)
      :simple -> Meadow.simple(opts)
      # Complex/Resonant default to depth=2 which can exceed the Jido per-action
      # 60s timeout under the LiveView's tick cadence. Force depth=1 in the UI
      # so the page remains responsive; users wanting deeper planning can call
      # the bundle constructors directly from IEx.
      :complex -> Meadow.complex(opts ++ [policy_depth: 1])
      :resonant -> Meadow.resonant(opts ++ [policy_depth: 1])
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="meadow-page">
      <header class="meadow-header">
        <h1>Bird Meadow</h1>
        <p class="meadow-tagline">
          Multi-agent active inference world — birds hear and sing using
          the audit-verified VFE/EFE math.
        </p>
      </header>

      <%= if @flash_msg do %>
        <div class="meadow-flash"><%= @flash_msg %></div>
      <% end %>

      <section class="meadow-controls">
        <fieldset>
          <legend>Meadow</legend>
          <%= for spec <- Meadows.all() do %>
            <label>
              <input
                type="radio"
                name="meadow"
                value={spec.id}
                checked={@meadow_id == spec.id}
                phx-click="select_meadow"
                phx-value-id={spec.id}
                disabled={@status != :idle}
              />
              <%= spec.name %>
            </label>
          <% end %>
        </fieldset>

        <fieldset>
          <legend>Bird tier</legend>
          <%= for {atom, label} <- [{:convergent, "Convergent (recommended — drives spatial convergence)"}, {:simple, "Simple"}, {:complex, "Complex"}, {:resonant, "Resonant"}] do %>
            <label>
              <input type="radio" name="tier" value={atom}
                checked={@tier == atom}
                phx-click="select_tier" phx-value-tier={atom}
                disabled={@status != :idle}
              />
              <%= label %>
            </label>
          <% end %>
          <p class="meadow-tier-note">
            Only <strong>Convergent</strong> birds move toward each other —
            their hidden state factor includes <em>partner_bearing</em>, so
            EFE has a spatial gradient. Simple/Complex/Resonant birds
            <strong>do not move spatially</strong> by design (their hearing
            factors are uniform conditional on position) — they exhibit
            singing / listening / duet behaviour. This is the
            audit-verified falsifiable claim the meadow tests.
          </p>
        </fieldset>

        <fieldset>
          <legend>Preferred song token</legend>
          <%= for tok <- [:t1, :t2, :t3, :t4] do %>
            <label>
              <input type="radio" name="token" value={tok}
                checked={@preferred_token == tok}
                phx-click="select_token" phx-value-token={tok}
                disabled={@status != :idle}
              />
              <%= tok %>
            </label>
          <% end %>
        </fieldset>
      </section>

      <section class="meadow-grid-section">
        <h2><%= spec_for(@meadow_id).name %></h2>
        <p class="meadow-hint">
          <%= cond do %>
            <% @status == :idle and @placed == [] -> %>
              Click a cell to place your first bird. For the convergence test,
              place two birds at <strong>opposite corners</strong> with the
              <strong>same preferred token</strong>.
            <% @status == :idle -> %>
              <%= length(@placed) %> bird(s) placed. Click another cell to add more,
              or press <strong>Start episode</strong>.
            <% @computing_at_ms -> %>
              Episode running &mdash; t=<%= @snapshot && @snapshot.steps || 0 %>.
              <span class="computing-pill">
                ⟳ Computing tick <%= (@snapshot && @snapshot.steps || 0) + 1 %>…
                <%= compute_elapsed_str(@computing_at_ms, @computing_now_ms) %>
              </span>
            <% true -> %>
              Episode running &mdash; t=<%= @snapshot && @snapshot.steps || 0 %>.
          <% end %>
        </p>
        <div class="meadow-grid" style={grid_style(spec_for(@meadow_id))}>
          <%= for r <- 0..(spec_for(@meadow_id).height - 1), c <- 0..(spec_for(@meadow_id).width - 1) do %>
            <% bird = bird_at(@placed, @snapshot, c, r) %>
            <% song = song_at(@snapshot, c, r) %>
            <div class={cell_class(bird, song)}
              style={cell_style(bird)}
              phx-click="place_bird" phx-value-col={c} phx-value-row={r}
              title={cell_tooltip(bird, song, c, r)}
            >
              <%= if bird do %>
                <span class="bird-index"><%= bird.index %></span>
                <span class="bird-token"><%= token_glyph(bird.preferred_token) %></span>
              <% end %>
              <%= if song && !bird, do: "♪" %>
            </div>
          <% end %>
        </div>

        <div class="meadow-legend">
          <span>Legend:</span>
          <%= for tok <- [:t1, :t2, :t3, :t4] do %>
            <span class="legend-chip" style={"background:#{token_color(tok)}"}>
              <%= token_glyph(tok) %> <%= tok %>
            </span>
          <% end %>
        </div>
      </section>

      <section class="meadow-actions">
        <%= if @status == :idle do %>
          <button class="btn btn-primary" phx-click="start" disabled={@placed == []}>
            ▶ Start episode
          </button>
        <% else %>
          <button class="btn" phx-click="step">⏭ Step</button>
          <%= if @auto_running? do %>
            <button class="btn" phx-click="pause">⏸ Pause</button>
          <% else %>
            <button class="btn btn-primary" phx-click="resume">▶ Resume</button>
          <% end %>
          <button class="btn" phx-click="reset">↺ Reset</button>
          <button class="btn btn-danger" phx-click="stop">■ Stop</button>
        <% end %>
      </section>

      <section class="meadow-birds-list">
        <h3>Placed birds (<%= length(@placed) %>)</h3>
        <%= if @placed == [] do %>
          <p class="muted">No birds placed yet.</p>
        <% else %>
          <ul class="placed-list">
            <%= for b <- @placed do %>
              <li>
                <span class="legend-chip" style={"background:#{token_color(b.preferred_token)}"}>
                  <%= b.index %><%= token_glyph(b.preferred_token) %>
                </span>
                <strong>Bird <%= b.index %></strong>
                — <%= b.tier %>, prefers <%= b.preferred_token %>,
                placed at column <%= elem(b.position, 0) %>, row <%= elem(b.position, 1) %>
                <%= if @status == :idle do %>
                  <button class="btn btn-ghost" phx-click="remove_bird" phx-value-id={b.agent_id}>remove</button>
                <% end %>
              </li>
            <% end %>
          </ul>
        <% end %>
      </section>

      <%= if @snapshot do %>
        <section class="meadow-telemetry">
          <h3>Live telemetry (t=<%= @snapshot.steps %>)</h3>
          <table>
            <thead>
              <tr>
                <th>Bird</th><th>Tier</th><th>Token</th><th>Position</th>
                <th>Last action</th><th>Context</th><th>π entropy</th>
              </tr>
            </thead>
            <tbody>
              <%= for {id, b} <- @snapshot.birds do %>
                <tr>
                  <td><%= id %></td>
                  <td><%= b.tier %></td>
                  <td><%= b.preferred_token %></td>
                  <td><%= inspect(Map.get(@snapshot.meadow.positions, id)) %></td>
                  <td><%= b.last_action %></td>
                  <td><%= b.current_context || "—" %></td>
                  <td><%= entropy_str(b.policy_posterior) %></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </section>
      <% end %>
    </div>

    <style>
    /* Dark-theme-aware meadow UI. Designed to be readable against the
       workbench's dark page background. */
    .meadow-page {
      padding: 1.5rem 2rem; font-family: ui-sans-serif, system-ui, sans-serif;
      color: #e8e8e8; max-width: 1200px;
    }
    .meadow-page h1 { font-size: 1.7rem; margin: 0 0 0.25rem; color: #ffffff; }
    .meadow-page h2 { font-size: 1.15rem; margin: 1rem 0 0.5rem; color: #ffffff; }
    .meadow-page h3 { font-size: 1rem; margin: 1rem 0 0.4rem; color: #ffffff; }
    .meadow-tagline { color: #a8b3c0; margin: 0 0 1.25rem; }
    .meadow-hint { color: #b8c4d0; font-size: 0.92rem; margin: 0.4rem 0 0.75rem; }
    .meadow-hint strong { color: #ffd070; }
    .computing-pill {
      display: inline-block; margin-left: 0.6rem;
      padding: 0.1rem 0.55rem; border-radius: 999px;
      background: #4d3c1a; color: #ffd070;
      border: 1px solid #b88a30; font-weight: 600;
      font-size: 0.85rem;
      animation: pulse-glow 1.4s ease-in-out infinite;
    }
    @keyframes pulse-glow {
      0%, 100% { box-shadow: 0 0 0 0 rgba(255, 208, 112, 0.0); }
      50%      { box-shadow: 0 0 8px 2px rgba(255, 208, 112, 0.45); }
    }
    .muted { color: #88909a; font-style: italic; }

    .meadow-flash {
      background: #4d3c1a; color: #ffd070; padding: 0.6rem 1rem;
      border: 1px solid #b88a30; border-radius: 6px; margin-bottom: 1rem;
      font-weight: 500;
    }

    .meadow-controls { display: flex; gap: 1rem; margin-bottom: 1.25rem; flex-wrap: wrap; }
    .meadow-controls fieldset {
      border: 1px solid #3a4554; background: #1c2330;
      padding: 0.6rem 0.85rem; border-radius: 6px; min-width: 200px;
    }
    .meadow-controls legend { font-weight: 600; padding: 0 0.4rem; color: #ffd070; }
    .meadow-controls label {
      display: block; padding: 0.15rem 0; cursor: pointer; color: #e8e8e8;
    }
    .meadow-controls input[type=radio] { margin-right: 0.4rem; }
    .meadow-tier-note {
      margin: 0.5rem 0 0; padding: 0.55rem 0.7rem;
      background: #1a2330; border-left: 3px solid #ffd070;
      color: #c8d0dc; font-size: 0.84rem; line-height: 1.4;
    }
    .meadow-tier-note strong { color: #ffd070; }
    .meadow-tier-note em { color: #b8cdf0; font-style: italic; }

    .meadow-grid {
      display: grid; gap: 3px; background: #2d3645;
      border: 2px solid #4a5568; padding: 3px; width: max-content;
      border-radius: 4px;
    }
    .meadow-cell {
      width: 56px; height: 56px; background: #f4f1ea;
      display: flex; align-items: center; justify-content: center;
      cursor: pointer; font-size: 0.9rem; position: relative;
      transition: background 0.15s, transform 0.1s;
      border-radius: 2px;
    }
    .meadow-cell:hover { background: #fff8d6; transform: scale(1.04); }
    .meadow-cell.occupied { color: #1a1a1a; font-weight: 700; }
    .meadow-cell.singing::after {
      content: "♪"; position: absolute; top: 1px; right: 3px;
      font-size: 1rem; color: #c0388a;
    }
    .meadow-cell .bird-index {
      font-size: 1.5rem; font-weight: 800; line-height: 1;
    }
    .meadow-cell .bird-token {
      position: absolute; bottom: 1px; right: 4px;
      font-size: 0.7rem; font-weight: 600; opacity: 0.85;
    }

    .meadow-legend {
      display: flex; gap: 0.5rem; margin: 0.75rem 0; align-items: center;
      color: #a8b3c0; font-size: 0.9rem;
    }
    .legend-chip {
      display: inline-block; padding: 0.15rem 0.55rem;
      border-radius: 3px; color: #1a1a1a; font-weight: 600;
      font-size: 0.85rem;
    }

    .meadow-actions { margin: 1.25rem 0; display: flex; gap: 0.6rem; }
    .btn {
      padding: 0.55rem 1.1rem; border-radius: 5px;
      border: 1px solid #4a5568; background: #2d3645; color: #e8e8e8;
      cursor: pointer; font-size: 0.95rem; font-weight: 500;
    }
    .btn:hover:not(:disabled) { background: #3a4658; border-color: #5a6878; }
    .btn:disabled { opacity: 0.4; cursor: not-allowed; }
    .btn-primary {
      background: #d97706; border-color: #b8650a; color: #1a1a1a; font-weight: 700;
    }
    .btn-primary:hover:not(:disabled) { background: #f59010; border-color: #d97706; }
    .btn-danger {
      background: #7c2d2d; border-color: #5a2222; color: #ffe0e0;
    }
    .btn-danger:hover:not(:disabled) { background: #9c3a3a; }
    .btn-ghost {
      padding: 0.2rem 0.5rem; font-size: 0.8rem;
      background: transparent; border: 1px solid #4a5568; color: #a8b3c0;
    }

    .placed-list { padding-left: 0; list-style: none; }
    .placed-list li {
      margin: 0.4rem 0; padding: 0.4rem 0.6rem;
      background: #1c2330; border: 1px solid #2d3645; border-radius: 4px;
      display: flex; align-items: center; gap: 0.5rem;
    }

    .meadow-telemetry table {
      border-collapse: collapse; margin-top: 0.5rem; font-size: 0.9rem;
      background: #1c2330; color: #e8e8e8;
    }
    .meadow-telemetry th, .meadow-telemetry td {
      border: 1px solid #2d3645; padding: 0.35rem 0.7rem; text-align: left;
    }
    .meadow-telemetry th { background: #2d3645; color: #ffd070; }
    </style>
    """
  end

  defp spec_for(id), do: Meadows.fetch(id)

  defp grid_style(spec) do
    "grid-template-columns: repeat(#{spec.width}, 56px); grid-template-rows: repeat(#{spec.height}, 56px);"
  end

  defp bird_at(placed, snapshot, c, r) do
    pos = {c, r}

    cond do
      snapshot && snapshot.meadow ->
        Enum.find(placed, fn b ->
          live_pos = Map.get(snapshot.meadow.positions, b.agent_id)
          live_pos == pos
        end)

      true ->
        Enum.find(placed, fn b -> b.position == pos end)
    end
  end

  defp song_at(nil, _, _), do: nil

  defp song_at(snapshot, c, r) do
    Enum.find(snapshot.meadow.song_events, fn ev -> ev.position == {c, r} end)
  end

  defp cell_class(bird, song) do
    base = "meadow-cell"
    base = if bird, do: base <> " occupied", else: base
    if song, do: base <> " singing", else: base
  end

  defp cell_style(nil), do: ""
  defp cell_style(%{preferred_token: token}), do: "background:#{token_color(token)};"

  # Color palette per token — high contrast against a dark glyph.
  defp token_color(:t1), do: "#ffd6c0"
  defp token_color(:t2), do: "#c0e6ff"
  defp token_color(:t3), do: "#d4f0c0"
  defp token_color(:t4), do: "#e8d0ff"
  defp token_color(_), do: "#f4f1ea"

  defp token_glyph(:t1), do: "A"
  defp token_glyph(:t2), do: "B"
  defp token_glyph(:t3), do: "C"
  defp token_glyph(:t4), do: "D"
  defp token_glyph(_), do: "?"

  defp cell_tooltip(nil, nil, c, r), do: "Empty (#{c},#{r}) — click to place"

  defp cell_tooltip(bird, _song, c, r) when not is_nil(bird) do
    "Bird #{bird.index} · #{bird.tier} · prefers #{bird.preferred_token} · at (#{c},#{r})"
  end

  defp cell_tooltip(_, _song, c, r), do: "Song heard at (#{c},#{r})"

  defp compute_elapsed_str(nil, _), do: ""
  defp compute_elapsed_str(_, nil), do: ""

  defp compute_elapsed_str(start_ms, now_ms) when now_ms >= start_ms do
    "(#{Float.round((now_ms - start_ms) / 1000.0, 1)}s)"
  end

  defp compute_elapsed_str(_, _), do: ""

  defp entropy_str([]), do: "—"

  defp entropy_str(p) do
    h =
      Enum.reduce(p, 0.0, fn x, acc ->
        if x > 0.0, do: acc - x * :math.log(x), else: acc
      end)

    Float.round(h, 3)
  end
end

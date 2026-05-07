defmodule WorkbenchWeb.Episode.MeadowEpisode do
  @moduledoc """
  Multi-agent episode runner for the Bird Meadow world.

  Parallel to `WorkbenchWeb.Episode` (which runs single-agent maze
  episodes). The maze episode embeds tightly into the maze Engine; the
  meadow has its own multi-agent step semantics, so a parallel runner
  keeps the Markov-blanket boundary clean and avoids a rewrite of the
  existing Episode module.

  ## Lifecycle per tick

  1. Read every bird's *current* observation from the meadow
     (`BirdMeadow.observe/2`). For tier-0 (newly placed) birds the
     observation is the world's initial encoding.
  2. Run each bird's `Perceive → Plan → Act` cycle in pure-mode
     (`ActiveInferenceAgent.cmd/2`), capturing the action atom
     emitted on the `%Directive.Emit{}` carrying the
     `"active_inference.action"` signal.
  3. Optionally apply the Resonant context-swap: if the bird's bundle
     carries `:resonant_meta`, evaluate the swap rule against its recent
     observation history and replace the bundle's `:c` if the active
     context changed.
  4. Submit the per-agent action map to `BirdMeadow.multi_step/2`,
     advancing the world by one tick and producing the next observation
     map (kept in state for the next tick's read).
  5. Append a per-bird telemetry entry (F, G, π, position, action,
     last_obs) to `:history`.

  ## Run modes

  Only `:pure` mode is implemented for v1 — the agent struct lives
  inside this GenServer's state and is updated via `cmd/2`. A
  `:supervised` mode (one `Jido.AgentServer` per bird) is a future
  extension; the cmd/2 contract makes the migration mechanical.

  The runner is intentionally **non-blocking on time**: there is no
  built-in tick scheduler. Tests and experiments call `step/1` in a
  tight loop; the LiveView calls `step/1` from a `handle_info(:tick,
  ...)` driven by `Process.send_after/3`.
  """

  use GenServer

  alias AgentPlane.{ActiveInferenceAgent, Telemetry}
  alias AgentPlane.Actions.{Act, Perceive, Plan, SwapContext}
  alias Jido.Agent.Directive
  alias SharedContracts.{ActionPacket, Blanket, ObservationPacket}
  alias WorldPlane.Worlds.BirdMeadow

  @typedoc "Per-bird configuration used at boot."
  @type bird_spec :: %{
          required(:agent_id) => String.t(),
          required(:bundle) => map(),
          required(:position) => {non_neg_integer(), non_neg_integer()}
        }

  @typedoc "Per-tick telemetry entry, one per bird."
  @type tick_entry :: %{
          t: non_neg_integer(),
          agent_id: String.t(),
          position: {non_neg_integer(), non_neg_integer()},
          action: atom(),
          policy_posterior: [float()],
          f: [float()],
          g: [float()],
          obs_channels: map(),
          context: atom() | nil
        }

  # -- Public API -------------------------------------------------------------

  @doc """
  Start a meadow episode.

  Required opts:
    * `:meadow_pid` — pid of a running `BirdMeadow` (callers boot this
      themselves, e.g., via `WorldPlane.Meadows.start/2`).
    * `:birds` — `[bird_spec]`. Each bird is added to the meadow at its
      position and tracked in the episode state.
    * `:max_steps` — positive integer cap on the number of `step/1`
      calls before the episode marks itself done.

  Optional:
    * `:session_id` — string for `WorkbenchWeb.Episode.Registry`
      lookup. When omitted a random id is generated.
    * `:blanket` — defaults to `Blanket.meadow_default/0`.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    session_id = Keyword.get(opts, :session_id, random_id())
    name = {:via, Registry, {WorkbenchWeb.Episode.Registry, session_id}}
    GenServer.start_link(__MODULE__, Keyword.put(opts, :session_id, session_id), name: name)
  end

  @doc "Like `start_link/1` but unlinked — survives caller LiveView push_navigate."
  @spec start_detached(keyword()) :: GenServer.on_start()
  def start_detached(opts) do
    session_id = Keyword.get(opts, :session_id, random_id())
    name = {:via, Registry, {WorkbenchWeb.Episode.Registry, session_id}}
    GenServer.start(__MODULE__, Keyword.put(opts, :session_id, session_id), name: name)
  end

  @spec step(pid() | String.t(), timeout()) :: {:ok, [tick_entry()]} | {:done, map()}
  def step(ref, timeout \\ 60_000), do: GenServer.call(ref_to_pid(ref), :step, timeout)

  @spec snapshot(pid() | String.t(), timeout()) :: map()
  def snapshot(ref, timeout \\ 60_000), do: GenServer.call(ref_to_pid(ref), :snapshot, timeout)

  @spec reset(pid() | String.t()) :: :ok
  def reset(ref), do: GenServer.call(ref_to_pid(ref), :reset)

  @spec stop(pid() | String.t()) :: :ok
  def stop(ref), do: GenServer.stop(ref_to_pid(ref))

  # -- GenServer --------------------------------------------------------------

  @impl true
  def init(opts) do
    meadow_pid = Keyword.fetch!(opts, :meadow_pid)
    birds = Keyword.fetch!(opts, :birds)
    max_steps = Keyword.fetch!(opts, :max_steps)
    blanket = Keyword.get(opts, :blanket, Blanket.meadow_default())
    session_id = Keyword.fetch!(opts, :session_id)

    # Place every bird in the meadow. Errors propagate as init errors.
    Enum.each(birds, fn b ->
      case BirdMeadow.add_bird(meadow_pid, b.agent_id, b.position) do
        :ok -> :ok
        {:error, reason} -> raise "MeadowEpisode init: add_bird/3 failed: #{inspect(reason)}"
      end
    end)

    # Materialise an ActiveInferenceAgent struct per bird (pure-mode).
    agents =
      Enum.into(birds, %{}, fn b ->
        agent = ActiveInferenceAgent.fresh(b.agent_id, b.bundle, blanket)
        # Resonant birds carry their initial context in resonant_meta — record it
        # so we can detect swaps later.
        ctx = get_in(b.bundle, [:resonant_meta, :initial_context])

        {b.agent_id,
         %{
           agent: agent,
           bird_spec: b,
           current_context: ctx,
           # Recent obs channels (a small ring buffer for the Resonant swap rule).
           recent_obs: []
         }}
      end)

    {:ok,
     %{
       meadow_pid: meadow_pid,
       blanket: blanket,
       agents: agents,
       max_steps: max_steps,
       steps: 0,
       history: [],
       session_id: session_id
     }}
  end

  @impl true
  def handle_call(:step, _from, %{steps: s, max_steps: m} = state) when s >= m do
    {:reply, {:done, summary(state)}, state}
  end

  def handle_call(:step, _from, state) do
    # 1. Read each bird's current observation from the meadow.
    obs_map =
      Enum.into(state.agents, %{}, fn {agent_id, _} ->
        case BirdMeadow.observe(state.meadow_pid, agent_id) do
          {:ok, obs} ->
            {agent_id, obs}

          {:error, reason} ->
            raise "MeadowEpisode: observe/2 failed for #{agent_id}: #{inspect(reason)}"
        end
      end)

    # 2. For each bird: maybe swap context (Resonant), then Perceive→Plan→Act.
    {new_agents, action_map, tick_entries} =
      Enum.reduce(state.agents, {%{}, %{}, []}, fn {agent_id, abundle},
                                                   {acc_agents, acc_actions, acc_entries} ->
        obs = Map.fetch!(obs_map, agent_id)

        {abundle1, ctx_swapped} = maybe_swap_resonant_context(abundle, obs)

        {agent_after, action} = run_inference_tick(abundle1.agent, obs)

        # Drop the new action onto the world's expected map.
        action_packet =
          ActionPacket.new(%{
            t: state.steps,
            action: action,
            agent_id: agent_id,
            blanket: state.blanket
          })

        entry = %{
          t: state.steps + 1,
          agent_id: agent_id,
          position: nil,
          action: action,
          policy_posterior: agent_after.state.policy_posterior,
          f: agent_after.state.last_f,
          g: agent_after.state.last_g,
          obs_channels: obs.channels,
          context: abundle1.current_context,
          context_swapped?: ctx_swapped
        }

        {
          Map.put(acc_agents, agent_id, %{
            abundle1
            | agent: agent_after,
              recent_obs: take_recent(abundle1.recent_obs, obs.channels, 32)
          }),
          Map.put(acc_actions, agent_id, action_packet),
          [entry | acc_entries]
        }
      end)

    # 3. Apply all actions to the meadow at once.
    {:ok, next_obs_map} = BirdMeadow.multi_step(state.meadow_pid, action_map)

    # 4. Backfill positions into the tick entries from the world's post-step state.
    world_state = BirdMeadow.peek(state.meadow_pid)

    populated_entries =
      Enum.map(tick_entries, fn entry ->
        %{entry | position: Map.get(world_state.positions, entry.agent_id)}
      end)

    # 5. Broadcast per-agent telemetry through the existing AgentPlane.Telemetry
    # PubSub so any LiveView subscribed to a specific bird picks it up.
    Enum.each(populated_entries, fn entry ->
      Telemetry.broadcast(entry.agent_id, %{
        t: entry.t,
        action: entry.action,
        position: entry.position,
        f: entry.f,
        g: entry.g,
        policy_posterior: entry.policy_posterior,
        obs_channels: entry.obs_channels,
        context: entry.context
      })
    end)

    new_state = %{
      state
      | agents: new_agents,
        steps: state.steps + 1,
        history: state.history ++ populated_entries
    }

    _ = next_obs_map
    {:reply, {:ok, populated_entries}, new_state}
  end

  def handle_call(:snapshot, _from, state) do
    {:reply, summary(state), state}
  end

  # `WorkbenchWeb.ActiveRuns` polls every episode registered in
  # `WorkbenchWeb.Episode.Registry` with `:inspect_state` on every layout
  # render (the "Running" nav chip). MeadowEpisode shares that registry
  # with the single-agent `WorkbenchWeb.Episode`, so it must answer the
  # same call or the GenServer dies with FunctionClauseError mid-tick.
  def handle_call(:inspect_state, _from, state) do
    first_agent_id =
      state.agents
      |> Map.keys()
      |> List.first()

    bird_count = map_size(state.agents)

    summary = %{
      session_id: state.session_id,
      steps: state.steps,
      max_steps: state.max_steps,
      terminal?: state.steps >= state.max_steps,
      agent: %{agent_id: first_agent_id || "meadow:#{bird_count}"}
    }

    {:reply, summary, state}
  end

  def handle_call(:reset, _from, state) do
    :ok = BirdMeadow.reset(state.meadow_pid)

    # Re-place birds and reset their agent structs to fresh.
    Enum.each(state.agents, fn {_, ab} ->
      :ok = BirdMeadow.add_bird(state.meadow_pid, ab.bird_spec.agent_id, ab.bird_spec.position)
    end)

    new_agents =
      Enum.into(state.agents, %{}, fn {agent_id, ab} ->
        agent = ActiveInferenceAgent.fresh(agent_id, ab.bird_spec.bundle, state.blanket)
        ctx = get_in(ab.bird_spec.bundle, [:resonant_meta, :initial_context])
        {agent_id, %{ab | agent: agent, current_context: ctx, recent_obs: []}}
      end)

    {:reply, :ok, %{state | agents: new_agents, steps: 0, history: []}}
  end

  # -- Inference helpers ------------------------------------------------------

  # Run Perceive → Plan → Act on a pure-mode agent. Returns {new_agent, action_atom}.
  defp run_inference_tick(agent, %ObservationPacket{} = obs) do
    {a1, _d1} = ActiveInferenceAgent.cmd(agent, {Perceive, %{observation: obs}})
    {a2, _d2} = ActiveInferenceAgent.cmd(a1, Plan)
    {a3, dirs3} = ActiveInferenceAgent.cmd(a2, Act)

    action =
      case Enum.find(dirs3 || [], &match?(%Directive.Emit{}, &1)) do
        %Directive.Emit{signal: %{data: %{action: a}}} -> a
        _ -> a3.state.last_action
      end

    {a3, action}
  end

  # Resonant context swap: evaluate the duet/explore rule on the bird's
  # recent observation channels. Returns {abundle_after_swap, swapped?}.
  #
  # The actual `bundle.c` mutation is routed through the `SwapContext`
  # JIDO action so the change is applied by the strategy inside `cmd/2`
  # — preserving the cmd/2 purity contract from `00-philosophy.md`
  # ("StateOps are applied by the strategy inside cmd/2 and never leave
  # it"). Tracking the active context label is episode bookkeeping and
  # stays here.
  defp maybe_swap_resonant_context(%{agent: agent} = ab, _new_obs) do
    case Map.get(ab.agent.state.bundle, :resonant_meta) do
      nil ->
        {ab, false}

      %{contexts: ctx_map, duet_window: window, silence_threshold: threshold} ->
        recent = Enum.take(ab.recent_obs, window)

        silent_count =
          Enum.count(recent, fn ch -> Map.get(ch, :hearing_amp) == :silence end)

        sang_count =
          Enum.count(recent, fn ch -> Map.get(ch, :self_sang_token, :none) != :none end)

        target_ctx =
          cond do
            silent_count >= threshold -> :duet
            sang_count >= threshold -> :explore
            true -> ab.current_context || :explore
          end

        if target_ctx != ab.current_context do
          new_c = Map.fetch!(ctx_map, target_ctx)
          {new_agent, _dirs} = ActiveInferenceAgent.cmd(agent, {SwapContext, %{c: new_c}})
          {%{ab | agent: new_agent, current_context: target_ctx}, true}
        else
          {ab, false}
        end
    end
  end

  defp take_recent(prev, channels, max_len) do
    Enum.take([channels | prev], max_len)
  end

  # -- Snapshot ---------------------------------------------------------------

  defp summary(state) do
    %{
      session_id: state.session_id,
      steps: state.steps,
      max_steps: state.max_steps,
      done?: state.steps >= state.max_steps,
      meadow: BirdMeadow.peek(state.meadow_pid),
      birds:
        Enum.into(state.agents, %{}, fn {agent_id, ab} ->
          {agent_id,
           %{
             tier: get_in(ab.agent.state.bundle, [:dims, :tier]),
             preferred_token: get_in(ab.agent.state.bundle, [:meadow_meta, :preferred_token]),
             current_context: ab.current_context,
             last_action: ab.agent.state.last_action,
             policy_posterior: ab.agent.state.policy_posterior,
             marginal_state_belief: ab.agent.state.marginal_state_belief,
             last_f: ab.agent.state.last_f,
             last_g: ab.agent.state.last_g,
             t: ab.agent.state.t
           }}
        end),
      history: state.history
    }
  end

  # -- Helpers ----------------------------------------------------------------

  defp ref_to_pid(pid) when is_pid(pid), do: pid

  defp ref_to_pid(session_id) when is_binary(session_id) do
    case Registry.lookup(WorkbenchWeb.Episode.Registry, session_id) do
      [{pid, _}] -> pid
      _ -> raise ArgumentError, "no meadow episode registered for #{inspect(session_id)}"
    end
  end

  defp random_id do
    "meadow-episode-" <> (:crypto.strong_rand_bytes(6) |> Base.url_encode64(padding: false))
  end
end

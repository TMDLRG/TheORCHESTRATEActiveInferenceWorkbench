defmodule WorkbenchWeb.Episode do
  @moduledoc """
  Orchestrates a maze episode by running two plane-independent APIs side by side.

  This module deliberately sits in the `workbench_web` app so that neither
  plane needs to import the other. The only symbols it uses from each plane
  are public:

    * `WorldPlane` — `start_run/1`, `Engine.current_observation/1`,
       `Engine.apply_action/2`, `Engine.stop/1`.
    * `AgentPlane` — JIDO-native `ActiveInferenceAgent.cmd/2` and friends.

  It passes information only via `SharedContracts` packets. In particular, it
  never reads the world's maze grid, nor the agent's belief tensors, to pass
  one into the other. The loop is:

      packet_from_world ──▶ agent.cmd(Step, %{observation: packet}) ──▶ action_packet
      action_packet ──▶ Engine.apply_action ──▶ next packet_from_world

  This makes the Markov-blanket crossing explicit and inspectable.
  """

  use GenServer

  alias AgentPlane.ActiveInferenceAgent
  alias AgentPlane.Actions.{Act, Perceive, Plan, SophisticatedPlan}
  alias AgentPlane.Runtime
  alias SharedContracts.ActionPacket
  alias WorldModels.{Bus, Event, EventLog}
  alias WorldPlane.Engine

  @type t :: %{
          world_pid: pid(),
          world_run_id: String.t(),
          agent: struct(),
          steps: non_neg_integer(),
          max_steps: non_neg_integer(),
          history: [%{obs: any(), action: atom() | nil, terminal?: boolean()}]
        }

  # -- Public API -------------------------------------------------------------

  @doc """
  Start an episode.

  Required opts:
    * `:maze` — a `WorldPlane.Maze.t()`
    * `:blanket` — a `SharedContracts.Blanket.t()`
    * `:bundle` — a POMDP bundle from `AgentPlane.BundleBuilder`
    * `:agent_id` — string
    * `:max_steps` — positive integer
    * `:goal_idx` — index the agent believes to be the goal

  Optional:
    * `:session_id` — string to register under `WorkbenchWeb.Episode.Registry`.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    session_id = Keyword.get(opts, :session_id, random_id())
    name = {:via, Registry, {WorkbenchWeb.Episode.Registry, session_id}}
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Like `start_link/1` but unlinked from the caller.

  LiveView pages that want their episode to survive `push_navigate`
  (the user clicking Guide / Credits / any other nav link) call this
  instead of `start_link/1`.  The episode remains registered under
  `WorkbenchWeb.Episode.Registry` so the user can return to it via the
  "Running sessions" chip or by URL.

  Used by `LabsLive.Run` and `StudioLive.Run`.  Studio's `attach/1`
  also uses unlinked `GenServer.start` for the same reason.
  """
  @spec start_detached(keyword()) :: GenServer.on_start()
  def start_detached(opts) do
    session_id = Keyword.get(opts, :session_id, random_id())
    name = {:via, Registry, {WorkbenchWeb.Episode.Registry, session_id}}
    GenServer.start(__MODULE__, opts, name: name)
  end

  @doc """
  Studio S3 -- attach an episode to an already-running agent.

  Unlike `start_link/1`, this does NOT spawn a new `Jido.AgentServer`.
  It looks up the existing agent via `AgentPlane.Runtime.state/1`, reads
  its bundle + blanket + goal_idx, runs a compatibility preflight against
  the target world, then boots a `WorkbenchWeb.Episode` in `:attached`
  mode that drives the existing agent through the world.

  On successful attach, the agent process is untouched except that
  Episode.step sends it signals via Runtime.  Detaching (`stop_attached/1`)
  leaves the agent `:live` and only stops the Episode + the world.

  Required opts:
    * `:agent_id` -- must be a live agent tracked in `AgentPlane.Instances`.
    * `:world_id` -- atom id known to `WorldPlane.WorldRegistry`.
    * `:max_steps` -- positive integer.

  Optional:
    * `:session_id` -- string.
    * `:planner_mode` -- `:naive | :sophisticated | :none` (default `:naive`).
  """
  @spec attach(keyword()) :: {:ok, pid(), String.t()} | {:error, term()}
  def attach(opts) do
    agent_id = Keyword.fetch!(opts, :agent_id)
    world_id = Keyword.fetch!(opts, :world_id)

    with :ok <- check_compatibility(agent_id, world_id),
         {:ok, srv} <- AgentPlane.Runtime.state(agent_id),
         agent_state = srv.agent.state,
         {:ok, world_pid} <- WorldPlane.WorldRegistry.boot(world_id, blanket: agent_state.blanket) do
      session_id = Keyword.get(opts, :session_id, random_id())

      attach_opts =
        [
          session_id: session_id,
          mode: :attached,
          agent_id: agent_id,
          agent_pid: srv,
          bundle: agent_state.bundle,
          blanket: agent_state.blanket,
          goal_idx: agent_state.goal_idx,
          attached_world_pid: world_pid,
          max_steps: Keyword.fetch!(opts, :max_steps),
          planner_mode: Keyword.get(opts, :planner_mode, :naive),
          extra_actions: Keyword.get(opts, :extra_actions, [])
        ]

      name = {:via, Registry, {WorkbenchWeb.Episode.Registry, session_id}}

      # Studio fix: use unlinked `GenServer.start` so the Episode survives
      # when the caller LV (Studio.New, or the cookbook controller) finishes
      # push_navigating to /studio/run/:session_id.  The Run LV then looks
      # the Episode up by session_id via the shared Registry.
      case GenServer.start(__MODULE__, attach_opts, name: name) do
        {:ok, pid} -> {:ok, pid, session_id}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Studio S3 -- compatibility preflight.  Refuses to attach a mismatched
  {agent, world} pair.  Returns `:ok` or a structured error suitable
  for UI display.

  Checks:

    * Agent exists in `AgentPlane.Instances` (or at least in Runtime).
    * World id is registered in `WorldPlane.WorldRegistry`.
    * Bundle dims match world dims (n_obs, n_states).
  """
  @spec check_compatibility(String.t(), atom()) ::
          :ok
          | {:error, {:unknown_agent, String.t()}}
          | {:error, {:unknown_world, atom()}}
          | {:error, {:dims, map()}}
  def check_compatibility(agent_id, world_id) do
    with {:ok, srv} <- AgentPlane.Runtime.state(agent_id),
         world_dims when is_map(world_dims) <- WorldPlane.WorldRegistry.dims(world_id) do
      agent_dims = srv.agent.state.bundle[:dims] || %{}

      if agent_dims[:n_obs] == world_dims.n_obs and
           agent_dims[:n_states] == world_dims.n_states do
        :ok
      else
        {:error, {:dims, %{agent: agent_dims, world: world_dims}}}
      end
    else
      {:error, :not_found} -> {:error, {:unknown_agent, agent_id}}
      nil -> {:error, {:unknown_world, world_id}}
      other -> {:error, other}
    end
  end

  @doc """
  Studio S3 -- stop an attached episode without killing the agent.

  Stops the Episode + the world but leaves the agent `:live` in its
  current state.  The caller can re-attach later or transition the agent
  to `:stopped` / `:archived` / `:trashed` via `AgentPlane.Runtime`.
  """
  @spec stop_attached(pid() | String.t()) :: :ok
  def stop_attached(ref) do
    pid = ref_to_pid(ref)

    try do
      st = :sys.get_state(pid)

      if Map.get(st, :mode) == :attached do
        if is_pid(st.world_pid), do: WorldPlane.WorldRegistry.stop(st.world_pid)
      end
    catch
      _, _ -> :ok
    end

    GenServer.stop(pid)
  end

  # Per-step compute grows with policy_depth — at depth 5 the pure
  # path does sweep_state_beliefs over 4⁵=1024 policies, which can
  # push a single Episode.step past the default 5s GenServer call
  # timeout on a cold start. Bump to 30s so deep-horizon bundles work.
  @step_timeout_ms 30_000

  @spec step(pid() | String.t()) :: {:ok, map()} | {:done, map()} | {:error, term()}
  def step(ref), do: GenServer.call(ref_to_pid(ref), :step, @step_timeout_ms)

  @spec inspect_state(pid() | String.t()) :: map()
  def inspect_state(ref), do: GenServer.call(ref_to_pid(ref), :inspect_state)

  @spec reset(pid() | String.t()) :: :ok
  def reset(ref), do: GenServer.call(ref_to_pid(ref), :reset)

  @doc """
  Reset the world to its starting state but **keep the agent's
  bundle, beliefs, obs_history, and Dirichlet counts intact**. Used by
  the multi-episode run loop: the agent re-enters the same maze and
  should benefit from everything it has already learned.
  """
  @spec reset_world(pid() | String.t()) :: :ok
  def reset_world(ref), do: GenServer.call(ref_to_pid(ref), :reset_world)

  @spec stop(pid() | String.t()) :: :ok
  def stop(ref) do
    pid = ref_to_pid(ref)
    # Stop the supervised AgentServer (if any) before stopping the Episode
    # so `agent.stopped` events fire cleanly.
    if state_pid = Process.alive?(pid) && pid do
      try do
        st = :sys.get_state(state_pid)

        if st.mode == :supervised and is_binary(st.agent_id) do
          _ = Runtime.stop_agent(st.agent_id)
        end
      catch
        _, _ -> :ok
      end
    end

    GenServer.stop(pid)
  end

  # -- GenServer --------------------------------------------------------------

  @impl true
  def init(opts) do
    mode = Keyword.get(opts, :mode, :pure)
    blanket = Keyword.fetch!(opts, :blanket)
    bundle = Keyword.fetch!(opts, :bundle)
    agent_id = Keyword.fetch!(opts, :agent_id)
    max_steps = Keyword.fetch!(opts, :max_steps)
    goal_idx = Keyword.fetch!(opts, :goal_idx)
    planner_mode = Keyword.get(opts, :planner_mode, :naive)
    extra_actions = Keyword.get(opts, :extra_actions, [])

    # S3 -- in :attached mode, the caller has already booted the world and
    # the agent is already alive.  Otherwise start a fresh world from the
    # supplied :maze.
    {world_pid, world_run_id} =
      case mode do
        :attached ->
          pid = Keyword.fetch!(opts, :attached_world_pid)
          {pid, Engine.peek(pid).run_id}

        _ ->
          maze = Keyword.fetch!(opts, :maze)
          {:ok, pid} = Engine.start_link(maze: maze, blanket: blanket)
          {pid, Engine.peek(pid).run_id}
      end

    {agent, agent_pid} =
      case mode do
        :pure ->
          a = ActiveInferenceAgent.fresh(agent_id, bundle, blanket, goal_idx: goal_idx)
          {a, nil}

        :supervised ->
          # Plan §12 Phase 3 — hand the agent to a real Jido.AgentServer
          # under AgentPlane.JidoInstance. The struct returned is the seed;
          # all subsequent state lives inside the server.
          spec = %{
            agent_id: agent_id,
            spec_id: Map.get(bundle, :spec_id),
            bundle: bundle,
            blanket: blanket,
            goal_idx: goal_idx
          }

          {:ok, ^agent_id, pid} = Runtime.start_agent(spec)
          {:ok, %Jido.AgentServer.State{} = srv} = Runtime.state(agent_id)
          {srv.agent, pid}

        :attached ->
          # Studio S3 -- the agent is already running; don't start a new one.
          {:ok, %Jido.AgentServer.State{} = srv} = Runtime.state(agent_id)
          {srv.agent, Keyword.get(opts, :agent_pid)}
      end

    state = %{
      world_pid: world_pid,
      world_run_id: world_run_id,
      agent: agent,
      agent_id: agent_id,
      agent_pid: agent_pid,
      mode: mode,
      planner_mode: planner_mode,
      extra_actions: extra_actions,
      steps: 0,
      max_steps: max_steps,
      history: []
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:step, _from, %{steps: s, max_steps: m} = state) when s >= m do
    {:reply, {:done, summary(state)}, state}
  end

  def handle_call(:step, _from, state) do
    obs_packet = Engine.current_observation(state.world_pid)

    cond do
      obs_packet.terminal? ->
        {:reply, {:done, summary(state)}, state}

      true ->
        # Plan §8.3 — publish world.observation as soon as the obs crosses
        # the blanket into the agent plane. Runs before Perceive so Glass
        # Engine can show the causal stimulus ahead of the state update.
        maybe_publish("world.observation", state.agent, state, %{
          channels: obs_packet.channels,
          t: obs_packet.t,
          terminal?: obs_packet.terminal?
        })

        # 1. Perceive (eq. 4.13 / B.5)
        {agent1, _dirs1} = do_perceive(state, obs_packet)

        maybe_publish(
          "agent.perceived",
          agent1,
          state,
          %{t: agent1.state.t, obs_history_len: length(agent1.state.obs_history)},
          equation_id: "eq_4_13_state_belief_update"
        )

        # 2. Plan (eq. 4.14 / B.9)
        {agent2, _dirs2} = do_plan(state, agent1)

        maybe_publish(
          "agent.planned",
          agent2,
          state,
          %{
            f: agent2.state.last_f,
            g: agent2.state.last_g,
            policy_posterior: agent2.state.policy_posterior,
            best_policy_index: agent2.state.last_policy_best_idx,
            chosen_action: agent2.state.last_action
          },
          equation_id: "eq_4_14_policy_posterior"
        )

        # 3. Act — in :pure mode Episode handles the Emit directive inline;
        # in :supervised mode the real AgentServer dispatches and this
        # returns the same agent + action already taken.
        {agent3, dirs3} = do_act(state, agent2)

        emit = Enum.find(dirs3 || [], &match?(%Jido.Agent.Directive.Emit{}, &1))

        action =
          case emit do
            %Jido.Agent.Directive.Emit{signal: %{data: %{action: a}}} -> a
            _ -> agent3.state.last_action
          end

        # The Jido.Signal data already carries the full provenance tuple
        # (Phase 1); lift it verbatim into the WorldModels event.
        emit_data =
          case emit do
            %Jido.Agent.Directive.Emit{signal: %{data: data}} -> data
            _ -> %{action: action, t: state.steps, agent_id: agent3.state.agent_id}
          end

        maybe_publish("agent.action_emitted", agent3, state, emit_data,
          equation_id: "eq_4_14_policy_posterior"
        )

        action_packet =
          ActionPacket.new(%{
            t: state.steps,
            action: action,
            agent_id: agent3.state.agent_id,
            blanket: agent3.state.blanket
          })

        {:ok, next_obs} = Engine.apply_action(state.world_pid, action_packet)

        # Lego-uplift Phase Ω — run any extra learner/maintainer actions
        # from the spec after Act. L4's Dirichlet learners live here:
        # they update α_A / α_B on the live bundle using the step's
        # (obs, action, new belief) triple so the agent can adjust its
        # world model online.
        agent_after_extras = apply_extras(state, agent3)

        entry = %{
          obs: obs_packet,
          action: action,
          terminal?: next_obs.terminal?,
          policy_posterior: agent3.state.policy_posterior,
          marginal_state_belief: agent3.state.marginal_state_belief,
          f: agent3.state.last_f,
          g: agent3.state.last_g
        }

        AgentPlane.Telemetry.broadcast(agent3.state.agent_id, entry)

        if next_obs.terminal? do
          maybe_publish("world.terminal", agent3, state, %{
            t: next_obs.t,
            pos: Engine.peek(state.world_pid).pos
          })
        end

        new_state = %{
          state
          | agent: agent_after_extras,
            steps: state.steps + 1,
            history: state.history ++ [entry]
        }

        reply =
          if next_obs.terminal? do
            {:done, summary(new_state)}
          else
            {:ok, entry}
          end

        {:reply, reply, new_state}
    end
  end

  def handle_call(:inspect_state, _from, state) do
    {:reply, summary(state), state}
  end

  def handle_call(:reset, _from, state) do
    _ = Engine.reset(state.world_pid)

    new_agent =
      ActiveInferenceAgent.fresh(
        state.agent.state.agent_id,
        state.agent.state.bundle,
        state.agent.state.blanket,
        goal_idx: state.agent.state.goal_idx
      )

    {:reply, :ok, %{state | agent: new_agent, steps: 0, history: []}}
  end

  # Multi-episode loop: reset world geometry to the start tile but keep
  # every agent-side learning — bundle (incl. any Dirichlet-updated A
  # or B), beliefs chain, obs_history, t counter. This is the hinge
  # that makes the "Run again" feature show cross-episode learning.
  def handle_call(:reset_world, _from, state) do
    _ = Engine.reset(state.world_pid)
    {:reply, :ok, %{state | steps: 0, history: []}}
  end

  # -- Mode-aware agent dispatch ---------------------------------------------

  # Plan §12 Phase 3 — in `:pure` mode the Episode IS the runtime (cmd/2 on
  # a pure struct). In `:supervised` mode the real Jido.AgentServer is
  # driving the agent; we send signals and pull the updated state.
  defp do_perceive(%{mode: :pure} = state, obs) do
    ActiveInferenceAgent.cmd(state.agent, {Perceive, %{observation: obs}})
  end

  defp do_perceive(%{mode: mode} = state, obs) when mode in [:supervised, :attached] do
    {:ok, _agent_struct} = Runtime.perceive(state.agent_id, obs)
    {:ok, srv} = Runtime.state(state.agent_id)
    {srv.agent, nil}
  end

  defp do_plan(%{mode: :pure, planner_mode: :sophisticated}, agent1) do
    # Lego-uplift Phase Ω — honour the SpecCompiler's planner choice.
    # Deep-horizon / beam-pruned policy search replaces the naïve
    # one-step softmax when the spec topology wires a
    # `sophisticated_planner` node. Params come from the action's
    # schema defaults (tree_policy="exhaustive", horizon=5, …);
    # topology params will flow through once the builder's Inspector
    # pipes them into the runtime.
    ActiveInferenceAgent.cmd(agent1, SophisticatedPlan)
  end

  defp do_plan(%{mode: :pure, planner_mode: :none}, agent1) do
    # HMM / perception-only specs don't plan — return the agent unchanged
    # so Perceive → Act fires with the agent's last action still nil
    # (Act will no-op when last_action is nil).
    {agent1, []}
  end

  defp do_plan(%{mode: :pure}, agent1) do
    ActiveInferenceAgent.cmd(agent1, Plan)
  end

  defp do_plan(%{mode: mode} = state, _agent1) when mode in [:supervised, :attached] do
    {:ok, _} = Runtime.plan(state.agent_id)
    {:ok, srv} = Runtime.state(state.agent_id)
    {srv.agent, nil}
  end

  defp do_act(%{mode: :pure}, agent2) do
    ActiveInferenceAgent.cmd(agent2, Act)
  end

  defp do_act(%{mode: mode} = state, _agent2) when mode in [:supervised, :attached] do
    {:ok, _agent_struct, _action} = Runtime.act(state.agent_id)
    {:ok, srv} = Runtime.state(state.agent_id)
    # The AgentServer dispatched the Emit directive itself; we don't replay it.
    {srv.agent, []}
  end

  # Lego-uplift Phase Ω — run the post-Act extra_actions (Dirichlet
  # learners for L4). Each module is expected to be a `Jido.Action` with
  # a run/2 returning `{:ok, %{bundle: updated_bundle}}` (see
  # `AgentPlane.Actions.DirichletUpdateA` / `...B`). We fold the
  # returned bundle into the agent's state so subsequent steps see the
  # updated A / B. No-ops when `extra_actions == []`.
  defp apply_extras(%{extra_actions: []}, agent), do: agent

  defp apply_extras(%{mode: :pure, extra_actions: modules}, agent) do
    Enum.reduce(modules, agent, fn mod, a ->
      case ActiveInferenceAgent.cmd(a, mod) do
        {next_agent, _dirs} -> next_agent
        _ -> a
      end
    end)
  end

  defp apply_extras(%{mode: mode}, agent) when mode in [:supervised, :attached], do: agent

  # -- Event publishing -------------------------------------------------------

  # Plan §8.2 / §8.3 — assemble the full provenance tuple from live agent
  # state + episode context and push through EventLog (persist) + Bus
  # (broadcast). No-op when the event log isn't running (test env).
  defp maybe_publish(type, agent, state, data, opts \\ []) do
    if Bus.running?() do
      event =
        Event.new(%{
          type: type,
          provenance: provenance_tuple(agent, state, opts),
          data: data
        })

      :ok = EventLog.append(event)
    end

    :ok
  end

  defp provenance_tuple(agent, state, opts) do
    %{
      agent_id: agent.state.agent_id,
      spec_id: agent.state.spec_id,
      bundle_id: agent.state.bundle_id,
      family_id: agent.state.family_id,
      world_run_id: state.world_run_id,
      equation_id: Keyword.get(opts, :equation_id),
      verification_status: agent.state.verification_status
    }
  end

  # -- Helpers ----------------------------------------------------------------

  defp summary(state) do
    world_peek = Engine.peek(state.world_pid)

    %{
      steps: state.steps,
      max_steps: state.max_steps,
      terminal?: world_peek.terminal?,
      goal_reached?: world_peek.terminal?,
      world: %{
        maze: world_peek.maze,
        pos: world_peek.pos,
        history: world_peek.history
      },
      agent: %{
        agent_id: state.agent.state.agent_id,
        t: state.agent.state.t,
        policy_posterior: state.agent.state.policy_posterior,
        policies: state.agent.state.bundle[:policies] || [],
        marginal_state_belief: state.agent.state.marginal_state_belief,
        best_policy_chain: Map.get(state.agent.state, :best_policy_chain, []),
        best_policy_actions: best_policy_actions(state.agent.state),
        last_action: state.agent.state.last_action,
        last_f: state.agent.state.last_f,
        last_g: state.agent.state.last_g,
        bundle_dims: state.agent.state.bundle[:dims]
      },
      history: state.history
    }
  end

  defp ref_to_pid(pid) when is_pid(pid), do: pid

  defp ref_to_pid(session_id) when is_binary(session_id) do
    case Registry.lookup(WorkbenchWeb.Episode.Registry, session_id) do
      [{pid, _}] -> pid
      _ -> raise ArgumentError, "no episode registered for session_id #{inspect(session_id)}"
    end
  end

  defp random_id do
    "episode-" <> (:crypto.strong_rand_bytes(6) |> Base.url_encode64(padding: false))
  end

  # Action sequence of the agent's winning policy, from
  # `state.bundle.policies[last_policy_best_idx]`. Returns [] when
  # the agent hasn't planned yet or the index is out of range.
  defp best_policy_actions(agent_state) do
    idx = Map.get(agent_state, :last_policy_best_idx, 0)

    case agent_state.bundle[:policies] do
      list when is_list(list) and list != [] ->
        Enum.at(list, idx, []) || []

      _ ->
        []
    end
  end
end

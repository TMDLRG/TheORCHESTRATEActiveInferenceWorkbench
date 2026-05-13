defmodule WorkbenchWeb.Episode.BirdsongEpisode do
  @moduledoc """
  Single-agent episode runner for the Birdsong Call-Response lab.

  The runner keeps the same Jido action sequence used elsewhere in the
  workbench: `Perceive -> Plan -> Act`. The world receives only an
  `ActionPacket`; free-energy values, beliefs, and policy posteriors stay on
  the agent side and are exposed by the episode snapshot for inspection.
  """

  use GenServer

  alias AgentPlane.ActiveInferenceAgent
  alias AgentPlane.Actions.{Act, Perceive, Plan}
  alias AgentPlane.BundleBuilder.Birdsong
  alias Jido.Agent.Directive
  alias SharedContracts.{ActionPacket, Blanket, ObservationPacket}
  alias WorldPlane.Worlds.BirdsongCallResponse
  alias WorldPlane.Worlds.BirdsongCallResponse.Synth

  @doc "Start a birdsong episode around an already-started birdsong world."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    session_id = Keyword.get(opts, :session_id, random_id())
    name = {:via, Registry, {WorkbenchWeb.Episode.Registry, session_id}}
    GenServer.start_link(__MODULE__, Keyword.put(opts, :session_id, session_id), name: name)
  end

  @doc "Advance the episode by one inference/action/world tick."
  @spec step(pid() | String.t(), timeout()) :: {:ok, map()} | {:done, map()}
  def step(ref, timeout \\ 60_000), do: GenServer.call(ref_to_pid(ref), :step, timeout)

  @doc "Run up to `limit` ticks or until a response action has been emitted."
  @spec run_until_response(pid() | String.t(), pos_integer(), timeout()) :: map()
  def run_until_response(ref, limit \\ 4, timeout \\ 60_000) do
    pid = ref_to_pid(ref)

    Enum.reduce_while(1..limit, snapshot(pid), fn _, _acc ->
      case step(pid, timeout) do
        {:ok, entry} ->
          if entry.response_wav do
            {:halt, snapshot(pid)}
          else
            {:cont, snapshot(pid)}
          end

        {:done, snap} ->
          {:halt, snap}
      end
    end)
  end

  @doc """
  Run one Active Inference call-response trial per input motif and concatenate
  the emitted response motifs into a multi-note WAV.

  This is the lab's high-level sequence bridge: each note remains a discrete
  POMDP trial, and the rendered WAV is the concatenation of the actions selected
  by Jido/Active Inference for each trial.
  """
  @spec run_motif_sequence([atom()], map(), keyword()) :: map()
  def run_motif_sequence(motifs, bundle, opts \\ []) when is_list(motifs) and is_map(bundle) do
    max_steps = Keyword.get(opts, :max_steps, 6)

    trials =
      Enum.map(motifs, fn motif ->
        {:ok, world} = BirdsongCallResponse.start_link(motifs: [motif])
        {:ok, ep} = start_link(world_pid: world, bundle: bundle, max_steps: max_steps)
        snapshot = run_until_response(ep, max_steps, 60_000)
        response = snapshot.world.response_events |> List.first(%{}) |> Map.get(:token)
        _ = stop(ep)
        if Process.alive?(world), do: GenServer.stop(world)

        %{
          heard_motif: motif,
          response_motif: response,
          action: snapshot.agent.last_action,
          snapshot: snapshot
        }
      end)

    response_motifs =
      trials
      |> Enum.map(& &1.response_motif)
      |> Enum.filter(&(&1 in [:a, :b, :c, :d]))

    response_wav =
      case response_motifs do
        [] -> nil
        [_ | _] -> Synth.render_wav(response_motifs)
      end

    %{
      trials: trials,
      response_motifs: response_motifs,
      response_wav: response_wav,
      response_data_url: maybe_data_url(response_wav),
      last_snapshot: trials |> List.last(%{}) |> Map.get(:snapshot)
    }
  end

  @doc "Return the current episode snapshot."
  @spec snapshot(pid() | String.t(), timeout()) :: map()
  def snapshot(ref, timeout \\ 60_000), do: GenServer.call(ref_to_pid(ref), :snapshot, timeout)

  @doc "Reset the agent and world."
  @spec reset(pid() | String.t()) :: :ok
  def reset(ref), do: GenServer.call(ref_to_pid(ref), :reset)

  @doc "Stop the episode."
  @spec stop(pid() | String.t()) :: :ok
  def stop(ref), do: GenServer.stop(ref_to_pid(ref))

  @impl true
  def init(opts) do
    world_pid = Keyword.fetch!(opts, :world_pid)
    blanket = Keyword.get(opts, :blanket, Blanket.birdsong_default())
    bundle = Keyword.get(opts, :bundle, Birdsong.build())
    agent_id = Keyword.get(opts, :agent_id, "birdsong-agent")
    session_id = Keyword.fetch!(opts, :session_id)
    max_steps = Keyword.get(opts, :max_steps, 8)

    agent = ActiveInferenceAgent.fresh(agent_id, bundle, blanket)

    {:ok,
     %{
       session_id: session_id,
       world_pid: world_pid,
       blanket: blanket,
       bundle: bundle,
       agent_id: agent_id,
       agent: agent,
       max_steps: max_steps,
       steps: 0,
       history: [],
       response_wavs: []
     }}
  end

  @impl true
  def handle_call(:step, _from, %{steps: steps, max_steps: max_steps} = state)
      when steps >= max_steps do
    {:reply, {:done, summary(state)}, state}
  end

  def handle_call(:step, _from, state) do
    if BirdsongCallResponse.terminal?(state.world_pid) do
      {:reply, {:done, summary(state)}, state}
    else
      obs = BirdsongCallResponse.current_observation(state.world_pid)
      {agent_after, action} = run_inference_tick(state.agent, obs)

      packet =
        ActionPacket.new(%{
          t: state.steps,
          action: action,
          agent_id: state.agent_id,
          blanket: state.blanket
        })

      {:ok, next_obs} = BirdsongCallResponse.step(state.world_pid, packet)
      response_wav = response_wav(action)

      entry = %{
        t: state.steps,
        observation: obs.channels,
        next_observation: next_obs.channels,
        action: action,
        response_wav: response_wav,
        response_data_url: maybe_data_url(response_wav),
        policy_posterior: agent_after.state.policy_posterior,
        f: agent_after.state.last_f,
        g: agent_after.state.last_g,
        best_policy_index: agent_after.state.last_policy_best_idx,
        best_policy: Enum.at(state.bundle.policies, agent_after.state.last_policy_best_idx),
        marginal_state_belief: agent_after.state.marginal_state_belief
      }

      new_state = %{
        state
        | agent: agent_after,
          steps: state.steps + 1,
          history: state.history ++ [entry],
          response_wavs: state.response_wavs ++ List.wrap(response_wav)
      }

      {:reply, {:ok, entry}, new_state}
    end
  end

  def handle_call(:snapshot, _from, state), do: {:reply, summary(state), state}

  def handle_call(:inspect_state, _from, state) do
    {:reply,
     %{
       session_id: state.session_id,
       steps: state.steps,
       max_steps: state.max_steps,
       terminal?: BirdsongCallResponse.terminal?(state.world_pid),
       agent: %{agent_id: state.agent_id}
     }, state}
  end

  def handle_call(:reset, _from, state) do
    :ok = BirdsongCallResponse.reset(state.world_pid)
    agent = ActiveInferenceAgent.fresh(state.agent_id, state.bundle, state.blanket)

    {:reply, :ok, %{state | agent: agent, steps: 0, history: [], response_wavs: []}}
  end

  defp run_inference_tick(agent, %ObservationPacket{} = obs) do
    {a1, _d1} = ActiveInferenceAgent.cmd(agent, {Perceive, %{observation: obs}})
    {a2, _d2} = ActiveInferenceAgent.cmd(a1, Plan)
    {a3, dirs3} = ActiveInferenceAgent.cmd(a2, Act)

    action =
      case Enum.find(dirs3 || [], &match?(%Directive.Emit{}, &1)) do
        %Directive.Emit{signal: %{data: %{action: emitted}}} -> emitted
        _ -> a3.state.last_action
      end

    {a3, action}
  end

  defp response_wav(:sing_a), do: Synth.render_wav([:a])
  defp response_wav(:sing_b), do: Synth.render_wav([:b])
  defp response_wav(:sing_c), do: Synth.render_wav([:c])
  defp response_wav(:sing_d), do: Synth.render_wav([:d])
  defp response_wav(_), do: nil

  defp maybe_data_url(nil), do: nil
  defp maybe_data_url(wav), do: "data:audio/wav;base64," <> Base.encode64(wav)

  defp summary(state) do
    world = BirdsongCallResponse.peek(state.world_pid)
    last = List.last(state.history)

    %{
      session_id: state.session_id,
      steps: state.steps,
      max_steps: state.max_steps,
      done?: state.steps >= state.max_steps or world.terminal?,
      agent: %{
        agent_id: state.agent_id,
        last_action: state.agent.state.last_action,
        policy_posterior: state.agent.state.policy_posterior,
        last_f: state.agent.state.last_f,
        last_g: state.agent.state.last_g,
        best_policy_index: state.agent.state.last_policy_best_idx,
        best_policy: Enum.at(state.bundle.policies, state.agent.state.last_policy_best_idx),
        policies: state.bundle.policies,
        marginal_state_belief: state.agent.state.marginal_state_belief
      },
      world: %{
        t: world.t,
        extracted: world.extracted,
        response_events: world.response_events,
        terminal?: world.terminal?
      },
      last_entry: last,
      response_data_url: last && last.response_data_url,
      history: state.history
    }
  end

  defp ref_to_pid(pid) when is_pid(pid), do: pid

  defp ref_to_pid(session_id) when is_binary(session_id) do
    case Registry.lookup(WorkbenchWeb.Episode.Registry, session_id) do
      [{pid, _}] -> pid
      _ -> raise ArgumentError, "no birdsong episode registered for #{inspect(session_id)}"
    end
  end

  defp random_id do
    "birdsong-episode-" <> (:crypto.strong_rand_bytes(6) |> Base.url_encode64(padding: false))
  end
end

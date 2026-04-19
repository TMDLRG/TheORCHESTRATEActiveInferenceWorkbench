defmodule AgentPlane.Runtime do
  @moduledoc """
  Plan §11.2 — façade over `Jido.AgentServer`.

  Closes GAP-R4: agents now run as supervised processes under
  `AgentPlane.JidoInstance`, which unlocks JIDO's built-in telemetry
  (`[:jido, :agent_server, :signal, :stop]`, directive lifecycle,
   strategy events) for the Glass Engine.

  The callers (Builder, Episode in `:supervised` mode) construct a spec
  map and call `start_agent/1`; this module handles the AgentServer
  boot, seeds the provenance tuple into initial state, and drives the
  agent via real `Jido.Signal`s — not direct `cmd/2` calls.
  """

  alias AgentPlane.{ActiveInferenceAgent, JidoInstance}
  alias Jido.AgentServer
  alias Jido.Signal
  alias SharedContracts.ObservationPacket
  alias WorldModels.{AgentRegistry, Bus, Event, EventLog}

  @type spec :: %{
          required(:agent_id) => String.t(),
          required(:bundle) => map(),
          required(:blanket) => SharedContracts.Blanket.t(),
          optional(:spec_id) => String.t() | nil,
          optional(:goal_idx) => non_neg_integer()
        }

  @doc """
  Start a supervised agent from a spec.

  Returns `{:ok, agent_id, pid}`. The agent's state is pre-seeded with
  the plan §7.1 provenance tuple so every later introspection is grounded.
  """
  @spec start_agent(spec()) :: {:ok, String.t(), pid()} | {:error, term()}
  def start_agent(%{agent_id: agent_id, bundle: bundle, blanket: blanket} = spec) do
    goal_idx = Map.get(spec, :goal_idx, 0)

    agent = ActiveInferenceAgent.fresh(agent_id, bundle, blanket, goal_idx: goal_idx)

    # Emit directives carry provenance-rich signals, but the agent itself
    # has no route for "active_inference.action" (only Perceive/Plan/Act/Step).
    # Route Emit to :noop so the default self-dispatch doesn't produce
    # "No route for signal" noise. Phase 8's Glass Engine already sees these
    # emissions via Episode's explicit WorldModels.Bus publishes.
    start_opts = [agent_module: ActiveInferenceAgent, default_dispatch: {:noop, []}]

    case JidoInstance.start_agent(agent, start_opts) do
      {:ok, pid} ->
        maybe_attach_live(agent_id, bundle)
        {:ok, agent_id, pid}

      {:ok, pid, _info} ->
        maybe_attach_live(agent_id, bundle)
        {:ok, agent_id, pid}

      {:error, _} = err ->
        err
    end
  end

  # Plan §12 Phase 5 — register the live agent in WorldModels.AgentRegistry
  # so Glass Engine's `live_for_spec/1` lookups resolve. Attach is
  # best-effort: a bundle without a spec_id (legacy callers, pure-mode
  # tests) just skips the attach; a Mnesia-not-running environment also
  # degrades quietly rather than taking the start path down.
  defp maybe_attach_live(agent_id, bundle) do
    case Map.get(bundle, :spec_id) do
      nil ->
        :ok

      spec_id when is_binary(spec_id) ->
        safe_registry(fn ->
          case AgentRegistry.attach_live(agent_id, spec_id) do
            :ok -> :ok
            {:error, :unknown_spec} -> :ok
          end
        end)
    end
  end

  defp safe_registry(fun) do
    try do
      fun.()
    catch
      :exit, _ -> :ok
    end
  end

  @doc """
  Stop a supervised agent (by id or pid) and publish `agent.stopped` on
  the bus with the agent's provenance intact.
  """
  @spec stop_agent(String.t() | pid()) :: :ok
  def stop_agent(ref) do
    provenance =
      case current_state(ref) do
        {:ok, %{agent: %{state: s}}} ->
          %{
            agent_id: Map.get(s, :agent_id),
            spec_id: Map.get(s, :spec_id),
            bundle_id: Map.get(s, :bundle_id),
            family_id: Map.get(s, :family_id),
            verification_status: Map.get(s, :verification_status)
          }

        _ ->
          %{agent_id: if(is_binary(ref), do: ref, else: nil)}
      end

    _ = JidoInstance.stop_agent(resolve_ref(ref))

    # Detach the live-agent directory row (safe to call even if not attached).
    case Map.get(provenance, :agent_id) do
      nil -> :ok
      agent_id -> safe_registry(fn -> AgentRegistry.detach_live(agent_id) end)
    end

    if Bus.running?() do
      event = Event.new(%{type: "agent.stopped", provenance: provenance, data: %{}})
      :ok = EventLog.append(event)
    end

    :ok
  end

  @doc "Fetch the underlying `%Jido.AgentServer.State{}` for inspection."
  @spec state(String.t() | pid()) :: {:ok, Jido.AgentServer.State.t()} | {:error, term()}
  def state(ref), do: AgentServer.state(resolve_ref(ref))

  defp current_state(ref) do
    case AgentServer.state(resolve_ref(ref)) do
      {:ok, state} -> {:ok, state}
      _ -> :error
    end
  end

  # Plan §11.2 — Jido.AgentServer functions require a pid (or {id, registry})
  # when called outside the JidoInstance module's own helpers. We resolve
  # string ids via our named instance's registry before handing off.
  defp resolve_ref(pid) when is_pid(pid), do: pid

  defp resolve_ref(id) when is_binary(id) do
    # `Jido.whereis/2` returns `pid() | nil` (not `{:ok, pid}`).
    case Jido.whereis(JidoInstance, id) do
      pid when is_pid(pid) -> pid
      _ -> id
    end
  end

  # -- Signal-driven inference loop ------------------------------------------

  @doc """
  Send `Perceive` as a JIDO signal. Synchronous — returns the updated agent.
  """
  @spec perceive(String.t() | pid(), ObservationPacket.t()) :: {:ok, struct()} | {:error, term()}
  def perceive(ref, %ObservationPacket{} = obs) do
    call_signal(ref, "active_inference.perceive", %{observation: obs})
  end

  @doc "Send `Plan` as a JIDO signal."
  @spec plan(String.t() | pid()) :: {:ok, struct()} | {:error, term()}
  def plan(ref), do: call_signal(ref, "active_inference.plan", %{})

  @doc "Send `Act` as a JIDO signal. Returns the updated agent + the action chosen."
  @spec act(String.t() | pid()) :: {:ok, struct(), atom()} | {:error, term()}
  def act(ref) do
    case call_signal(ref, "active_inference.act", %{}) do
      {:ok, agent} ->
        {:ok, agent, agent.state.last_action}

      err ->
        err
    end
  end

  defp call_signal(ref, type, data) do
    signal =
      Signal.new!(%{
        type: type,
        source: signal_source(ref),
        data: data
      })

    AgentServer.call(resolve_ref(ref), signal)
  end

  defp signal_source(ref) when is_binary(ref), do: "/runtime/" <> ref
  defp signal_source(_), do: "/runtime"

  # -- Studio S4: tracked lifecycle ------------------------------------------
  # These wrappers extend start/stop with `AgentPlane.Instances` writes so
  # /studio can surface state badges and lifecycle controls.  They are
  # additive: the untracked `start_agent/1` + `stop_agent/1` above are
  # unchanged so Labs / Builder / existing Episode modes keep working.

  alias AgentPlane.Instance
  alias AgentPlane.Instances

  @doc """
  Start an agent and register it in `AgentPlane.Instances` with state
  `:live`.  Returns `{:ok, Instance.t(), pid()}`.

  Required lifecycle_opts:

    * `:source` -- one of `:builder | :studio | :labs | :cookbook`
    * `:name` -- user-editable display name (optional; falls back to agent_id)
    * `:recipe_slug` -- optional cookbook slug for provenance
  """
  @spec start_tracked_agent(spec(), keyword()) ::
          {:ok, Instance.t(), pid()} | {:error, term()}
  def start_tracked_agent(%{agent_id: agent_id} = spec, lifecycle_opts \\ []) do
    case start_agent(spec) do
      {:ok, ^agent_id, pid} ->
        {:ok, instance} =
          Instances.create(
            agent_id: agent_id,
            spec_id: Map.get(spec, :spec_id) || Map.get(spec.bundle, :spec_id) || "",
            source: Keyword.get(lifecycle_opts, :source, :studio),
            recipe_slug: Keyword.get(lifecycle_opts, :recipe_slug),
            pid: pid,
            state: :live,
            name: Keyword.get(lifecycle_opts, :name) || agent_id
          )

        {:ok, instance, pid}

      err ->
        err
    end
  end

  @doc """
  Stop a tracked agent: stops the `Jido.AgentServer` and transitions the
  Instance row to `:stopped`.  Idempotent.
  """
  @spec stop_tracked(String.t()) :: {:ok, Instance.t()} | {:error, term()}
  def stop_tracked(agent_id) when is_binary(agent_id) do
    _ = stop_agent(agent_id)

    case Instances.get(agent_id) do
      {:ok, %Instance{state: :stopped} = i} -> {:ok, i}
      {:ok, _} -> Instances.transition(agent_id, :stopped, pid: nil)
      :error -> {:error, :not_found}
    end
  end

  @doc """
  Archive a tracked agent.  Stops the process if live, then transitions
  to `:archived`.  Idempotent.
  """
  @spec archive(String.t()) :: {:ok, Instance.t()} | {:error, term()}
  def archive(agent_id) when is_binary(agent_id) do
    case Instances.get(agent_id) do
      {:ok, %Instance{state: :live}} ->
        _ = stop_agent(agent_id)
        Instances.transition(agent_id, :stopped, pid: nil)
        Instances.transition(agent_id, :archived, pid: nil)

      {:ok, %Instance{state: :stopped}} ->
        Instances.transition(agent_id, :archived, pid: nil)

      {:ok, %Instance{state: :archived} = i} ->
        {:ok, i}

      {:ok, %Instance{state: :trashed}} ->
        Instances.transition(agent_id, :archived, pid: nil)

      :error ->
        {:error, :not_found}
    end
  end

  @doc """
  Soft-delete a tracked agent (move to trash).  Stops the process if live.
  Can be called from any non-trashed state.  Idempotent on trashed rows.
  """
  @spec trash(String.t()) :: {:ok, Instance.t()} | {:error, term()}
  def trash(agent_id) when is_binary(agent_id) do
    case Instances.get(agent_id) do
      {:ok, %Instance{state: :live}} ->
        _ = stop_agent(agent_id)
        Instances.transition(agent_id, :stopped, pid: nil)
        Instances.transition(agent_id, :trashed, pid: nil)

      {:ok, %Instance{state: :stopped}} ->
        Instances.transition(agent_id, :trashed, pid: nil)

      {:ok, %Instance{state: :archived}} ->
        Instances.transition(agent_id, :trashed, pid: nil)

      {:ok, %Instance{state: :trashed} = i} ->
        {:ok, i}

      :error ->
        {:error, :not_found}
    end
  end

  @doc """
  Restore a trashed or archived agent to `:stopped`.  The caller can then
  optionally call `restart_tracked/1` to re-boot a live process with the
  same spec.  Idempotent on `:stopped`.
  """
  @spec restore(String.t()) :: {:ok, Instance.t()} | {:error, term()}
  def restore(agent_id) when is_binary(agent_id) do
    case Instances.get(agent_id) do
      {:ok, %Instance{state: :trashed}} -> Instances.transition(agent_id, :stopped)
      {:ok, %Instance{state: :archived}} -> Instances.transition(agent_id, :stopped)
      {:ok, %Instance{state: :stopped} = i} -> {:ok, i}
      {:ok, _} -> {:error, :invalid_transition}
      :error -> {:error, :not_found}
    end
  end

  @doc """
  Re-boot a stopped tracked agent.

  Specs store Topology, not a bundle, so the caller passes a freshly
  compiled bundle (via `WorkbenchWeb.SpecCompiler.compile/3`).  This
  keeps agent_plane free of the workbench_web dependency.

  Required keys in `opts`:

    * `:bundle`  -- the compiled bundle map.
    * `:blanket` -- `SharedContracts.Blanket.t()`; defaults to `maze_default/0`.
    * `:goal_idx` -- integer; defaults to `bundle.dims.n_states - 1`.
  """
  @spec restart_tracked(String.t(), keyword()) :: {:ok, Instance.t(), pid()} | {:error, term()}
  def restart_tracked(agent_id, opts \\ []) when is_binary(agent_id) do
    bundle = Keyword.get(opts, :bundle)
    blanket = Keyword.get(opts, :blanket, SharedContracts.Blanket.maze_default())

    with {:ok, %Instance{state: :stopped, spec_id: spec_id}} <- Instances.get(agent_id),
         true <- is_map(bundle) or {:error, :bundle_required},
         goal_idx =
           Keyword.get(opts, :goal_idx, get_in(bundle, [:dims, :n_states]) |> default_goal()),
         {:ok, ^agent_id, pid} <-
           start_agent(%{
             agent_id: agent_id,
             spec_id: spec_id,
             bundle: bundle,
             blanket: blanket,
             goal_idx: goal_idx
           }) do
      {:ok, updated} = Instances.transition(agent_id, :live, pid: pid)
      {:ok, updated, pid}
    else
      {:ok, %Instance{state: s}} -> {:error, {:invalid_state, s}}
      :error -> {:error, :unknown_spec}
      {:error, _} = e -> e
      other -> {:error, other}
    end
  end

  defp default_goal(nil), do: 0
  defp default_goal(n) when is_integer(n) and n > 0, do: n - 1
  defp default_goal(_), do: 0
end

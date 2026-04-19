defmodule AgentPlane.Instances do
  @moduledoc """
  Mnesia-backed CRUD + lifecycle state machine for Studio-tracked agents.
  S2 of the Studio plan.

  Records live in the `:agent_plane_instances` table created by
  `WorldModels.EventLog.Setup`.  State transitions are authoritative --
  every legal transition writes synchronously.

  On Phoenix boot, call `reconcile_orphans/0` to demote any `:live` rows
  whose pid is no longer alive to `:stopped`.  This handles Phoenix
  restart cleanly (Mnesia is `disc_copies` so rows survive, but BEAM
  processes do not).
  """

  alias AgentPlane.Instance
  alias WorldModels.EventLog.Setup

  @table Setup.instances_table()

  @instances_attributes [
    :agent_id,
    :spec_id,
    :source,
    :recipe_slug,
    :pid,
    :state,
    :name,
    :started_at_usec,
    :updated_at_usec
  ]

  @doc """
  Ensure the Mnesia table exists.  Idempotent; called lazily by every
  public function in case the Setup supervisor hasn't created the table
  yet (e.g. after a hot-reload introducing the table).
  """
  @spec ensure_table!() :: :ok
  def ensure_table! do
    # Start Mnesia if it isn't already (test env may have stopped it).
    _ = :mnesia.start()

    opts = [
      {:attributes, @instances_attributes},
      {storage_for_node(), [node()]},
      {:type, :set},
      {:index, [:state, :spec_id]}
    ]

    case :mnesia.create_table(@table, opts) do
      {:atomic, :ok} ->
        _ = :mnesia.wait_for_tables([@table], 5_000)
        :ok

      {:aborted, {:already_exists, @table}} ->
        :ok

      {:aborted, reason} ->
        raise "AgentPlane.Instances table create failed: #{inspect(reason)}"
    end
  end

  # Unnamed nodes (`nonode@nohost` -- common in ExUnit without a :name set)
  # cannot host disc_copies tables.  Fall back to ram_copies in that case
  # so tests can run without a distributed-node setup.
  defp storage_for_node do
    case node() do
      :nonode@nohost -> :ram_copies
      _ -> :disc_copies
    end
  end

  # -- Create ---------------------------------------------------------------

  @doc """
  Persist a new instance.  Returns `{:ok, Instance.t()}` or `{:error, reason}`.

  Required keys: `:agent_id`, `:spec_id`.  Optional: `:source`
  (default `:studio`), `:recipe_slug`, `:pid`, `:state`
  (default `:live`), `:name`.
  """
  @spec create(keyword() | map()) :: {:ok, Instance.t()} | {:error, term()}
  def create(fields) when is_list(fields), do: create(Map.new(fields))

  def create(fields) when is_map(fields) do
    ensure_table!()
    now = now_usec()
    instance = %Instance{
      agent_id: fetch!(fields, :agent_id),
      spec_id: fetch!(fields, :spec_id),
      source: Map.get(fields, :source, :studio),
      recipe_slug: Map.get(fields, :recipe_slug),
      pid: Map.get(fields, :pid),
      state: Map.get(fields, :state, :live),
      name: Map.get(fields, :name),
      started_at_usec: Map.get(fields, :started_at_usec, now),
      updated_at_usec: now
    }

    case :mnesia.sync_transaction(fn -> :mnesia.write(record_from(instance)) end) do
      {:atomic, :ok} -> {:ok, instance}
      {:aborted, reason} -> {:error, reason}
    end
  end

  # -- Read -----------------------------------------------------------------

  @doc "Fetch an instance by agent_id."
  @spec get(String.t()) :: {:ok, Instance.t()} | :error
  def get(agent_id) when is_binary(agent_id) do
    ensure_table!()

    case :mnesia.dirty_read(@table, agent_id) do
      [record] -> {:ok, instance_from(record)}
      _ -> :error
    end
  end

  @doc """
  List instances.  Filter options:

    * `:state` -- one of `:live | :stopped | :archived | :trashed`
    * `:states` -- list of states; default `[:live, :stopped, :archived]`
      (i.e. trash is hidden unless explicitly requested)
    * `:spec_id` -- filter by spec
    * `:source` -- filter by source tag
  """
  @spec list(keyword()) :: [Instance.t()]
  def list(opts \\ []) do
    ensure_table!()

    all_records =
      :mnesia.dirty_all_keys(@table)
      |> Enum.flat_map(fn key -> :mnesia.dirty_read(@table, key) end)
      |> Enum.map(&instance_from/1)

    all_records
    |> filter_state(opts)
    |> filter_spec(opts)
    |> filter_source(opts)
    |> Enum.sort_by(&(&1.updated_at_usec || 0), :desc)
  end

  # -- Update ---------------------------------------------------------------

  @doc """
  Transition an instance to a new state.  Writes synchronously and stamps
  `updated_at_usec`.  Returns `{:error, :invalid_transition}` if the state
  move is not legal per `AgentPlane.Instance.valid_transition?/2`.
  """
  @spec transition(String.t(), Instance.state(), keyword()) ::
          {:ok, Instance.t()} | {:error, :not_found | :invalid_transition | term()}
  def transition(agent_id, next_state, opts \\ []) when is_binary(agent_id) do
    case get(agent_id) do
      {:ok, %Instance{} = instance} ->
        if Instance.valid_transition?(instance.state, next_state) do
          updated = %Instance{
            instance
            | state: next_state,
              pid: Keyword.get(opts, :pid, maybe_clear_pid(instance.pid, next_state)),
              updated_at_usec: now_usec()
          }

          persist(updated)
        else
          {:error, :invalid_transition}
        end

      :error ->
        {:error, :not_found}
    end
  end

  @doc "Update the user-editable display name of an instance."
  @spec rename(String.t(), String.t()) :: {:ok, Instance.t()} | {:error, :not_found}
  def rename(agent_id, name) when is_binary(agent_id) and is_binary(name) do
    case get(agent_id) do
      {:ok, %Instance{} = instance} ->
        persist(%Instance{instance | name: name, updated_at_usec: now_usec()})

      :error ->
        {:error, :not_found}
    end
  end

  @doc "Update just the pid for a live instance (after restart)."
  @spec set_pid(String.t(), pid() | nil) :: {:ok, Instance.t()} | {:error, :not_found}
  def set_pid(agent_id, pid) when is_binary(agent_id) do
    case get(agent_id) do
      {:ok, %Instance{} = instance} ->
        persist(%Instance{instance | pid: pid, updated_at_usec: now_usec()})

      :error ->
        {:error, :not_found}
    end
  end

  defp persist(%Instance{} = instance) do
    case :mnesia.sync_transaction(fn -> :mnesia.write(record_from(instance)) end) do
      {:atomic, :ok} -> {:ok, instance}
      {:aborted, reason} -> {:error, reason}
    end
  end

  # -- Delete ---------------------------------------------------------------

  @doc """
  Permanently remove an instance from Mnesia.  Only callable on `:trashed`
  rows -- other states raise.  Used by `/studio/trash` Empty-trash.
  """
  @spec purge(String.t()) :: :ok | {:error, :not_trashed | :not_found}
  def purge(agent_id) when is_binary(agent_id) do
    case get(agent_id) do
      {:ok, %Instance{state: :trashed}} ->
        case :mnesia.sync_transaction(fn -> :mnesia.delete({@table, agent_id}) end) do
          {:atomic, :ok} -> :ok
          {:aborted, reason} -> {:error, reason}
        end

      {:ok, _} ->
        {:error, :not_trashed}

      :error ->
        {:error, :not_found}
    end
  end

  @doc """
  Permanently delete every `:trashed` instance.  Returns the list of
  deleted agent_ids.  Called by the Empty-trash UI confirm flow.
  """
  @spec empty_trash() :: {:ok, [String.t()]}
  def empty_trash do
    trashed = list(states: [:trashed])
    ids = Enum.map(trashed, & &1.agent_id)

    :mnesia.sync_transaction(fn ->
      Enum.each(ids, fn id -> :mnesia.delete({@table, id}) end)
    end)

    {:ok, ids}
  end

  # -- Boot reconciliation --------------------------------------------------

  @doc """
  On Phoenix boot, any `:live` row whose pid is no longer alive is
  demoted to `:stopped`.  Returns the list of reconciled agent_ids.
  Called from `WorkbenchWeb.Application.start/2` after Mnesia is ready.
  """
  @spec reconcile_orphans() :: {:ok, [String.t()]}
  def reconcile_orphans do
    orphans =
      list(states: [:live])
      |> Enum.reject(fn i -> is_pid(i.pid) and Process.alive?(i.pid) end)

    reconciled =
      for %Instance{agent_id: id} <- orphans do
        {:ok, _} = transition(id, :stopped, pid: nil)
        id
      end

    {:ok, reconciled}
  end

  # -- Internals ------------------------------------------------------------

  defp record_from(%Instance{} = i) do
    {@table, i.agent_id, i.spec_id, i.source, i.recipe_slug, i.pid, i.state, i.name,
     i.started_at_usec, i.updated_at_usec}
  end

  defp instance_from({@table, agent_id, spec_id, source, recipe_slug, pid, state, name,
       started_at_usec, updated_at_usec}) do
    %Instance{
      agent_id: agent_id,
      spec_id: spec_id,
      source: source,
      recipe_slug: recipe_slug,
      pid: pid,
      state: state,
      name: name,
      started_at_usec: started_at_usec,
      updated_at_usec: updated_at_usec
    }
  end


  defp filter_state(list, opts) do
    state = opts[:state]
    states = opts[:states]

    cond do
      is_atom(state) and not is_nil(state) ->
        Enum.filter(list, &(&1.state == state))

      is_list(states) ->
        set = MapSet.new(states)
        Enum.filter(list, &MapSet.member?(set, &1.state))

      true ->
        # Default: hide trash unless explicitly requested.
        Enum.reject(list, &(&1.state == :trashed))
    end
  end

  defp filter_spec(list, opts) do
    case opts[:spec_id] do
      nil -> list
      id -> Enum.filter(list, &(&1.spec_id == id))
    end
  end

  defp filter_source(list, opts) do
    case opts[:source] do
      nil -> list
      s -> Enum.filter(list, &(&1.source == s))
    end
  end

  defp fetch!(fields, key) do
    case Map.fetch(fields, key) do
      {:ok, v} -> v
      :error -> raise ArgumentError, "AgentPlane.Instances.create/1 missing #{inspect(key)}"
    end
  end

  defp maybe_clear_pid(_pid, state) when state in [:stopped, :archived, :trashed], do: nil
  defp maybe_clear_pid(pid, _state), do: pid

  defp now_usec, do: System.system_time(:microsecond)
end

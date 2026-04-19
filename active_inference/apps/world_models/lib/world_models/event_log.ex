defmodule WorldModels.EventLog do
  @moduledoc """
  Plan §8.5 + §10.6 — disk-durable append-only event log, Mnesia-backed.

  API is stateless and pushes directly through `:mnesia.dirty_*` for
  throughput. All writes also fan out onto `WorldModels.Bus`.
  """

  alias WorldModels.{Bus, Event}
  alias WorldModels.EventLog.Setup

  @table Setup.table()

  @type filter ::
          {:agent_id, String.t()}
          | {:type, String.t()}
          | {:from_ts, integer()}
          | {:to_ts, integer()}
          | {:limit, pos_integer()}
          | {:order, :asc | :desc}
          | {:spec_id, String.t()}
          | {:world_run_id, String.t()}

  @doc """
  Persist an event to Mnesia AND broadcast it on the bus. Call-site (e.g.
  Episode) gets a single write-through API. Idempotent is not guaranteed
  — append assumes unique event ids.
  """
  @spec append(Event.t()) :: :ok
  def append(%Event{} = e) do
    record = to_record(e)

    # Plan §8.5 — disc_copies durability.
    # `dirty_write/1` only updates RAM/ETS (no log hit → lost on BEAM crash).
    # `sync_transaction/1` forces fsync per write, which turns every
    # equation.evaluated span into a disk seek; in supervised mode with
    # ~150 spans per step, that pushed Episode.step past the 5s GenServer
    # timeout.
    # `transaction/1` writes to the disc log (persisted across BEAM
    # restarts — Phase 2 disk-durability test still passes) without
    # forcing a synchronous fsync, so write cost is ~µs per event. On a
    # hard crash we lose at most the last millisecond of events, which
    # is acceptable for observability.
    {:atomic, :ok} =
      :mnesia.transaction(fn -> :mnesia.write(record) end)

    if Bus.running?() do
      :ok = Bus.broadcast(e)
    end

    :ok
  end

  @doc """
  Query by any combination of filters. Agents are the common access path,
  so we use the `:agent_id` secondary index when agent_id is given;
  otherwise a table-wide select. Time bounds apply after retrieval.
  """
  @spec query([filter()]) :: [Event.t()]
  def query(filters \\ []) do
    filters = Map.new(filters)

    rows =
      cond do
        Map.has_key?(filters, :agent_id) ->
          :mnesia.dirty_index_read(@table, Map.fetch!(filters, :agent_id), :agent_id)

        Map.has_key?(filters, :type) ->
          :mnesia.dirty_index_read(@table, Map.fetch!(filters, :type), :type)

        true ->
          scan_all()
      end

    rows
    |> Enum.map(&from_record/1)
    |> filter_events(filters)
    |> sort_events(Map.get(filters, :order, :asc))
    |> maybe_limit(Map.get(filters, :limit))
  end

  @doc """
  Return every event for an agent with `ts_usec <= ts`, ordered ascending,
  plus a `:state` map reconstructed by folding the event stream.

  The folded state carries the latest seen `{f, g, policy_posterior,
  best_policy_index, chosen_action, marginal_state_belief, obs_history_len}`
  — enough for Glass Engine's timeline scrub to hydrate the state tree at
  any past ts.
  """
  @spec snapshot_at(String.t(), integer()) :: %{events: [Event.t()], state: map()}
  def snapshot_at(agent_id, ts_usec) when is_binary(agent_id) and is_integer(ts_usec) do
    events = query(agent_id: agent_id, to_ts: ts_usec)

    state =
      Enum.reduce(events, %{}, fn e, acc ->
        case e.type do
          "agent.planned" ->
            Map.merge(
              acc,
              safe_take(e.data, [
                :f,
                :g,
                :policy_posterior,
                :best_policy_index,
                :chosen_action
              ])
            )

          "agent.action_emitted" ->
            Map.merge(acc, safe_take(e.data, [:action, :t, :best_policy_index]))

          "agent.perceived" ->
            Map.merge(acc, safe_take(e.data, [:t, :obs_history_len]))

          "world.observation" ->
            Map.put(acc, :last_obs_channels, Map.get(e.data, :channels))

          "world.terminal" ->
            Map.put(acc, :terminal?, true)

          _ ->
            acc
        end
      end)

    %{events: events, state: state}
  end

  @doc "Fetch a single event by its `id` (for /glass/signal/:id detail page)."
  @spec fetch_event(String.t()) :: {:ok, Event.t()} | :error
  def fetch_event(event_id) when is_binary(event_id) do
    # :id is not an index key (the primary is {ts_usec, id}); scan.
    spec = [
      {
        {@table, {:_, :"$1"}, :_, :_, :_, :_, :"$2"},
        [{:==, :"$1", event_id}],
        [:"$2"]
      }
    ]

    case :mnesia.dirty_select(@table, spec) do
      [%Event{} = e | _] -> {:ok, e}
      _ -> :error
    end
  end

  defp safe_take(map, keys) when is_map(map) do
    Enum.reduce(keys, %{}, fn k, acc ->
      cond do
        Map.has_key?(map, k) -> Map.put(acc, k, Map.get(map, k))
        Map.has_key?(map, to_string(k)) -> Map.put(acc, k, Map.get(map, to_string(k)))
        true -> acc
      end
    end)
  end

  defp safe_take(_, _), do: %{}

  @spec purge(String.t()) :: :ok
  def purge(agent_id) when is_binary(agent_id) do
    :mnesia.dirty_index_read(@table, agent_id, :agent_id)
    |> Enum.each(fn {@table, key, _aid, _t, _sid, _wid, _ev} ->
      :mnesia.dirty_delete(@table, key)
    end)

    :ok
  end

  @spec purge_older_than(integer()) :: :ok
  def purge_older_than(ts_usec) when is_integer(ts_usec) do
    match_spec = [
      {
        {@table, {:"$1", :"$2"}, :_, :_, :_, :_, :_},
        [{:"=<", :"$1", ts_usec}],
        [{{:"$1", :"$2"}}]
      }
    ]

    :mnesia.dirty_select(@table, match_spec)
    |> Enum.each(&:mnesia.dirty_delete(@table, &1))

    :ok
  end

  @spec count() :: non_neg_integer()
  def count do
    case :mnesia.table_info(@table, :size) do
      n when is_integer(n) -> n
      _ -> 0
    end
  end

  # -- Record ↔ Event --------------------------------------------------------

  defp to_record(%Event{} = e) do
    p = e.provenance || %{}

    {@table, {e.ts_usec, e.id}, Map.get(p, :agent_id), e.type, Map.get(p, :spec_id),
     Map.get(p, :world_run_id), e}
  end

  defp from_record({@table, _key, _aid, _type, _sid, _wid, event}), do: event

  defp scan_all do
    :mnesia.dirty_select(@table, [{{@table, :_, :_, :_, :_, :_, :_}, [], [:"$_"]}])
  end

  # -- Filters / ordering ---------------------------------------------------

  defp filter_events(events, filters) do
    events
    |> maybe_filter(:type, filters, fn e, v -> e.type == v end)
    |> maybe_filter(:agent_id, filters, fn e, v -> Map.get(e.provenance, :agent_id) == v end)
    |> maybe_filter(:spec_id, filters, fn e, v -> Map.get(e.provenance, :spec_id) == v end)
    |> maybe_filter(:world_run_id, filters, fn e, v ->
      Map.get(e.provenance, :world_run_id) == v
    end)
    |> maybe_filter(:from_ts, filters, fn e, v -> e.ts_usec >= v end)
    |> maybe_filter(:to_ts, filters, fn e, v -> e.ts_usec <= v end)
  end

  defp maybe_filter(events, key, filters, pred) do
    case Map.get(filters, key) do
      nil -> events
      v -> Enum.filter(events, &pred.(&1, v))
    end
  end

  defp sort_events(events, :asc), do: Enum.sort_by(events, & &1.ts_usec)
  defp sort_events(events, :desc), do: Enum.sort_by(events, & &1.ts_usec, :desc)

  defp maybe_limit(events, nil), do: events
  defp maybe_limit(events, n) when is_integer(n) and n > 0, do: Enum.take(events, n)
end

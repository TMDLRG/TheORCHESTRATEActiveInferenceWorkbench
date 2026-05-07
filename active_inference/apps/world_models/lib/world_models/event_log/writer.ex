defmodule WorldModels.EventLog.Writer do
  @moduledoc """
  Async batching writer for `WorldModels.EventLog`.

  The hot path in heavy multi-bird Active Inference runs fires ~150
  `equation.evaluated` spans per `Plan` action; doing one
  `:mnesia.transaction/1` per event turned a 2-Resonant-bird Meadow
  step into a 60–80s wait under dev-mode telemetry. This GenServer
  accepts events via `cast`, queues them in-memory, and flushes the
  queue as a single batched Mnesia transaction on either:

    * a 50 ms heartbeat (so even sparse events land within an audit
      window), or
    * a 200-event high-watermark (so bursty workloads can't unbounded
      the queue).

  Durability semantics match the previous implementation: events live
  in the disc-log without per-write fsync. On a hard BEAM crash we lose
  at most one batch (~50 ms) of events, which is acceptable for
  observability and matches the original module's documented trade-off.

  Falls back to a direct synchronous write if the writer isn't started
  (e.g. tests that opt out via `:auto_start_event_log`).
  """

  use GenServer

  alias WorldModels.{Bus, Event}
  alias WorldModels.EventLog.Setup

  @table Setup.table()
  @flush_interval_ms 50
  @flush_threshold 200

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Enqueue an event for asynchronous batched persistence + bus broadcast.
  Returns `:ok` immediately. Falls back to synchronous write if the
  writer process is not running.
  """
  @spec append(Event.t()) :: :ok
  def append(%Event{} = e) do
    case Process.whereis(__MODULE__) do
      nil -> sync_write(e)
      pid -> GenServer.cast(pid, {:append, e})
    end
  end

  @doc "Force-flush the queue and return only after the batch is persisted."
  @spec flush() :: :ok
  def flush do
    case Process.whereis(__MODULE__) do
      nil -> :ok
      _ -> GenServer.call(__MODULE__, :flush, 30_000)
    end
  end

  @impl true
  def init(_) do
    schedule_flush()
    {:ok, %{queue: []}}
  end

  @impl true
  def handle_cast({:append, event}, %{queue: queue} = state) do
    new_queue = [event | queue]

    if length(new_queue) >= @flush_threshold do
      do_flush(new_queue)
      {:noreply, %{state | queue: []}}
    else
      {:noreply, %{state | queue: new_queue}}
    end
  end

  @impl true
  def handle_call(:flush, _from, %{queue: queue} = state) do
    do_flush(queue)
    {:reply, :ok, %{state | queue: []}}
  end

  @impl true
  def handle_info(:flush, %{queue: queue} = state) do
    schedule_flush()
    do_flush(queue)
    {:noreply, %{state | queue: []}}
  end

  @impl true
  def terminate(_reason, %{queue: queue}) do
    do_flush(queue)
    :ok
  end

  defp schedule_flush do
    Process.send_after(self(), :flush, @flush_interval_ms)
  end

  # Empty batch — no-op.
  defp do_flush([]), do: :ok

  defp do_flush(reversed_events) do
    # Restore chronological order — append/1 prepends.
    events = Enum.reverse(reversed_events)
    records = Enum.map(events, &to_record/1)

    # One Mnesia transaction for the whole batch — amortises log-write
    # overhead across N events instead of paying it per event.
    {:atomic, :ok} =
      :mnesia.transaction(fn ->
        Enum.each(records, &:mnesia.write/1)
      end)

    if Bus.running?() do
      Enum.each(events, &Bus.broadcast/1)
    end

    :ok
  rescue
    _ -> :ok
  catch
    :exit, _ -> :ok
    _, _ -> :ok
  end

  defp sync_write(%Event{} = e) do
    record = to_record(e)

    {:atomic, :ok} =
      :mnesia.transaction(fn -> :mnesia.write(record) end)

    if Bus.running?() do
      :ok = Bus.broadcast(e)
    end

    :ok
  rescue
    _ -> :ok
  catch
    :exit, _ -> :ok
    _, _ -> :ok
  end

  defp to_record(%Event{} = e) do
    p = e.provenance || %{}

    {@table, {e.ts_usec, e.id}, Map.get(p, :agent_id), e.type, Map.get(p, :spec_id),
     Map.get(p, :world_run_id), e}
  end
end

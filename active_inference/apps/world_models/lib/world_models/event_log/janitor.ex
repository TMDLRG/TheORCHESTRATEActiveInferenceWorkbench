defmodule WorldModels.EventLog.Janitor do
  @moduledoc """
  Plan §8.5 — periodic retention worker.

  Purges events older than `:retention_ms` (default 7 days) every
  `:interval_ms` (default 1 hour). Runs as a plain `GenServer`; tests can
  spin it up with tiny retention to verify behavior.
  """

  use GenServer

  alias WorldModels.EventLog

  @default_retention_ms 7 * 24 * 60 * 60 * 1_000
  @default_interval_ms 60 * 60 * 1_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @impl true
  def init(opts) do
    state = %{
      retention_ms: Keyword.get(opts, :retention_ms, @default_retention_ms),
      interval_ms: Keyword.get(opts, :interval_ms, @default_interval_ms)
    }

    schedule(state.interval_ms)
    {:ok, state}
  end

  @impl true
  def handle_info(:purge, state) do
    cutoff_usec = System.system_time(:microsecond) - state.retention_ms * 1_000
    :ok = EventLog.purge_older_than(cutoff_usec)
    schedule(state.interval_ms)
    {:noreply, state}
  end

  defp schedule(ms), do: Process.send_after(self(), :purge, ms)
end

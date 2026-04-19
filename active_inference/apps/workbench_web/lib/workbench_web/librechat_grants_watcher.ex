defmodule WorkbenchWeb.LibreChatGrantsWatcher do
  @moduledoc """
  Background GenServer that re-runs the grant step in the seeder every
  `@poll_ms` milliseconds so newly-registered LibreChat users immediately
  inherit the same agent + prompt-group ACL as the seeder admin — no need
  for the learner to restart the suite.

  Mechanism: spawns `python tools/librechat_seed/globalize.py` (which is
  idempotent) and relies on its `$setOnInsert` upsert to add only the ACL
  entries that don't yet exist.  A run for a handful of users takes less
  than a second on Mongo's default indexes.

  Disable by setting `WORKSHOP_GRANTS_WATCHER=false` before `mix phx.server`.
  """
  use GenServer
  require Logger

  @poll_ms 60_000

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    if enabled?() do
      Process.send_after(self(), :tick, 5_000)
      {:ok, %{last_run: nil}}
    else
      :ignore
    end
  end

  defp enabled? do
    System.get_env("WORKSHOP_GRANTS_WATCHER", "true") not in ["false", "0", ""]
  end

  @impl true
  def handle_info(:tick, state) do
    run()
    Process.send_after(self(), :tick, @poll_ms)
    {:noreply, %{state | last_run: System.system_time(:second)}}
  end

  defp run do
    root =
      Application.app_dir(:workbench_web, ".")
      |> Path.join(["..", "..", "..", ".."])
      |> Path.expand()

    script = Path.join(root, "tools/librechat_seed/globalize.py")

    if File.exists?(script) do
      case System.cmd(python_binary(), [script],
             cd: root,
             env: [{"PYTHONIOENCODING", "utf-8"}],
             stderr_to_stdout: true
           ) do
        {out, 0} ->
          Logger.debug("[grants_watcher] ok — #{String.slice(out, -120, 120)}")

        {out, code} ->
          Logger.warning("[grants_watcher] exit #{code}: #{String.slice(out, -200, 200)}")
      end
    end
  rescue
    e ->
      Logger.warning("[grants_watcher] exception: #{inspect(e)}")
  end

  defp python_binary do
    cond do
      find_executable("python3") -> "python3"
      find_executable("python") -> "python"
      true -> "python"
    end
  end

  defp find_executable(bin), do: System.find_executable(bin) != nil
end

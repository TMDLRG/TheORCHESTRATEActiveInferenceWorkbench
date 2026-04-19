defmodule WorldModels.MnesiaCase do
  @moduledoc """
  Plan §12 Phase 0 — S-0.2 spike outcome + Phase 2 event log foundation.

  Gives a test a clean Mnesia node on an isolated on-disk dir, creates
  the schema + the `WorldModels.EventLog` table, and wipes everything
  in an `on_exit` callback.

  Usage:

      use WorldModels.MnesiaCase, async: false

  Marked `async: false` is deliberate — `:mnesia` is a global OTP app
  and we want exactly one Mnesia lifecycle per test. Tests using this
  case cannot run in parallel against each other, but can run in
  parallel with other unrelated tests.

  The actual `EventLog` schema lands in Phase 2 (§12). Until then this
  helper only boots/stops `:mnesia` with an ephemeral dir, so the
  S-0.2 spike tests (schema bootstrap) can be written red first.
  """
  use ExUnit.CaseTemplate

  using do
    quote do
      import WorldModels.MnesiaCase, only: [mnesia_tmp_dir: 0]
    end
  end

  setup _tags do
    dir = mnesia_tmp_dir()
    File.rm_rf!(dir)
    File.mkdir_p!(dir)

    # Stop the app-owned mnesia (if running) so we can point it at our tmp dir.
    :stopped = :mnesia.stop()
    :ok = Application.put_env(:mnesia, :dir, String.to_charlist(dir))

    on_exit(fn ->
      :stopped = :mnesia.stop()
      File.rm_rf!(dir)
    end)

    {:ok, mnesia_dir: dir}
  end

  @doc "Per-test isolated Mnesia directory under the umbrella's _build tree."
  @spec mnesia_tmp_dir() :: String.t()
  def mnesia_tmp_dir do
    base =
      System.tmp_dir!()
      |> Path.join("world_models_mnesia_test")

    unique = :erlang.unique_integer([:positive, :monotonic]) |> Integer.to_string()
    Path.join(base, unique)
  end
end

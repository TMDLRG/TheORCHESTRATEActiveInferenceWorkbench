defmodule WorldModels.MnesiaCaseTest do
  @moduledoc """
  Plan §12 Phase 0 spike S-0.2 — prove the MnesiaCase harness isolates
  and cleans up per test so the upcoming EventLog tests (Phase 2) can
  trust it.
  """
  use WorldModels.MnesiaCase, async: false

  test "tmp dir exists and mnesia is isolated to it", %{mnesia_dir: dir} do
    assert File.exists?(dir)
    assert :mnesia.system_info(:is_running) == :no

    # Spin up a clean schema + start mnesia, proving the harness lets
    # tests do what Phase 2 needs (schema create + mnesia start).
    :ok = :mnesia.create_schema([node()])
    :ok = :mnesia.start()
    assert :mnesia.system_info(:is_running) == :yes

    # The on-disk files should live under our tmp dir, not the global one.
    # Mnesia normalizes to forward slashes + lowercase drive letter on Windows;
    # normalize both sides before comparing.
    normalize = fn p -> p |> String.downcase() |> String.replace("\\", "/") end
    mnesia_path = :mnesia.system_info(:directory) |> to_string() |> normalize.()
    assert mnesia_path == normalize.(dir)

    # Schema file should be present on disk now.
    assert File.exists?(Path.join(dir, "schema.DAT"))
  end

  test "a second test gets a fresh isolated dir", %{mnesia_dir: dir2} do
    # Not equal to dir from the previous test — each test gets its own.
    assert File.exists?(dir2)
    assert :mnesia.system_info(:is_running) == :no
  end
end

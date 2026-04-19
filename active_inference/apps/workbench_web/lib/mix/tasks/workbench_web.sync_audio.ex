defmodule Mix.Tasks.WorkbenchWeb.SyncAudio do
  @moduledoc """
  Copy the book's podcast MP3s from the repo-root `audio book/` folder into
  `apps/workbench_web/priv/static/book/audio/` so Phoenix can serve them under
  `/book/audio/chNN_partPP.mp3`.  The directory name contains a space, which
  we strip in the destination (`audio book/` → `book/audio/`).

  Idempotent.  Copies everything; preserves the `preface/` subdirectory.
  """
  @shortdoc "Copy podcasts into priv/static/book/audio/"

  use Mix.Task

  @impl true
  def run(_args) do
    cwd = File.cwd!()

    repo_root =
      cond do
        File.dir?(Path.join(cwd, "audio book")) -> cwd
        File.dir?(Path.join(cwd, "../audio book")) -> Path.expand("..", cwd)
        File.dir?(Path.join(cwd, "../../audio book")) -> Path.expand("../..", cwd)
        File.dir?(Path.join(cwd, "../../../audio book")) -> Path.expand("../../..", cwd)
        true -> nil
      end

    unless repo_root do
      Mix.shell().error("repo-root `audio book/` directory not found (cwd=#{cwd})")
      exit({:shutdown, 1})
    end

    src = Path.join(repo_root, "audio book")
    dest = Path.join(repo_root, "active_inference/apps/workbench_web/priv/static/book/audio")

    # Clean any partial copy from earlier runs (directories named like chNN_partPP
    # with no extension).
    if File.dir?(dest) do
      for name <- File.ls!(dest) do
        fp = Path.join(dest, name)

        if File.dir?(fp) and not String.ends_with?(name, [".mp3", ".wav"]) do
          File.rm_rf!(fp)
        end
      end
    end

    File.mkdir_p!(dest)

    # Each podcast lives inside a subfolder named like ch01_part01 with an mp3
    # of the same name inside; flatten into priv/static/book/audio/ch01_part01.mp3.
    count =
      src
      |> File.ls!()
      |> Enum.reduce(0, fn name, acc ->
        from_dir = Path.join(src, name)

        cond do
          File.dir?(from_dir) ->
            case find_first_mp3(from_dir) do
              nil ->
                acc

              mp3 ->
                basename = Path.basename(mp3)

                target =
                  if String.starts_with?(name, "preface") do
                    File.mkdir_p!(Path.join(dest, "preface"))
                    Path.join([dest, "preface", basename])
                  else
                    Path.join(dest, basename)
                  end

                File.cp!(mp3, target)
                acc + 1
            end

          String.ends_with?(name, ".mp3") ->
            File.cp!(from_dir, Path.join(dest, name))
            acc + 1

          true ->
            acc
        end
      end)

    Mix.shell().info("Synced #{count} podcasts → #{Path.relative_to_cwd(dest)}")
  end

  defp find_first_mp3(dir) do
    dir
    |> File.ls!()
    |> Enum.find(fn n -> String.ends_with?(String.downcase(n), ".mp3") end)
    |> case do
      nil -> nil
      name -> Path.join(dir, name)
    end
  end
end

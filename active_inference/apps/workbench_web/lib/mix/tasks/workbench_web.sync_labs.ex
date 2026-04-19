defmodule Mix.Tasks.WorkbenchWeb.SyncLabs do
  @moduledoc """
  Copies the seven standalone learning-lab HTML files from the repo-root
  `learninglabs/` directory into `apps/workbench_web/priv/static/learninglabs/`
  so the Phoenix endpoint can serve them via `Plug.Static`.

  Idempotent — overwrites on every run. Intended to be called:

    * manually during dev (`mix workbench_web.sync_labs`) after editing a lab,
    * at Docker-build time just before `mix release`, and
    * as part of the release assemble step via `:mix_release`.
  """
  @shortdoc "Copy learninglabs/*.html into workbench_web priv/static/learninglabs/"

  use Mix.Task

  @impl true
  def run(_args) do
    src = Path.expand("../../../../../learninglabs", __DIR__)
    dest = Path.expand("../../../priv/static/learninglabs", __DIR__)

    unless File.dir?(src) do
      Mix.shell().error("learninglabs source not found at #{src}")
      exit({:shutdown, 1})
    end

    File.mkdir_p!(dest)

    html_files =
      src
      |> Path.join("*.html")
      |> Path.wildcard()

    if html_files == [] do
      Mix.shell().error("no *.html files found in #{src}")
      exit({:shutdown, 1})
    end

    for file <- html_files do
      target = Path.join(dest, Path.basename(file))
      File.cp!(file, target)
    end

    Mix.shell().info("Synced #{length(html_files)} labs → #{Path.relative_to_cwd(dest)}")
  end
end

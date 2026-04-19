defmodule WorkbenchWeb.KbPaths do
  @moduledoc """
  Resolves the on-disk paths to the curated Jido knowledgebase and the
  upstream Jido guides, which live **outside** the umbrella (at the repo
  root, alongside `active_inference/`).

  Centralised here so the guide LiveViews don't each re-invent the walk.

  Resolution is lazy and runtime: we probe a small set of candidate
  locations relative to `File.cwd!/0` and `__DIR__`.  The first one
  whose `MASTER-INDEX.md` (for knowledgebase) or directory (for upstream
  guides) actually exists wins.
  """

  @doc "Absolute path to `knowledgebase/jido/`, or a non-existent fallback."
  @spec knowledgebase_dir() :: Path.t()
  def knowledgebase_dir do
    candidates()
    |> Enum.map(&Path.join(&1, "knowledgebase/jido"))
    |> Enum.find(&File.dir?/1)
    |> Kernel.||(Path.expand("../knowledgebase/jido", File.cwd!()))
  end

  @doc "Absolute path to `jido/guides/`, or a non-existent fallback."
  @spec jido_guides_dir() :: Path.t()
  def jido_guides_dir do
    candidates()
    |> Enum.map(&Path.join(&1, "jido/guides"))
    |> Enum.find(&File.dir?/1)
    |> Kernel.||(Path.expand("../jido/guides", File.cwd!()))
  end

  # Candidate repo roots.  `mix phx.server` from the umbrella leaves cwd
  # at `active_inference/`, so `../` is the repo root.  `mix phx.server`
  # from the umbrella app leaves cwd at `active_inference/apps/workbench_web/`.
  defp candidates do
    cwd = File.cwd!()

    [
      Path.expand("..", cwd),
      Path.expand("../..", cwd),
      Path.expand("../../..", cwd),
      Path.expand("../../../..", cwd),
      cwd
    ]
    |> Enum.uniq()
  end
end

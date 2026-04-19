defmodule AgentPlane.MixProject do
  use Mix.Project

  def project do
    [
      app: :agent_plane,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {AgentPlane.Application, []}
    ]
  end

  defp deps do
    [
      {:active_inference_core, in_umbrella: true},
      {:shared_contracts, in_umbrella: true},
      {:world_models, in_umbrella: true},
      # Native JIDO — from the local worktree in this workspace so the
      # workbench is pinned to the exact JIDO code in `../../jido`.
      {:jido, path: "../../../jido"}
      # NOTE: No dependency on :world_plane. The agent plane never imports
      # world-plane types or modules.
    ]
  end
end

defmodule CompositionRuntime.MixProject do
  use Mix.Project

  def project do
    [
      app: :composition_runtime,
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
      mod: {CompositionRuntime.Application, []}
    ]
  end

  defp deps do
    [
      {:agent_plane, in_umbrella: true},
      {:shared_contracts, in_umbrella: true},
      {:world_models, in_umbrella: true},
      # Routing uses Jido.Signal directly; no raw send/2 between agents.
      {:jido, path: "../../../jido"}
    ]
  end
end

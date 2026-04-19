defmodule WorldPlane.MixProject do
  use Mix.Project

  def project do
    [
      app: :world_plane,
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
      mod: {WorldPlane.Application, []}
    ]
  end

  defp deps do
    [
      {:shared_contracts, in_umbrella: true}
      # NOTE: NO dependency on :agent_plane or :active_inference_core.
      # The world plane is the generative process. It must be ignorant of
      # the agent's internals.
    ]
  end
end

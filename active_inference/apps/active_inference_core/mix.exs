defmodule ActiveInferenceCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :active_inference_core,
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
      # Plan §8.4 — declare :telemetry so the dep is resolved at the app
      # boundary (avoids "undefined" compile-time warnings when this app
      # is compiled standalone).
      extra_applications: [:logger, :telemetry]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      # Plan §8.4 — per-equation `:telemetry.span/3` in DiscreteTime.
      {:telemetry, "~> 1.2"}
    ]
  end
end

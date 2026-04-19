defmodule WorkbenchWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :workbench_web,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger, :runtime_tools, :inets, :ssl],
      mod: {WorkbenchWeb.Application, []}
    ]
  end

  defp deps do
    [
      {:active_inference_core, in_umbrella: true},
      {:shared_contracts, in_umbrella: true},
      {:world_models, in_umbrella: true},
      {:world_plane, in_umbrella: true},
      {:agent_plane, in_umbrella: true},
      # Phoenix stack — pinned to versions compatible with Elixir 1.17+ / OTP 26+.
      {:phoenix, "~> 1.7.14"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_view, "~> 0.20.17"},
      {:phoenix_pubsub, "~> 2.1"},
      {:bandit, "~> 1.5"},
      {:jason, "~> 1.4"},
      {:plug_cowboy, "~> 2.7", only: [:dev, :test]},
      # Plan §12 Phase 6 — LiveView DOM assertions in Phoenix.LiveViewTest.
      {:floki, ">= 0.30.0", only: :test}
    ]
  end
end

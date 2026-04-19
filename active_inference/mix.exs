defmodule ActiveInferenceWorkbench.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      elixirc_options: [warnings_as_errors: false],
      name: "ORCWorkbench",
      source_url: "https://github.com/TMDLRG/ORCWorkbench",
      homepage_url: "https://github.com/TMDLRG/ORCWorkbench",
      docs: docs(),
      releases: releases()
    ]
  end

  defp releases do
    [
      orcworkbench: [
        include_executables_for: [:unix],
        applications: [
          active_inference_core: :permanent,
          shared_contracts: :permanent,
          world_plane: :permanent,
          agent_plane: :permanent,
          world_models: :permanent,
          composition_runtime: :permanent,
          workbench_web: :permanent,
          runtime_tools: :permanent,
          mnesia: :permanent
        ]
      ]
    ]
  end

  # Plan §16 — ensure `mix quality` / `mix q` run under MIX_ENV=test without
  # the caller needing to set it.
  def cli do
    [preferred_envs: [quality: :test, q: :test]]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "../README.md",
        "../ARCHITECTURE.md",
        "../CONTRIBUTING.md",
        "../CLAUDE.md",
        "README.md",
        "DELIVERABLE.md",
        "docs/decisions/canvas-library.md"
      ],
      groups_for_extras: [
        Project: ["../README.md", "../ARCHITECTURE.md", "../CONTRIBUTING.md", "../CLAUDE.md"],
        Umbrella: ["README.md", "DELIVERABLE.md"],
        Decisions: ["docs/decisions/canvas-library.md"]
      ],
      groups_for_modules: [
        "Core (math & registries)": [~r/^ActiveInferenceCore/],
        "Shared Contracts (blanket)": [~r/^SharedContracts/],
        "Agent Plane": [~r/^AgentPlane/],
        "World Plane": [~r/^WorldPlane/],
        "World Models (events, specs)": [~r/^WorldModels/],
        "Composition Runtime": [~r/^CompositionRuntime/],
        "Workbench Web (UI)": [~r/^WorkbenchWeb/]
      ]
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "cmd mix setup"],
      test: ["test"],
      # Plan §16 — umbrella quality gate.
      # Phase 9 ships this pipeline; a later phase may add credo + dialyzer.
      # `test --warnings-as-errors` compiles in :test env with the flag, so
      # we don't need a separate `compile` step (which would run in the
      # caller's env and cause env mismatches).
      quality: [
        "format --check-formatted",
        "test --warnings-as-errors"
      ],
      q: ["quality"]
    ]
  end
end

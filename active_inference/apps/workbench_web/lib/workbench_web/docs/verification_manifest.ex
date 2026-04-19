defmodule WorkbenchWeb.Docs.VerificationManifest do
  @moduledoc """
  Declarative verification-status manifest for code areas not covered by
  `ActiveInferenceCore.Equation.verification_status`.

  Status vocabulary (shared with the equation registry):

    * `:verified`   — backed by at least one passing test that exercises
                      the contract end-to-end.
    * `:scaffolded` — code exists and compiles; no end-to-end test yet.
    * `:uncertain`  — known gap or open question.

  Keep this manifest honest. If something moves from `:scaffolded` to
  `:verified`, update here.
  """

  @type entry :: %{
          id: String.t(),
          area: String.t(),
          status: :verified | :scaffolded | :uncertain,
          evidence: String.t(),
          notes: String.t()
        }

  @entries [
    %{
      id: "plane-separation",
      area: "world_plane ↛ agent_plane ↛ world_plane dependency enforcement",
      status: :verified,
      evidence: "apps/{world_plane,agent_plane}/test/plane_separation_test.exs",
      notes: "Compile-time introspection proves neither app imports the other."
    },
    %{
      id: "discrete-pomdp-math",
      area: "Discrete-time POMDP math (eq. 4.10, 4.11, 4.13, 4.14, B.5, B.9, B.29, B.30)",
      status: :verified,
      evidence:
        "apps/active_inference_core/test/discrete_time_test.exs + mvp_maze / mvp_golden tests",
      notes: "Covered end-to-end: maze agent reaches goal on tiny_open_goal."
    },
    %{
      id: "telemetry-to-event-log",
      area: "Telemetry → Event log round-trip",
      status: :verified,
      evidence: "apps/workbench_web/test/integration/equation_telemetry_test.exs",
      notes: "equation.evaluated events resolve to registry entries."
    },
    %{
      id: "mnesia-durability",
      area: "Event log survives Mnesia restart (BEAM-restart proxy)",
      status: :verified,
      evidence: "scripts/phase8_observe.exs + apps/world_models/test/event_log_test.exs",
      notes: "Disc copies; schema bootstrapped by WorldModels.EventLog.Setup."
    },
    %{
      id: "jido-native-integration",
      area: "Native Jido.Agent + Jido.AgentServer integration",
      status: :verified,
      evidence:
        "apps/agent_plane/test/jido_native_test.exs + integration/mvp_maze_supervised_test.exs",
      notes: "Agents run as real Jido.AgentServer, not struct-based shims."
    },
    %{
      id: "spec-content-addressing",
      area: "WorldModels.Spec BLAKE2b content addressing",
      status: :verified,
      evidence: "apps/world_models/test/agent_registry_test.exs",
      notes: "canonical_form + provenance_hash round-trip; Spec.new/1 idempotent."
    },
    %{
      id: "sophisticated-planner",
      area: "Sophisticated planner (Ch 7 deep-horizon rollout)",
      status: :scaffolded,
      evidence:
        "apps/agent_plane/lib/agent_plane/actions/sophisticated_plan.ex; used by L3 example",
      notes: "Compiles and runs; no dedicated test for deep-horizon correctness yet."
    },
    %{
      id: "dirichlet-learning",
      area: "Dirichlet A / B updates (eq. 7.10, B.10–B.12)",
      status: :scaffolded,
      evidence: "apps/agent_plane/lib/agent_plane/actions/dirichlet_update_{a,b}.ex; used by L4",
      notes: "Integration wired; long-horizon convergence not yet verified."
    },
    %{
      id: "continuous-time-generalised-filtering",
      area: "Continuous-time generalised filtering (eq. 8.1, 8.2, B.42, B.47, B.48)",
      status: :scaffolded,
      evidence: "Registered in ActiveInferenceCore.Equations",
      notes: "Registry + runtime hooks exist; no discrete-time implementation yet."
    },
    %{
      id: "hybrid-models",
      area: "Hybrid continuous/discrete models",
      status: :scaffolded,
      evidence: "Registered in ActiveInferenceCore.Models",
      notes: "Taxonomy entry; no runtime implementation."
    },
    %{
      id: "hierarchical-composition",
      area: "L5 hierarchical composition (multi-agent via CompositionRuntime)",
      status: :scaffolded,
      evidence: "apps/composition_runtime/test/composition_runtime_test.exs (smoke)",
      notes: "Signal broker routes; multi-agent orchestration patterns not fully exercised."
    },
    %{
      id: "docstring-coverage",
      area: "Full @doc/@spec coverage on every public function",
      status: :scaffolded,
      evidence: "ExDoc output at doc/; WorkbenchWeb.Docs.ApiCatalog enumerates",
      notes:
        "Backfilled incrementally during the documentation pass; see " <>
          "apps/workbench_web/test/docs/api_catalog_test.exs (planned) for CI enforcement."
    }
  ]

  @doc "Every entry in the manifest."
  @spec all() :: [entry()]
  def all, do: @entries

  @doc "Entries with `:status == status`."
  @spec by_status(:verified | :scaffolded | :uncertain) :: [entry()]
  def by_status(status), do: Enum.filter(@entries, &(&1.status == status))

  @doc "Rollup counts per status."
  @spec counts() :: %{
          verified: non_neg_integer(),
          scaffolded: non_neg_integer(),
          uncertain: non_neg_integer()
        }
  def counts do
    Enum.reduce(@entries, %{verified: 0, scaffolded: 0, uncertain: 0}, fn %{status: s}, acc ->
      Map.update!(acc, s, &(&1 + 1))
    end)
  end
end

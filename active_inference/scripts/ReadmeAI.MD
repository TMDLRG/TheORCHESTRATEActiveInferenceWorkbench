# active_inference/scripts/ — ReadmeAI

## Purpose

Phase-by-phase **runtime observation scripts**. Each script boots the full supervision tree (or as much of it as the phase requires), drives an end-to-end scenario, and prints a class-A observability report — used during development to prove that a phase's invariants hold outside the test suite.

These are not end-user tools. They complement `mix test` by exercising things the test environment deliberately suppresses (e.g. Mnesia auto-start is off in `test.exs:11`, so scripts run under `MIX_ENV=dev`).

## Contents

All scripts are standalone `.exs` files. Invoke from the umbrella root with `mix run scripts/phaseN_observe.exs` (default `MIX_ENV=dev`). Each starts with a ~200–300 ms `Process.sleep/1` so the supervision tree can finish booting before the script begins.

| Script | Phase (from project plan) | What it demonstrates | File |
|---|---|---|---|
| [`phase2_observe.exs`](phase2_observe.exs) | Phase 2 | One episode end-to-end in dev; Mnesia durability inspection | [phase2_observe.exs:1-3](phase2_observe.exs) |
| [`phase3_observe.exs`](phase3_observe.exs) | Phase 3 | Supervised Jido.AgentServer through `tiny_open_goal`; reports episode + JIDO runtime telemetry | [phase3_observe.exs:1-6](phase3_observe.exs) |
| [`phase4_observe.exs`](phase4_observe.exs) | Phase 4 | `equation.evaluated` events per `DiscreteTime` function; every event resolves to registry; Glass can walk equation → family → bundle → spec → agent | [phase4_observe.exs:1-9](phase4_observe.exs) |
| [`phase5_observe.exs`](phase5_observe.exs) | Phase 5 | Spec registration round-trip: `spec_id → fetch_spec / live_for_spec`; `agent_id → fetch_live`; event `provenance.spec_id` back to builder spec | [phase5_observe.exs:1-10](phase5_observe.exs) |
| [`phase6_observe.exs`](phase6_observe.exs) | Phase 6 | Boots in-process Episode the way `/world` does; curls `/glass/agent/:id` against running endpoint to prove handoff observable without UI | [phase6_observe.exs:1-7](phase6_observe.exs) |
| [`phase6_timing.exs`](phase6_timing.exs) | Phase 6 | Timing variant of phase 6 (no header comment); used to measure end-to-end latency | [phase6_timing.exs](phase6_timing.exs) |
| [`phase7_observe.exs`](phase7_observe.exs) | Phase 7 | Full Builder round-trip: seed archetype → validate → save → instantiate → verify live agent in `AgentRegistry` + Glass-accessible | [phase7_observe.exs:1-7](phase7_observe.exs) |
| [`phase8_observe.exs`](phase8_observe.exs) | Phase 8 | Registers Spec, runs supervised Episode; verifies Glass routes populated AND state/spec survive Mnesia restart (BEAM-restart proxy) | [phase8_observe.exs:1-7](phase8_observe.exs) |
| [`phase9_uat_observe.exs`](phase9_uat_observe.exs) | Phase 9 (UAT) | Final user-acceptance observation: seeds complete spec, runs Episode, reports each of 6 UATs with class-A observed evidence | [phase9_uat_observe.exs:1-7](phase9_uat_observe.exs) |

## Public API surface

None — scripts are executables, not libraries.

## Data types & schemas

None beyond what they alias from the apps (`AgentPlane.BundleBuilder`, `SharedContracts.Blanket`, `WorkbenchWeb.Episode`, `WorldModels.{AgentRegistry, Archetypes, Bus, EventLog, Spec}`, `WorldPlane.Worlds`).

## Constants & config keys

None emitted. Scripts depend on `:mnesia, :dir = ~c"priv/mnesia/dev"` (set by [`../config/dev.exs:14`](../config/dev.exs)) and the default `:world_models, :auto_start_event_log` (true in dev).

## Telemetry / signals / events emitted here

None directly. Scripts observe events emitted by the running system (equation.evaluated, runtime.jido.* — see [`../apps/agent_plane/lib/agent_plane/telemetry/bus.ex`](../apps/agent_plane/lib/agent_plane/telemetry/bus.ex)).

## Dependencies

- **Inbound**: manual invocation via `mix run scripts/<name>.exs`.
- **Outbound**:
  - [`../apps/agent_plane/`](../apps/agent_plane/)
  - [`../apps/shared_contracts/`](../apps/shared_contracts/)
  - [`../apps/workbench_web/`](../apps/workbench_web/) (for `Episode`)
  - [`../apps/world_models/`](../apps/world_models/) (`AgentRegistry`, `EventLog`, `Bus`, `Spec`, `Archetypes`)
  - [`../apps/world_plane/`](../apps/world_plane/) (`Worlds`)
  - [`../apps/active_inference_core/`](../apps/active_inference_core/) (`Equations`, `Models`) — phase 9 only

## Verification status

- `:verified` — each script was used to validate the corresponding phase. They are regression tools; if a script fails after a change, it signals a behaviour regression worth investigating.
- `:uncertain` — scripts rely on `Process.sleep/1` (200–300ms) at start; see [`../CONTRIBUTING.md`](../../CONTRIBUTING.md). This is acceptable here because scripts are bootstrap tools, not tests. Do **not** copy this pattern into `test/`.

## Related

- Test suite: [`../apps/*/test/`](../apps/)
- Runtime config: [`../config/ReadmeAI.MD`](../config/ReadmeAI.MD)
- Event log setup: [`../apps/world_models/lib/world_models/event_log/setup.ex`](../apps/world_models/lib/world_models/event_log/setup.ex)

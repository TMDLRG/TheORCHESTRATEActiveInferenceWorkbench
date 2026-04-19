# apps/agent_plane/ — ReadmeAI

## Purpose

The **generative model**. Hosts the native Jido agent, the POMDP generative-model bundle, the six Jido actions (Perceive / Plan / Act / Step / DirichletUpdate{A,B} / SophisticatedPlan), and the telemetry bus that forwards Jido events into `WorldModels`. **Does not depend on `world_plane`** — the agent only sees `SharedContracts` packets.

## Contents

| Path | Role |
|---|---|
| [`lib/agent_plane.ex`](lib/agent_plane.ex) | Root; `build_maze_bundle/1`, `start_agent/1` |
| [`lib/agent_plane/application.ex`](lib/agent_plane/application.ex) | OTP Application (supervises `JidoInstance`, `Telemetry`) |
| [`lib/agent_plane/active_inference_agent.ex`](lib/agent_plane/active_inference_agent.ex) | `use Jido.Agent`; `fresh/4` |
| [`lib/agent_plane/runtime.ex`](lib/agent_plane/runtime.ex) | High-level lifecycle (`start_agent`, `perceive`, `plan`, `act`, `step`, `state`, `stop`) |
| [`lib/agent_plane/bundle_builder.ex`](lib/agent_plane/bundle_builder.ex) | POMDP bundle builder (`for_maze/1`, `enumerate_policies/2`) |
| [`lib/agent_plane/jido_instance.ex`](lib/agent_plane/jido_instance.ex) | `use Jido` instance + supervisor for `Jido.AgentServer` |
| [`lib/agent_plane/obs_adapter.ex`](lib/agent_plane/obs_adapter.ex) | ObservationPacket → 64-way categorical index |
| [`lib/agent_plane/equation_map.ex`](lib/agent_plane/equation_map.ex) | `{fn, arity}` → equation IDs for provenance |
| [`lib/agent_plane/actions/`](lib/agent_plane/actions/) | 7 Jido actions — [subtree README](lib/agent_plane/actions/ReadmeAI.MD) |
| [`lib/agent_plane/skills/`](lib/agent_plane/skills/) | Reusable math skills (softmax, KL, free-energy) — [subtree README](lib/agent_plane/skills/ReadmeAI.MD) |
| [`lib/agent_plane/telemetry/`](lib/agent_plane/telemetry/) | Telemetry Bus + Context — [subtree README](lib/agent_plane/telemetry/ReadmeAI.MD) |
| [`test/`](test/) | 5 tests — [`test/ReadmeAI.MD`](test/ReadmeAI.MD) |

## Public API surface (high-traffic)

| Module | Function | Arity | Purpose |
|---|---|---|---|
| `AgentPlane` | `build_maze_bundle/1` | 1 | Delegates to `BundleBuilder.for_maze/1` |
| `AgentPlane` | `start_agent/1` | 1 | Delegates to `Runtime.start_agent/1` |
| `AgentPlane.Runtime` | `start_agent/1` | 1 | Boot supervised `Jido.AgentServer` |
| `AgentPlane.Runtime` | `stop_agent/1` | 1 | Stop server |
| `AgentPlane.Runtime` | `state/1` | 1 | Read agent state snapshot |
| `AgentPlane.Runtime` | `perceive/2` | 2 | Run `Actions.Perceive` via `Jido.cmd` |
| `AgentPlane.Runtime` | `plan/1` | 1 | Run `Actions.Plan` |
| `AgentPlane.Runtime` | `act/2` | 2 | Run `Actions.Act` |
| `AgentPlane.Runtime` | `step/3` | 3 | Perceive → Plan → Act in one call |
| `AgentPlane.ActiveInferenceAgent` | `fresh/4` | 4 | New agent struct with uniform beliefs |
| `AgentPlane.BundleBuilder` | `for_maze/1` | 1 | Build POMDP bundle from maze spec |
| `AgentPlane.BundleBuilder` | `enumerate_policies/2` | 2 | All action sequences of given depth |
| `AgentPlane.ObsAdapter` | `n_obs/0` | 0 | `64` — 4-bit walls × 2-bit goal × 2-bit hit |
| `AgentPlane.ObsAdapter` | `to_obs_vector/1` | 1 | 64-long one-hot |
| `AgentPlane.ObsAdapter` | `obs_index/3` | 3 | Pack channels → integer index |
| `AgentPlane.EquationMap` | `lookup/3` | 3 | `{fn, arity} → [equation_id]` |
| `AgentPlane.EquationMap` | `all/0` | 0 | Full map |

Jido actions under [`lib/agent_plane/actions/`](lib/agent_plane/actions/) each expose `run/2` per the `Jido.Action` contract. See [actions/ReadmeAI.MD](lib/agent_plane/actions/ReadmeAI.MD).

## Data types & schemas

| Type | File:Line | Fields |
|---|---|---|
| `ActiveInferenceAgent.State` | [active_inference_agent.ex:44-69](lib/agent_plane/active_inference_agent.ex) | `:agent_id`, `:bundle`, `:blanket`, `:beliefs`, `:obs_history`, `:t`, `:policy_posterior`, `:last_action`, `:last_policy_best_idx`, `:last_f`, `:last_g`, `:marginal_state_belief`, `:best_policy_chain`, `:goal_idx`, `:telemetry`, `:spec_id`, `:bundle_id`, `:family_id`, `:primary_equation_ids`, `:verification_status` |
| Bundle (map) | [bundle_builder.ex:35-44](lib/agent_plane/bundle_builder.ex) | `:a`, `:b`, `:c`, `:d`, `:e`, `:actions`, `:policies`, `:horizon`, `:spec_id`, `:bundle_id`, `:family_id` |

## Constants & config keys

| Constant | Value | File:Line |
|---|---|---|
| `@pomdp_family_name` | `"Partially Observable Markov Decision Process (POMDP)"` | [bundle_builder.ex:26](lib/agent_plane/bundle_builder.ex) |
| `@n_obs` | `64` | [obs_adapter.ex](lib/agent_plane/obs_adapter.ex) |
| `@handler_id` | `AgentPlane.Telemetry.Bus` | [telemetry/bus.ex:17](lib/agent_plane/telemetry/bus.ex) |
| `@events` | 11 event names | [telemetry/bus.ex:20-32](lib/agent_plane/telemetry/bus.ex) |

Runtime config: `:agent_plane, AgentPlane.JidoInstance, :max_tasks` (default `1000`, set in [`../../config/config.exs:3`](../../config/config.exs)).

## Telemetry / signals / events emitted here

| Event | Re-emitted as (`WorldModels.Event.type`) | Emitter |
|---|---|---|
| `[:active_inference_core, :discrete_time, :call, :stop]` | `"equation.evaluated"` | `AgentPlane.Telemetry.Bus` [bus.ex:18](lib/agent_plane/telemetry/bus.ex) |
| `[:jido, :agent_server, :signal, :start\|:stop\|:exception]` | `"runtime.jido.agent_server.signal.*"` | ibid |
| `[:jido, :agent_server, :directive, :start\|:stop\|:exception]` | `"runtime.jido.agent_server.directive.*"` | ibid |
| `[:jido, :agent, :cmd, :start\|:stop\|:exception]` | `"runtime.jido.agent.cmd.*"` | ibid |

Jido signals emitted by `Actions.Act`: type `"active_inference.action"` (carries `ActionPacket` + F, G, policy posterior).

Directives used: `Jido.Agent.Directive.Emit`.

## Dependencies

- **Inbound**: [`../composition_runtime/`](../composition_runtime/), [`../workbench_web/`](../workbench_web/), [`../../scripts/`](../../scripts/).
- **Outbound (Hex)**: `:jido` (path: `../../../jido`; git submodule).
- **Outbound (umbrella)**: `:active_inference_core`, `:shared_contracts`, `:world_models`.

## Verification status

- `:verified` — 5 tests pass (native Jido integration, plane separation, corridor convergence, provenance, runtime).
- `:verified` — `cmd/2` purity guaranteed by framework and tested by JidoTest.
- `:scaffolded` — `Actions.DirichletUpdateA`, `Actions.DirichletUpdateB`, `Actions.SophisticatedPlan` compile and are wired but lack dedicated end-to-end tests; referenced by example L3–L4.

## Related

- Book math: [`../active_inference_core/ReadmeAI.MD`](../active_inference_core/ReadmeAI.MD)
- Blanket types: [`../shared_contracts/ReadmeAI.MD`](../shared_contracts/ReadmeAI.MD)
- Orchestrator: [`../workbench_web/lib/workbench_web/episode.ex`](../workbench_web/lib/workbench_web/episode.ex)
- Jido framework: [`../../knowledgebase/jido/MASTER-INDEX.md`](../../../knowledgebase/jido/MASTER-INDEX.md)

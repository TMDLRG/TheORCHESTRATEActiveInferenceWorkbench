# agent_plane/lib/ — ReadmeAI

## Purpose

Source tree for the generative model (the Jido agent, its actions, skills, telemetry bus).

## Contents

| File | Module | Purpose |
|---|---|---|
| [`agent_plane.ex`](agent_plane.ex) | `AgentPlane` | Root |
| [`agent_plane/application.ex`](agent_plane/application.ex) | `AgentPlane.Application` | OTP app supervising `JidoInstance` + `Telemetry` |
| [`agent_plane/active_inference_agent.ex`](agent_plane/active_inference_agent.ex) | `AgentPlane.ActiveInferenceAgent` | `use Jido.Agent` |
| [`agent_plane/runtime.ex`](agent_plane/runtime.ex) | `AgentPlane.Runtime` | Lifecycle + cmd/signal interface |
| [`agent_plane/jido_instance.ex`](agent_plane/jido_instance.ex) | `AgentPlane.JidoInstance` | `use Jido` + AgentServer supervisor |
| [`agent_plane/bundle_builder.ex`](agent_plane/bundle_builder.ex) | `AgentPlane.BundleBuilder` | POMDP bundle from maze spec |
| [`agent_plane/obs_adapter.ex`](agent_plane/obs_adapter.ex) | `AgentPlane.ObsAdapter` | ObservationPacket → 64-way index |
| [`agent_plane/equation_map.ex`](agent_plane/equation_map.ex) | `AgentPlane.EquationMap` | `{fn, arity} → [equation_id]` |

### Subtrees

| Subtree | Modules | README |
|---|---|---|
| [`agent_plane/actions/`](agent_plane/actions/) | 7 Jido actions (Perceive / Plan / Act / Step / DirichletUpdate{A,B} / SophisticatedPlan) | [subtree README](agent_plane/actions/ReadmeAI.MD) |
| [`agent_plane/skills/`](agent_plane/skills/) | Reusable math skills (softmax, KL, free-energies) | [subtree README](agent_plane/skills/ReadmeAI.MD) |
| [`agent_plane/telemetry/`](agent_plane/telemetry/) | Bus + Context | [subtree README](agent_plane/telemetry/ReadmeAI.MD) |

See [`../ReadmeAI.MD`](../ReadmeAI.MD) for the consolidated public API table + telemetry taxonomy.

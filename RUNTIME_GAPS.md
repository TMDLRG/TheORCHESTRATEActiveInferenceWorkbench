# Runtime Gaps — Cookbook Coverage Map

**Ticket G1.** Source-of-truth inventory of the current Active Inference runtime against the 50-recipe cookbook planned in D7/D8/D9. Every recipe must be **runnable end-to-end on real native Jido** (no scaffold banners, no disabled buttons). This document pins what exists, what each wave needs, and which G-ticket closes each gap before the recipe ships.

---

## Current runtime inventory (authoritative)

### Agent actions — [agent_plane/lib/agent_plane/actions/](active_inference/apps/agent_plane/lib/agent_plane/actions/)

| Action module | Purpose | Book ref |
|---|---|---|
| `AgentPlane.Actions.Perceive` | Update belief q(s) from an observation | Eq 4.13 |
| `AgentPlane.Actions.Plan` | Compute policy posterior q(π) from EFE | Eq 4.14 / B.9 |
| `AgentPlane.Actions.Act` | Emit ActionPacket drawn from q(π) | — |
| `AgentPlane.Actions.Step` | Full perceive → plan → act loop | — |
| `AgentPlane.Actions.SophisticatedPlan` | Tree-search planning with nested EFE | B.22+ |
| `AgentPlane.Actions.DirichletUpdateA` | Count-based update of observation model A | 7.10 |
| `AgentPlane.Actions.DirichletUpdateB` | Count-based update of transition model B | 7.10 |

### Agent skills — [agent_plane/lib/agent_plane/skills/](active_inference/apps/agent_plane/lib/agent_plane/skills/)

| Skill module | Returns | Book ref |
|---|---|---|
| `AgentPlane.Skills.ShannonEntropy` | H(q) | B.3 |
| `AgentPlane.Skills.KlDivergence` | KL(q‖p) | B.4 |
| `AgentPlane.Skills.Softmax` | σ(−G/temperature) | B.9 |
| `AgentPlane.Skills.ExpectedFreeEnergy` | G(π) = epistemic + pragmatic | 4.10 / B.9 |
| `AgentPlane.Skills.VariationalFreeEnergy` | F(q) = complexity − accuracy | 4.11 / B.5 |

### Agent entry points

- `AgentPlane.ActiveInferenceAgent` — the `Jido.Agent` itself.
- `AgentPlane.BundleBuilder.for_maze/1` — materialises a generative model (A, B, C, D, horizon, policy_depth, preference_strength) from a maze spec.
- `AgentPlane.Runtime` — supervised boot of agent instances.
- `AgentPlane.EquationMap` — signal → equation provenance registry for the Glass Engine.

### Worlds — [world_plane/lib/world_plane/worlds.ex](active_inference/apps/world_plane/lib/world_plane/worlds.ex)

Five mazes registered via `WorldPlane.Worlds.all/0`:

1. `:tiny_open_goal` — 3×3, one-step, sanity check.
2. `:corridor_turns` — narrow path with 90° turns.
3. `:forked_paths` — branching, epistemic-win demo.
4. `:deceptive_dead_end` — trap path; plan-depth matters.
5. `:hierarchical_maze` — larger layout; exercises longer horizons.

Engine: `WorldPlane.Engine` (generative process, collisions, terminal). Encoder: `WorldPlane.ObservationEncoder`.

---

## Wave → runtime coverage map

### Wave 1 — 10 MVP recipes (D7)

All runnable on the current runtime. No G dependencies.

| Theme | Count | Actions/Skills/World |
|---|---|---|
| Bayes — single-step, sequential, odds-form | 3 | Perceive + Softmax skill; `tiny_open_goal` as a stub world or no-world (pure belief updates) |
| POMDP — full-trajectory, epistemic win, plan-depth | 3 | Perceive/Plan/Act; mazes `tiny_open_goal`, `forked_paths`, `deceptive_dead_end` |
| Free Energy — VFE decomposition, EFE decomposition | 2 | VariationalFreeEnergy + ExpectedFreeEnergy skills; no world (compute on fixed q, p) |
| Planning-as-Inference — softmax temperature, horizon depth | 2 | Plan + Softmax + BundleBuilder; `forked_paths` |

**Gaps for Wave 1:** none.

### Wave 2 — 20 recipes (D8)

| Theme | Count | Actions/Skills/World | Gap |
|---|---|---|---|
| Perception | 5 | Perceive + ShannonEntropy + KlDivergence | none |
| Epistemic (info-gain) | 5 | Plan with EFE dominance on epistemic term; `forked_paths`, `corridor_turns` | none |
| Preference/Pragmatic (C-vector engineering) | 5 | Plan with EFE dominance on pragmatic term; `BundleBuilder` with `C_preference_override` | **G6** (`C_preference_override` option on BundleBuilder) |
| Multi-modal (Jumping Frog patterns) | 5 | Perceive with two channels; new world fixture | **G2** (2-channel non-maze world: `:frog_pond`) |

**Gaps for Wave 2:** G2 (+1 world), G6 (BundleBuilder option). Small.

### Wave 3 — 20 recipes (D9)

| Theme | Count | Actions/Skills/World | Gap |
|---|---|---|---|
| Dirichlet Learning | 5 | DirichletUpdateA/B; BundleBuilder `learning_enabled: true` | **G6** (learning flag) |
| Sophisticated Planning | 5 | SophisticatedPlan; `deceptive_dead_end`, `hierarchical_maze` | none |
| Predictive Coding (Laplace Tower recipes) | 5 | New action `PredictiveCodingPass` over a 2-level hierarchy | **G3** |
| Continuous-Time (generalized coords) | 3 | New skill `GeneralizedFilter` + action `ContinuousStep`; new world `:sinusoid_tracker` | **G4** (+ G2 for the world) |
| Hierarchical composition | 2 | New agent variant `AIA.Hierarchical` (2 stacked `ActiveInferenceAgent`s via `Jido.Signal`) | **G5** (+ uses existing `:hierarchical_maze`) |

---

## G-ticket ownership

| Ticket | Closes |
|---|---|
| **G1** *(this doc)* | — |
| **G2** | 2 new worlds: `:frog_pond` (2-channel non-maze), `:sinusoid_tracker` (continuous-time fixture). |
| **G3** | `AgentPlane.Actions.PredictiveCodingPass` — pure action that runs 2-level top-down prediction + bottom-up error over the existing VFE skill. Unit test on a 2-level fixture. |
| **G4** | `AgentPlane.Skills.GeneralizedFilter` + `AgentPlane.Actions.ContinuousStep`. Narrow scope: 1 hidden state, 1 sensor, 2 orders of motion. Unit test reproduces eq 8.1 dynamics on `:sinusoid_tracker`. |
| **G5** | `AgentPlane.ActiveInferenceAgent.Hierarchical` supervised pod (see `knowledgebase/jido/11-pods.md`). 2-level test shows upper-level context changing lower-level A matrix. |
| **G6** | `BundleBuilder` options: `precision_vector`, `C_preference_override`, `learning_enabled`. Each Zoi-schema'd and consumed by existing actions. |
| **G7** | Topology-registry entries for every new block so `/builder` palette surfaces them. |
| **G8** | `/labs` accepts `?recipe=<slug>` — hydrates spec + world from `Cookbook.Loader` and boots an episode without the builder detour. |

Every recipe in `priv/cookbook/*.yaml` must declare `runtime.actions_used` and `runtime.skills_used` that resolve against the live modules. `mix cookbook.validate` (ticket D1) fails the build if any referenced module does not exist yet. This is the tripwire that guarantees "everything runs on real native Jido."

---

## Execution order

1. **G2** ships early (two world fixtures; unblocks Wave-2 and Wave-3 continuous recipes).
2. **G6** ships alongside G2 (needed by Wave-2 preference recipes).
3. **D1 / D2 / D3 / D4 / D5 / D6 / D7** ship once G2 + G6 land — Wave 1 needs nothing extra.
4. **D8** ships after G2 + G6.
5. **G3** ships before D9 predictive-coding recipes.
6. **G4** ships before D9 continuous-time recipes.
7. **G5** ships before D9 hierarchical recipes.
8. **G7 / G8** ship any time after G2–G6 are in.

The validator in D1 is the gate — no recipe ships with unresolved runtime references.

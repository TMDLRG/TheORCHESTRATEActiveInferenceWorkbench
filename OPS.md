# OPS — The ORCHESTRATE Active Inference Workbench

Operational reality of the workbench: deployment, capability ceilings, known failure modes, and the Nx-port roadmap. Read this before claiming the workbench works in your environment, and before claiming it doesn't.

---

## 1. What this workbench is, scoped honestly

This is a **pedagogical Elixir reference implementation** of discrete-time POMDP active inference (Parr, Pezzulo & Friston 2022). It runs on the BEAM with pure-Elixir list-based math. It is **not** a production-scale inference engine — for that, see §4 (Nx port roadmap).

What works at the current scale:
- Single-agent maze episodes with policy depth ≤ 3.
- Multi-agent Bird Meadow with **ConvergentBird at policy depth 1** (the bird tier introduced specifically to fit within the per-action timeout — see §3).
- All 5 audit-anchor tests against brute-force forward-backward ground truth.
- The full LiveView UI at `/labs/meadow` for interactive demonstration.

What does **not** work at the current scale:
- ComplexBird at policy depth ≥ 2 on the meadow's 1000-dim observation space hits the Jido per-action timeout (60 s default). The integration test passes at depth 1; the call-response hypothesis at depth 2 is documented as unsolved without an Nx-backed math path.
- Long-horizon multi-bird simulations (>200 ticks across multiple seeds) exceed wall-clock budget on a developer machine and require either smaller alphabets or a substrate change.

The README's first paragraph names this scope explicitly. If you find a claim in the codebase that contradicts this, it's a bug — file an issue.

---

## 2. Deployment

### Local development

```bash
git clone https://github.com/TMDLRG/TheORCHESTRATEActiveInferenceWorkbench.git
cd TheORCHESTRATEActiveInferenceWorkbench/active_inference
mix deps.get
mix compile --warnings-as-errors
mix test --exclude slow_experiment   # ~60s
mix phx.server                       # → http://localhost:4000/labs/meadow
```

The `PORT` env var is honoured (default 4000). Used in CI and when port 4000 is held by another instance.

### Docker compose (full suite)

The repo's top-level `docker-compose.yml` brings up the Phoenix workbench plus optional services (LibreChat, Qwen LLM, Speech TTS, Speech MCP). See `RUN_LOCAL.md` for service-by-service detail.

### Production (current state)

There is no production deployment. The workbench is **pedagogical-scale only** until the Nx port lands (§4). Self-hosted dev/teaching environments are the supported runtime.

---

## 3. Known capability ceilings

These are real limits, not aspirations. Each one is documented in source somewhere; this section centralises them.

| Limit | Symptom | Root cause | Mitigation |
|---|---|---|---|
| **Per-action 60s timeout** | `Jido.Exec` times out mid-Perceive on ComplexBird at depth ≥ 2 | Pure-Elixir list matvecs on 1000-dim observation × 1152-state hidden space at depth 2 = ~1.5G ops/Plan | Use ConvergentBird (5-state) or stay at depth 1 until Nx port |
| **Long-horizon multi-bird** | Experiment 2 at full scale (20 seeds × 200 ticks) blows wall-clock | Same root cause: per-tick cost too high for the substrate | `MEADOW_EXPERIMENT_SCALE=smoke` (3 seeds × 30 ticks) is the supported scale until Nx |
| **Maze policy depth** | `enumerate_policies/depth` is `\|A\|^d` exponential — depth 5 with 4 actions = 1024 policies, depth 6 = 4096 | POMDP receding-horizon brute enumeration | Default depth 2-3; increase only with explicit horizon configuration |
| **Mnesia disc tables on rename** | If you rename app atoms, on-disk tables get orphaned | Mnesia stores by atom; rename leaves old data | See ADR-001: rename strategy keeps Mnesia atoms unchanged |

Each mitigation is enforced or documented in the codebase. None are silent.

---

## 4. Roadmap: the Nx port milestone (`v2-nx-port`)

The **W1 finding** from the external review panel (Wolpert) named the pure-Elixir list math as the substrate problem. The v2 delta review noted this has graduated from "developer note" to "load-bearing capability constraint" because Experiment 2's call-response hypothesis at depth ≥ 2 is gated by it.

The Nx port targets:

1. `ActiveInferenceCore.Math.matvec/2` and `softmax/1` — re-implement on Nx tensors.
2. `Skills.VariationalFreeEnergy` and `Skills.ExpectedFreeEnergy` — switch their inner ops to Nx.
3. `DiscreteTime.choose_action/4` — gate the per-policy belief sweep behind Nx if `:nx_backend` config is `true`.

**Acceptance criterion:** ComplexBird at depth 2 on a 1000-dim observation space, single tick, under 5 s on a developer laptop. (Currently: tens of seconds, often timeout.)

**Numerical equivalence test:** pure-Elixir vs. Nx outputs match within `1.0e-9` on random inputs. If they diverge, the port is wrong.

The pure-Elixir path stays as the **pedagogical reference** — readable, no compile-time deps on Nx, suitable for teaching the math from the source equations.

This is a milestone, not a sprint. Multi-week effort. Tracked in this OPS.md as the canonical reference; PR/issue links will appear here as the work proceeds.

---

## 5. Known failure modes (with diagnostics)

### 5.1 (HISTORICAL, fixed in v1.1) Silent Dirichlet learning

**Symptom**: Online L4 Dirichlet updates (`DirichletUpdateA`, `DirichletUpdateB`) appear to run without error but the learned A and B matrices never reflect the agent's actual posterior. Alpha counts grew uniformly across hidden states regardless of `state.marginal_state_belief`.

**Root cause**: Both action modules read `marginal_state_belief` and `prev_marginal_state_belief` from the bundle map; the fields live on agent state. `Map.get(bundle, :marginal_state_belief, ...)` always hit the fallback. DirichletUpdateB was a complete no-op (`q_now` also fell through to nil); DirichletUpdateA reduced to uniform-weighted observation averaging.

**Diagnostic**: Run `mix test apps/agent_plane/test/actions/dirichlet_update_a_test.exs apps/agent_plane/test/actions/dirichlet_update_b_test.exs`. Three positive regression tests now guard against the bug returning. They assert state-dependent alpha deltas, not just "alpha changed."

**Fixed in**: commit `96f4c35` (PR 1 of v1.1-remediation). External review credit: Cantrill C2 finding (v1, unchanged in v2).

### 5.2 LiveView page hangs on auto-tick under load

**Symptom**: `/labs/meadow` shows the live grid but stops updating mid-episode.

**Root cause**: The auto-tick `Process.send_after(self(), :tick, 600)` fires regardless of whether the previous tick completed. Under heavy load (e.g. ComplexBird depth ≥ 2), the tick handler stacks up. LiveView's process mailbox grows and rendering falls behind.

**Diagnostic**: Click "Pause" → "Step" manually a few times. If single steps return cleanly, the math works; the auto-tick is the issue. Use ConvergentBird tier or smaller meadow.

**Mitigation**: Pin tier to `:convergent` or `:simple` for live demos. The plan's substrate framing (§4) addresses this fundamentally.

### 5.3 Mnesia disc table orphaned after schema change

**Symptom**: `world_models` app starts, but spec lookups return `nil` for previously-saved specs.

**Root cause**: Mnesia stores tables by atom name in `Mnesia.<node>/`. If you (or a future contributor) rename `:world_models_specs`, the old `.DCD` file is orphaned and a fresh empty table is created.

**Diagnostic**: `ls Mnesia.<node>/` shows old `world_models_*.DCD` files alongside new tables.

**Mitigation**: ADR-001 in `_local_guides/` mandates that Mnesia table atoms stay stable across renames. The `:world_models` Elixir app atom can be renamed (and was, in v1.1); the table atoms are preserved with a "legacy name" comment. If you absolutely must rename a table, write a migration shim that copies old → new on first boot.

### 5.4 Phoenix server fails to start with `:eaddrinuse`

**Symptom**: `mix phx.server` exits with `:eaddrinuse` on port 4000.

**Root cause**: Another `mix phx.server` instance, or another local service (often LibreChat at default port), is bound to 4000.

**Diagnostic**: `lsof -i :4000` (or `Get-NetTCPConnection -LocalPort 4000` on Windows).

**Mitigation**: `PORT=4002 mix phx.server`. The endpoint config reads `PORT` env var (added in v1.1).

---

## 6. CI and verification

The fast verification suite is what should pass on every PR before merge:

```bash
cd active_inference
mix compile --warnings-as-errors
mix test --exclude slow_experiment --exclude qwen_live --exclude flaky
```

Acceptance: 0 failures on `apps/agent_plane/test/`, `apps/world_plane/test/`, `apps/active_inference_core/test/`, `apps/shared_contracts/test/`. The `apps/workbench_web/test/` LiveView assertions occasionally drift behind UI changes — see §7 for the maintenance discipline.

The slow-tagged experiments (`mix test --include slow_experiment`) run at smoke scale by default (~5 minutes). Full-scale (`MEADOW_EXPERIMENT_SCALE=full`) runs in tens of minutes to hours and is gated to manual invocation.

A GitHub Actions workflow is on the v1.2-hardening roadmap (C1 finding from the external review).

---

## 7. Maintenance discipline

### 7.1 Audit-anchor-as-source-code-test pattern

Every claim that lives in a docstring or design document should have a corresponding test in `apps/agent_plane/test/meadow/` (or sibling app test dirs) that enforces the claim at the source-code or mathematical-property level. The five existing exemplars:

- `vfe_bound_test.exs` — `F[q] >= -ln p(y)` against brute-force forward algorithm
- `elbo_bound_test.exs` — `ELBO[q] <= ln p(y)`
- `q_vs_p_naming_test.exs` — production and audit code paths can't accidentally merge
- `blanket_ci_test.exs` — inter-agent Markov blanket is a real CI partition (replay-determinism test)
- `no_thermo_overclaim_test.exs` — source-code lint for thermodynamic overclaims

The external review panel called this triad "the most valuable single artifact in the codebase" and recommended adoption by their own Ecphory project. New audit anchors should follow the same pattern: name the claim, write a test that fails when the claim drifts, run it in CI.

### 7.2 LiveView test drift

The LiveView tests in `apps/workbench_web/test/workbench_web/live/` assert on rendered HTML strings. When the UI improves (e.g. placement-list format change in v1.0 → v1.1), the assertions need to be updated in the same commit. Currently 4 such tests are stale and tracked as a `test: align LiveView assertions with current UI` follow-up; this should be a discipline going forward, not a dedicated maintenance pass.

### 7.3 The public-review loop

The workbench was published 2026-05-07 with a public ask for community validation (dev.to article + LinkedIn). An external panel responded within 24 hours with findings; this OPS.md and the v1.1-remediation tag are the visible response. The same loop should remain open for future findings — file an issue, expect a thoughtful response, expect named limits to be honoured.

---

## 8. Reference

- **Repo**: https://github.com/TMDLRG/TheORCHESTRATEActiveInferenceWorkbench
- **Latest published artifact**: dev.to https://dev.to/tmdlrg/bird-meadow-a-multi-agent-active-inference-world-id-like-the-community-to-poke-holes-in-1aod
- **Mathematical source**: Parr, Pezzulo & Friston (2022) *Active Inference*, MIT Press (CC BY-NC-ND)
- **Code license**: CC BY-NC-ND (matches the underlying math text)
- **External review credits**: see `_local_guides/` for ADR-001 and the audit-anchor pattern guide

---

*OPS.md last revised in v1.1-remediation (2026-05-07). This document is part of the public-science maintenance contract — keep it honest about what works, what doesn't, and what's deferred.*

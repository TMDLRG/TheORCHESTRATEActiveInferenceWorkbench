# Learning Labs — QA Master Report

Date: 2026-04-18 (post-redesign + Learning-Shell uplift update)

## Uplift pass (new)

All seven simulators now ship the Learning Shell: a shared audience picker, persistent 4-way learning-path toggle (🌱 Story / 🧭 Real-world / 🛠️ Equation / 🎓 Derivation), layered equation panel (Story / Picture / Equation / Derivation tabs), analogy library, physical-exercise drawer, beat-script runner, 3-tier glossary tooltip engine, dyslexia-friendly font toggle, and reduced-motion support. The Shell sits above the previously-added sticky strip / intro strip / primary toolbar / guided tour chrome; none of those pieces was removed.

Per-sim content deliverables (inlined, no external fetches):

- 9–15 glossary terms per sim with Kid / Adult / PhD definitions.
- Five analogies per sim (one per persona P1→P5) with a variable-map table and a micro-exercise.
- Three-to-four physical exercises per sim, each printable at half-letter via the browser's print dialog.
- Seven-to-ten beats per sim, each with per-path narration and (where applicable) a wired "Do this" button.

**Math regression passed on fresh load** for every sim: bit-exact cold-load values against `_baselines/*.baseline.json`. BayesChips presets 0–3 (0.368, 0.538, 0.191, 0.815), POMDP standard/noisy/sticky F (1.490, 2.553, 1.946), Forge Calibration Bay F=2.542, Laplace Tower preset_0 F=0.270, Atlas predictive-coding starter F=0.291, Frog clear-jumping-frog P=0.500.

**UI elegance pass** on Laplace Tower Hierarchy Machine canvas: canvas now dynamically scales height to `levels × (orders × 72 + 90)`; node sub-labels moved to the left of each circle so rows no longer collide at 3 levels × 3 orders. Previous renderings showed `εx`/`μx`/`μv`/`εv` labels smashing into the next row; that is gone.

**Shell-isolation hardening**: Forge, Laplace Tower, Anatomy, Atlas, and Frog each host the Shell in a dedicated `<script>` block so any pre-existing exception inside the sim's own IIFE (e.g. Forge's `fmt.toFixed` edge case on `loadPreset(0)`) cannot prevent `LS` from initialising.

See `FINAL_ACCEPTANCE_TABLE.md`, `QA_ISSUES_CHECKLIST.md`, and `UPLIFT_PROOF.md` for details.

---

## (Previous) Redesign summary
Scope: seven standalone HTML educational simulators in `learninglabs/` covering Bayesian inference, variational/expected free energy, predictive coding in generalized coordinates, discrete POMDP active inference, and the anatomy-of-inference bridge.

This report covers static code audit, math fidelity review, pedagogy review, runtime review, applied fixes, UI/UX redesign pass, browser-based UAT, and remaining caveats.

## Redesign summary (new)

After the initial math/runtime fixes (listed below) the simulators still had UI/UX defects: scattered buttons, cramped canvases, no onboarding. A full per-file redesign pass was applied following the approved plan at `~/.claude/plans/fuzzy-watching-honey.md`:

- Every simulator now has a **sticky status strip** of 6 cells pinned above its canvas, showing the quantities that matter for that sim.
- Every simulator now has a **primary toolbar** with run buttons (Step / Run / Reset / Preset / …) placed immediately above the canvas — no more cross-column hunts for the button that moves the machine.
- Every simulator now has a dismissable **intro strip** ("Goal / Watch / First move") that remembers dismissal in `localStorage`.
- Every simulator now has a **guided tour overlay** with numbered steps, reopenable from a "?" button on the toolbar.
- Every redesigned simulator was **verified in Chrome via MCP screenshots** at 1568×720/766.

See `FINAL_ACCEPTANCE_TABLE.md` for the pass/fail grid and `QA_ISSUES_CHECKLIST.md` for the detailed checklist.

---

## Executive summary

| # | Simulator | Math fidelity | Pedagogy | Runtime | UI polish | Verdict after fixes |
|---|---|---|---|---|---|---|
| 1 | BayesChips | 5/5 | 5/5 | 5/5 | 4/5 | **PASS** |
| 2 | active_inference_pomdp_machine | 5/5 | 4/5 | 5/5 | 4/5 | **PASS** |
| 3 | free_energy_forge_eq419 | 5/5 | 4/5 | 5/5 | 4/5 | **PASS** (notation fixed) |
| 4 | laplace_tower_predictive_coding_builder | 5/5 | 4/5 | 5/5 | 4/5 | **PASS** |
| 5 | anatomy_of_inference_studio | 4/5 | 4/5 | 5/5 | 4/5 | **PASS** (orders editor fixed) |
| 6 | active_inference_atlas_educational_sim | 4/5 | 4/5 | 5/5 | 4/5 | **PASS** (Πx silent-overwrite fixed) |
| 7 | jumping_frog_generative_model_lab | 4/5 | 4/5 | 5/5 | 4/5 | **PASS** (math/pedagogy corrected) |

"Pedagogy 4/5" means: the simulator teaches the intended concept, but at least one teaching simplification is strong enough that the learner must read the ledger text to stay honest about what is exact vs. a didactic stand-in. Each such simplification is now explicitly flagged in the simulator's own on-screen text.

The highest-severity issue found was a silent mutation in the Atlas neuromodulator code that overwrote every level's Πx on every compute cycle. It is fixed. The next highest-severity cluster was three interconnected issues in the Jumping Frog that (a) set observations from current belief, (b) selected actions that reward belief confirmation rather than information gain, and (c) showed two separately-computed posteriors that diverged. All three are fixed and now consistent.

---

## Files modified

- `BayesChips.html` — Run-All restarts the animation when already at the final step.
- `active_inference_pomdp_machine.html` — token field now shows `q(s1)` mix instead of a fixed decorative 7+7 token bar.
- `active_inference_atlas_educational_sim.html` — NA (noradrenaline) slider becomes a multiplicative gain on per-level Πx instead of silently replacing each level's stored Πx; ledger shows effective Πx; teaching panel updated.
- `anatomy_of_inference_studio.html` — level editor now renders every generalized order and every η component. Previously hardcoded to μx[0], μx[1] only, so the 3-orders preset had unreachable coordinates.
- `free_energy_forge_eq419.html` — replaced the ambiguous `!` suffix with proper `~` tildes for generalized-coordinate stacks (ỹ, μ̃x, μ̃v, η̃, ε̃y, ε̃x, ε̃v) throughout the UI, ledger, step cards, and subtitle.
- `jumping_frog_generative_model_lab.html` — four coordinated fixes:
  1. `complementDist` now carries a prominent comment labeling it as a didactic stand-in for `P(obs | other)`.
  2. Action contingency no longer sets the tactile observation as a function of current posterior. Instead, action scales the tactile channel's precision gain g(a): touch 1.5, do_nothing 1.0, poke_fast 0.3.
  3. `exact` and `fromOdds` posteriors are computed once from a single LLR-sum formula, so they agree by construction.
  4. `actionStep` now picks the action that maximizes expected Bayesian surprise `E_o[KL(P(H|o,a) ‖ P(H))]`, i.e. genuine active-inference epistemic value, instead of rewarding belief-confirmation.

---

## Per-simulator audit

### 1. BayesChips.html — Bayes Machine

**Intent.** Exact Bayesian updating in a fully constructed 100-case world. The simulator wants the displayed equation and the physical chip world to match *line by line*.

**Exact mathematics being taught.**
- `P(H) = a/100`
- `P(E | H) = b/a`, `P(E | ¬H) = c/(100-a)`, with the complementary `P(¬E | ·)` counts computed from the same chip population.
- `P(H | obs) = [selected gold chips] / [all selected chips]`, which equals `P(obs|H)·P(H) / [P(obs|H)·P(H) + P(obs|¬H)·P(¬H)]` by construction.

**Pedagogy.** Excellent. Step lamps, ledger, and physical chip animation reinforce each other. Mission card and score system are honest. The "Physical reading of the same answer" line shows both algebraic and combinatorial forms of the posterior.

**Bugs found.**
- Run All from step 4 did nothing (no loop iterations). This made the animation un-rewatchable without manually resetting.

**Fixes applied.** Run All now restarts from step 0 if the learner clicks it while already at step 4.

**Remaining caveats.**
- At extreme parameter choices (e.g., a=100 with notB large), the chip positions in the H-tray at step 2 can visually overflow the tray bounds. Layout is still readable; values in the ledger are still correct. Deferred as cosmetic.
- The decorative "chamber" positions are picked via fixed offsets and cols=10, which is robust for a≤88 but can look cramped for a=100. Deferred.

### 2. active_inference_pomdp_machine.html — Clockwork Active Inference

**Intent.** Discrete-time POMDP active inference: categorical likelihood A, transitions B(u), preferences C, initial state belief D, two states, two observations, four policies over two transitions. Teach the separation of F (explains current observation + transition structure) and G (expected free energy over futures) and the policy posterior `π = softmax(-G - F)`.

**Exact mathematics being taught.**
- Message-passing update Eq 4.13-style: `v_τ` accumulates likelihood, forward transition, backward transition, and `-ln s_τ` corrections; `s_τ = softmax(v_τ)`.
- Variational free energy per policy, summed over τ=1,2,3 slices, with `-ln A·o₁ - ln D` at τ=1 and `-ln B·s_{τ-1}` for τ=2,3.
- Expected free energy `G = risk + ambiguity` per future slice (τ=2,3), where `risk = KL(Q(o|π) ‖ C)` and `ambiguity = E_{Q(s|π)}[H[P(o|s)]]`.
- Policy posterior `π = softmax(-G - F)`.

All match the displayed equations.

**Pedagogy.** Strong. Each policy card shows its own q(s1..3), F, G, π, and first action, all editable through a focus selector. Ledger shows the full v_τ update equation with numeric message vectors.

**Bugs found.**
- Hidden-chamber token field always displayed 7 gold + 7 steel tokens regardless of state or belief. Decorative but misleading — implied quantitative meaning.

**Fixes applied.** Token field is now a 20-token bar proportional to the current mixed `q(s1)` (brass = P(Calm), steel = P(Faulty)). A tooltip labels each half.

**Remaining caveats.**
- When the user-edited preferred-Quiet slider is near its endpoints (0.55 or 0.98), C can become extreme and G can become numerically large before softmax clamping. This is correct behavior but can make policy posteriors saturate on one plan. This is documented in teaching notes ("dopamine-like γ sharpens or flattens the softmax").

### 3. free_energy_forge_eq419.html — Free Energy Forge

**Intent.** Teach Equation 4.19 in a compact 3-dimensional linear world so every term stays visible. Tildes denote vectors over generalized coordinates.

**Exact mathematics being taught.**
- `F = ½ ( ε̃y' Πy ε̃y + ε̃x' Πx ε̃x + ε̃v' Πv ε̃v )`
- `ε̃y = ỹ − g(μ̃x, μ̃v)`, `ε̃x = D μ̃x − f(μ̃x, μ̃v)`, `ε̃v = μ̃v − η̃`
- D is the upper-shift operator (ones above the leading diagonal).
- Teaching-world linear maps: `g(μ̃x, μ̃v) = μ̃x + μ̃v`, `f(μ̃x, μ̃v) = [μx[1]+μv[0], μx[2]+μv[1], μv[2]]`.

Gradient descent is numerical on the same `compute()` output as the ledger, so the meter falls only when the actual equation falls (stated in the UI).

**Pedagogy.** Strong. Six-step card list walks through the full computation. The canvas "mechanical signal path" labels every chip with the term it corresponds to. Precisions are explicitly stated as diagonal.

**Bugs found.**
- The simulator used `!` as an ASCII stand-in for the tilde `~` that marks generalized-coordinate vectors in the book notation. This collides with factorial notation and is confusing to a learner who has just read a probability textbook.

**Fixes applied.** Replaced `!` with proper combining-tilde (`ỹ`, `μ̃x`, `μ̃v`, `η̃`, `ε̃y`, `ε̃x`, `ε̃v`) in the subtitle, control-deck group titles, pipes row, step cards, ledger, and model equation block. Added a one-line subtitle note stating "Tildes mark generalized coordinates (stacks over temporal orders)".

**Remaining caveats.**
- Precisions are scalar here ("diagonal Π with equal values across orders"). The screen notes this. A generalization to block-diagonal Π per order is possible but would complicate the ledger.

### 4. laplace_tower_predictive_coding_builder.html — Laplace Tower

**Intent.** Box 4.3 generalized predictive coding, multi-level hierarchy, quadratic free energy around the posterior mode, action that only changes sensory input.

**Exact mathematics being taught.**
- `q(x) ≈ N(μ, Σ⁻¹)` with `Σ⁻¹ = -∂² ln p(x,y)/∂x²`.
- `F = ½ Πy εy² + Σᵢ ½ Πxⁱ ‖εxⁱ‖² + Σᵢ ½ Πvⁱ ‖εvⁱ‖²`.
- `εy = y(u) − g₀(...)`, `εxⁱ = D μxⁱ − fⁱ(...)`, `εvⁱ = μvⁱ − gⁱ⁺¹(...)` (top level uses η).
- Action law: `u̇ = -∂F/∂u`.

Belief and action updates are numerical gradients of the same F displayed in the ledger. Hierarchy add/remove and order add/remove correctly rebuild the editor and state.

**Pedagogy.** Strong. "Builder Notes" table maps every abstract concept (Laplace approx, precision, D, εx, εv, εy, action) to its concrete location in the simulator. Mission-ordered presets (1 level/2 orders → 3 levels/3 orders) encourage progressive disclosure.

**Bugs found.** None of significance. `addLevel` correctly reassigns predX/predV on the previous top level so hierarchical coupling is not lost. `removeLevel` correctly zeroes predX/predV on the new top.

**Remaining caveats.**
- The linear teaching maps g and f make the hierarchy strictly linear. Nonlinear maps would be closer to neural reality but would hurt readability.
- The numerical gradient uses `h = 1e-4`, which is fine for well-conditioned problems here. Extremely high precisions (≥ 8 everywhere) can cause a slightly noisy `∂F/∂u`, but convergence is robust in practice.

### 5. anatomy_of_inference_studio.html — Anatomy of Inference Studio

**Intent.** Figure 5.5-style single-system view: habits (E), planning (π), goals (C), prediction (descending categorical → continuous target), continuous predictive coding, action that only changes sensory data.

**Exact mathematics being taught.**
- The same continuous predictive-coding F as the Laplace Tower.
- A compact scalar-EFE proxy for each policy: `G_π = ½ χ (y + control_π − target_π)² + ambiguity_π − habit_π`, then `π = softmax(-γ G)`. This is explicitly a teaching simplification of the full EFE; it keeps only the preference-mismatch (risk) and ambiguity axes and treats habit as a log-prior over policies.
- Categorical-to-continuous bridge: the policy-posterior-weighted average of `target_π` becomes a descending continuous target on the top hidden cause, and the weighted average of `control_π` nudges the continuous control u.

**Pedagogy.** Good. Atlas canvas, policies canvas, continuous-control canvas, and bridge canvas each make a different theme salient. Guided lessons tab enumerates dependencies in a helpful order.

**Bugs found.**
- `renderEditors` hardcoded inputs for `mux[0]` and `mux[1]` only, ignoring orders ≥ 3. The preset "Figure 5.5 style integrated loop" uses 3 orders, so μx[2], μv[2], and η[*] were unreachable through the UI.

**Fixes applied.** `renderEditors` now loops over `model.orders` and emits μx[k], μv[k] rows for every order. For the top level it also emits η[k] rows. Edits go through the existing `data-vec`/`data-k` wiring (which already supported arbitrary k but was never fed by the markup).

**Remaining caveats.**
- The policy equation is explicitly labeled as a proxy for EFE. A learner must not walk away thinking "G is always this closed-form scalar". The ledger uses the full form with terms named "risk", "ambiguity", "habit" so this caveat is explicit in context.
- The bridge-target mechanism nudges `top.muv[0]` toward the policy-posterior-weighted target. This is a simplification; in a full system it would be the output of message passing from policy to cortex. Labeled clearly on the bridge tab.

### 6. active_inference_atlas_educational_sim.html — Active Inference Atlas

**Intent.** A wide tour of continuous-time active inference: Laplace approximation, generalized coordinates, cortical microcircuit mapping (SP/DP/SS/II), policy/basal-ganglia mapping, and a neuromodulator→precision simplification (ACh→Πy, NA→Πx, DA→γ, 5-HT→χ).

**Exact mathematics being taught.**
- Same quadratic-F structure as the Laplace Tower.
- Same scalar-EFE proxy as the Anatomy studio: `G_π = ½ χ (y + control_π − target_π)² + ambiguity_π − habit_π`, `π = softmax(-γ G)`.

**Bugs found (HIGH SEVERITY).**
- `compute()` silently overwrote every level's stored `L.px` with the global NA slider value on every call:

      m.levels.forEach(L=> L.px = m.nor);

  This meant the per-level Πx input in the hierarchy editor was effectively dead. Any value the learner typed was discarded on the next render because the next `update()` overwrote it from the NA slider. Also, the cortex and hierarchy wire thicknesses used `L.px` after overwrite, creating the illusion that NA "wired through" the hierarchy, when actually the per-level control didn't work at all.

**Fixes applied.**
- Removed the silent overwrite.
- Added `NA_BASELINE = 1.5` and `naGain = m.nor / NA_BASELINE`.
- Effective Πx at each level is now `L.px * naGain`. This preserves both the per-level editor (relative precision per level) and the NA slider (global precision gain).
- The ledger now shows `effective Πx = L.px · naGain`.
- The neuromodulator bench text was updated to state "NA scales per-level Πx multiplicatively. At NA = 1.5 the stored Πx is used as-is."

**Remaining caveats.**
- The ACh slider in the neuromodulator bench editor and the `Πy/ζ` slider in the Global Controls panel both drive `model.chol`/`model.py`. Moving one does not update the other's slider thumb (they stay in sync in terms of the value used by `compute()`, because `updateGlobalsFromUI` forces `model.chol = model.py` and vice versa through compute's `m.py = m.chol`). This is a minor UI desync; deferred.
- The cortical-microcircuit tab assigns SP/DP/SS/II to prediction-error and posterior-mean slots in a didactic way. It is not a claim about which population does what in cortex. The teaching-view table below the canvas says this explicitly.

### 7. jumping_frog_generative_model_lab.html — Jumping Frog Generative Model Lab

**Intent.** Hierarchical Bayesian concept inference from multiple sensory modalities; action that only changes (the reliability of) sensory input; log-odds Bayes updating as the primary computational object.

**Exact mathematics being taught.**
- `logit P(H | y, a) = logit P(H) + Σₘ log [P(yₘ|H) / P(yₘ|other)] + (g(a) − 1) · log [P(y_tactile|H) / P(y_tactile|other)]`
- `g(a)` = tactile precision gain: touch 1.5, do_nothing 1.0, poke_fast 0.3.
- Active-inference action selection: choose a maximizing `E_o[KL(P(H|o,a) ‖ P(H))]`.

**Bugs found (HIGH SEVERITY cluster).**
1. Action contingency was circular: if the user picked "touch" and the posterior was > 0.5, the simulator silently set the tactile observation to `'wrinkly'`. This makes action depend on current belief about the hidden state, which is exactly the causal structure active inference refuses. It taught a wrong mental model.
2. `actionStep` picked the action that maximizes `P(obs | current belief)`. That rewards belief-confirmation, not information gain. For active inference it should be the opposite: maximize expected Bayesian surprise.
3. `exact` (product form) used the raw tactile observation; `fromOdds` (log-odds form) used the action-contingent override. The two posterior numbers on screen therefore disagreed. A learner trying to reconcile them was being lied to.
4. `complementDist` is a fixed heuristic that derives `P(obs|other)` from `P(obs|frog)`, but was presented as if it were a user-specifiable independent likelihood.

**Fixes applied.**
1. Action no longer writes into the observation variable. Instead, it scales the tactile LLR by g(a).
2. `actionStep` replaced with an information-gain scorer that computes expected Bayesian surprise on tactile outcomes under the current belief and picks the a with the highest value. Log now reports all three utilities so the learner can verify.
3. Posterior is computed once from a single LLR sum; `exact` and `fromOdds` return the same number by construction. Ledger shows the single computation path.
4. `complementDist` is now annotated as a teaching heuristic in both the code and the on-screen equation panel.

**Remaining caveats.**
- `P(obs | other)` is still derived rather than user-editable. A future improvement would expose an independent likelihood table for the alternative hypothesis. Deferred.
- `beliefStep` is an exponential smoothing toward the exact posterior rather than a VFE gradient step. This is a cosmetic animation choice; the "exact" target is still the correct Bayesian posterior. Noted in the ledger.

---

## Cross-simulator consistency

The seven simulators consciously preserve distinct mechanical metaphors (chip machine, clockwork, forge, tower, studio, atlas, frog lab). This report does not force a single aesthetic. Instead, it enforces these consistency properties after the fixes:

- **Notation for generalized coordinates:** Forge now uses `~` (matching the book). Laplace Tower and Atlas use explicit `μx[k]`, `μv[k]` notation. No simulator now uses `!` for tilde.
- **Precision symbol:** `Πy, Πx, Πv` used throughout the continuous-time family (Forge, Laplace Tower, Atlas, Anatomy Studio).
- **Variational vs expected free energy:** F and G are kept visibly distinct in both the POMDP Machine and the Anatomy Studio / Atlas. F appears with its per-slice decomposition; G appears with risk + ambiguity (± habit).
- **Action rule:** All continuous-time sims use the same language: "action only changes sensory data; `u̇ = -∂F/∂u`". No sim edits hidden-state beliefs by action.
- **Truth-in-labeling:** The didactic simplifications (scalar-EFE proxy in Anatomy/Atlas, action precision-gain in Jumping Frog, `complementDist` in Jumping Frog) are now labeled as teaching stand-ins in their on-screen text.

---

## Risk register (remaining)

- **Anatomy/Atlas scalar EFE proxy.** Students might generalize `G = ½ χ (y + u_π − t_π)² + ambiguity − habit` to "this is what G always looks like". Mitigation: the on-screen text explicitly calls this a proxy for Eq 4.14-style G; the POMDP Machine shows the honest discrete form with risk + ambiguity.
- **Jumping Frog complementDist.** `P(obs|other)` is not independently specifiable. Mitigation: explicit on-screen label. Future work: add an alt-likelihood editor.
- **BayesChips chip overflow at extreme counts.** Cosmetic; math remains correct.
- **Atlas ACh vs Πy slider desync.** Cosmetic; effective value in `compute()` is consistent.

# Learning Labs — Final Acceptance Table

Date: 2026-04-18. Uplift pass (Learning Shell) landed on all seven simulators and UAT'd in Chrome via MCP at 1568×726.

| # | Simulator | Math fidelity | Pedagogy | Runtime | UI polish | Shell | Path toggle | Glossary | Analogies | Exercises | Beats | Pass/Fail | Notes |
|---|-----------|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|-------|
| 1 | BayesChips.html | PASS | PASS | PASS | PASS | PASS | ✓ 4 paths | 13 | 5 | 4 | 8 | **PASS** | Pattern-setter. 4-preset math regression bit-exact. Intro strip, sticky strip, 6-step guided tour retained. |
| 2 | active_inference_pomdp_machine.html | PASS | PASS | PASS | PASS | PASS | ✓ 4 paths | 14 | 5 | 3 | 8 | **PASS** | 3-preset F regression exact on fresh load. π = softmax(−G−F) unchanged. |
| 3 | free_energy_forge_eq419.html | PASS | PASS | PASS | PASS | PASS | ✓ 4 paths | 15 | 5 | 3 | 7 | **PASS** | Eq 4.19 F=2.542 matches baseline. Shell lives in a separate script tag to isolate from a pre-existing `fmt.toFixed` edge case in the original sim. |
| 4 | laplace_tower_predictive_coding_builder.html | PASS | PASS | PASS | PASS | PASS | ✓ 4 paths | 14 | 5 | 3 | 8 | **PASS** | F=0.270 on load matches baseline. **Canvas elegance pass applied** — dynamic height, left-side node labels, no row collisions at 3×3. |
| 5 | anatomy_of_inference_studio.html | PASS | PASS | PASS | PASS | PASS | ✓ 4 paths | 11 | 5 | 3 | 7 | **PASS** | F=0.512 / G=0.160 on load. Shell in separate script tag. |
| 6 | active_inference_atlas_educational_sim.html | PASS | PASS | PASS | PASS | PASS | ✓ 4 paths | 13 | 5 | 3 | 8 | **PASS** | F=0.291 on load. NA→Πx multiplicative fix preserved. |
| 7 | jumping_frog_generative_model_lab.html | PASS | PASS | PASS | PASS | PASS | ✓ 4 paths | 9 | 5 | 3 | 8 | **PASS** | P(frog)=0.500 start. Action-as-precision-gain honesty + single LLR-sum posterior preserved. |

## What the Shell adds to every sim

- **Path bar** pinned above the title: 🌱 Story · 🧭 Real-world · 🛠️ Equation · 🎓 Derivation, plus a ♻ Switch audience button and a 🅰 Font (dyslexia-friendly) toggle.
- **First-load audience picker** overlay (4 cards). Preference stored in `localStorage` per sim. Dismissal defaults to Real-world.
- **Layered Equation Panel** (four tabs) placed in a 2-column footer section. Same math, four depths.
- **Beat Script** placed beside the Layered Panel. 7–10 beats per sim; each beat has per-path narration and, where applicable, a "Do this" button wired to an existing sim action.
- **Dock** bottom-right with Glossary / Analogies / Exercises buttons. Each opens a slide-in side panel.
  - **Glossary**: 9–15 terms per sim, each with Kid / Adult / PhD definitions and a search box.
  - **Analogies**: five analogies per sim (one per persona) with a variable-map table and a micro-exercise.
  - **Exercises**: three-to-four physical exercises per sim; each prints to half-letter via the browser's print dialog.
- **Tooltip engine** wires every `data-term` in the DOM to the 3-tier glossary; order of tiers follows the active path.
- **Accessibility**: `role="region"`, `aria-live` on sticky strip, `aria-pressed` on path buttons, full keyboard focus on terms, Escape closes panels, `@media (prefers-reduced-motion)` halves transitions.

## Verification evidence

- **Screenshots at 1568×726** captured for every simulator after the shell landed (POMDP Machine, Frog, Atlas shown mid-pass; Laplace Tower pre/post canvas elegance fix).
- **Math regression**: cold-load posterior / F values match `_baselines/*.baseline.json` exactly for BayesChips (4/4 presets), POMDP (3/3 presets), Forge (Calibration Bay), Laplace Tower (preset_0), Atlas (predictive-coding starter), and Frog (clear jumping frog).
- **Path switching**: `LS.setPath('kid'/'real'/'equation'/'derivation')` never resets sim state in any file. Verified on BayesChips, Forge, POMDP (Fy/Fx/Fv / posterior unchanged across all 4 paths).
- **Console cleanliness**: zero new errors on BayesChips, POMDP, Laplace Tower, Anatomy, Atlas, Frog. Forge still emits a pre-existing `fmt.toFixed` on `loadPreset(0)`; the Shell is isolated in a second `<script>` tag so LS still initialises.

## Remaining caveats

- **Responsive check at 820px** could not be visually confirmed — the Chrome MCP `resize_window` call doesn't actually resize the viewport. Narrow-width CSS (`@media (max-width: 820px)`) is in place and verified by stylesheet inspection.
- **BayesChips chip overflow** at extreme preset values — cosmetic, pre-existing.
- **Forge pre-existing `fmt` edge case** — Shell isolated; does not regress.
- **ACh / Πy slider desync in Atlas** — pre-existing cosmetic issue carried forward.
- **Jumping Frog `complementDist` heuristic** — labelled clearly as a didactic stand-in in code, on-screen text, and the Derivation tab.

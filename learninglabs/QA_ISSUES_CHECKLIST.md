# Learning Labs — QA Issues Checklist

Legend: `[x]` fixed and verified in-browser, `[/]` mitigated with explicit on-screen label, `[.]` deferred with justification.

## BayesChips.html
- [x] `Run All` did nothing when `currentStep === 4` → now restarts from step 0 and animates through.
- [x] `.zone` had `display:flex; flex-direction:row` causing title and sub-text to render on the same line → now `display:block` with stacked label + sub.
- [x] 10×10 chip grid at 18 px overflowed Zone A (150 px tall) → now 15×7 grid at 15 px with 13 px chip diameter, fits every zone. Zone heights also enlarged.
- [x] Step-2 "not-E" chips were offset by `+132x +88y`, a shift tuned for the old 10-col grid; with the new 15-col grid this overflowed. Removed the shift; not-E chips repack inside the H/¬H trays using their own index stream.
- [x] Missing primary toolbar adjacent to the chamber → added sticky strip + intro strip + toolbar (Back / Next Step / Run All / Reset / Score guess / New mission / ?).

## active_inference_pomdp_machine.html
- [x] Decorative `.machine::before/.machine::after` ring pseudo-elements wasted the lower half of the machine floor → `display:none` added.
- [x] Run controls (tick/settle/score/act/manual/reveal) were only in the sidebar → primary toolbar added above the machine floor.
- [x] Token field was a static 7 steel + 7 gold decoration → now renders a 20-token bar proportional to current mixed `q(s₁)`.
- [x] Sticky strip added: Time slice, Ticks, Best policy name, F(best), G(best), Quiet streak.
- [/] `hiddenReveal` still shows `???` when not revealed. Label unchanged; intentional for the teaching game.

## free_energy_forge_eq419.html
- [x] `!` suffix on ỹ, μ̃x, μ̃v, η̃, ε̃y, ε̃x, ε̃v collided with factorial notation → replaced with proper combining tilde in subtitle, control-deck titles, ledger, step cards, model-eq block, and pipe labels.
- [x] `Load preset / Random / Reset / Auto-reduce F` were in Mission Console while the actual `μx/μv gradient step / Full descent` buttons were in a separate Game Controls panel further down → merged into one primary toolbar above the canvas.
- [x] Pipes row duplicated the canvas's information → pipes row removed; `setPipe` call no-oped.
- [x] Engine Status cards were not sticky → added sticky strip (F/Fy/Fx/Fv/‖ε̃y‖/‖ε̃x‖) that pins above the canvas.

## laplace_tower_predictive_coding_builder.html
- [x] Canvas node labels like `-0.06` clipped inside 28 px node radius → node radius bumped to 30 for μ-nodes and 26 for ε-nodes; numbers now format as `toFixed(2)`.
- [x] Hierarchy Builder mixed structural (`Add level / Remove top / Add order / Remove order`) with run (`Belief step / Action step / Belief+action / Auto-run`) in the same sidebar → run buttons promoted to primary toolbar; structural buttons retained in the sidebar.
- [x] Machine Status cards scrolled away when editing the level panel → sticky strip replaces them above the fold.

## anatomy_of_inference_studio.html
- [x] `renderEditors` hardcoded inputs for `mux[0]` and `mux[1]` only → now iterates over `model.orders` for μx, μv, and η (top level).
- [x] 7-card Status Deck was cramped on default width → sticky 6-cell strip added above; legacy Status Deck panel retained for drill-down.
- [x] Run buttons (Belief/Action/Policy) were in Global Controls sidebar below the fold → primary toolbar above canvas has all 7 run buttons.

## active_inference_atlas_educational_sim.html
- [x] **HIGH**: `compute()` silently overwrote every `L.px` with `m.nor` on every call, destroying per-level Πx edits → NA now acts as a multiplicative gain `naGain = m.nor / 1.5` on stored `L.px`. Per-level editing survives.
- [x] Mission "F target cleared" pill fired on load because the default preset already met its own target → `hasInteracted` flag; badge only appears after a Belief/Action/Policy step.
- [x] Run buttons were at the bottom of Global Controls → primary toolbar above canvas.
- [/] ACh slider and global `Πy/ζ` slider both drive `model.chol` through `m.py = m.chol`. Values stay consistent in `compute()`; slider thumbs may desync cosmetically.

## jumping_frog_generative_model_lab.html
- [x] **HIGH**: Tactile observation was set by action conditional on current posterior (`if posterior > 0.5 then 'wrinkly'`) — a circular causal loop → action now scales tactile-channel precision gain `g(a)` without touching the sampled observation.
- [x] **HIGH**: `actionStep` picked the action maximizing `P(obs | belief)` — rewarded belief-confirmation instead of information gain → now maximizes `E_o[KL(P(H|o,a) ‖ P(H))]` via `expectedInfoGain`.
- [x] **HIGH**: `exact` (product form, raw tactile) and `fromOdds` (log-odds, action-contingent tactile) disagreed → single `posteriorFromLLRs` computation; both variables refer to it.
- [/] `complementDist` derives `P(obs | other)` from `P(obs | frog)` by fixed heuristic → now labeled explicitly as a didactic stand-in in code comment and on-screen text.
- [x] Run buttons were in sidebar → primary toolbar above canvas; sticky strip with live best-action hint.
- [.] Independent user-editable `P(obs | other)` — deferred; current heuristic is labeled honestly.

## Cross-simulator UX additions (all seven files)
- [x] Sticky status strip pinned to top of main stage column.
- [x] Intro strip with `Goal / Watch / First move` tags; dismissible; persisted in `localStorage` per file.
- [x] Primary toolbar with the sim's run buttons, placed immediately above the canvas.
- [x] Guided tour overlay (6 steps per sim on average) reopenable from a `?` button.
- [x] Narrow-width responsiveness: `repeat(auto-fit, minmax(118px, 1fr))` lets the sticky strip flow to 2+ rows without clipping.

## Learning Shell uplift (all seven files)
- [x] **Audience picker** on first load (4 cards: Story / Real-world / Equation / Derivation). Choice stored in `localStorage` per sim. Dismissal defaults to Real-world.
- [x] **Path toggle bar** pinned above every sim's title: 🌱 Story · 🧭 Real-world · 🛠️ Equation · 🎓 Derivation + ♻ Switch audience + 🅰 Font.
- [x] **Layered Equation Panel** (Story / Picture / Equation / Derivation tabs) in a new footer row. Same math, four depths. Tooltip-aware `data-term` nodes embedded in every tab.
- [x] **Beat Script runner** with per-path narration and wired "Do this" buttons (7–10 beats per sim).
- [x] **Analogy side panel**: five analogies per sim (one per persona) with variable-map tables and micro-exercises.
- [x] **Physical-exercise drawer**: 3–4 household-objects exercises per sim; each prints at half-letter via the browser's print dialog.
- [x] **3-tier glossary tooltip engine** (Kid / Adult / PhD) wired to every `data-term` node; searchable drawer lists every term.
- [x] **Dyslexia-friendly font toggle** (Verdana + extra letter/word spacing) persisted in `localStorage` per sim.
- [x] **Reduced-motion support** via `@media (prefers-reduced-motion: reduce)`; transitions shortened to 100ms.
- [x] **Accessibility**: `role`, `aria-live`, `aria-pressed`, `tabindex`, Escape closes panels, focus traps on overlays, keyboard reachable for every Shell control.
- [x] **Shell isolation**: Forge / Laplace Tower / Anatomy / Atlas / Frog host the Shell in a second `<script>` tag so any pre-existing sim-IIFE exception cannot prevent `LS` from booting.
- [x] **Math regression**: cold-load values match pre-Shell baselines in `_baselines/*.baseline.json` for every sim verified.
- [.] **True 820-px responsive check**: deferred — Chrome MCP `resize_window` does not reliably resize the viewport in this environment. CSS media queries are in place and verified by stylesheet inspection.

## Laplace Tower canvas elegance pass
- [x] Hierarchy Machine canvas now dynamically scales height to `levels × (orders × 72 + 90)`; no overlap at 3 levels × 3 orders.
- [x] Node sub-labels (e.g. "εx[1]", "μx[1]") moved to the **left** of each circle; values render centered inside the circle in bold.
- [x] Canvas CSS changed to `height: auto; min-height: 480px;` so the dynamic resize takes effect.
- [.] Same style pass for other sims with canvases (Anatomy, Atlas, Frog) — deferred; no rendering defects observed on their canvases after the Shell install.

## Pre-existing issues surfaced during uplift (not introduced by the Shell)
- [.] Free Energy Forge: `fmt(x).toFixed` throws on `loadPreset(0)` in certain paths. Shell-isolation hardening works around it.
- [.] POMDP Machine: cross-preset state leak (F depends on previous preset's settle). Cold-load values match baseline; the Shell doesn't touch the compute.

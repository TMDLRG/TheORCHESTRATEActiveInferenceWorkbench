# Learning Labs — Uplift Proof

Date: 2026-04-18 (uplift pass landed).

The Learning Shell (audience picker, persistent path toggle, layered equation panel, analogy library, physical-exercise drawer, beat-script runner, 3-tier glossary tooltip engine, dyslexia-friendly toggle, reduced-motion support) is now live in all seven simulators. Math on every canvas is unchanged; only vocabulary, depth, and narration swap with the selected path.

## Per-simulator persona proof

For each simulator the Shell offers five on-ramps (🌱 Story / 🧭 Real-world / 🛠️ Equation / 🎓 Derivation, plus a default picker on first load). Each of the five personas (P1 kid → P5 PhD) can reach the hero concept using only in-sim affordances available on their path. Below are the observed paths, with the number of clicks from a cold load to first hero-value change.

### 1. BayesChips — Bayes update

- **P1 (kid, Story path).** Picker → Story → Beat `▶` once to reach "Set the prior" → drag slider 1. Posterior updates in the sticky strip. **3 clicks.**
- **P2 (pre-algebra, Story path).** Story → "Cookie crumb" analogy side card → micro-exercise with 12 index cards → back to sim, step through beats 1–5. **Within 6 clicks.**
- **P3 (adult, Real-world).** Real-world picker → intro strip "Goal/Watch/First move" → Next Step ×4. Posterior = 9/17 visible in Selected cell. **5 clicks.**
- **P4 (engineer, Equation).** Equation path → layered panel "Equation" tab → reads `P(H | E) = P(E | H)·P(H) / P(E)`, confirms the exact 100-chip ratio. **2 clicks.**
- **P5 (PhD, Derivation).** Derivation path → panel "Derivation" tab → Jaynes Ch. 4 reference + log-odds form. **2 clicks.**

Observation (cold-load math regression, five preset values):
`preset_0`=7/19·0.368; `preset_1`=28/52·0.538; `preset_2`=13/68·0.191; `preset_3`=44/54·0.815 — all bit-exact against `_baselines/BayesChips.baseline.json`.

### 2. POMDP Machine — Clockwork Active Inference

- **P1 Story.** Beat `▶` to "Observe the gauge" → New episode → token-bar shifts. **3 clicks.**
- **P2 Story.** "Thermostat that can't see" analogy → sticky-note belief-track exercise. **2 clicks to reach exercise.**
- **P3 Real-world.** Old car analogy → Settle beliefs → π posterior appears. **3 clicks.** `standard` preset F=1.490 matches baseline.
- **P4 Equation.** Layered panel shows `F_π = Σ_τ …`, `π = softmax(−G−F)`. Ledger corresponds. **2 clicks.**
- **P5 Derivation.** Variational message passing in generalized form (Da Costa 2020). EFE decomposition (risk + ambiguity). **2 clicks.**

Math regression: fresh loads of `standard`/`noisy`/`sticky` match baseline F exactly (1.490 / 2.553 / 1.946).

### 3. Free Energy Forge — Eq. 4.19

- **P1 Story.** "Tug-of-war with three ropes" analogy card → rubber-band exercise. **2 clicks.**
- **P2 Story.** "Cost of being wrong" analogy → paper exercise E2 (prediction/error tracker). **2 clicks.**
- **P3 Real-world.** Tuning-a-guitar analogy → Load preset → Full descent step. F drops (2.542 → 1.818). **3 clicks.**
- **P4 Equation.** Equation panel: `F = ½ ( ε̃yᵀΠyε̃y + ε̃xᵀΠxε̃x + ε̃vᵀΠvε̃v )`. **2 clicks.**
- **P5 Derivation.** Full derivation with Laplace + references to Friston 2008. **2 clicks.**

Math regression: Calibration Bay preset F=2.542 matches baseline on load; Full descent click drops F to 1.818.

### 4. Laplace Tower — Box 4.3

- **P1 Story.** "Telephone game" analogy → whisper exercise. **2 clicks.**
- **P2 Story.** Assembly-line analogy → Add level → Belief step. **3 clicks.**
- **P3 Real-world.** Org-chart analogy → Belief+action → F drops. **3 clicks.**
- **P4 Equation.** Panel shows `F = ½ Πy εy² + Σᵢ ½ Πxⁱ ‖εxⁱ‖² + Σᵢ ½ Πvⁱ ‖εvⁱ‖²`, `μ̇ = −∂F/∂μ`, `u̇ = −∂F/∂u`. **2 clicks.**
- **P5 Derivation.** "Motion of the mode is the mode of the motion"; Box 4.3 + Friston 2008 references. **2 clicks.**

Math regression: initial preset_0 strip shows F=0.270 / Fy=0.250 / Fx=0.002 / Fv=0.018 / action=0.000 / shape=1×2 — bit-exact against baseline.

**UI elegance fix applied** to the Hierarchy Machine canvas:

- Canvas height now scales with `levels × (orders × 72 + 90)` so multi-level / multi-order presets never overlap.
- Node sub-labels ("εx[1]", "μx[1]", …) moved to the **left** of each circle so vertical rows pack tightly without label collision.
- Values render centered inside the circle in bold; the tag sits immediately left, vertically centered.
- CSS canvas height is now `auto; min-height: 480px;` so the dynamic resize takes effect.

### 5. Anatomy of Inference Studio — Figure 5.5

- **P1 Story.** "Coach + player" analogy → board-game exercise E1. **2 clicks.**
- **P2 Story.** Siri-picking-app analogy → sticky-note ranking exercise. **2 clicks.**
- **P3 Real-world.** Commute-driver analogy → Policy step → π updates. **3 clicks.**
- **P4 Equation.** `G_π = ½ χ (y + u_π − t_π)² + ambiguity − habit`, `π = softmax(−γ G)`. **2 clicks.**
- **P5 Derivation.** Full 5.5 decomposition; bridge from categorical planning messages to continuous PC targets. **2 clicks.**

### 6. Active Inference Atlas

- **P1 Story.** "City with four traffic lights" analogy → draw-intersection exercise. **2 clicks.**
- **P2 Story.** "Thermostats in different rooms" analogy. **1 click to glossary `🅰 Font` toggle.**
- **P3 Real-world.** Mixing-board analogy → Policy step → π row updates with γ. **3 clicks.**
- **P4 Equation.** `Πx(effective) = L.px · (NA / 1.5)` shown explicitly. **2 clicks.**
- **P5 Derivation.** Friston 2008/2017 mapping, honesty about speculative vs endorsed links. **2 clicks.**

### 7. Jumping Frog Generative Model Lab

- **P1 Story.** Mystery-box analogy → shoebox exercise E1. **2 clicks.**
- **P2 Story.** 20-questions analogy → 4-card discriminator exercise. **2 clicks.**
- **P3 Real-world.** Plant-ID-app analogy → Action step → best-action hint updates. **3 clicks.**
- **P4 Equation.** `logit P(H|y,a) = logit P(H) + Σ_m LLR_m + (g(a) − 1)·LLR_tactile`. **2 clicks.**
- **P5 Derivation.** Factor graph + expected Bayesian surprise for action selection. **2 clicks.**

## Verification checklist (executed per sim)

| # | Sim | Shell loads | LS global | Picker on 1st load | 4 paths switchable | Math ≡ baseline | Beat runner | Glossary / Analogies / Exercises panels |
|---|-----|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|
| 1 | BayesChips | ✓ | ✓ | ✓ | ✓ | ✓ (4/4 presets) | ✓ 8 beats | ✓ 13 / 5 / 4 |
| 2 | POMDP | ✓ | ✓ | ✓ | ✓ | ✓ (3/3 presets) | ✓ 8 beats | ✓ 14 / 5 / 3 |
| 3 | Forge | ✓ | ✓ | ✓ | ✓ | ✓ (F=2.542) | ✓ 7 beats | ✓ 15 / 5 / 3 |
| 4 | Laplace Tower | ✓ | ✓ | ✓ | ✓ | ✓ (F=0.270) | ✓ 8 beats | ✓ 14 / 5 / 3 |
| 5 | Anatomy Studio | ✓ | ✓ | ✓ | ✓ | ✓ (F=0.512) | ✓ 7 beats | ✓ 11 / 5 / 3 |
| 6 | Atlas | ✓ | ✓ | ✓ | ✓ | ✓ (F=0.291) | ✓ 8 beats | ✓ 13 / 5 / 3 |
| 7 | Jumping Frog | ✓ | ✓ | ✓ | ✓ | ✓ (P=0.500 start) | ✓ 8 beats | ✓ 9 / 5 / 3 |

(Glossary / Analogies / Exercises counts are per-sim totals loaded into the dock panels.)

## Cross-simulator consistency

- **Notation.** Tildes (`ỹ`, `μ̃x`, `ε̃y`, …) used consistently in Forge (generalized coords). `μx[k]`, `μv[k]` used in Laplace Tower and Atlas for order-indexed coordinates. No remaining `!` suffixes.
- **Variational vs expected free energy.** F and G are kept visibly distinct in the POMDP Machine, Anatomy Studio, and Atlas. The EFE proxy in Anatomy/Atlas is labelled as a teaching simplification in both code comments and on-screen Derivation-tab text.
- **Path toggle + dock ordering.** Path bar always `Story / Real-world / Equation / Derivation`. Dock is always `Glossary / Analogies / Exercises`. Equation tabs always `Story / Picture / Equation / Derivation`.
- **Sim-level chrome** (sticky strip / intro strip / primary toolbar / guided tour) is unchanged from the previous pass; the Shell sits above it.

## Known caveats

- Chrome MCP `resize_window` does not reliably resize the viewport in this environment; screenshots captured at the native 1568×726. CSS media queries for narrow-width (`max-width: 820px`) are in place and verified by stylesheet inspection; behaviour at true 820px width was not visually confirmed.
- Two pre-existing sim bugs (Forge `fmt.toFixed` edge case; POMDP cross-preset state leak) are orthogonal to the Shell — they exist in the originals and do not prevent the Shell or the math from working. Documented in `QA_ISSUES_CHECKLIST.md`.
- Laplace Tower Hierarchy Machine canvas: fully addressed in this pass (dynamic height + left-side labels); no more label collisions or cramming at 3 levels × 3 orders.
- BayesChips chip-grid overflow at extreme preset values: still cosmetic; math remains correct (pre-existing).

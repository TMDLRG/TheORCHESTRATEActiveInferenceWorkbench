# Learning Labs — Approachability & Adaptive-Pedagogy Uplift Plan

## 1. Intent

Make every simulator learnable by anyone from a curious 5th grader who has never seen algebra to a mathematician who wants the formal derivation. Do this without dumbing down the math or over-complicating the interface for advanced learners. Build the adaptive machinery once as a shared "Learning Shell" and then give every sim the per-topic content that shell needs to plug in.

Non-goals: gamification for its own sake, infantilizing the math, framework migration, cloud infrastructure, login.

## 2. Audience model

Five distinct personas. Each simulator must have at least one meaningful on-ramp for each one.

| ID | Persona | Numeracy floor | Prefers |
|----|---------|----------------|---------|
| P1 | **Curious kid (≈ 5th grade)** | Counting, fractions as "out of 10", simple ratios. | Story, physical objects, one hero quantity at a time. |
| P2 | **Pre-algebra learner (≈ 8th grade)** | Percentages, decimals, very light variable-as-letter. | Step-by-step narration, short checkable exercises, seeing the rule play out. |
| P3 | **Curious adult, no recent math** | Arithmetic, "which is more likely?" reasoning, everyday analogies. | Real-world analogies, reason-through-it prose, a practical mission. |
| P4 | **Quantitative adult (engineer, biologist, data worker)** | Algebra, probability, basic calculus. | Equations tied to code, short derivations, parameter sweeps. |
| P5 | **Expert (PhD in math / physics / ML)** | Fluent in measure theory, variational calculus, Bayesian machinery. | Full formalism, citations, proofs, derivation links. |

Each persona maps to a **Learning Path** (see §4). The Learning Path controls the vocabulary, the visible equations, the depth of the ledger, the narration style, and the suggested exercises.

## 3. Core design principles

1. **One interface, five dictionaries.** The *same* state, canvas, and controls stay on screen across paths. We swap vocabulary (labels, tooltips, captions) and the *depth* of the math panel. No persona gets a "baby" UI and no one gets a "pro" UI — the chrome is identical. This is honest and prevents a ceiling.
2. **Progressive disclosure, both ways.** A 5th-grader can tap "show me the equation" and see it; a PhD can tap "show me a toy analogy" and see it. Neither direction is locked.
3. **Analogy before algebra.** Every new symbol enters the UI with a real-world example visible within one click. Equations never appear naked.
4. **Show the same thing three times, differently.** For every quantity on screen, the sim surfaces (a) an everyday-object version, (b) a picture/graph version, and (c) an equation version. They point at the same state.
5. **Physical companion exercises.** Each simulator ships a small deck of offline activities the learner can do with household objects (coins, dice, index cards, paper cups, sticky notes, string). This is where intuition locks in.
6. **Checkable micro-quizzes, never blocking.** Short "does this click?" prompts between steps. Learners can always skip. Wrong answers never shame — they route to a kinder analogy.
7. **No unannounced jargon.** The first time any term appears, it's underlined and hoverable for a one-sentence plain definition plus one formal definition.
8. **Adaptivity is a suggestion, not a sentence.** The sim proposes a path at load based on a quick "what sounds most like you?" card, but the learner can switch paths at any time from a persistent toggle.

## 4. The Learning Shell (shared across all 7 sims)

A single inline JS+CSS snippet every sim copy-pastes. Components:

### 4.1 Audience picker
On first load (no preference stored), show a 4-card picker:
- 🌱 **"I want the story"** (P1 / P2): narrative + physical objects
- 🧭 **"I want real-world examples"** (P3): analogies + practical missions
- 🛠️ **"I want the equations"** (P4, current default)
- 🎓 **"I want the full derivation"** (P5): proofs + citations

Selection stored in `localStorage`. Persistent toggle in the header lets the learner switch anytime. Switching never resets state — only swaps the vocabulary.

### 4.2 Tooltip engine
- Every math symbol rendered anywhere on screen gets a `data-term` attribute.
- A central glossary `TERMS = { "μ": {kid: "...", adult: "...", phd: "..."}, ... }` provides three tiers of definition.
- Hover (or tap on touch) opens a small card showing the definition at the current learning path, plus a "other views" link that shows all tiers side by side.
- Everything hoverable also appears in a searchable glossary drawer.

### 4.3 Layered equation panel
Current sims have one "Core teaching equations" block. Replace with a tabbed panel with four tabs:
- **Story**: the equation translated to one narrative sentence.
- **Picture**: a diagram of the equation (arrows from quantities to result).
- **Equation**: the current math block.
- **Derivation**: for P5 — the formal derivation + link to the original theorem.

Tabs remember the learner's default path but can be clicked freely.

### 4.4 Narrated step script
Each sim defines an ordered list of *beats* — like a script. Each beat has:
- A hero quantity (1 primary, up to 2 secondary).
- A one-sentence story at each learning path.
- A visible highlight target (reused from the guided tour machinery we already built).
- A micro-exercise (optional).

The "Run" button in the toolbar advances one beat. A visible beat counter shows `beat k / N`. Learners can scrub forward/back.

### 4.5 Analogy library
Each simulator declares up to 5 analogies. Shown in a collapsible "Analogies" side card. Each analogy has:
- A title (e.g., "Medical test").
- A concrete scenario in plain English.
- A mapping table from every sim-variable to the analogy's real-world counterpart.
- A matching micro-exercise.

Switching analogies re-labels the sim's readouts in-place (if the learner opts in) using the mapping table.

### 4.6 Physical-exercise deck
A compact drawer at the bottom of the sim. Shows a single card at a time:
- **What you need** (coins, cards, cups, …).
- **Do this** (3–5 steps).
- **What you should see** (target outcome).
- **Back to the sim** (suggests the next click).

Exercises are designed for 2–5 minutes with household objects. The shell ships a few shared exercises (coin game, cup-and-ball); each sim adds 3–6 sim-specific ones.

### 4.7 Adaptive difficulty
For sims with a mission/target:
- If the learner clears the mission with < 3 actions, the sim surfaces a "harder variant" suggestion (preset with a lower target).
- If the learner struggles (> 20 actions without clearing), the sim offers: "try the story path" or "try a kid-level physical exercise".
- No forced gating.

### 4.8 Checkable micro-quizzes
Between beats. Two-to-three button quick checks ("which bar is longer?", "did the number go up or down?"). Wrong answers route to the "Story" tab of the equation panel and re-suggest the relevant analogy. Never block.

### 4.9 Reading-level and language pass
Every piece of Story-path prose targets Flesch-Kincaid ≤ 6. Every Equation-path label may assume high-school algebra. Every Derivation-path may assume undergrad real analysis. We commit to this consistently.

### 4.10 Accessibility baseline
- Keyboard-only operation for all primary controls.
- ARIA labels on buttons, roles on the shell, live regions for status-strip updates.
- Prefers-reduced-motion halves animation durations.
- Contrast meets WCAG AA everywhere (we already fixed some muted-text contrast in the previous pass).
- Optional "dyslexia-friendly font" toggle in a settings menu (inline CSS; no asset fetch).

## 5. Per-simulator uplift

For each sim, we define: hero concept, five analogies (one per persona), a physical-exercise set, the beat script, and the glossary entries it contributes.

### 5.1 BayesChips.html — exact Bayes update

**Hero concept**: "new evidence changes how likely an idea is, proportionally to how much that evidence is expected under it."

**Analogies**
1. **Kid (P1)**: *"The marble jar."* One jar has mostly red marbles, another mostly blue. Someone draws a red. Which jar is more likely?
2. **Pre-algebra (P2)**: *"The cookie theft."* 12 kids at a party — 3 love peanut butter cookies. You find a peanut butter crumb on a sleeve. Who do you suspect?
3. **Adult (P3)**: *"The medical test."* A disease affects 1 in 100 people. A test catches 9 out of 10 cases and false-alarms 1 out of 100. If the test beeps, how likely do you have the disease?
4. **Quantitative (P4)**: "spam filter": hidden state = spam yes/no, evidence = word 'offer'.
5. **PhD (P5)**: full Bayes' rule derivation + reference to Jaynes Chapter 4.

**Physical exercises**
- E1: 100 index cards; mark 12 gold, 88 steel; mark 9 gold + 8 steel as "stamped"; physically pull out the stamped ones; count gold in the pile.
- E2: coin-flip mission: one fair coin, one weighted coin in two cups; pick a cup, flip 3 times, use counts to guess the cup.
- E3: family-member-guess game: one family member is hiding; clues dribble in; track how each clue moves your guess.

**Beat script (8 beats)**
1. Look at the whole world of 100 chips. 2. Slide the gold count (prior). 3. Slide how often the stamp appears among gold (likelihood H). 4. Same for steel (likelihood not-H). 5. Pick what you observe. 6. Predict the posterior. 7. Run the machine, see both the pile and the equation. 8. Score; try a different scenario.

**Glossary contributions**: H, ¬H, P(H), P(E|H), P(H|E), base rate, likelihood, posterior, normalization.

### 5.2 active_inference_pomdp_machine.html — discrete POMDP active inference

**Hero concept**: "you can't see inside, so guess what's likely, imagine what would happen if you acted, then pick the action that best serves you."

**Analogies**
1. **Kid**: *"The rattle machine."* A machine is either calm or rattly inside. You can't open it. You hear a sound and decide whether to rest or fix it.
2. **Pre-algebra**: *"Thermostat that can't see."* You only feel room temperature, not the thermostat's dial. Turn up or wait?
3. **Adult**: *"Old car."* It's either fine or failing. The engine noise is your only clue. Drive it, or take it in?
4. **Quantitative**: partially observable Markov decision process with softmax policy under expected free energy.
5. **PhD**: variational message passing (Eq 4.13) + EFE decomposition (risk + ambiguity), citations.

**Physical exercises**
- E1: opaque cups with colored beads — pick a cup by feel, infer which it is from one draw.
- E2: 2-coin planning: write each 2-step plan on paper, simulate each on a friend who holds the hidden state card; see which plan's outcomes you'd prefer.
- E3: dice-based transition tables — roll to update hidden state; keep belief on a sticky-note track.

**Beat script (10 beats)**
1. Meet A, B, C, D. 2. Observe the gauge. 3. One message tick. 4. Watch q(s) settle. 5. Score each plan's F. 6. Score each plan's G. 7. Sum → softmax. 8. Auto-act the best. 9. See the hidden state move. 10. Try a different preset.

**Glossary contributions**: A, B, C, D, F, G, π, posterior over policies, message passing.

### 5.3 free_energy_forge_eq419.html — quadratic free energy

**Hero concept**: "three kinds of disagreement — with what you see, with how things flow, and with what you expected — each weighted by how strict we are about them."

**Analogies**
1. **Kid**: *"A tug-of-war with three ropes."* Your μ is the knot. Each rope pulls toward a target; the stiffest rope wins.
2. **Pre-algebra**: *"Cost of being wrong."* Wrong about what you see costs a little, wrong about momentum costs a little, wrong about expectations costs a little. Total cost = F.
3. **Adult**: *"Tuning a guitar."* You pluck a string (ỹ), you have a target (prediction), the tuner reads the error, you turn the peg (μ).
4. **Quantitative**: Gaussian log-evidence lower bound with diagonal precision.
5. **PhD**: full derivation from variational inference, link to the Laplace approximation proof.

**Physical exercises**
- E1: rubber band + 3 weights — let the knot find equilibrium between three pulls.
- E2: paper "prediction/error" tracker — record μx, μv, errors by hand across iterations.
- E3: spring-and-scale analogue — visualize precision as spring stiffness.

**Beat script (7 beats)**
1. Meet ỹ. 2. Guess μ̃x, μ̃v. 3. Compute ε̃y (eye-term). 4. Compute ε̃x (flow-term). 5. Compute ε̃v (expectation-term). 6. Sum F. 7. Take a gradient step. Repeat.

### 5.4 laplace_tower_predictive_coding_builder.html — multi-level predictive coding

**Hero concept**: "build a tower. Each floor tries to explain the floor below. When every floor agrees with its neighbors, the tower is stable."

**Analogies**
1. **Kid**: *"Telephone game."* Each whispers to the next. When the whisper matches, nobody corrects. When it doesn't, a correction goes back up.
2. **Pre-algebra**: *"Assembly line."* Managers predict the line below. Workers report errors up.
3. **Adult**: *"Organization chart"* — VP expects sales, sales reports gaps, VP updates expectation.
4. **Quantitative**: linear-Gaussian hierarchical model with generalized coordinates.
5. **PhD**: message passing in GC, "motion of the mode is the mode of the motion" with proof sketch.

**Physical exercises**
- E1: 3 stacked paper cups, each predicting the next cup's marble count.
- E2: whisper game with 3 people, introduce a lie on level 2; watch where corrections flow.
- E3: "who corrects whom?" Sticky-note diagram.

**Beat script (8 beats)**
1. Start with 1 level. 2. Belief step. 3. Add level. 4. See upper-level predictions flow down. 5. See errors flow up. 6. Add an order (think faster). 7. Action step. 8. Auto-run to equilibrium.

### 5.5 anatomy_of_inference_studio.html — Figure 5.5

**Hero concept**: "habits, plans, goals, predictions, and actions are one machine working together."

**Analogies**
1. **Kid**: *"Coach + player."* Coach (plan) picks the move; player (body) does it; both watch the game (sensory) and update.
2. **Pre-algebra**: *"Siri deciding what app to open."* Habit says "usually music"; goal says "you asked for weather"; final action blends both.
3. **Adult**: *"Driver on a familiar commute."* Habit dominates; a changed goal (stop for gas) overrides.
4. **Quantitative**: scalar-EFE proxy for policies + continuous PC hierarchy, labeled as a teaching simplification.
5. **PhD**: full Figure 5.5 decomposition; explicit map from categorical planning messages to continuous bridge messages.

**Physical exercises**
- E1: board game with habit cards and goal cards; play rounds.
- E2: two sticky notes — "habit" vs "goal" — rank which wins each move.
- E3: role-play: one person is the habit, one is the goal, one is the action; arbitrate.

### 5.6 active_inference_atlas_educational_sim.html — cortex + neuromodulation atlas

**Hero concept**: "the same F-minimizing machinery with different precision knobs plays different roles in a brain-like story."

**Analogies**
1. **Kid**: *"A city with four traffic lights."* Each light is a neuromodulator; turning one up or down reroutes traffic.
2. **Pre-algebra**: *"Thermostats in different rooms."* Each knob turns one room's sensitivity up or down.
3. **Adult**: *"Volume knobs on a mixing board."* ACh, NA, DA, 5-HT each control a channel.
4. **Quantitative**: same F/G as POMDP + Laplace Tower, with precision parameters mapped to ACh, NA, DA, 5-HT.
5. **PhD**: review Friston 2008/2017 mapping; flag which mappings are widely endorsed and which are speculative.

**Physical exercises**
- E1: four volume sliders on a cardboard mixing board — label them and play with "noise" (dice rolls).
- E2: turn-down-the-lights analogy: close eyes in a room, notice how the "sensory precision" down-weights visual input.
- E3: family "who's in charge?" exercise for policy precision.

### 5.7 jumping_frog_generative_model_lab.html — multi-modal concept inference

**Hero concept**: "many clues, one guess. Picking an action that gets you a useful clue beats guessing."

**Analogies**
1. **Kid**: *"Guess the animal in the box."* You can see a color, hear a sound, feel the texture. What is it?
2. **Pre-algebra**: *"20 questions."* Best question = the one that splits possibilities.
3. **Adult**: *"Plant identification app."* Photo + sound + smell each vote; you choose which to capture.
4. **Quantitative**: log-odds form of Bayes over modalities; action as precision gain on one channel.
5. **PhD**: factor graph + full derivation of expected Bayesian surprise for action selection.

**Physical exercises**
- E1: mystery box with a hidden object; players pick which sense to use (touch/look/listen).
- E2: 4-card trick: each card has a fact; pick the card most likely to discriminate.
- E3: blindfold texture game — the "touch" action really does deliver new info.

## 6. Shared content library (once, reused)

- **GLOSSARY.json** — every math symbol with 3 tiers of definition.
- **ANALOGIES.json** — every analogy with its mapping table and exercises.
- **EXERCISES/** — one Markdown sheet per physical exercise, printable on half a sheet.
- **BEATS/** — one JSON per sim defining the beat script.

All inlined into each sim's HTML via a build-optional pattern: either literally copy-pasted (default) or fetched from a sibling `.json` that sits next to the HTML. Both work on the file system without a build step.

## 7. Reading level and tone guide

- Story path: 5th-grade reading level, 2nd-person ("you see", "you pick"), no unannounced jargon.
- Real-world path: 8th-grade reading level, everyday analogy first, then the variable name.
- Equation path: high-school algebra assumed. Inline math via Unicode, not MathJax (stays standalone).
- Derivation path: undergrad analysis assumed. Proof sketches end with references.

## 8. Implementation order

1. **Shell scaffolding (1 sim, BayesChips as proof)**: audience picker, path toggle, tooltip engine, layered equation panel, analogy side card, physical-exercise drawer, beat script runner.
2. **Glossary seeding**: write the 3-tier definitions for ~40 shared symbols.
3. **Analogy & exercise content** for BayesChips end-to-end.
4. **Roll the shell to the remaining 6 sims** one at a time, each landing with its own analogies, exercises, and beat script.
5. **Reading-level pass** on every Story-path line (automated readability check + manual edit).
6. **Accessibility pass** (keyboard + aria).
7. **Author-mode fixtures**: a hidden `?author=1` query flag that surfaces "missing glossary terms" and "unwired analogies" so maintainers can see coverage.

## 9. Verification (for each sim)

1. **Reading-level lint** — automated pass at each learning path's prose.
2. **Glossary completeness** — every `data-term` attribute in the DOM has a matching `TERMS[]` entry at all 3 tiers.
3. **Beat-script sanity** — every beat highlights a selector that exists and shows text at every learning path.
4. **Analogy mapping** — every analogy's variable map covers every symbol the sim exposes.
5. **Physical-exercise printability** — exercises print clean at half-letter.
6. **Path-switch stability** — switching path mid-session does not reset sim state, does not throw, and does relabel visible controls within 100 ms.
7. **Chrome MCP UAT** — each path captured in a screenshot at 1440×900 and 820×900. Each path has a quick "do a belief step" interaction confirming the sim responded.
8. **No-persona default works** — if `localStorage` is empty the picker shows once; dismissing it defaults to the Real-world path (P3) — the broadest single on-ramp.

## 10. Out of scope for this uplift

- External LLM integration for "explain this to me in my words" (could be added later; deliberately kept out so the labs stay offline-capable).
- Cloud progress tracking / multi-device sync.
- Speech / narration audio.
- Full curriculum structuring across sims (they remain independent tools).
- Pro-grade math rendering (MathJax) — Unicode-only keeps the standalone constraint.

## 11. Risks and mitigations

- **Risk: interface gets cluttered with four paths and five analogies.** *Mitigation*: every path hides the UI affordances it doesn't use; analogies live in a collapsible side card; only the currently selected path's vocabulary is rendered in the live UI.
- **Risk: kid-path prose feels condescending to adults.** *Mitigation*: the adult paths never see it. Kids' prose is tested on real 5th-graders before landing.
- **Risk: PhD path over-promises.** *Mitigation*: we label derivations "proof sketch" when they are sketches; full proofs link out to the canonical source.
- **Risk: content maintenance burden.** *Mitigation*: single glossary + analogy JSON per sim, review rules documented; unwired terms surfaced by `?author=1`.
- **Risk: physical exercises are too hard to set up.** *Mitigation*: every exercise must pass a "household-objects-only" test; hot-glue, timer, or special paper disqualifies.

## 12. Files this plan will touch

- All seven HTML files under `learninglabs/`.
- New shared snippets in inline `<style>`/`<script>` of each (copy-pasted from a maintenance template).
- Optional sibling JSONs: `learninglabs/glossary.json`, `learninglabs/analogies.json`, `learninglabs/exercises/*.md`, `learninglabs/beats/*.json` (sim-keyed).
- `QA_MASTER_REPORT.md`, `FINAL_ACCEPTANCE_TABLE.md`, `QA_ISSUES_CHECKLIST.md` — updated after each sim lands.

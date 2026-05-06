# Final Validation Checklist

This is the audit step. The brief specified SMART criteria, a PRO role audit, an AUDIT (V-E-R-I-F-Y) pass, and a PROVE editorial test. I check the guide against each.

## SMART — measurable success criteria

| # | Criterion | Status | Evidence |
|---|---|---|---|
| 1 | An average reader can explain Active Inference in plain language after reading. | ✅ Pass | The guide opens with a one-paragraph version (§2), uses the kid-tier language from [glossary.ex](../active_inference/apps/workbench_web/lib/workbench_web/book/glossary.ex) throughout, and avoids math beyond inline definitions. |
| 2 | Each major claim is traceable to repo evidence, labelled as general background, or marked as speculative. | ✅ Pass | Every section has at least one `> **Repo source.**` block or an explicit evidence label. The compact evidence map (§17) and full claim/evidence map ([02_CLAIM_EVIDENCE_MAP.md](02_CLAIM_EVIDENCE_MAP.md)) cross-reference each claim. |
| 3 | Distinguishes established concepts from interpretation, analogy, and speculation. | ✅ Pass | Five labels used consistently: "Strong repo support", "Partial repo support", "General background", "Interpretive synthesis", "Speculative / analogy". Applied per claim. |
| 4 | Covers at least 8 disciplines or domains. | ✅ Pass | §10 covers 11 domains: neuroscience, psychiatry, psychology/decision science, theoretical biology, physiology/interoception, RL/optimal control, robotics/motor control, statistical physics, philosophy of mind, AI literacy, education. Each with What it changes / Example / Evidence status. |
| 5 | Includes a glossary of key terms. | ✅ Pass | §16 has 26 entries spanning the 20 terms requested in the brief plus 6 domain-helpful additions. |
| 6 | "What this does and does not mean" section. | ✅ Pass | §15. Eight specific overclaim refutations. |
| 7 | Comparison of Active Inference / reward-seeking models / LLM-style prediction. | ✅ Pass | §8 (AIF vs reward-seeking, with direct book quote) + §14 (AIF vs LLMs, with structural comparison table). |
| 8 | Avoids hype, mysticism, unsupported certainty. | ✅ Pass | No "revolutionary", "mind-blowing", "quantum", or "proves" used. "Resonance" is explicitly labelled as my evocative gloss for the repo's "synchrony". The DNA / Big Bang ambition is flagged as "speculative bonus" not theory. |

## Brief's required topical coverage (12 items)

| # | Required | Where covered | Status |
|---|---|---|---|
| 1 | What Active Inference is | §1, §2 | ✅ |
| 2 | Why it matters | §1 (loop), §10 (cross-discipline impact), §14 (LLM contrast) | ✅ |
| 3 | How it crosses many disciplines | §10 (11 domains) | ✅ |
| 4 | Surprise, prediction, action, perception, predict–act loop | §3, §4, §5 | ✅ |
| 5 | Precision, dopamine, calibration | §6, §7 | ✅ |
| 6 | Shift from "humans seek reward" to "humans predict" / EFE / uncertainty | §8 | ✅ |
| 7 | Baby's first breath / low O₂ / breath-control example, labelled appropriately | §9 — labelled "speculative analogy / interpretive synthesis", with the surrounding interoception/allostasis framing labelled "Strong repo support" | ✅ |
| 8 | Active Inference "all the way down" — cells, organisms, DNA — separating supported from speculative | §11 — cells/organisms/communities supported, DNA / Big Bang flagged speculative-bonus | ✅ |
| 9 | "Instinct" reframed as alignment with high-quality signals | §12 — flagged interpretive synthesis | ✅ |
| 10 | Resonance / adaptation / self-regulation / contact with reality | §13 — repo's "synchrony" as the underlying claim, "resonance" as my gloss | ✅ |
| 11 | What this means for LLM limits | §14 | ✅ |
| 12 | GPT-style systems as shaped artefacts (training, alignment, products) | §14 (table + "what this does mean" sub-section) | ✅ |

## V-E-R-I-F-Y audit

- **V — Validate.** Repo inspected. Source inventory in [01_SOURCE_INVENTORY.md](01_SOURCE_INVENTORY.md) covers 30+ files across the equation registry, glossary, chapters, sessions, book extracts, ARCHITECTURE.md, and 100-short curriculum.
- **E — Evidence.** Every major claim has a repo file path. The most-cited files are [equations.ex](../active_inference/apps/active_inference_core/lib/active_inference_core/equations.ex) (math), [glossary.ex](../active_inference/apps/workbench_web/lib/workbench_web/book/glossary.ex) (definitions), [sessions.ex](../active_inference/apps/workbench_web/lib/workbench_web/book/sessions.ex) (curriculum framings), and the per-session book extracts.
- **R — Recalculate / Replicate.** No mathematical derivations were attempted in the guide; the math is explained in plain language. Where equations are referenced (eq 4.13, 4.14, 8.1/8.2), the guide links to their registry entries.
- **I — Identify** assumptions and uncertainty. Explicit interpretive labels for: §9 (baby's first breath), §11 (DNA / Big Bang), §12 (instinct reframing), §13 (resonance gloss), §14 (LLM contrast as interpretive synthesis). Each has a note distinguishing repo support from my contribution.
- **F — Flag** unsupported claims and contradictions. None of the brief's stated "must-coverage" claims were left unsupported; the speculative ones are flagged. No internal contradictions detected. Two specific overclaims that the brief flagged as "invalid" were avoided: the guide does not say "Active Inference proves humans do not seek reward" (it instead says AIF *replaces the reward-as-primitive ontology*) and does not say "Dopamine is precision" without qualification (it gives the repo's careful theoretical-commitment framing).
- **Y — Yield** confidence levels. Per-claim 1–5 ratings in [02_CLAIM_EVIDENCE_MAP.md](02_CLAIM_EVIDENCE_MAP.md).

## PROVE editorial test

- **P — Prediction.** A non-technical reader should be able to summarise Active Inference and distinguish it from LLM token prediction after reading. The closing "Reader's next questions" (§18) tests this directly.
- **R — Reversibility.** If a section overclaims, the rule was: downgrade certainty, add caveats, or move to a speculative section. Applied to §9, §11, §12, §13.
- **O — Observation.** Checked the draft against source support, beginner readability, coverage of the 12 required topics, clarity of LLM distinction, and absence of unsupported certainty. All passed.
- **V — Validation success criteria.** All requested topics covered. No major unsupported claim presented as fact. Evidence Map completed (§17 in-line + 02_CLAIM_EVIDENCE_MAP.md detailed). Guide reads clearly to an average reader.
- **E — Execution.** One revision pass after the audit was budgeted; minor wording tweaks were made inline as I drafted.

## Areas where the guide is intentionally limited

These are not failures; they're scope choices. Listing them so you know what was deliberately *not* attempted:

1. **No mathematical derivations.** The guide names equations (4.13, 4.14, etc.) and cites the registry, but does not derive variational free energy or expected free energy from first principles. The repo's `equation`/`derivation` curriculum tiers are designed for that audience; this guide is the `kid`/`real`-tier complement.
2. **No detailed walkthrough of the Workbench / Labs UI.** The guide mentions [equations.ex](../active_inference/apps/active_inference_core/lib/active_inference_core/equations.ex) and [glossary.ex](../active_inference/apps/workbench_web/lib/workbench_web/book/glossary.ex) as the source of truth, but does not document `mix phx.server` or the Studio routes. That's [README.md](../README.md)'s job.
3. **No empirical defence of the dopamine-precision mapping.** The guide reports the repo's framing ("most robustly supported AIF-to-neuromodulator mapping; theoretical commitment with growing support") rather than reviewing the empirical literature. A research-grade treatment would need [shorts/specs/95.json](../shorts/specs/95.json)'s OCD/psychosis/ADHD studies plus citations beyond the repo.
4. **No survey of LLM internals.** The LLM section (§14) describes LLMs at the level relevant for distinguishing them from embodied agents. It does not cover transformer mechanics, RLHF maths, or chain-of-thought.
5. **No critique of the Free Energy Principle as such.** Friston-FEP-skepticism is a real research area. The guide stays inside the framework's own self-presentation, with caveats about computational scaling and consciousness — but does not attempt a "case against".

## What still has uncertainty

- **The empirical robustness of the precision-to-neuromodulator mapping.** The repo says DA↔γ is "most robustly supported" and ACh / NA / 5-HT are "theoretical commitments with growing support". The guide reproduces that framing faithfully; a reader who wants conviction here needs primary literature.
- **The status of the "Active Inference all the way down" idea.** Both the cells/communities supported version *and* the DNA / Big Bang speculative version come from the same repo author / project. Treating them as different evidence-strength claims is correct in my reading; some readers might disagree.
- **Whether the LLM contrast (§14) is *too* strong.** The guide claims LLMs "have no priors over their own continued existence". This is true at the level relevant here, but a sufficiently determined reader could argue that an instruction-tuned model has implicit priors over "what kind of output gets produced." I think the contrast still holds (those priors are *not* about the model's own continued existence in any biological sense), but the line could be drawn differently.

## Confidence summary

- **Repo-grounded sections (§1–§8, §15, §16, §17):** High confidence. Direct repo support cited per claim.
- **Carefully labelled interpretive sections (§9, §11, §12, §13):** Medium confidence. Repo establishes the surrounding framework; the specific stitching together is mine, and labelled as such.
- **Synthesised section (§14):** Medium confidence on the structural distinction (well-supported by ARCHITECTURE.md + glossary), lower confidence on the specific LLM training-process descriptions (general background, not from this repo).
- **Discipline coverage (§10):** High confidence on neuroscience, psychology, biology, RL contrast, robotics, statistical physics, philosophy of mind. Medium confidence on psychiatry (presented as ongoing) and education (curriculum-design-supported only). Lower on AI literacy (interpretive).

## Final verdict

The guide meets every "yes-criteria" in the brief:

- ✅ Explains Active Inference in one paragraph (§2).
- ✅ Explains surprise without reducing it to ordinary emotional surprise (§3).
- ✅ Explains the predict–act loop (§4).
- ✅ Explains precision as calibration / confidence-weighting (§6).
- ✅ Discusses dopamine as part of calibration carefully (§7).
- ✅ Explains why "reward-seeking" may be too narrow (§8).
- ✅ Explains why embodied living systems differ from LLMs (§14).
- ✅ Shows which claims are repo-supported and which are not (§17 + 02_CLAIM_EVIDENCE_MAP.md).
- ✅ Avoids the brief's enumerated overclaims.

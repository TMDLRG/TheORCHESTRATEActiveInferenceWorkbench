# Source Inventory

Every file consulted while preparing the *Beginning Guide to Active Inference*.
Confidence is on a 1–5 scale (5 = strongly supports the claims I drew from it,
1 = consulted but contributed little).

## Primary repo sources (verbatim derivative extracts and code-grade content)

| File | Relevance | Key concepts found | Confidence |
|---|---|---|---|
| [active_inference/apps/active_inference_core/lib/active_inference_core/equations.ex](../active_inference/apps/active_inference_core/lib/active_inference_core/equations.ex) | Equation registry — verbatim from Parr/Pezzulo/Friston (2022) with verification status (`:verified_against_source` / `:verified_against_source_and_appendix`). | Bayes' rule (eq 2.1), KL divergence (eq 2.3), variational free energy F (eq 2.5), expected free energy G (eq 2.6, 4.10, B.30), entropy/surprise (eq 3.1, 3.2), POMDP likelihood A (eq 4.5), state transitions B (eq 4.6), policy prior + EFE (eq 4.7), state belief update (eq 4.13), policy posterior (eq 4.14), info gain (eq 7.4, 7.8, B.29), Dirichlet learning (eq 7.10), continuous generative model & process (eq 8.1, 8.2), Laplace free energy (B.42), predictive coding hierarchy (B.47), action on sensors (B.48). | 5 |
| [active_inference/apps/workbench_web/lib/workbench_web/book/glossary.ex](../active_inference/apps/workbench_web/lib/workbench_web/book/glossary.ex) | 60+ glossary entries, kid/adult/phd tiers — single source of truth for tooltip copy across the suite. | active-inference, generative-model, generative-process, markov-blanket, prior/likelihood/posterior, surprise, KL, F, G, policy, risk, ambiguity, epistemic-/pragmatic-value, softmax, policy-precision (γ) ↔ DA, ACh ↔ Πy, NA ↔ Πx, 5-HT ↔ χ, predictive coding, prediction error, precision (Π), Laplace, action-as-inference, prior-preferences (C), reflex-arc. | 5 |
| [active_inference/apps/workbench_web/lib/workbench_web/book/chapters.ex](../active_inference/apps/workbench_web/lib/workbench_web/book/chapters.ex) | 11-chapter catalogue (preface + 10) with ranges, equations, prerequisites, blurb, hero. | Chapter list, theory vs practice split, equation IDs per chapter. | 5 |
| [active_inference/apps/workbench_web/lib/workbench_web/book/sessions.ex](../active_inference/apps/workbench_web/lib/workbench_web/book/sessions.ex) | 39 sessions (preface + 38) with kid/real/equation/derivation narration tiers, concepts, quizzes, lab links. | The strongest single-file source of beginner-friendly phrasings; informs language and structure of the guide. | 5 |
| [active_inference/apps/workbench_web/priv/book/sessions/*.txt](../active_inference/apps/workbench_web/priv/book/sessions/) | Attributed CC BY-NC-ND derivative extracts from Parr/Pezzulo/Friston (2022). Every per-session excerpt is keyed by chapter and section. | The authoritative book prose where it touches AIF concepts. Used to verify that the repo establishes (e.g.) the rejection of value/Bellman framings, the autopoiesis link, the Markov blanket synchrony argument. | 5 |
| [active_inference/apps/workbench_web/priv/book/sessions/high-road__s1_expected_free_energy.txt](../active_inference/apps/workbench_web/priv/book/sessions/high-road__s1_expected_free_energy.txt) | Chapter 3 extract — Markov blanket and synchrony. | Pendulum/Huygens analogy of agent–world synchrony; nested blankets across brains, organisms, dyads, communities. | 5 |
| [active_inference/apps/workbench_web/priv/book/sessions/high-road__s3_softmax_policy.txt](../active_inference/apps/workbench_web/priv/book/sessions/high-road__s3_softmax_policy.txt) | Chapter 3 extract — comparison with optimal control / RL / Bellman. | Replaces value with belief; explicit contrast with reward-seeking models; Hamilton's principle of least Action; "preference for a course of action becomes simply a belief about what it expects to do". | 5 |
| [active_inference/apps/workbench_web/priv/book/sessions/unified-theory__s2_limitations.txt](../active_inference/apps/workbench_web/priv/book/sessions/unified-theory__s2_limitations.txt) | Chapter 10 extract — RL comparison, allostasis, interoception, emotion. | "Active Inference dispenses with the notions of reward, value functions, and Bellman optimality"; predictive interoception; allostasis as predictive regulation (e.g., raising cardiac output before exertion); emotions as priors on precision. | 5 |
| [ARCHITECTURE.md](../ARCHITECTURE.md) | Three-plane architecture: agent plane / world plane / shared contracts crossing a typed Markov blanket. | Reinforces the structural distinction between the agent's *generative model* and the world's *generative process*. | 5 |
| [README.md](../README.md) | Project overview + attribution + licensing. | Establishes that the curriculum is built on Parr, Pezzulo, Friston (2022, MIT Press, CC BY-NC-ND) and that book reproduction is forbidden. | 5 |
| [BRANDING.md](../BRANDING.md) | Citation strings, the "apply the frameworks, never reproduce" rule. | Anchors how to cite the book without quoting it long-form. | 5 |
| [CLAUDE.md](../CLAUDE.md) | Project rules — Jido stack, prompt + cookbook authoring conventions. | Indirect: confirms the suite's epistemic discipline ("validate every claim against `mix cookbook.validate`"). | 4 |

## Beginner-language shorts (repo-supported phrasings, with caveats)

| File | Relevance | Confidence |
|---|---|---|
| [shorts/PLAN.md](../shorts/PLAN.md) | 100-short series outline with explicit myth list. Anchors what the curriculum considers settled vs commonly misstated. | 4 |
| [shorts/specs/34.json](../shorts/specs/34.json) | "C is the only place preferences live. Not a reward function. Not a value estimator. A distribution over what you want to see." Repo-supported shorthand. | 5 |
| [shorts/specs/90.json](../shorts/specs/90.json) | Myth-busting: "Active Inference explains consciousness" — labelled as MYTH. Framework is agnostic. | 5 |
| [shorts/specs/93.json](../shorts/specs/93.json) | Myth-busting: "Dopamine = reward" — labelled as MYTH. The repo-supported framing is "Dopamine = precision on reward-related errors. Not the reward itself." | 5 |
| [shorts/specs/95.json](../shorts/specs/95.json) | Empirical fitting to OCD / psychosis / ADHD precision profiles. | 4 |
| [shorts/specs/100.json](../shorts/specs/100.json) | Closing arc — what the learner should walk away with. | 4 |
| [shorts/specs/101.json](../shorts/specs/101.json) | **Bonus / explicitly speculative.** "Active Inference stem cells", "Big Bang as the flip of the switch", "matter minimising F". The repo presents this as a thought experiment, not core theory. | 2 |
| [shorts/specs/102.json](../shorts/specs/102.json) - [shorts/specs/111.json](../shorts/specs/111.json) | "Abstractionist Papers" series — Red Space / Blue Space framework by Von Paumgartten, presented as a *separate philosophical lens* the curriculum engages with. Not core AIF; clearly external. | 2 |

## Lower-priority / context-only files

| File | Why consulted | Confidence |
|---|---|---|
| [WORKSHOP_PLAN.md](../WORKSHOP_PLAN.md), [STUDIO_PLAN.md](../STUDIO_PLAN.md), [RUNTIME_GAPS.md](../RUNTIME_GAPS.md) | Project-level orientation. | 3 |
| [active_inference/apps/active_inference_core/lib/active_inference_core/discrete_time.ex](../active_inference/apps/active_inference_core/lib/active_inference_core/discrete_time.ex) | Numerical implementations of Eq. 4.10/4.13/4.14/B.5/B.30. Confirms what the suite actually computes. | 4 |
| [knowledgebase/jido/*.md](../knowledgebase/jido/) | Jido framework reference — not Active Inference content. | 1 |
| [learninglabs/*.html](../learninglabs/) | Seven interactive simulations. Confirms the curriculum is structured around manipulable models, but consulted only at filename level for this guide. | 2 |

## Notable absences

- **Baby's first breath / neonatal hypoxia / breath learning.** The repo extracts mention oxygen, cardiac output, allostasis, and predictive interoception in [unified-theory__s2_limitations.txt](../active_inference/apps/workbench_web/priv/book/sessions/unified-theory__s2_limitations.txt) (lines 367–372 of that extract: "increasing cardiac output before a long run in anticipation of increased oxygen demands"). They do **not** narrate the specific newborn-first-breath example. That example is therefore treated as a **speculative analogy** in the guide, with the surrounding allostasis/interoception framing labelled **repo-supported**.
- **DNA, gene expression, single-cell metabolism as Active Inference.** The repo discusses nested Markov blankets ("brains, organisms, dyads, and communities") and reconciliation with autopoietic / enactive theories of life (Maturana & Varela 1980), but does **not** extend to DNA-level or single-cell metabolic framings in the curriculum extracts. Treated as **interpretive synthesis / speculative**.
- **GPT / LLM-style next-token prediction as a category distinct from embodied agency.** The repo's anti-claim is structural (it separates *generative process* from *generative model*, and mandates that action affects only sensors, not beliefs directly), but it does not contain a polemic against LLMs. The LLM section of the guide is therefore framed as **interpretive synthesis**: it draws on the repo's structural distinctions, plus general background on how LLMs are trained, plus the user's framing.
- **Resonance as a technical AIF term.** The repo supports "synchrony" via the Huygens pendulum analogy across the Markov blanket. "Resonance" is **not** a verbatim repo term — it's the user's framing and is treated as an evocative gloss.

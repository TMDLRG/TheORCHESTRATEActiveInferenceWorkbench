# Prompt Design — ORCHESTRATE applied to the LibreChat catalogue

Every agent and saved prompt shipped via `tools/librechat_seed/` is shaped by **THE ORCHESTRATE METHOD™** (Polzin, 2025). This document is the reference every prompt author or reviewer runs through before a PR.

See [`../../BRANDING.md`](../../BRANDING.md) for the canonical citation block and the copyright-safe authoring rule.

---

## The 11 letters (brief)

| Letter | Framework | In one line |
|---|---|---|
| **O** | Objective (SMART) | What must exist when done |
| **R** | Role (PRO) | Who is doing it, from what perspective |
| **C** | Context (WORLD) | What situational facts constrain the approach |
| **H** | Handoff (READY) | How the work is delivered / when to pause |
| **E** | Examples (FIT) | Concrete anchors the model can match |
| **S** | Structure (FLOW) | The shape the reply must take |
| **T** | Tone (VIBE) | Voice, register, word ceilings |
| **R** | Review (DONE) | Self-check before sending |
| **A** | Assure (VERIFY) | Guarantee of quality properties |
| **T** | Test (PROVE) | Evidence the deliverable is correct |
| **E** | Execute (RUN) | Cross-session / multi-agent coordination |

O-R-C delivers ~80% of quality gains at minimal token cost. H-E-S-T adds ~15%. R-A-T adds the final ~5%. E is for system-level orchestration.

## Mapping to the suite

### Layer 1 — Agent system instructions

Agents in [`agents.yaml`](agents.yaml) (and generated specialists/coaches in [`agents.generated.yaml`](agents.generated.yaml)) carry **O-R-C + a one-line T**, plus the **ORCHESTRATE Core Preamble** that the seeder prepends automatically (see `orchestrate_core:` at the top of the yaml).

- The preamble encodes the ORCHESTRATE *discipline*: lead every reply with O + R + C; if the ask is vague, ask one clarifying question first.
- Each agent's `instructions:` field fills in the Role, Context (chapter/lab/equation), and Tone specific to that agent.
- Target length: ≤ 700 chars per agent instruction.

### Layer 2 — Saved prompts (chat-templates)

Saved prompts in [`prompts.yaml`](prompts.yaml) (and generated variants in [`prompts.generated.yaml`](prompts.generated.yaml)) layer in **only the ORCHESTRATE sub-letters that the specific prompt class needs** — to avoid token bloat when the system layer already supplies Role + Context:

| Prompt class | Letters applied | Typical addition |
|---|---|---|
| Chapter-tour explainers (~36) | **O + S** | `Objective: … Structure: …` |
| Equation walkthroughs (4) | **O + S + light E** | Objective + numbered structure + one numeric anchor |
| Lab starters (7) | **O + light C + T** | Objective + preserved lab anchors + tone line |
| Study-workflow plan-day | **O + R** | Objective + `Review: before replying, check …` |
| Study-workflow check-understanding | **O + A + H** | Objective + `Assure: verify …` + `Handoff: one at a time` |
| Quiz-style prompts | **O + H** | Objective + `Handoff: ask one at a time, wait for answer` |
| Data-driven generator templates (per chapter, equations, models, glossary, labs, session pathfinder) | **O + S**, with **H** for coaching and **R** for planning | Same pattern, enum dropdowns preserved |

## Worked example — before & after

### Agent system instructions

**Before** (BayesChips Lab Coach — 213 chars):
```
You coach the BayesChips lab (/learn/lab/bayes).  Ground every reply in the
chip world: 100 chips total, a gold out of 100, b showing the obs among gold,
c showing the obs among steel.  Use Bayes' rule explicitly.  Offer to
narrate the posterior via speak~voice.
```

**After** (584 chars, +174% — but now explicitly O-R-C-T, trivially reviewable, and the learner gets a consistent shape across all coaches):
```
Role: BayesChips Lab Coach.  Learners run /learn/lab/bayes and change sliders a, b, c.
Objective: explain each posterior update in the chip world using explicit Bayes' rule (prior, likelihood, evidence, posterior).
Context: 100 chips total; a gold out of 100; b = observations seen among gold; c = observations seen among steel.  Ch02 is your grounding.
Tone: crisp, numerical, one computation per reply.  Offer speak~voice narration of the posterior when the learner asks.
```

*(Note: we intentionally accept >30% growth on **agent system instructions** because every reply in that agent's lifetime inherits the improvement. Saved prompts are the place to keep the +30% ceiling — see below.)*

### Saved prompt

**Before** (`ch1-big-idea`, 147 chars):
```
Explain the single biggest idea of Chapter 1 of the Active Inference textbook
in {{format}}.  Assume I'm a {{audience}} learner.  Keep it under {{limit}} sentences.
```

**After** (195 chars, +33% — inside the ceiling given the Structure directive):
```
Objective: state Chapter 1's single biggest Active Inference idea for a {{audience}} learner in {{format}}, <= {{limit}} sentences.
Structure: lead with the idea itself; follow with one line on why it matters.
```

## Copyright-safe rule (non-negotiable)

Never reproduce book prose. See [`../../BRANDING.md`](../../BRANDING.md) §9 for the full checklist. Short form:

- ✅ Name the framework (11 ORCHESTRATE letters; 6 AI-UMM levels).
- ✅ Apply the framework structure.
- ✅ Cite the books.
- ❌ Do not paste chapter text, examples, tables from the Polzin books.
- ❌ Do not add book source files to git.

## Editor checklist (run before opening a PR)

1. Each modified agent instruction ≤ 700 chars.
2. Each modified saved prompt body grew ≤ +30% bytes over baseline.
3. Every `{{placeholder}}` preserved.
4. The ORCHESTRATE Core Preamble at the top of `agents.yaml` and `agents.generated.yaml` is unchanged (it's the shared invariant).
5. Generator regenerated: `python tools/librechat_seed/agents_from_content.py && python tools/librechat_seed/prompts_from_content.py`.
6. Grep-check: no paragraph from `THE ORCHESTRATE METHOD.txt` or `LEVEL_UP_KDP_Interior.pdf` appears verbatim in the diff.
7. Smoke-test at least one agent + one saved prompt in LibreChat. Record outputs in the PR description.

## Smoke test recipe (B12)

Per the B12 ticket in the plan: 18 agent smoke checks + 8 saved-prompt category smoke checks = 26 total.

**Agents (18):**
- 4 path tutors (story / real / equation / derivation) — same probe: "Teach me Chapter 4's big idea."
- 7 lab coaches (bayes / pomdp / forge / tower / anatomy / atlas / frog) — same probe: "What should I try first in this lab?"
- 5 role coaches (math / intuition / proof / exam / lab-debug) — same probe: "Pick a starting point for me."
- 2 randomly-chosen chapter specialists — probe: "What's this chapter's biggest misconception?"

Expected: every reply opens with explicit Objective / Role / Context labels (from the core preamble + per-agent instructions), stays on-topic, and is ≤ ~200 words unless the prompt required longer.

**Saved prompts (8):**
- `ch1-big-idea`, `bayes`, `eq-419`, `ch4-forge`, `pomdp-belief`, `plan-day`, `check-understanding`, `ch1-quiz` — each run once with sensible variable values.

Log output snippets in the PR description.

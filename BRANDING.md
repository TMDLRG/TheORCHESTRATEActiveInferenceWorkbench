# Branding

Canonical identity for the suite. Single source of truth for every title, tagline, citation, and attribution. If you change copy in the UI, the README, the docs, or any prompt, pull the strings from this document.

---

## 1. Canonical name

**The ORCHESTRATE Active Inference Learning Workbench**

- Short form (navbar, tab title): *The ORCHESTRATE Active Inference Learning Workbench*
- Ultra-short (favicon tooltip, mobile): *ORCHESTRATE × AI Workbench*
- Never abbreviate as "OAIW" or similar. Use the full name or the short-form.

## 2. Short tagline (navbar, hero strap)

**ORCHESTRATE × Active Inference — runs on pure Jido**

## 3. Full tagline (about pages, README, global footer)

> *Built with wisdom from THE ORCHESTRATE METHOD™ and LEVEL UP by Michael Polzin — running on pure Jido on the BEAM, teaching Active Inference from Parr, Pezzulo & Friston (2022).*

## 4. Book 1 — THE ORCHESTRATE METHOD™

- **Title:** THE ORCHESTRATE METHOD™ — Systematic Prompting for Professional AI Outputs
- **Author:** Michael Polzin
- **Year:** 2025
- **Publisher:** Action Based Consulting, Inc.
- **ISBN:** 9798274456920
- **Link:** https://www.amazon.com/ORCHESTRATE-Prompting-Professional-AI-Outputs-ebook/dp/B0G2B9LG6V
- **Framework (the 11 letters):**
  - **O** — Objective (SMART)
  - **R** — Role (PRO)
  - **C** — Context (WORLD)
  - **H** — Handoff (READY)
  - **E** — Examples (FIT)
  - **S** — Structure (FLOW)
  - **T** — Tone (VIBE)
  - **R** — Review (DONE)
  - **A** — Assure (VERIFY)
  - **T** — Test (PROVE)
  - **E** — Execute (RUN)
- **How the suite uses it:** every system prompt gets the O-R-C foundation plus a persona anchor. Saved prompts add only the sub-letters they need (S for explainers, R+A for study-workflow, H for quizzes, etc.).
- **Reference (not reproduction):** the framework names and structure are applied; book prose is never reproduced.

## 5. Book 2 — LEVEL UP (AI-UMM)

- **Title:** LEVEL UP — The AI Usage Maturity Model
- **Author:** Michael Polzin
- **Year:** 2026
- **Publisher:** Action Based Consulting, Inc.
- **ISBN:** 9798251618921
- **Link:** https://www.amazon.com/Level-Usage-Maturity-Model-Excellence-ebook/dp/B0GS4WDVFZ
- **Framework (AI-UMM, levels 0–5):**
  - **Level 0** — None: The Curious Dabbler
  - **Level 1** — Initial: The Skeptical Supervisor
  - **Level 2** — Managed: The Quality Controller
  - **Level 3** — Defined: The Team Lead
  - **Level 4** — Quantitative: The Strategic Director
  - **Level 5** — Optimizing: The Amplified Human
- **How the suite uses it:** brand overlay + learner-path mapping. `story` path → Levels 0–1. `real` → 2–3. `equation` → 3–4. `derivation` → 4–5. Labs and cookbook recipes carry a Level 1–5 badge for orientation.
- **Reference (not reproduction):** level names and personas are cited; the assessment instrument and chapter prose are not shipped.

## 6. Book 3 — Active Inference (the subject the suite teaches)

- **Title:** Active Inference — The Free Energy Principle in Mind, Brain, and Behavior
- **Authors:** Thomas Parr, Giovanni Pezzulo, Karl J. Friston
- **Year:** 2022
- **Publisher:** MIT Press
- **ISBN:** 9780262369978
- **License:** Creative Commons **CC BY-NC-ND 4.0**
- **Link:** https://mitpress.mit.edu/9780262045353/active-inference/
- **How the suite uses it:** the equation registry, chapter index, session decomposition, and learning content all derive from the book. Committed derivative extracts live under `active_inference/apps/workbench_web/priv/book/chapters/*.txt` and `.../sessions/*.txt` with attribution preserved. The original PDF/TXT is gitignored and supplied locally per [BOOK_SOURCES.md](BOOK_SOURCES.md).

## 7. Author credit (Michael Polzin)

Reusable block, drop into About / Creator / footer contexts:

> **Michael Polzin** — Author of *THE ORCHESTRATE METHOD™* and *LEVEL UP: The AI Usage Maturity Model*. Creator of the AI-UMM framework. [LinkedIn](https://www.linkedin.com/in/mpolzin/).

Related work to mention once, sparingly: *Run on Rhythm: Build a Business That Doesn't Run You* (also by Polzin).

## 8. Jido credit

Reusable block:

> **Jido** — the pure-Elixir agent framework powering this suite. Created and maintained by the **agentjido** organization. Repository: https://github.com/agentjido/jido. Homepage: https://jido.run. This suite runs on Jido **v2.2.0**. The curated knowledgebase in [knowledgebase/jido/](knowledgebase/jido/) reflects that version.

## 9. Copyright-safe authoring rule

**APPLY the frameworks, NEVER reproduce book prose.** Every prompt, guide page, cookbook card, and doc must pass this checklist before it ships:

- ✅ Names the framework elements (the 11 ORCHESTRATE letters, the 6 AI-UMM levels) and applies their structure.
- ✅ Cites the books with title, author, ISBN, and purchase link when referenced.
- ✅ For Active Inference content, uses attributed derivative extracts from `priv/book/` (CC BY-NC-ND compliant).
- ❌ Does not paste paragraphs, chapter text, tables, worksheets, or multi-sentence examples from the Polzin books.
- ❌ Does not add any of the three book source files (`THE ORCHESTRATE METHOD.txt`, `LEVEL_UP_KDP_Interior.pdf`, `book_9780262369978.pdf`) to git.
- ✅ If a reviewer can paste a sentence from one of the books and find it verbatim in the suite, the sentence must be rewritten in the author's own words.

Release-gate grep (documented in `BOOK_SOURCES.md`): a short list of known sentences from each book is grepped before tagging a release. Zero matches → pass.

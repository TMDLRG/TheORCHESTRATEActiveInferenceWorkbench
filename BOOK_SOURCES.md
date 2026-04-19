# Book Sources

This suite cites three books. **None of the book source files are tracked in git.** Contributors supply their own local copies; the repo's runtime does not require the originals — only the derivative extracts under `active_inference/apps/workbench_web/priv/book/` (already committed with attribution).

If you are developing on this repo and want the book files alongside the code, drop them at the paths below. They are already listed in [.gitignore](.gitignore) so git will not re-track them.

---

## 1. THE ORCHESTRATE METHOD™ — Systematic Prompting for Professional AI Outputs

- **Author:** Michael Polzin
- **Publisher:** Action Based Consulting, Inc.
- **ISBN:** 9798274456920
- **Year:** 2025
- **Where to buy:** https://www.amazon.com/ORCHESTRATE-Prompting-Professional-AI-Outputs-ebook/dp/B0G2B9LG6V
- **Local-only path (gitignored):** `THE ORCHESTRATE METHOD.txt` at repo root
- **What the suite uses:** the O-R-C-H-E-S-T-R-A-T-E framework *by name*, applied to every shipped system prompt and saved prompt. The suite **does not** reproduce chapter prose, examples, or tables from the book.

## 2. LEVEL UP — The AI Usage Maturity Model

- **Author:** Michael Polzin
- **Publisher:** Action Based Consulting, Inc.
- **ISBN:** 9798251618921
- **Year:** 2026
- **Where to buy:** https://www.amazon.com/Level-Usage-Maturity-Model-Excellence-ebook/dp/B0GS4WDVFZ
- **Local-only path (gitignored):** `LEVEL_UP_KDP_Interior.pdf` at repo root
- **What the suite uses:** the AI-UMM 6-level naming (Curious Dabbler, Skeptical Supervisor, Quality Controller, Team Lead, Strategic Director, Amplified Human) as brand overlay and path-mapping orientation. The suite **does not** ship the assessment instrument or chapter prose.

## 3. Active Inference — The Free Energy Principle in Mind, Brain, and Behavior

- **Authors:** Thomas Parr, Giovanni Pezzulo, Karl J. Friston
- **Publisher:** MIT Press
- **ISBN:** 9780262369978
- **Year:** 2022
- **License:** Creative Commons **CC BY-NC-ND 4.0** — attribution required, non-commercial, no derivatives
- **Where to obtain:** https://mitpress.mit.edu/9780262045353/active-inference/ (also available as a free PDF from the publisher under the CC license)
- **Local-only path (gitignored):** `book_9780262369978.pdf` + `book_9780262369978 (1).txt` at repo root
- **What the suite uses:** the equations, chapter structure, and session decomposition from the book drive the entire learning system. The extracted derivative files under `active_inference/apps/workbench_web/priv/book/chapters/*.txt` and `.../sessions/*.txt` *are committed* because the CC license permits attributed redistribution and they are the code-grade source of truth for the equation registry and chapter navigation. The original full-text PDF/TXT is not needed at runtime and is therefore not tracked.

---

## Why the Polzin books are gitignored

THE ORCHESTRATE METHOD™ and LEVEL UP are **commercial works** copyrighted by Michael Polzin and published via Action Based Consulting, Inc. This suite is otherwise open source and does not have redistribution rights to the book interiors. We cite, credit, and *apply* the frameworks those books describe; we do not redistribute them.

## Copyright-safe authoring rule (applies to ALL prompts, docs, cookbook cards)

**APPLY the frameworks, NEVER reproduce book prose.**

- ✅ Name the 11 ORCHESTRATE letters and their sub-frameworks (O = Objective / SMART, R = Role / PRO, etc.).
- ✅ Name the AI-UMM 6 levels and their personas.
- ✅ Apply the framework *structure* to a prompt, page, or recipe.
- ✅ Cite the books with title, author, ISBN, and purchase link.
- ❌ Do not paste paragraphs, chapter text, tables, worksheets, or multi-sentence examples from the books.
- ❌ Do not include the book source files (.txt / .pdf) in git.
- ✅ For Active Inference (CC BY-NC-ND), attributed derivative extracts in `priv/book/` are permitted and committed.

This rule is enforced by convention and by a release-gate grep in the QA checklist.

---

## History note

The three books were previously tracked in git; they were removed from the index via `git rm --cached` (not `git rm`), so old commits still contain them. If you need to purge them from history as well, that is a separate `git filter-repo` operation not covered here.

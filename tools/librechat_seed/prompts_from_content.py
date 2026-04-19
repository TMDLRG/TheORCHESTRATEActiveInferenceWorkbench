"""Data-driven prompt generator.

Reads `scripts/.suite/state/suite_content.json` (exported from Phoenix by the
mix task `workbench_web.export_suite_content`) and generates a
`prompts.generated.yaml` whose every `{{var}}` is backed by an
`[[var:opt1,opt2,...]]` enum of real catalogue entries — chapters, equations,
models, labs, glossary terms, learner paths.  Re-running the seeder overwrites
LibreChat's seeded groups, so edits to the source data propagate cleanly.

Design:
- One PromptGroup per chapter (with chapter-scoped prompts that can only point
  at that chapter's equations/sessions — keeps dropdown options manageable).
- One PromptGroup per lab (coach prompts pre-filtered by lab).
- One PromptGroup "Equations (all)" with a dropdown that spans the entire
  31-item registry.
- One PromptGroup "Concepts (glossary)" backed by the 79-term glossary.
- One PromptGroup "Study Workflow".

Phase F (enrichment) of LIBRECHAT_EXTENSIONS_PLAN.md."""
from __future__ import annotations

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent.parent
CONTENT_JSON = REPO_ROOT / "scripts" / ".suite" / "state" / "suite_content.json"
OUTPUT_YAML = HERE / "prompts.generated.yaml"


def _enum(values: list[str]) -> str:
    """Render a list of option strings into LibreChat's pipe-separated enum.

    LibreChat parses `{{var:opt1|opt2|opt3}}` into a select/combobox.  Pipes
    in option text would break the syntax, so replace them with fullwidth
    vertical bar; commas are safe to keep."""
    safe = [str(v).replace("|", "｜") for v in values]
    return "|".join(safe)


def _chapter_label(ch: dict) -> str:
    return f"Ch {ch['num']} - {ch['title']}"


def _equation_label(eq: dict) -> str:
    return str(eq.get("id", "?"))


def _session_label(s: dict) -> str:
    return f"Ch{s['chapter']} · {s['slug']} ({s['minutes']}min)"


def _model_label(m: dict) -> str:
    mid = m.get("id") or "?"
    name = m.get("name") or ""
    return f"{mid} — {name}" if name else str(mid)


def _glossary_label(g: dict) -> str:
    return f"{g.get('key') or '?'} ({g.get('name') or ''})"


def _escape_yaml(text: str) -> str:
    """For literal block scalars the only real risk is embedded `{{` / `[[`,
    and those are intentional.  Nothing to escape — YAML literal block handles
    newlines natively.  Kept as a hook for future sanitisation."""
    return text


def generate() -> dict:
    if not CONTENT_JSON.exists():
        print(
            f"[prompts-gen] missing {CONTENT_JSON} — run "
            "`mix workbench_web.export_suite_content` first",
            file=sys.stderr,
        )
        return {"groups": []}
    data = json.loads(CONTENT_JSON.read_text(encoding="utf-8"))

    chapters = data.get("chapters", [])
    equations = data.get("equations", [])
    models = data.get("models", [])
    sessions = data.get("sessions", [])
    glossary = data.get("glossary", [])
    labs = data.get("labs", [])
    paths = data.get("paths", ["kid", "real", "equation", "derivation"])

    all_eq_ids = [_equation_label(e) for e in equations if e.get("id")]
    all_model_ids = [_model_label(m) for m in models if m.get("id")]
    all_chapter_labels = [_chapter_label(c) for c in chapters]
    all_session_labels = [_session_label(s) for s in sessions]
    all_glossary_labels = [_glossary_label(g) for g in glossary]
    path_enum = _enum(paths)
    lab_enum = _enum(labs)

    groups: list[dict] = []

    # ---- per-chapter groups ---------------------------------------------
    for ch in chapters:
        num = ch["num"]
        ch_label = _chapter_label(ch)
        ch_title = ch["title"]
        ch_sessions = [s for s in sessions if s.get("chapter") == num]
        ch_eqs = [e for e in equations if e.get("id", "").startswith(f"eq_{num}_")]
        # Session enum -- if empty, fall back to "overview"
        session_opts = [s["slug"] for s in ch_sessions] or ["overview"]
        eq_opts = [_equation_label(e) for e in ch_eqs] or all_eq_ids

        prompts = [
            {
                "type": "chat",
                "prompt": f"""Objective: state the {ch_label} big-idea in the {{{{path:{path_enum}}}}} voice -- the single concept that differentiates this chapter from its neighbours.
Structure: one-sentence idea -> one cited equation ID from the chapter -> one concrete example the book uses.""",
            },
            {
                "type": "chat",
                "prompt": f"""Objective: explain equation {{{{eq:{_enum(eq_opts)}}}}} from {ch_label} in the {{{{path:{path_enum}}}}} voice.
Structure: symbolic form -> one-paragraph motivation -> one numeric worked example -> units for every symbol.""",
            },
            {
                "type": "chat",
                "prompt": f"""Objective: walk session {{{{session:{_enum(session_opts)}}}}} of {ch_label} at the {{{{path:{path_enum}}}}} level.
Structure: hero idea -> one concrete anchor (lab or figure) -> the next session to open and why.""",
            },
            {
                "type": "chat",
                "prompt": f"""Objective: quiz me on {ch_label} with {{{{count:3|5|8|12}}}} short questions, one per core idea.
Handoff: ask one question at a time; wait for my answer; reveal a one-line correction; then move to the next.""",
            },
            {
                "type": "chat",
                "prompt": f"""Objective: unstick me on {ch_label} where I named {{{{stuck:the math notation|the intuition|a worked example|why it matters|what to read next}}}}, at the {{{{path:{path_enum}}}}} level.
Structure: exactly one next step (no menu) -> a 1-line reason that step will help.""",
            },
        ]

        groups.append(
            {
                "name": f"Ch {num} - {ch_title}",
                "category": "chapter",
                "oneliner": f"Chapter-scoped prompts with dropdowns from the {ch_label} catalogue.",
                "prompts": prompts,
            }
        )

    # ---- Equations (all 31) ----------------------------------------------
    groups.append(
        {
            "name": "Equations (all 31)",
            "category": "equations",
            "oneliner": "Every equation in the registry, selectable from a dropdown with provenance.",
            "prompts": [
                {
                    "type": "chat",
                    "prompt": f"""Objective: explain equation {{{{eq:{_enum(all_eq_ids)}}}}} in the {{{{path:{path_enum}}}}} voice.
Structure: symbolic form -> intuitive meaning -> units per symbol -> one numeric worked example -> chapter that introduces it.""",
                },
                {
                    "type": "chat",
                    "prompt": f"""Objective: compare equations {{{{eq_a:{_enum(all_eq_ids)}}}}} and {{{{eq_b:{_enum(all_eq_ids)}}}}}.
Structure: shared symbols -> which (if either) is a special case -> chapter each sits in -> 1-line takeaway.""",
                },
                {
                    "type": "chat",
                    "prompt": f"""Objective: suggest a numerical recipe that implements equation {{{{eq:{_enum(all_eq_ids)}}}}} in {{{{lang:python|elixir|pseudocode|whiteboard}}}}.
Structure: shape annotations per tensor -> step-by-step recipe -> edge cases to guard -> 1-line numerical-stability note.""",
                },
            ],
        }
    )

    # ---- Models registry -----------------------------------------------
    if all_model_ids:
        groups.append(
            {
                "name": "Models (registry)",
                "category": "models",
                "oneliner": "Every worked model from ActiveInferenceCore.Models, with provenance to equations.",
                "prompts": [
                    {
                        "type": "chat",
                        "prompt": f"""Objective: walk model {{{{model:{_enum(all_model_ids)}}}}} at the {{{{path:{path_enum}}}}} level.
Structure: equation IDs used -> hidden states -> observations -> one scenario where it is the right pick.""",
                    },
                    {
                        "type": "chat",
                        "prompt": f"""Objective: contrast model {{{{model_a:{_enum(all_model_ids)}}}}} with model {{{{model_b:{_enum(all_model_ids)}}}}}.
Structure: the first equation that differs -> which scenario pushes toward each -> 1-line takeaway.""",
                    },
                ],
            }
        )

    # ---- Glossary (concepts) -------------------------------------------
    if all_glossary_labels:
        groups.append(
            {
                "name": "Concepts (glossary)",
                "category": "concepts",
                "oneliner": "Every glossary term, explained at the depth you pick.",
                "prompts": [
                    {
                        "type": "chat",
                        "prompt": f"""Objective: define {{{{term:{_enum(all_glossary_labels)}}}}} at the {{{{path:{path_enum}}}}} level.
Structure: one-sentence plain-English definition -> one concrete example -> one common misconception -> chapter that introduces it.""",
                    },
                    {
                        "type": "chat",
                        "prompt": f"""Objective: compare {{{{term_a:{_enum(all_glossary_labels)}}}}} and {{{{term_b:{_enum(all_glossary_labels)}}}}} at the {{{{path:{path_enum}}}}} level.
Structure: which appears first in the book -> dependency direction -> 1-line takeaway.""",
                    },
                ],
            }
        )

    # ---- Labs ----------------------------------------------------------
    groups.append(
        {
            "name": "Lab Coaches (dropdown)",
            "category": "labs",
            "oneliner": "Coach prompts that route to the right lab and preset.",
            "prompts": [
                {
                    "type": "chat",
                    "prompt": f"""Objective: coach me in the {{{{lab:{lab_enum}}}}} lab given I am {{{{state:just-opened|after-one-step|stuck-on-a-concept|wrapping-up}}}}, at the {{{{path:{path_enum}}}}} level.
Handoff: open with exactly one clarifying question -> wait for my answer -> then give one concrete next action.""",
                },
                {
                    "type": "chat",
                    "prompt": f"""Objective: in {{{{lab:{lab_enum}}}}} I observed {{{{observation:posterior|free-energy|prediction-error|belief-shift|surprise|none-of-these}}}} change unexpectedly -- diagnose it.
Structure: where to look next (specific UI element) -> the equation that explains the swing -> 1-line sanity-check I can run.""",
                },
                {
                    "type": "chat",
                    "prompt": f"""Objective: give me a bite-sized challenge for {{{{lab:{lab_enum}}}}} at {{{{level:novice|intermediate|advanced}}}} difficulty.
Structure: the challenge -> a clear success criterion -> one hint to use only if stuck.""",
                },
            ],
        }
    )

    # ---- Sessions pathfinder -------------------------------------------
    if all_session_labels:
        groups.append(
            {
                "name": "Session pathfinder",
                "category": "meta",
                "oneliner": "Pick any session in the 39-session catalogue and get a tailored intro.",
                "prompts": [
                    {
                        "type": "chat",
                        "prompt": f"""Objective: open session {{{{session:{_enum(all_session_labels)}}}}} at the {{{{path:{path_enum}}}}} level.
Structure: hero idea -> one equation to keep in mind -> one concrete thing to try in the linked lab.""",
                    }
                ],
            }
        )

    # ---- Meta / study flow ---------------------------------------------
    groups.append(
        {
            "name": "Study Workflow",
            "category": "meta",
            "oneliner": "Daily flow builders that span the full suite.",
            "prompts": [
                {
                    "type": "chat",
                    "prompt": f"""Objective: design a {{{{minutes:15|30|45|60|90|120}}}}-minute plan covering {{{{topic:{_enum(all_chapter_labels)}}}}} at the {{{{path:{path_enum}}}}} level, mixing one lab and one quiz.
Review: before replying, check that every block has a labelled time cost, totals match the budget within +/-5 minutes, and each surface has a deep-link URL (Phoenix chat-bridge or LibreChat prompt).""",
                },
                {
                    "type": "chat",
                    "prompt": f"""Objective: check my understanding of {{{{topic:{_enum(all_chapter_labels)}}}}} with one Socratic question per core concept.
Handoff: never reveal the answer until I have taken a swing; after my answer give a 1-line correction and move on.""",
                },
            ],
        }
    )

    return {"groups": groups}


def main() -> int:
    payload = generate()
    # PyYAML adds quoting that LibreChat's prompt parser tolerates; emit as YAML.
    try:
        import yaml
    except ImportError:
        print("[prompts-gen] PyYAML not installed; pip install pyyaml", file=sys.stderr)
        return 1
    text = yaml.safe_dump(payload, sort_keys=False, allow_unicode=True, width=120)
    OUTPUT_YAML.write_text(text, encoding="utf-8")
    print(f"[prompts-gen] wrote {OUTPUT_YAML} ({len(payload['groups'])} groups)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

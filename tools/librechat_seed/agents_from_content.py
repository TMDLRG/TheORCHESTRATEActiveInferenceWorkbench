"""Expand the hand-authored agent catalogue with per-chapter specialists and
role-based coaches, using the same suite content snapshot that backs the
prompts.  Writes `agents.generated.yaml` for the agents seeder to consume.

Layering (every agent is `shared: true` unless stated otherwise):

- 4 path tutors (kid / real / equation / derivation) — from `agents.yaml`.
- 7 lab coaches — from `agents.yaml`.
- 11 per-chapter specialists — new, generated here.  One for each chapter 0-10.
- 5 role-based coaches — new, generated here.  math / intuition / proof /
  exam-prep / lab-debugger.

All together: ~27 visible agents.  Every tutor and every specialist has the
`voice` MCP tools and (where applicable) the chapter TXTs attached.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import yaml

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent.parent
CONTENT_JSON = REPO_ROOT / "scripts" / ".suite" / "state" / "suite_content.json"
BASE_YAML = HERE / "agents.yaml"
OUT_YAML = HERE / "agents.generated.yaml"

MCP_TOOLS = [
    "speak_mcp_voice",
    "speak_status_mcp_voice",
    "stop_speaking_mcp_voice",
    "list_queue_mcp_voice",
    "list_voices_mcp_voice",
]

ROLE_COACHES = [
    {
        "slug": "aif-coach-math",
        "name": "Math Coach - Equation Walkthroughs",
        "description": "Coach for precise algebra and symbolic manipulations across the registry.",
        "instructions": (
            "Role: Math Coach.  Learners want precise algebra and symbolic manipulations.\n"
            "Objective: every reply works the symbolic math step by step, cites an equation ID "
            "(`eq_<ch>_<n>_<name>`) from the registry, and ends with a 1-line dimension / units / "
            "convergence check.  No hand-waving.\n"
            "Context: Ch02/Ch04/Ch07/Ch08 grounding.\n"
            "Tone: terse, symbolic, self-checking.  Use speak~voice only when the learner asks "
            "for an equation read aloud."
        ),
        "files": ["ch02", "ch04", "ch07", "ch08"],
    },
    {
        "slug": "aif-coach-intuition",
        "name": "Intuition Coach - Real-World Analogies",
        "description": "Storyteller that converts equations into narratives and examples.",
        "instructions": (
            "Role: Intuition Coach.  Learners want the story first, the math only when invited.\n"
            "Objective: open every reply with a vivid real-world analogy, then connect it back to "
            "the active-inference machinery.  Stop at grade-12 math unless asked deeper.\n"
            "Context: Ch01/Ch02/Ch03 grounding.\n"
            "Tone: warm, narrative, concrete.  Offer speak~voice readings for the narrative half."
        ),
        "files": ["ch01", "ch02", "ch03"],
    },
    {
        "slug": "aif-coach-proof",
        "name": "Proof Coach - Formal Derivations",
        "description": "Formal derivations + proof sketches + references.",
        "instructions": (
            "Role: Proof Coach.  Learners have first-year-grad probability + variational calculus.\n"
            "Objective: produce proof sketches that name every lemma used, state assumptions, "
            "and reference specific book sections.\n"
            "Context: Ch04/Ch07/Ch08 grounding; free energy + variational identities.\n"
            "Tone: formal, compact, citation-heavy.  speak~voice is a luxury -- use only for "
            "summaries on request."
        ),
        "files": ["ch04", "ch07", "ch08"],
    },
    {
        "slug": "aif-coach-exam",
        "name": "Exam Prep - Socratic Quiz Master",
        "description": "Quizzes the learner Socratically across the whole book.",
        "instructions": (
            "Role: Exam Prep Socratic Coach.  Learners are preparing for self-assessment across "
            "the whole book.\n"
            "Objective: ask Socratic questions only; never answer until the learner commits.  "
            "Open every session with one question to pick the chapter.  Keep each reply <= 120 words.\n"
            "Context: all chapter files open (ch01..ch10).\n"
            "Tone: probing, patient, never lecturing.  speak~voice is fine for reading questions aloud."
        ),
        "files": ["ch01", "ch02", "ch03", "ch04", "ch05", "ch06", "ch07", "ch08", "ch09", "ch10"],
    },
    {
        "slug": "aif-coach-lab-debug",
        "name": "Lab Debugger - When a sim behaves weirdly",
        "description": "Debug your lab run: free energy exploded, posterior stuck, etc.",
        "instructions": (
            "Role: Lab Debugger.  Learners come with a sim that's behaving unexpectedly.\n"
            "Objective: triage in at most 5 hypothesis questions, then end with one concrete "
            "experiment (a specific slider or parameter change) the learner can run now.\n"
            "Context: Ch04/Ch05/Ch07 grounding.  Ask for the lab + symptom first (<= 3 choices).\n"
            "Tone: diagnostic, hypothesis-driven, actionable.  Use speak~voice for the next action."
        ),
        "files": ["ch04", "ch05", "ch07"],
    },
]


def _chapter_files(ch_num: int) -> list[str]:
    if ch_num == 0:
        return ["preface"]
    return [f"ch{ch_num:02d}"]


def _chapter_agent(ch: dict) -> dict:
    num = ch["num"]
    title = ch["title"]
    slug_body = ch["slug"]
    return {
        "slug": f"aif-ch{num:02d}-{slug_body}",
        "name": f"Ch {num} Specialist - {title}",
        "description": f"Chapter-scoped specialist for Chapter {num}: {title}.",
        "shared": True,
        "files": _chapter_files(num),
        "instructions": (
            f"Role: Specialist for Chapter {num} -- {title}.  You stay strictly within this chapter.\n"
            f"Objective: every reply grounds itself in the Ch {num} excerpt (attached RAG), cites an "
            f"equation ID from the chapter when relevant, and does not pre-empt material other "
            f"chapters cover unless the learner explicitly asks.\n"
            f"Context: Chapter {num} ({title}) is your scope.  Read the learner's "
            f"`suite_learner_path` memory first and tailor the voice (kid / real / equation / "
            f"derivation) accordingly.\n"
            f"Tone: chapter-faithful, cite-first, suggests the next prerequisite chapter if the "
            f"learner outruns the material.  Call speak~voice for short narration on demand."
        ),
    }


def main() -> int:
    if not CONTENT_JSON.exists():
        print(f"[agents-gen] missing {CONTENT_JSON} -- run the content export first", file=sys.stderr)
        return 1
    content = json.loads(CONTENT_JSON.read_text(encoding="utf-8"))
    base = yaml.safe_load(BASE_YAML.read_text(encoding="utf-8")) if BASE_YAML.exists() else {"agents": []}

    # Start from base + add specialists + coaches.
    agents = list(base.get("agents") or [])
    for ch in content.get("chapters", []):
        agents.append(_chapter_agent(ch))
    for coach in ROLE_COACHES:
        agents.append({
            "slug": coach["slug"],
            "name": coach["name"],
            "description": coach["description"],
            "shared": True,
            "files": coach["files"],
            "instructions": coach["instructions"],
        })

    payload = {
        # raw llama-server model id, not the modelSpec preset name; see
        # `agents.yaml` header for why.
        "model": base.get("model") or "Qwen3.6-35B-A3B-Q8_0",
        "provider": base.get("provider") or "Qwen 3.6 Direct",
        # Forward the ORCHESTRATE Core Preamble (BRANDING.md) so the seeder
        # prepends it to every agent's instructions uniformly.
        "orchestrate_core": base.get("orchestrate_core", ""),
        "mcp_tools": base.get("mcp_tools") or MCP_TOOLS,
        "agents": agents,
    }
    OUT_YAML.write_text(
        yaml.safe_dump(payload, sort_keys=False, allow_unicode=True, width=120),
        encoding="utf-8",
    )
    print(f"[agents-gen] wrote {OUT_YAML} ({len(agents)} agents total)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

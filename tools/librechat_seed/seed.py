"""Run every seeder in order: files -> agents -> export."""
from __future__ import annotations

import runpy
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent


def _run(name: str) -> None:
    print(f"\n=== running {name} ===", flush=True)
    try:
        runpy.run_path(str(HERE / name), run_name="__main__")
    except SystemExit as e:
        if e.code not in (0, None):
            raise


def main() -> int:
    # Order matters: generators before seeders; purge after generators but
    # before prompts.py so stale groups go first; globalize.py last so it
    # finds every seeded agent + prompt group to register in the `instance`
    # project.
    for mod in (
        "files.py",
        "agents_from_content.py",
        "agents.py",
        "prompts_from_content.py",
        "purge_old_prompts.py",
        "prompts.py",
        "memories.py",
        "export_agent_ids.py",
        "globalize.py",
    ):
        _run(mod)
    return 0


if __name__ == "__main__":
    sys.exit(main())

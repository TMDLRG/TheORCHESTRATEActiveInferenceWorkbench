"""Copy the seeded `{slug → agent_id}` map to Phoenix's priv/ dir so the
chat-bridge controller can resolve `?agent=<slug>` → `?agent_id=<id>`."""
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent.parent
SRC = REPO_ROOT / "scripts" / ".suite" / "state" / "librechat.agents.json"
DST_DIR = REPO_ROOT / "active_inference" / "apps" / "workbench_web" / "priv" / "librechat"
DST = DST_DIR / "agents.json"


def main() -> int:
    if not SRC.exists():
        print(f"[export] {SRC} missing — run agents.py first", file=sys.stderr)
        return 1
    DST_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(SRC, DST)
    mapping = json.loads(DST.read_text(encoding="utf-8"))
    print(f"[export] wrote {DST} ({len(mapping)} slugs)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

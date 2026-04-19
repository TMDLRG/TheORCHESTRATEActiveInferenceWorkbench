"""Delete every seeded prompt group whose name does NOT appear in the current
generated YAML.  Run after the content taxonomy changes so the learner's
library stays in sync with the source of truth."""
from __future__ import annotations

import sys
from pathlib import Path

import yaml

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from common import lc_curl, load_admin  # noqa: E402


def main() -> int:
    admin = load_admin()
    # Source of truth: prefer the generated catalogue.  If it's missing (first
    # run on a fresh machine before the content export), fall through to the
    # legacy hand-authored prompts.yaml.
    generated = HERE / "prompts.generated.yaml"
    legacy = HERE / "prompts.yaml"
    source = generated if generated.exists() else legacy
    keep: set[str] = set()
    if source.exists():
        cfg = yaml.safe_load(source.read_text(encoding="utf-8"))
        for g in cfg.get("groups", []):
            if g.get("name"):
                keep.add(g["name"])

    r = lc_curl("GET", "/api/prompts/groups?pageSize=200", token=admin.token)
    r.raise_for_status()
    body = r.json()
    groups = body.get("promptGroups") or body

    removed = 0
    for g in groups:
        name = g.get("name")
        gid = g.get("_id")
        if not name or not gid:
            continue
        if name in keep:
            continue
        print(f"  removing stale group: {name}")
        d = lc_curl("DELETE", f"/api/prompts/groups/{gid}", token=admin.token)
        if d.status_code in (200, 204):
            removed += 1
    print(f"[purge] removed {removed} stale prompt groups")
    return 0


if __name__ == "__main__":
    sys.exit(main())

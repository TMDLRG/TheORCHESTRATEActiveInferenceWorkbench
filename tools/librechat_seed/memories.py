"""Seed starter per-user memories (Phase G).

Writes a handful of default memories to the admin user's memory store so the
agents can read `suite_learner_path`, `suite_progress_chapter`, and
`preferred_voice` on their first reply.  Extend for every learner who logs
into the workshop LibreChat (v1 just handles the admin)."""
from __future__ import annotations

import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from common import lc_curl, load_admin  # noqa: E402


STARTER_MEMORIES: dict[str, str] = {
    "suite_learner_path": "real",
    "suite_progress_chapter": "0",
    "suite_notes": "Active Inference workshop — start each session by reading recent progress.",
    "preferred_voice": "piper_jenny",
    "tutor_preference": "use_analogies_first",
}


def _existing(token: str) -> dict[str, str]:
    r = lc_curl("GET", "/api/memories", token=token)
    r.raise_for_status()
    body = r.json()
    return {m["key"]: m.get("value", "") for m in body.get("memories", [])}


def _put(token: str, key: str, value: str) -> None:
    # POST creates; if it already exists, patch.
    r = lc_curl("POST", "/api/memories", token=token, json={"key": key, "value": value})
    if r.status_code == 201:
        return
    if r.status_code in (400, 409):
        # Try update via PUT.
        r2 = lc_curl("PUT", f"/api/memories/{key}", token=token, json={"value": value})
        r2.raise_for_status()
        return
    r.raise_for_status()


def main() -> int:
    admin = load_admin()
    print(f"[memories] admin={admin.email}")

    existing = _existing(admin.token)
    created = 0
    for key, value in STARTER_MEMORIES.items():
        if key in existing and existing[key] == value:
            print(f"  [{key}] already set -> {value!r}")
            continue
        _put(admin.token, key, value)
        created += 1
        print(f"  [{key}] wrote -> {value!r}")
    print(f"[memories] wrote/updated {created} entries")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Post-deploy checks aligned with LIBRECHAT_EXTENSIONS_PLAN.md §9.

Requires: LibreChat up, admin state from `scripts/librechat_bootstrap.py`, and
optional `LC_BASE_URL` (default http://localhost:3080).

Exit 0 if all automated checks pass; 1 otherwise.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import requests
import yaml

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))

from common import BROWSER_UA, LC_BASE_URL, load_admin  # noqa: E402

EXPECTED_MEMORY_KEYS = frozenset(
    {
        "suite_learner_path",
        "suite_progress_chapter",
        "suite_notes",
        "preferred_voice",
        "tutor_preference",
    }
)
MIN_PROMPT_GROUPS = 13
VOICE_HTTP = os.environ.get("VOICE_HTTP_URL", "http://127.0.0.1:7712")
AGENTS_YAML = HERE / "agents.yaml"


def _fail(msg: str) -> None:
    print(f"  [FAIL] {msg}")


def _ok(msg: str) -> None:
    print(f"  [ok] {msg}")


def main() -> int:
    fails = 0
    voice_url = VOICE_HTTP.rstrip("/")

    print(f"\n== voice HTTP ({voice_url}) ==")
    try:
        r = requests.get(f"{voice_url}/healthz", timeout=5)
        if r.status_code != 200:
            _fail(f"healthz status {r.status_code}")
            fails += 1
        else:
            n = len((r.json() or {}).get("voices") or [])
            _ok(f"healthz ({n} voices)")
    except OSError as e:
        _fail(f"healthz: {e}")
        fails += 1

    print(f"\n== LibreChat ({LC_BASE_URL}) ==")
    try:
        admin = load_admin()
    except SystemExit as e:
        _fail(f"admin auth: {e}")
        return 1

    headers = {"Authorization": f"Bearer {admin.token}", "User-Agent": BROWSER_UA}

    yaml_cfg = yaml.safe_load(AGENTS_YAML.read_text(encoding="utf-8"))
    expected_names = {a["name"] for a in yaml_cfg.get("agents", [])}

    r = requests.get(f"{LC_BASE_URL}/api/agents", headers=headers, timeout=30)
    if r.status_code != 200:
        _fail(f"/api/agents status {r.status_code}")
        fails += 1
    else:
        body = r.json()
        agents = body if isinstance(body, list) else body.get("data") or body.get("agents") or []
        if not isinstance(agents, list):
            agents = []
        names = {a.get("name") for a in agents if isinstance(a, dict)}
        hit = len(expected_names & names)
        if hit < len(expected_names):
            missing = expected_names - names
            _fail(f"agents: expected {len(expected_names)} workshop agents; missing names: {sorted(missing)[:3]}…")
            fails += 1
        else:
            _ok(f"agents ({hit} workshop agents by name)")

    r = requests.get(
        f"{LC_BASE_URL}/api/prompts/groups?pageNumber=1&pageSize=200",
        headers=headers,
        timeout=30,
    )
    if r.status_code != 200:
        _fail(f"/api/prompts/groups status {r.status_code}")
        fails += 1
    else:
        body = r.json()
        groups = body.get("promptGroups") or body.get("data") or body
        if isinstance(groups, dict):
            groups = groups.get("items", [])
        n = len(groups) if isinstance(groups, list) else 0
        if n < MIN_PROMPT_GROUPS:
            _fail(f"prompt groups: need >= {MIN_PROMPT_GROUPS}, got {n}")
            fails += 1
        else:
            _ok(f"prompt groups ({n})")

    r = requests.get(f"{LC_BASE_URL}/api/memories", headers=headers, timeout=15)
    if r.status_code != 200:
        _fail(f"/api/memories status {r.status_code}")
        fails += 1
    else:
        mems = (r.json() or {}).get("memories") or []
        keys = {m.get("key") for m in mems if isinstance(m, dict)}
        missing = EXPECTED_MEMORY_KEYS - keys
        if missing:
            _fail(f"memories missing: {sorted(missing)}")
            fails += 1
        else:
            _ok("memories (starter keys)")

    agents_json = (
        REPO_ROOT / "active_inference" / "apps" / "workbench_web" / "priv" / "librechat" / "agents.json"
    )
    print(f"\n== Phoenix agent map ({agents_json}) ==")
    expected_slugs = {a["slug"] for a in yaml_cfg.get("agents", [])}
    if not agents_json.exists():
        _fail("agents.json missing — run tools/librechat_seed/seed.py")
        fails += 1
    else:
        try:
            data = json.loads(agents_json.read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            _fail(f"agents.json: {e}")
            fails += 1
        else:
            miss = expected_slugs - set(data.keys())
            if miss:
                _fail(f"agents.json missing slugs: {sorted(miss)}")
                fails += 1
            else:
                _ok(f"agents.json ({len(data)} slugs)")

    print()
    if fails:
        print(f"verify_suite: {fails} check(s) failed.")
        return 1
    print("verify_suite: all automated checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

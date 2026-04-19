"""Seed the LibreChat Prompts library from `prompts.yaml`.

Each top-level `groups:` entry becomes a PromptGroup; each nested `prompts:`
entry becomes a Prompt attached to that group.  Idempotent -- prompts are
matched to existing groups by name; duplicate prompts (same text) are skipped.

Phase F of LIBRECHAT_EXTENSIONS_PLAN.md."""
from __future__ import annotations

import sys
from pathlib import Path

import yaml

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from common import lc_curl, load_admin  # noqa: E402

# Prefer the data-driven generated yaml (every variable backed by a real
# suite-content enum dropdown).  Fall back to the hand-authored prompts.yaml
# if the generator hasn't been run yet.
_GENERATED = HERE / "prompts.generated.yaml"
_LEGACY = HERE / "prompts.yaml"
PROMPTS_YAML = _GENERATED if _GENERATED.exists() else _LEGACY


def _list_groups(token: str) -> dict[str, dict]:
    """Return {group_name -> group_dict}."""
    r = lc_curl("GET", "/api/prompts/groups?pageNumber=1&pageSize=200", token=token)
    r.raise_for_status()
    body = r.json()
    groups = body.get("promptGroups") or body.get("data") or body
    if isinstance(groups, dict):
        groups = groups.get("items", [])
    return {g["name"]: g for g in groups if isinstance(g, dict) and "name" in g}


def _list_prompts_in_group(token: str, group_id: str) -> set[str]:
    r = lc_curl("GET", f"/api/prompts?groupId={group_id}", token=token)
    if r.status_code >= 300:
        return set()
    body = r.json()
    items = body if isinstance(body, list) else body.get("prompts", [])
    return {p.get("prompt") for p in items if p.get("prompt")}


def _create_group_with_first_prompt(token: str, group: dict, first: dict) -> dict:
    body = {
        "prompt": {"type": first.get("type", "chat"), "prompt": first["prompt"]},
        "group": {k: v for k, v in group.items() if k in ("name", "category", "oneliner", "command")},
    }
    r = lc_curl("POST", "/api/prompts", token=token, json=body)
    r.raise_for_status()
    return r.json()


def _add_prompt_to_group(token: str, group_id: str, prompt: dict) -> None:
    body = {
        "prompt": {
            "type": prompt.get("type", "chat"),
            "prompt": prompt["prompt"],
        }
    }
    r = lc_curl("POST", f"/api/prompts/groups/{group_id}/prompts", token=token, json=body)
    r.raise_for_status()


def _share_group_public(token: str, group_id: str) -> None:
    """Grant the PUBLIC principal viewer access so every learner sees the
    prompt in their library.  Without this, only the author sees it."""
    body = {
        "public": True,
        "publicAccessRoleId": "promptGroup_viewer",
        "updated": [],
        "removed": [],
    }
    r = lc_curl(
        "PUT",
        f"/api/permissions/promptGroup/{group_id}",
        token=token,
        json=body,
    )
    # A stale group may 404 on the permissions endpoint; ignore so seeding continues.
    if r.status_code not in (200, 404):
        r.raise_for_status()


def main() -> int:
    admin = load_admin()
    print(f"[prompts] admin={admin.email}")

    cfg = yaml.safe_load(PROMPTS_YAML.read_text(encoding="utf-8"))
    existing_groups = _list_groups(admin.token)

    created_groups = 0
    created_prompts = 0
    for g in cfg["groups"]:
        prompts = g.get("prompts") or []
        if not prompts:
            print(f"  [{g['name']}] has no prompts, skipping")
            continue

        if g["name"] in existing_groups:
            group = existing_groups[g["name"]]
            group_id = group["_id"]
            print(f"  [{g['name']}] reuse {group_id}")
        else:
            result = _create_group_with_first_prompt(admin.token, g, prompts[0])
            group_id = result["group"]["_id"]
            existing_groups[g["name"]] = result["group"]
            created_groups += 1
            created_prompts += 1
            print(f"  [{g['name']}] created {group_id} with first prompt")

        known = _list_prompts_in_group(admin.token, group_id)
        # Skip the first prompt if this group was just created (already added).
        start_idx = 1 if g["name"] not in existing_groups or existing_groups[g["name"]].get("_id") != group_id else 0
        # Simpler: iterate all, skip duplicates.
        for p in prompts:
            if p["prompt"] in known:
                continue
            _add_prompt_to_group(admin.token, group_id, p)
            created_prompts += 1

        # Make every group visible to every learner, not only the seeder admin.
        _share_group_public(admin.token, group_id)

    print(f"[prompts] groups created: {created_groups}; prompts created: {created_prompts}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

"""Create/update workshop agents in LibreChat.

Idempotent: existing agents are matched by `name` and PATCHed; new agents are
POSTed.  Writes `scripts/.suite/state/librechat.agents.json` with the
`{slug → agent_id}` map the export step hands to Phoenix.

Phase E of LIBRECHAT_EXTENSIONS_PLAN.md."""
from __future__ import annotations

import json
import sys
from pathlib import Path

import yaml

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from common import lc_curl, list_agents, load_admin  # noqa: E402

REPO_ROOT = HERE.parent.parent
# Prefer the generated catalogue (base agents + per-chapter specialists + role
# coaches).  Fall back to the hand-authored minimum if the generator hasn't run.
_GEN = HERE / "agents.generated.yaml"
_BASE = HERE / "agents.yaml"
AGENTS_YAML = _GEN if _GEN.exists() else _BASE
FILES_STATE = REPO_ROOT / "scripts" / ".suite" / "state" / "librechat.files.json"
AGENTS_STATE = REPO_ROOT / "scripts" / ".suite" / "state" / "librechat.agents.json"


def _build_tool_resources(file_slugs: list[str], file_map: dict[str, str]) -> dict:
    file_ids = [file_map[s] for s in file_slugs if s in file_map]
    if not file_ids:
        return {}
    return {"file_search": {"file_ids": file_ids}}


def _payload(cfg: dict, global_cfg: dict, file_map: dict[str, str]) -> dict:
    tools = list(global_cfg.get("mcp_tools", []))
    if cfg.get("files"):
        tools.append("file_search")

    # ORCHESTRATE Core Preamble (THE ORCHESTRATE METHOD, Polzin 2025) prepended
    # at the system level so every agent inherits the O-R-C discipline without
    # per-agent duplication.  See BRANDING.md and tools/librechat_seed/PROMPT_DESIGN.md.
    core = (global_cfg.get("orchestrate_core") or "").strip()
    per_agent = (cfg.get("instructions") or "").rstrip()
    instructions = f"{core}\n\n{per_agent}" if core else per_agent

    body = {
        "name": cfg["name"],
        "description": cfg.get("description", ""),
        "instructions": instructions,
        "model": global_cfg.get("model", "qwen-36-direct"),
        "provider": global_cfg.get("provider", "Qwen 3.6 Direct"),
        "tools": tools,
    }
    resources = _build_tool_resources(cfg.get("files", []) or [], file_map)
    if resources:
        body["tool_resources"] = resources
    return body


def _share_agent_public(token: str, agent_public_id: str, mongo_id: str, shared: bool) -> None:
    """Grant public viewer access so every learner sees this agent in the
    `/api/agents` list.

    LibreChat's permissions API keys by MongoDB ObjectId (`_id`), not the
    public `agent_<slug>` id.  Without the public grant, the agent is
    invisible outside the owner and deep-links via `?agent_id=` work only
    for the admin who created them."""
    if not shared or not mongo_id:
        return
    body = {
        "public": True,
        "publicAccessRoleId": "agent_viewer",
        "updated": [],
        "removed": [],
    }
    r = lc_curl(
        "PUT",
        f"/api/permissions/agent/{mongo_id}",
        token=token,
        json=body,
    )
    if r.status_code not in (200, 404):
        r.raise_for_status()


def _ensure_file_ids_attached(token: str, agent_id: str, file_ids: list[str]) -> None:
    """Some LibreChat versions don't honor `tool_resources` on PATCH; if we see
    that, attach each file via POST /api/files with agent_id + endpoint=agents
    to force the link.  Here we short-circuit — it already worked on create."""
    if not file_ids:
        return
    r = lc_curl("GET", f"/api/agents/{agent_id}/expanded", token=token)
    if r.status_code >= 300:
        return
    body = r.json()
    attached = (body.get("tool_resources") or {}).get("file_search", {}).get("file_ids") or []
    missing = [fid for fid in file_ids if fid not in attached]
    if not missing:
        return
    r = lc_curl(
        "PATCH",
        f"/api/agents/{agent_id}",
        token=token,
        json={"tool_resources": {"file_search": {"file_ids": file_ids}}},
    )
    r.raise_for_status()


def main() -> int:
    admin = load_admin()
    print(f"[agents] admin={admin.email}")

    yaml_cfg = yaml.safe_load(AGENTS_YAML.read_text(encoding="utf-8"))
    # Force unique names so PATCH-on-collision works even if yaml is re-edited.
    file_map: dict[str, str] = {}
    if FILES_STATE.exists():
        file_map = json.loads(FILES_STATE.read_text(encoding="utf-8"))

    existing = {a.get("name"): a for a in list_agents(admin.token)}

    slug_to_id: dict[str, str] = {}
    for cfg in yaml_cfg["agents"]:
        body = _payload(cfg, yaml_cfg, file_map)
        name = cfg["name"]
        if name in existing:
            agent_id = existing[name]["id"]
            print(f"  [{cfg['slug']}] updating {agent_id}…")
            r = lc_curl("PATCH", f"/api/agents/{agent_id}", token=admin.token, json=body)
        else:
            print(f"  [{cfg['slug']}] creating…")
            r = lc_curl("POST", "/api/agents", token=admin.token, json=body)
        r.raise_for_status()
        resp = r.json()
        agent_id = resp.get("id")
        mongo_id = resp.get("_id")
        slug_to_id[cfg["slug"]] = agent_id
        # Ensure RAG file list is attached (LibreChat versions differ).
        file_ids = [file_map[s] for s in (cfg.get("files") or []) if s in file_map]
        _ensure_file_ids_attached(admin.token, agent_id, file_ids)
        # Make every workshop agent visible to every learner.  Lab coaches
        # default to shared=true via the YAML; only the hidden file-holder
        # agent (separate flow) stays admin-only.
        _share_agent_public(admin.token, agent_id, mongo_id, cfg.get("shared", True))

    AGENTS_STATE.parent.mkdir(parents=True, exist_ok=True)
    AGENTS_STATE.write_text(json.dumps(slug_to_id, indent=2), encoding="utf-8")
    print(f"[agents] wrote {AGENTS_STATE} ({len(slug_to_id)} entries)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

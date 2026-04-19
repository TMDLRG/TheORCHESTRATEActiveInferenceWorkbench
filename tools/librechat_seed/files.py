"""Upload chapter TXTs to LibreChat as RAG files.

Writes a map `{slug -> file_id}` to `scripts/.suite/state/librechat.files.json`
so the agents seeder can attach the right subset to each agent.

LibreChat's `/api/files` requires an agent_id when tool_resource=file_search,
so we maintain a hidden `aif-file-holder` agent that receives every upload;
real agents reference the same file_ids via PATCH tool_resources in agents.py.

Idempotent -- files present under the holder agent are reused rather than
re-uploaded.

Phase H of LIBRECHAT_EXTENSIONS_PLAN.md."""
from __future__ import annotations

import json
import sys
import uuid
from pathlib import Path

import requests

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from common import BROWSER_UA, LC_BASE_URL, lc_curl, list_agents, load_admin  # noqa: E402

REPO_ROOT = HERE.parent.parent
CHAPTER_DIR = REPO_ROOT / "active_inference" / "apps" / "workbench_web" / "priv" / "book" / "chapters"
STATE_FILE = REPO_ROOT / "scripts" / ".suite" / "state" / "librechat.files.json"

HOLDER_AGENT_NAME = "aif-file-holder"

CHAPTERS: dict[str, str] = {
    "preface": "preface.txt",
    "ch01": "ch01.txt",
    "ch02": "ch02.txt",
    "ch03": "ch03.txt",
    "ch04": "ch04.txt",
    "ch05": "ch05.txt",
    "ch06": "ch06.txt",
    "ch07": "ch07.txt",
    "ch08": "ch08.txt",
    "ch09": "ch09.txt",
    "ch10": "ch10.txt",
}


def _holder_agent_id(token: str) -> str:
    """Ensure a hidden holder agent exists; return its id.

    This agent is never surfaced to learners -- it only exists to satisfy
    LibreChat's `agent_id required` check when uploading RAG files."""
    existing = {a.get("name"): a for a in list_agents(token)}
    if HOLDER_AGENT_NAME in existing:
        return existing[HOLDER_AGENT_NAME]["id"]
    body = {
        "name": HOLDER_AGENT_NAME,
        "description": "Hidden holder -- receives RAG uploads so other agents can share the file ids.",
        "instructions": "Internal only.",
        "model": "qwen-36-direct",
        "provider": "Qwen 3.6 Direct",
        "tools": ["file_search"],
    }
    r = lc_curl("POST", "/api/agents", token=token, json=body)
    r.raise_for_status()
    return r.json()["id"]


def _existing_files(token: str) -> dict[str, str]:
    r = lc_curl("GET", "/api/files", token=token)
    r.raise_for_status()
    return {item["filename"]: item["file_id"] for item in r.json() if item.get("embedded")}


def _upload(token: str, holder_id: str, slug: str, filename: str) -> str | None:
    path = CHAPTER_DIR / filename
    if not path.exists():
        print(f"  [{slug}] missing {path}, skipping", file=sys.stderr)
        return None
    file_id = str(uuid.uuid4())
    with path.open("rb") as fh:
        r = requests.post(
            f"{LC_BASE_URL}/api/files",
            headers={"User-Agent": BROWSER_UA, "Authorization": f"Bearer {token}"},
            files={"file": (filename, fh, "text/plain")},
            data={
                "file_id": file_id,
                "agent_id": holder_id,
                "tool_resource": "file_search",
                "endpoint": "agents",
            },
            timeout=180,
        )
    if r.status_code >= 300:
        print(f"  [{slug}] upload failed {r.status_code}: {r.text[:200]}", file=sys.stderr)
        return None
    body = r.json()
    return body.get("file_id")


def main() -> int:
    admin = load_admin()
    print(f"[files] admin={admin.email}")

    holder_id = _holder_agent_id(admin.token)
    print(f"[files] holder agent_id={holder_id}")

    existing = _existing_files(admin.token)
    result: dict[str, str] = {}
    for slug, filename in CHAPTERS.items():
        if filename in existing:
            fid = existing[filename]
            print(f"  [{slug}] reuse {filename} -> {fid}")
        else:
            fid = _upload(admin.token, holder_id, slug, filename)
            if fid is None:
                continue
            print(f"  [{slug}] uploaded {filename} -> {fid}")
        result[slug] = fid

    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(f"[files] wrote {STATE_FILE} ({len(result)} entries)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

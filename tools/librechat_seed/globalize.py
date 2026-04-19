"""Register every workshop agent + prompt group in the LibreChat `instance`
project (the built-in "global" project) and flip `is_promoted: true` +
`isCollaborative: true` on each agent.

Why: LibreChat's agent picker segments results into "My Agents" (author ==
current user), "Shared" (via ACL), and "Marketplace" (in `instance` project
+ `is_promoted: true`).  A learner who is not the seeder admin sees the
marketplace/shared tabs, but "My Agents" stays near-empty — even though they
can USE every seeded agent.  Pushing the catalogue into the `instance`
project makes the agents behave globally (every user sees them under the
marketplace filter by default and the picker doesn't hide them).

Phoenix deep-links continue to use `agent_id=<agent_XXX>` so the chat-bridge
still lands on the right specialist.  This change only affects which tab the
agent appears in inside LibreChat's picker UI."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from common import lc_curl, load_admin  # noqa: E402

INSTANCE_PROJECT = "instance"


def _mongo(js: str) -> str:
    res = subprocess.run(
        ["docker", "exec", "chat-mongodb", "mongosh", "--quiet", "LibreChat", "--eval", js],
        capture_output=True,
        text=True,
        timeout=60,
    )
    if res.returncode != 0:
        raise RuntimeError(f"mongosh failed: {res.stderr}")
    return res.stdout.strip()


def _workshop_agent_oids(token: str) -> list[str]:
    """Return MongoDB ObjectId strings of every agent the seeder authored."""
    agents_state = HERE.parent.parent / "scripts" / ".suite" / "state" / "librechat.agents.json"
    slugs = list(json.loads(agents_state.read_text(encoding="utf-8")).values())
    oids: list[str] = []
    for slug in slugs:
        r = lc_curl("GET", f"/api/agents/{slug}/expanded", token=token)
        if r.status_code == 200:
            oid = r.json().get("_id")
            if oid:
                oids.append(oid)
    # Always include the file-holder -- it owns the uploaded chapter TXTs
    # so sharing its files across the tenant needs it globalised too.
    r = lc_curl("GET", "/api/agents?pageSize=200&requiredPermission=1", token=token)
    if r.status_code == 200:
        for a in (r.json().get("data") or []):
            if a.get("name") == "aif-file-holder" and a.get("_id") not in oids:
                oids.append(a["_id"])
                break
    return oids


def _workshop_prompt_group_oids(token: str) -> list[str]:
    r = lc_curl("GET", "/api/prompts/groups?pageSize=200", token=token)
    r.raise_for_status()
    body = r.json()
    groups = body.get("promptGroups") or body
    return [g["_id"] for g in groups if g.get("_id")]


def main() -> int:
    admin = load_admin()
    print(f"[globalize] admin={admin.email}")

    agent_oids = _workshop_agent_oids(admin.token)
    group_oids = _workshop_prompt_group_oids(admin.token)
    print(f"[globalize] {len(agent_oids)} agents, {len(group_oids)} prompt groups")

    # Upsert the `instance` project.  agentIds must be strings — LibreChat's
    # schema stores them as Mongo ObjectId-as-string.
    agent_list = json.dumps(agent_oids)
    group_list = json.dumps(group_oids)
    js = f"""
    db.projects.updateOne(
      {{ name: "{INSTANCE_PROJECT}" }},
      {{
        $set: {{
          name: "{INSTANCE_PROJECT}",
          updatedAt: new Date()
        }},
        $addToSet: {{
          agentIds:       {{ $each: {agent_list} }},
          promptGroupIds: {{ $each: {group_list} }}
        }},
        $setOnInsert: {{ createdAt: new Date() }}
      }},
      {{ upsert: true }}
    );
    print("instance project agentIds=" + (db.projects.findOne({{name:"{INSTANCE_PROJECT}"}}).agentIds || []).length);
    print("instance project promptGroupIds=" + (db.projects.findOne({{name:"{INSTANCE_PROJECT}"}}).promptGroupIds || []).length);
    """
    print(_mongo(js))

    # Flip is_promoted + isCollaborative on every workshop agent.  projectIds
    # is also set so the agent doc knows it belongs to the instance project.
    # Look up the instance project's _id for projectIds.
    js2 = f"""
    const inst = db.projects.findOne({{ name: "{INSTANCE_PROJECT}" }});
    const oids = {agent_list}.map(s => ObjectId(s));
    const r = db.agents.updateMany(
      {{ _id: {{ $in: oids }} }},
      {{
        $set: {{
          is_promoted: true,
          isCollaborative: true
        }},
        $addToSet: {{ projectIds: inst._id }}
      }}
    );
    print("updated agents: " + r.modifiedCount);
    """
    print(_mongo(js2))

    # Same for prompt groups (project reference + public field if any).
    js3 = f"""
    const inst = db.projects.findOne({{ name: "{INSTANCE_PROJECT}" }});
    const oids = {group_list}.map(s => ObjectId(s));
    const r = db.promptgroups.updateMany(
      {{ _id: {{ $in: oids }} }},
      {{ $addToSet: {{ projectIds: inst._id }} }}
    );
    print("updated prompt groups: " + r.modifiedCount);
    """
    print(_mongo(js3))

    # Back-fill ACL so every EXISTING user sees every workshop agent + every
    # prompt group as "mine" (author==self fails, but ACL editor puts them in
    # every "my / shared / accessible" list the client renders).  Same for
    # prompt groups.  For each (user, agent) pair we upsert an AclEntry doc
    # with the `agent_editor` role (permBits: 3); for (user, group) we use
    # `promptGroup_editor` (permBits: 3).  `$setOnInsert` keeps grants
    # idempotent — the exact same ObjectId lands in the same slot on re-runs.
    js4 = f"""
    const ownerAgent  = db.accessroles.findOne({{ accessRoleId: "agent_editor" }});
    const ownerGroup  = db.accessroles.findOne({{ accessRoleId: "promptGroup_editor" }});
    if (!ownerAgent || !ownerGroup) {{
      print("[grant] WARN accessroles missing; re-seed LibreChat roles first");
    }}
    const agentOids = {agent_list}.map(s => ObjectId(s));
    const groupOids = {group_list}.map(s => ObjectId(s));
    const users = db.users.find({{}}, {{_id: 1, email: 1}}).toArray();
    let a = 0, g = 0;
    for (const u of users) {{
      for (const aid of agentOids) {{
        const r = db.aclentries.updateOne(
          {{ principalId: u._id, principalType: "user", resourceId: aid, resourceType: "agent" }},
          {{
            $set: {{
              principalModel: "User",
              resourceType: "agent",
              principalType: "user",
              principalId: u._id,
              resourceId: aid,
              roleId: ownerAgent._id,
              permBits: 3,
              grantedBy: u._id,
              grantedAt: new Date(),
              updatedAt: new Date()
            }},
            $setOnInsert: {{ createdAt: new Date() }}
          }},
          {{ upsert: true }}
        );
        if (r.upsertedId || r.modifiedCount) a++;
      }}
      for (const gid of groupOids) {{
        const r = db.aclentries.updateOne(
          {{ principalId: u._id, principalType: "user", resourceId: gid, resourceType: "promptGroup" }},
          {{
            $set: {{
              principalModel: "User",
              resourceType: "promptGroup",
              principalType: "user",
              principalId: u._id,
              resourceId: gid,
              roleId: ownerGroup._id,
              permBits: 3,
              grantedBy: u._id,
              grantedAt: new Date(),
              updatedAt: new Date()
            }},
            $setOnInsert: {{ createdAt: new Date() }}
          }},
          {{ upsert: true }}
        );
        if (r.upsertedId || r.modifiedCount) g++;
      }}
    }}
    print("granted agent ACL entries: " + a);
    print("granted promptGroup ACL entries: " + g);
    print("users reached: " + users.length);
    """
    print(_mongo(js4))

    print("[globalize] done")
    return 0


if __name__ == "__main__":
    sys.exit(main())

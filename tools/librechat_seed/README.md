# LibreChat seeders

Python scripts that provision the workshop LibreChat instance from scratch:
admin user + agents (chapter tutors & lab coaches) + RAG files + prompts + memories.

Run every time the stack boots: **`./scripts/start_suite.sh`** or **`scripts/start_suite.ps1`**
calls `scripts/librechat_bootstrap.py` then `tools/librechat_seed/seed.py` after LibreChat
is reachable. Idempotent per name — re-running PATCHes existing agents/prompts rather than creating duplicates.

Post-deploy checks: **`python tools/librechat_seed/verify_suite.py`** (see `scripts/RELEASE_RUNBOOK.md`).

## Files

| file | purpose |
|---|---|
| `common.py`     | JWT state file (`scripts/.suite/state/librechat.admin.json`), `lc_curl` helper, browser UA header (LibreChat's `uaParser` rejects anything else). |
| `agents.yaml`   | Declarative agent catalogue — eleven agents (four path tutors + seven lab coaches). |
| `agents.py`     | Creates/updates agents, attaches `voice` MCP tools, wires RAG file lists. |
| `files.py`      | Uploads `priv/book/chapters/ch*.txt` to LibreChat and returns a `{slug → file_id}` map. |
| `prompts/*.yaml`| Per-chapter / per-equation / per-lab prompt libraries (Phase F). |
| `prompts.py`    | Seeds LibreChat PromptGroups from the YAML files. |
| `memories.py`   | Writes starter per-user memories (Phase G). |
| `export_agent_ids.py` | Writes `active_inference/apps/workbench_web/priv/librechat/agents.json`; Phoenix reads it to deep-link `/c/new?agent_id=...`. |
| `verify_suite.py` | Optional QA script — voice health, agent names, prompt groups, memories, `agents.json` slugs. |
| `seed.py`       | Orchestrator — runs files → agents → prompts → memories → export. |

`priv/librechat/agents.json` is **gitignored** (generated per machine). `agents.json.example` is an empty `{}` placeholder; run `seed.py` to populate.

## Usage

```
python scripts/librechat_bootstrap.py      # register admin, capture JWT
python tools/librechat_seed/seed.py        # run everything
```

Or individually:

```
python tools/librechat_seed/files.py
python tools/librechat_seed/agents.py
python tools/librechat_seed/export_agent_ids.py
```

## Requirements

- LibreChat reachable at `LC_BASE_URL` (default `http://localhost:3080`).
- Python 3.11+, `requests`, `pyyaml`.

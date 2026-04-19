# LibreChat + workshop stack — release and promotion

Use this after merging to `master` or tagging a release. Aligns with [LIBRECHAT_EXTENSIONS_PLAN.md](../LIBRECHAT_EXTENSIONS_PLAN.md) §9 and the [librechat_seed README](../tools/librechat_seed/README.md).

## 1. Pin the revision

- Create an annotated tag (example: `v2026.04.19`) and record the commit SHA in release notes.

## 2. Sync configuration

- **LibreChat**: Copy or merge [`Qwen3.6/librechat/.env`](../Qwen3.6/librechat/.env) from `.env.example` on the target host. See plan §10.1 (`ENDPOINTS=agents,custom`, agents capabilities), §10.2 (full RAG image + HuggingFace embeddings), §10.3 (seeder-friendly UA / ban settings for local workshop).
- **Phoenix** (optional behind a proxy): Set `PHX_PUBLIC_ORIGIN` to the public base URL (no trailing slash) so the voice-autoplay bookmarklet on `/learn/voice-autoplay` loads the correct `/assets/voice-autoplay.js`.

## 3. Build and start Docker

From the repo root:

```bash
cd Qwen3.6/librechat
docker compose build voice
docker compose up -d
```

Wait for LibreChat on `:3080`, voice HTTP on `:7712`, MCP SSE on `:7711`.

## 4. Bootstrap and seed LibreChat (Mongo)

The suite launcher runs these automatically after LibreChat is reachable:

```bash
# From repo root (Python 3.11+)
python scripts/librechat_bootstrap.py
python tools/librechat_seed/seed.py
```

Or run `./scripts/start_suite.sh` (or `start_suite.ps1` on Windows), which includes the same steps.

Seeding is idempotent: agents and prompts are updated by name; `export_agent_ids.py` writes `active_inference/apps/workbench_web/priv/librechat/agents.json` (gitignored; generated per environment).

## 5. Start Phoenix (and Qwen if used)

```bash
cd active_inference
MIX_ENV=dev PORT=4000 mix phx.server
```

`WorkbenchWeb.LibreChatAgents` reads `agents.json` from disk on each lookup; restart Phoenix after seeding if you run a **release** build that bakes `priv` at compile time.

## 6. Verification

Automated:

```bash
python tools/librechat_seed/verify_suite.py
```

Optional env: `LC_BASE_URL`, `VOICE_HTTP_URL`.

Manual (see plan §9):

- Learn hub → chapter → Full Chat → correct agent, starter prompt, RAG, voice tools.
- LibreChat Prompts library → seeded group (e.g. Bayes) with variables.
- Install bookmarklet from `/learn/voice-autoplay` (or TamperMonkey); trigger `speak~voice` and confirm audio after playback.

## 7. Troubleshooting

| Symptom | Check |
|--------|--------|
| No agents/prompts | `scripts/.suite/logs/librechat_seed.log`; re-run `seed.py` |
| Bootstrap fails | `librechat_bootstrap.log`; Mongo `chat-mongodb` running; `docker exec chat-mongodb …` per bootstrap error |
| Bridge has no `agent_id` | `priv/librechat/agents.json` exists and matches slugs; re-run seed |
| Voice MCP errors | `mcpSettings.allowedDomains` in `librechat.yaml`; `docker logs workshop-voice` |
| HTTPS LibreChat + HTTP voice | Mixed content; proxy voice or set `PHX_PUBLIC_ORIGIN` and use HTTPS for voice upstream |

## 8. Expected seeded content

| Artifact | Count / note |
|----------|----------------|
| Agents | 11 (4 path tutors + 7 lab coaches) from `agents.yaml` |
| Prompt groups | ≥ 13 from `prompts.yaml` |
| Memories | 5 starter keys for admin user |
| `agents.json` | One LibreChat `agent_id` per slug for Phoenix deep-links |

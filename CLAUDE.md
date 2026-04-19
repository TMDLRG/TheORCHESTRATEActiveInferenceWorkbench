# WorldModels — Project Rules

## Stack Mandate

This project uses **pure Jido / Elixir / BEAM** for all agent work. No Python, no external agent runtimes (LangChain, CrewAI, Autogen, etc.). AI/LLM integration goes through `jido_ai`.

## Before Writing Agent Code — Read the Knowledgebase

The Jido knowledgebase lives at [knowledgebase/jido/](knowledgebase/jido/). **Always open it first.**

Entry point: [knowledgebase/jido/MASTER-INDEX.md](knowledgebase/jido/MASTER-INDEX.md).

Non-negotiables (from [knowledgebase/jido/00-philosophy.md](knowledgebase/jido/00-philosophy.md)):
- `cmd/2` is pure: same input → same `{agent, directives}` output
- Directives describe external effects; they never mutate agent state
- StateOps are applied by the strategy inside `cmd/2` and never leave it
- Cross-agent communication is **signals** (`Jido.Signal`) or **directives** — never raw `send/2`, `GenServer.call/3` to an agent pid, or `Phoenix.PubSub.broadcast/3` from `cmd/2`
- Errors at public boundaries are `{:error, %Jido.Error.*{}}` (Splode-structured), not strings/atoms/raw maps
- Tests never use `Process.sleep/1` — use `Jido.await/2`, `JidoTest.Eventually`, or event-driven assertions
- `--no-verify` / skipping pre-commit hooks is off-limits unless explicitly authorized
- Writing to reserved `:__xxx__` state keys directly is off-limits (framework manages them)

## Upstream Reference

The cloned Jido repo lives at [jido/](jido/) (version `2.2.0`, matches hexdocs.pm/jido). Use it as the source of truth when the knowledgebase is ambiguous:
- `jido/guides/` maps 1:1 to hexdocs pages
- `jido/lib/` is the canonical API
- `jido/usage-rules.md` and `jido/AGENTS.md` are canonical author rules
- `jido/test/AGENTS.md` documents test helpers (`JidoTest.Case`, `JidoTest.Eventually`)

## Runtime Baseline

- Elixir `~> 1.18`, OTP `27+`
- Use `Zoi` schemas for new agent/plugin/signal/directive contracts (legacy `NimbleOptions` still works but don't author new code with it)

## QA Commands (when the Elixir app exists)

- `mix test` (default excludes `:flaky`)
- `mix test --include flaky` (full suite)
- `mix q` / `mix quality` (format, compile with warnings-as-errors, credo, dialyzer)

## Knowledgebase Maintenance

Keep the knowledgebase in sync when upstream Jido changes:
1. `cd jido && git pull`
2. Diff `jido/guides/` and `jido/lib/` for material changes
3. Update the relevant `knowledgebase/jido/NN-*.md` file(s) and `MASTER-INDEX.md` if the set of topics shifts

## Prompt + cookbook authoring

This suite is *The ORCHESTRATE Active Inference Learning Workbench* (see [BRANDING.md](BRANDING.md)). Prompts and cookbook recipes follow strict conventions:

- **Prompt design** (every LibreChat agent + saved prompt): [tools/librechat_seed/PROMPT_DESIGN.md](tools/librechat_seed/PROMPT_DESIGN.md). O-R-C on system prompts; per-prompt sub-letters only where needed.
- **Cookbook schema** (50 runnable recipes): [active_inference/apps/workbench_web/priv/cookbook/_schema.yaml](active_inference/apps/workbench_web/priv/cookbook/_schema.yaml). Validate with `mix cookbook.validate` — a recipe that references a missing Jido action or skill cannot ship.
- **Copyright-safe rule** (non-negotiable): apply the frameworks, never reproduce book prose. Polzin books are gitignored per [BOOK_SOURCES.md](BOOK_SOURCES.md).
- **Runtime gaps**: [RUNTIME_GAPS.md](RUNTIME_GAPS.md) tracks which actions/skills/worlds exist vs. which a pending recipe needs.
- **Screenshots**: [scripts/capture_screenshots.md](scripts/capture_screenshots.md) is the authoritative capture checklist for the guide.

## Studio vs. Labs (runtime choice)

Two coexisting episode runners, both running native Jido on the BEAM:

- **`/labs`** -- stable "fresh agent + fresh world per click."  Do not regress; snapshot-tested.
- **`/studio`** -- flexible workshop.  Accepts already-running agents, tracks full lifecycle (live / stopped / archived / trashed), supports soft-delete + restore + empty trash.  Any module implementing [WorldPlane.WorldBehaviour](active_inference/apps/world_plane/lib/world_plane/world_behaviour.ex) plugs in.  See [STUDIO_PLAN.md](STUDIO_PLAN.md) for the full design; [AgentPlane.Instances](active_inference/apps/agent_plane/lib/agent_plane/instances.ex) owns the Mnesia lifecycle table.

Future custom-world builder work targets the `WorldBehaviour` contract, not the Engine internals.

# Contributing

Thank you for helping improve ORCWorkbench / WorldModels. This document summarises the rules that apply to every contribution. The authoritative source for project-wide rules is [`CLAUDE.md`](CLAUDE.md); the Jido framework reference is at [`knowledgebase/jido/MASTER-INDEX.md`](knowledgebase/jido/MASTER-INDEX.md).

## Non-negotiables

These are enforced by the test suite and by `mix q`. Do not bypass them.

1. **Stack mandate** — pure Jido / Elixir / BEAM for all agent work. No Python, no external agent runtimes (LangChain, CrewAI, AutoGen, etc.). AI/LLM integration goes through `jido_ai`.
2. **`cmd/2` purity** — same input must produce the same `{agent, directives}` output. No side effects inside `cmd/2`.
3. **Directives describe external effects** — they never mutate agent state. StateOps are applied by the strategy inside `cmd/2` and never leave it.
4. **Cross-agent communication is signals or directives** — never raw `send/2`, `GenServer.call/3` to an agent pid, or `Phoenix.PubSub.broadcast/3` from inside `cmd/2`.
5. **Errors at public boundaries are Splode-structured** — `{:error, %Jido.Error.*{}}`, not strings, atoms, or raw maps.
6. **No `Process.sleep/1` in tests** — use `Jido.await/2`, `JidoTest.Eventually`, or event-driven assertions on [`WorldModels.Bus`](active_inference/apps/world_models/lib/world_models/bus.ex).
7. **Do not write to reserved `:__xxx__` state keys directly** — the framework manages them.
8. **Do not skip pre-commit hooks** — `--no-verify`, `--no-gpg-sign`, etc. are off-limits unless explicitly authorized.
9. **Plane separation** — `world_plane` does not depend on `agent_plane` or `active_inference_core`; `agent_plane` does not depend on `world_plane`. Enforced by `apps/*/test/plane_separation_test.exs`.

## Runtime baseline

- Elixir `~> 1.18` (tested on 1.19.5)
- Erlang/OTP `27+` (tested on OTP 28)
- Use **Zoi** schemas for new agent/plugin/signal/directive contracts. Legacy `NimbleOptions` still works in existing code; do not author new code with it.

## Before submitting a change

From the umbrella root (`active_inference/`):

```bash
mix format                         # format staged changes
mix compile --warnings-as-errors   # zero warnings
mix test                           # default excludes :flaky tag
mix test --include flaky           # full suite
mix q                              # full quality gate (format + warnings-as-errors test)
mix docs                           # build ExDoc HTML; verify your @doc additions render
```

### Documentation expectations

- Every public function must carry `@doc` and `@spec`. Private functions (`defp`) do not.
- `@moduledoc` is mandatory at every module: state the architectural role and cite the equation(s) implemented where applicable.
- If you touch a file that has a sibling `ReadmeAI.MD`, update it to reflect the change (module added/removed, new public function, new event type).
- If you add a new folder under source, add a `ReadmeAI.MD` using the template described in the [documentation plan](active_inference/docs/decisions/) and existing examples.

### Verification-status vocabulary

Borrow the vocabulary from [`ActiveInferenceCore.Equation.verification_status`](active_inference/apps/active_inference_core/lib/active_inference_core/equation.ex):

- `:verified` — backed by at least one passing test that exercises the contract end-to-end.
- `:scaffolded` — code exists and compiles; no end-to-end test yet.
- `:uncertain` — known gap or open question.

Use the same vocabulary when writing `@doc` or `ReadmeAI.MD` so documentation reads consistently.

### Commit etiquette

- Create new commits rather than amending existing ones (exceptions: the user explicitly asked).
- Prefer many small commits over one large one — each one should leave the tree in a working state.
- Do not stage `.env`, credentials, or build artefacts. `.gitignore` is authoritative; add to it rather than using `git add -f`.
- Do not force-push to `master` / `main`.

### Pull request body

- Summary (1–3 bullets): what changed and why.
- Test plan: a bulleted checklist of what you ran to verify.
- If you added documentation, link the rendered `/guide/technical/*` route or `doc/` page.

## Adding a new umbrella app

1. `cd active_inference && mix new apps/<name> --sup`.
2. Add to umbrella dependency graph respecting the plane-separation invariant.
3. Add `@moduledoc` to every module.
4. Add `ReadmeAI.MD` at `apps/<name>/`, `apps/<name>/lib/`, `apps/<name>/test/`.
5. Add a plane-separation test if the app participates in the agent↔world boundary.
6. Register the app in [`active_inference/mix.exs`](active_inference/mix.exs) (ExDoc `groups_for_modules`).

## Updating the Jido knowledgebase

The Jido reference at [`knowledgebase/jido/`](knowledgebase/jido/) is kept in sync manually when upstream changes:

```bash
cd jido && git pull
# Diff jido/guides/ and jido/lib/ for material changes
# Update the relevant knowledgebase/jido/NN-*.md file(s)
# Update knowledgebase/jido/MASTER-INDEX.md if the set of topics shifts
```

## Questions

If a rule seems to conflict with a legitimate use case, raise the question in the PR rather than working around it. The rules exist because the maintainers have been bitten by the alternative.

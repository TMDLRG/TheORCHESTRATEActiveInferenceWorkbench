# ADR-001 — `:world_models` app atom rename: deferred

**Status:** Deferred from v1.1-remediation; tracked for v2 milestone
**Date:** 2026-05-07
**Driver:** External review finding A1 (Aaronson, v1+v2)

## Context

The repository's `world_models` Elixir app — a registry/event-log for generative-model specs and archetypes — collides in name with the Hafner & Schmidhuber 2018 / DreamerV3 / DayDreamer lineage of "world models" as **learned environment dynamics models**. The workbench's bundles are hand-built, not learned.

The reviewer's prescription: rename to something like `ActiveInferenceWorkbench` or `GenerativeModelWorkbench`.

## What we tried in v1.1

Initial plan was to rename the OTP app atom only (`:world_models` → `:spec_registry`), preserving the directory `apps/world_models/`, the `WorldModels.*` module namespace, and the Mnesia table atoms. This was the lowest-blast-radius interpretation of the rename.

We applied the change across:
- `apps/world_models/mix.exs` (`app:` atom)
- 3 consumer `mix.exs` files (`{:world_models, in_umbrella: true}` → `{:spec_registry, ...}`)
- Umbrella `releases:` declaration
- `Application.get_env(:world_models, :auto_start_event_log, ...)` in `world_models/application.ex`
- `config :world_models, ...` in `config/test.exs`
- Two UI/test refs to the config key string

## What blocked it

**Mix umbrella has a hard constraint**: `apps/<dirname>/mix.exs` must declare `app: :<dirname>`. From the failed compile:

```
** (Mix) Umbrella app :spec_registry is located at directory world_models.
   Mix requires the directory to match the application name for umbrella apps.
   Please rename the directory or change the application name in the mix.exs file.
```

The `path: "../world_models"` override that works for non-umbrella deps does not satisfy this constraint — Mix enforces the convention at the umbrella resolver level, before path resolution.

So the rename of the OTP atom alone is not possible. Three real options:

1. **Rename the directory `apps/world_models/` → `apps/spec_registry/`.** Cost: every existing dev clone's `cd` muscle memory, IDE workspace files, and shell histories break. Also forces a renaming of the `WorldModels.*` namespace to stay consistent (otherwise `apps/spec_registry/` containing `WorldModels.*` modules is uglier than the original). That cascades through hundreds of `defmodule`, `alias`, and `@spec` lines.
2. **Move the app out of the umbrella into a non-umbrella dep.** Massive refactor; the app would need its own repo or path-dep configuration. Out of scope for v1.1.
3. **Don't rename. Treat the README revision (PR 3) as the substantive A1 fix; keep `:world_models` internally.** Documented inconsistency between the user-facing framing ("Active Inference workbench, POMDP+VMP+EFE") and the internal app naming.

## Decision

**Option 3 for v1.1.** Revert all code changes; ship only the README revision (PR 3) as the A1 remediation. Keep `:world_models` everywhere internally.

**Document the constraint here.** The Mix-umbrella directory-atom equivalence is a real constraint; future contributors should know about it before re-attempting this rename.

**Defer to v2 milestone.** A proper rename (directory + namespace + atom + Mnesia migration shim) is multi-day work. Track it as part of `v2-nx-port` or a sibling milestone — pair it with the substrate rework so the cost is amortised.

## What addresses A1 in v1.1

- **README first paragraph rewrite (PR 3, commit `6898579`)**: explicit "pedagogical Active Inference workbench: BEAM-native reference implementation of discrete-time POMDP with mean-field VMP and EFE-weighted policy posterior" + "Scope honesty" callout naming what is and isn't implemented.
- **OPS.md (PR 2, commit `aabeaed`)**: pedagogical-scale framing throughout, capability ceilings disclosed.

The reviewer's quote in v2: *"the README's first sentence is..."* — that surface is fixed. The internal `:world_models` atom remains as a known name-not-quite-matched-to-purpose.

## Consequences

**Positive.** v1.1 ships clean and compiling. The user-facing surface (README, OPS.md) reflects the corrected framing. The deferred work is named explicitly so it's not lost.

**Negative.** Internal name `:world_models` remains for an app that does spec/event registration, not learned world modelling. A reviewer reading `mix deps.tree` still sees `:world_models`.

**Mitigation.** This ADR is the documentation that resolves the apparent inconsistency. It also captures the Mix-umbrella constraint that drove the deferral.

## References

- External review v1 (Aaronson A1): `~/Downloads/pulzin-active-inference-review_V1.pdf`
- External review v2 (status UNCHANGED): `~/Downloads/pulzin-active-inference-review-v2.md`
- README revision (PR 3, A1 substantive fix): commit `6898579`
- OPS.md (framing remediation): commit `aabeaed`
- Plan-agent critique (advised against full directory rename): archived in `~/.claude/plans/c-users-mpolz-documents-worldmodels-mak-streamed-key.md`

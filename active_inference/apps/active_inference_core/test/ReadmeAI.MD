# active_inference_core/test/ — ReadmeAI

## Purpose

Tests for the pure math library. All use `ExUnit.Case, async: true` — no GenServers, no Mnesia, no process state.

## Contents

| File | Scope |
|---|---|
| [`equation_registry_test.exs`](equation_registry_test.exs) | Registry integrity (unique ids, dependency resolution, verification-status shape); T1 extraction completeness |
| [`discrete_time_test.exs`](discrete_time_test.exs) | POMDP inference math: belief updates, F, G, policy posterior, choose_action |
| [`discrete_time_telemetry_test.exs`](discrete_time_telemetry_test.exs) | `:telemetry.span/3` emissions on `[:active_inference_core, :discrete_time, :call]` |
| [`test_helper.exs`](test_helper.exs) | `ExUnit.start()` |

## Conventions

- `ExUnit.Case, async: true` on every test module
- No `Process.sleep/1` (enforced by [`CLAUDE.md`](../../../../CLAUDE.md))
- Numbered test labels (`T1 — …`, `T2 — …`) on the boundary tests
- `@doc` / `@spec` on helper functions

## Verification status

- `:verified` — 20 tests, all passing.

## Related

- App docs: [`../ReadmeAI.MD`](../ReadmeAI.MD)

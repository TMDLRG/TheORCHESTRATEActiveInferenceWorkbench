# composition_runtime/test/ — ReadmeAI

## Purpose

Smoke tests for the composition supervisor + signal broker.

## Contents

| File | Scope |
|---|---|
| [`composition_runtime_test.exs`](composition_runtime_test.exs) | Supervisor starts; `SignalBroker` routes a signal between two registered agents |
| [`test_helper.exs`](test_helper.exs) | `ExUnit.start()` |

## Conventions

`ExUnit.Case, async: true`. No `Process.sleep` — use `Jido.await/2` where needed.

## Verification status

- `:scaffolded` — basic routing covered; multi-agent orchestration patterns (aggregation, fan-out) not yet exercised.

## Related

- App docs: [`../ReadmeAI.MD`](../ReadmeAI.MD)

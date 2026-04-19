# shared_contracts/test/ — ReadmeAI

## Purpose

Tests for the Markov-blanket packet types. Pure data; no process state.

## Contents

| File | Scope |
|---|---|
| [`blanket_test.exs`](blanket_test.exs) | `Blanket.maze_default/0` shape; `ActionPacket.new/1` rejects actions outside vocabulary; `ObservationPacket.new/1` rejects channels outside declared set; channel_spec kinds |
| [`test_helper.exs`](test_helper.exs) | `ExUnit.start()` |

## Conventions

`ExUnit.Case, async: true`. 4 tests total.

## Verification status

- `:verified` — blanket enforcement is provably tight.

## Related

- App docs: [`../ReadmeAI.MD`](../ReadmeAI.MD)

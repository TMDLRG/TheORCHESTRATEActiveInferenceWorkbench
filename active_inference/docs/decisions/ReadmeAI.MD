# active_inference/docs/decisions/ — ReadmeAI

## Purpose

Architecture Decision Records (ADRs). Each file documents a single non-trivial architectural choice with its context, candidates, decision, rationale, and implications. Format matches the inline ADRs in [`../../DELIVERABLE.md`](../../DELIVERABLE.md) §6.

## Contents

| ADR | Title | Status | Date |
|---|---|---|---|
| [`canvas-library.md`](canvas-library.md) | Composition canvas library for the Agent Builder (litegraph.js chosen over rete.js v2) | Accepted | 2026-04-17 |

### Inline ADRs (not in this folder)

[`../../DELIVERABLE.md`](../../DELIVERABLE.md) §6 embeds six additional ADRs covering umbrella architecture, blanket contracts, native Jido, Phoenix LiveView, inline CSS, and Bandit HTTP adapter. Migrating them into standalone files is a future cleanup.

## ADR format (inherited, do not change)

```markdown
# ADR-NNN: <title>

**Date:** YYYY-MM-DD
**Phase:** <plan phase reference>
**Status:** Proposed | Accepted | Superseded by ADR-XXX | Rejected

## Context
## Candidates (re-evaluated)
## Decision
## Rationale
## Implications
## Risks
## Tests
```

## Public API surface

None.

## Data types & schemas

None.

## Constants & config keys

None.

## Telemetry / signals / events emitted here

None.

## Dependencies

- **Inbound**: [`../../CONTRIBUTING.md`](../../CONTRIBUTING.md), [`../../docs/INDEX.md`](../../docs/INDEX.md), the in-app `/guide/technical/verification` page.
- **Outbound**: none.

## Verification status

- `:verified` — ADR-001 implemented and verified (see `../apps/workbench_web/lib/workbench_web/live/builder_live/compose.ex`).

## Related

- Parent: [`../ReadmeAI.MD`](../ReadmeAI.MD)
- Full list of ADRs (inline + standalone): [`../../DELIVERABLE.md`](../../DELIVERABLE.md) §6

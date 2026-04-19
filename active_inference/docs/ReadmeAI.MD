# active_inference/docs/ — ReadmeAI

## Purpose

Project-level documentation artefacts that don't fit in a specific app — currently Architecture Decision Records (ADRs). High-level project documentation lives at the repository root (`ARCHITECTURE.md`, `CONTRIBUTING.md`, etc.); ADRs live here.

## Contents

| Path | Role |
|---|---|
| [`decisions/`](decisions/) | Architecture Decision Records |

## Public API surface

None.

## Data types & schemas

None.

## Constants & config keys

None.

## Telemetry / signals / events emitted here

None.

## Dependencies

- **Inbound**: referenced from [`../../CONTRIBUTING.md`](../../CONTRIBUTING.md) and [`../../docs/INDEX.md`](../../docs/INDEX.md).
- **Outbound**: none.

## Verification status

- `:verified` — ADR-001 is live and implemented (`litegraph.js` is used by [`../apps/workbench_web/lib/workbench_web/live/builder_live/compose.ex`](../apps/workbench_web/lib/workbench_web/live/builder_live/compose.ex)).

## Related

- Inline ADRs in [`../DELIVERABLE.md`](../DELIVERABLE.md) §6 (umbrella architecture, blanket contracts, native Jido, Phoenix LiveView, etc.)
- [`decisions/ReadmeAI.MD`](decisions/ReadmeAI.MD)

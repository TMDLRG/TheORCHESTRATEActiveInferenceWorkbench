# workbench_web/lib/workbench_web/live/guide_live/ — ReadmeAI

## Purpose

The in-app guide: user tutorial, examples catalogue, block catalogue, and — added by the documentation pass — the full technical reference. Every page is a Phoenix LiveView that fetches its data from module-introspection (`Code.fetch_docs/1`) and the runtime registries (`Equations`, `Models`, `Archetypes`, `Topology`).

## Contents

### User-facing (existing)

| File | Module | Route | Purpose |
|---|---|---|---|
| [`index.ex`](index.ex) | `WorkbenchWeb.GuideLive.Index` | `/guide` | Landing: what-is-AI, architecture, markov blanket |
| [`blocks.ex`](blocks.ex) | `WorkbenchWeb.GuideLive.Blocks` | `/guide/blocks` | Block catalogue — auto-generated from `WorldModels.Spec.Topology.node_types/0` |
| [`examples.ex`](examples.ex) | `WorkbenchWeb.GuideLive.Examples` | `/guide/examples`, `/guide/examples/:slug` | Five L1–L5 examples (list + detail) |
| [`example_catalog.ex`](example_catalog.ex) | `WorkbenchWeb.GuideLive.ExampleCatalog` | (support) | Data module backing `Examples` |
| [`tutorial.ex`](tutorial.ex) | `WorkbenchWeb.GuideLive.Tutorial` | `/guide/build-your-first` | 6-step tutorial (world → matrices → bundle → actions → save → glass) |

### Technical reference (Phase D additions — see [`../../../../../../.claude/plans/fully-document-this-solution-delightful-hejlsberg.md`](../../../../../../CLAUDE.md))

| File | Module | Route | Purpose |
|---|---|---|---|
| `technical/index.ex` | `WorkbenchWeb.GuideLive.Technical.Index` | `/guide/technical` | Landing for technical reference |
| `technical/architecture.ex` | `WorkbenchWeb.GuideLive.Technical.Architecture` | `/guide/technical/architecture` | Plane separation, event flow, dependency graph |
| `technical/apps.ex` | `WorkbenchWeb.GuideLive.Technical.Apps` | `/guide/technical/apps` | Per-app public API tables |
| `technical/signals.ex` | `WorkbenchWeb.GuideLive.Technical.Signals` | `/guide/technical/signals` | Every Jido signal / directive / telemetry / `WorldModels.Event` type |
| `technical/data.ex` | `WorkbenchWeb.GuideLive.Technical.Data` | `/guide/technical/data` | Structs, typespecs, Mnesia tables, PubSub topics |
| `technical/config.ex` | `WorkbenchWeb.GuideLive.Technical.Config` | `/guide/technical/config` | Every Application env key, `config/*.exs` entry |
| `technical/module.ex` | `WorkbenchWeb.GuideLive.Technical.Module` | `/guide/technical/api/:module` | Per-module page from `Code.fetch_docs/1` |
| `technical/verification.ex` | `WorkbenchWeb.GuideLive.Technical.Verification` | `/guide/technical/verification` | Verified / scaffolded / uncertain honesty manifest |

## Dependencies (technical subtree)

Technical pages pull data from:

- `WorkbenchWeb.Docs.ApiCatalog` — enumerates modules per umbrella app via `Application.spec/2`; introspects `@doc`/`@spec` via `Code.fetch_docs/1`
- `WorkbenchWeb.Docs.EventCatalog` — catalogue of every event type (signals, directives, telemetry, `WorldModels.Event`)
- `WorkbenchWeb.Docs.VerificationManifest` — declarative manifest of verification status by module / feature

## Verification status

- `:verified` — user-facing pages rendered by tests in [`../../../../test/live/`](../../../../test/live/) (implicitly, via `/guide` route).
- `:scaffolded` — technical subtree being added in this documentation pass. Coverage test: `test/live/guide_technical_test.exs` (Phase E).

## Related

- Router: [`../../router.ex`](../../router.ex)
- Docs support modules (to be added): `../../docs/`
- App docs: [`../../../ReadmeAI.MD`](../../../ReadmeAI.MD)

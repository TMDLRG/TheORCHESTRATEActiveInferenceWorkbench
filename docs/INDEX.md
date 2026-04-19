# Documentation Master Index

This is the navigation hub for every piece of documentation in the repository. Patterned after [`knowledgebase/jido/MASTER-INDEX.md`](../knowledgebase/jido/MASTER-INDEX.md).

If you are new, read in this order: **README → ARCHITECTURE → CLAUDE → the ReadmeAI.MD for the folder you're working in**.

---

## Top-level

| Doc | Scope |
|---|---|
| [`README.md`](../README.md) | Project landing; quick start; route map |
| [`ARCHITECTURE.md`](../ARCHITECTURE.md) | Canonical architecture — planes, Markov blanket, event flow, dependency graph |
| [`CONTRIBUTING.md`](../CONTRIBUTING.md) | Contribution rules; non-negotiables; runtime baseline; PR expectations |
| [`CLAUDE.md`](../CLAUDE.md) | Project rules (Jido-only mandate; non-negotiables; upstream reference) |
| [`ReadmeAI.MD`](../ReadmeAI.MD) | AI-oriented navigation of this repo |

## The umbrella

| Doc | Scope |
|---|---|
| [`active_inference/README.md`](../active_inference/README.md) | Run guide for the umbrella |
| [`active_inference/DELIVERABLE.md`](../active_inference/DELIVERABLE.md) | Extraction report, equation ledger, ADRs, completion status |
| [`active_inference/ReadmeAI.MD`](../active_inference/ReadmeAI.MD) | Umbrella overview (AI-oriented) |
| [`active_inference/docs/decisions/`](../active_inference/docs/decisions/) | Architecture decision records (ADRs) |
| [`active_inference/scripts/ReadmeAI.MD`](../active_inference/scripts/ReadmeAI.MD) | Phase observation scripts catalog |
| [`active_inference/config/ReadmeAI.MD`](../active_inference/config/ReadmeAI.MD) | Configuration catalog |

## Per-app documentation

Each umbrella app has its own `ReadmeAI.MD` at the app root with the full public API surface, telemetry events, dependencies, and verification status. Per-subtree `ReadmeAI.MD` files go deeper.

| App | Root ReadmeAI | Lib subtree | Tests |
|---|---|---|---|
| [`active_inference_core`](../active_inference/apps/active_inference_core/ReadmeAI.MD) | math, equation + model registries | [`lib/`](../active_inference/apps/active_inference_core/lib/ReadmeAI.MD) | [`test/`](../active_inference/apps/active_inference_core/test/ReadmeAI.MD) |
| [`shared_contracts`](../active_inference/apps/shared_contracts/ReadmeAI.MD) | Markov-blanket packets | [`lib/`](../active_inference/apps/shared_contracts/lib/ReadmeAI.MD) | [`test/`](../active_inference/apps/shared_contracts/test/ReadmeAI.MD) |
| [`world_plane`](../active_inference/apps/world_plane/ReadmeAI.MD) | generative process (maze engine) | [`lib/`](../active_inference/apps/world_plane/lib/ReadmeAI.MD) | [`test/`](../active_inference/apps/world_plane/test/ReadmeAI.MD) |
| [`agent_plane`](../active_inference/apps/agent_plane/ReadmeAI.MD) | generative model (Jido agent) | [`lib/`](../active_inference/apps/agent_plane/lib/ReadmeAI.MD) | [`test/`](../active_inference/apps/agent_plane/test/ReadmeAI.MD) |
| [`world_models`](../active_inference/apps/world_models/ReadmeAI.MD) | event log, spec registry, bus | [`lib/`](../active_inference/apps/world_models/lib/ReadmeAI.MD) | [`test/`](../active_inference/apps/world_models/test/ReadmeAI.MD) |
| [`composition_runtime`](../active_inference/apps/composition_runtime/ReadmeAI.MD) | multi-agent signal broker | [`lib/`](../active_inference/apps/composition_runtime/lib/ReadmeAI.MD) | [`test/`](../active_inference/apps/composition_runtime/test/ReadmeAI.MD) |
| [`workbench_web`](../active_inference/apps/workbench_web/ReadmeAI.MD) | Phoenix LiveView UI | [`lib/`](../active_inference/apps/workbench_web/lib/ReadmeAI.MD) | [`test/`](../active_inference/apps/workbench_web/test/ReadmeAI.MD) |

## In-app documentation (served by the running workbench)

Start `mix phx.server` then browse:

| Route | Scope |
|---|---|
| `/guide` | User guide (what-is-AI, 10-minute tutorial, L1–L5 examples) |
| `/guide/build-your-first` | 6-step tutorial |
| `/guide/blocks` | Block catalogue auto-generated from `WorldModels.Spec.Topology` |
| `/guide/examples` | Five capability-gradient examples |
| `/guide/technical` | **In-app technical reference** |
| `/guide/technical/architecture` | Plane separation, event flow, dependency graph (rendered) |
| `/guide/technical/apps` | Per-app public API tables with `@doc`/`@spec` |
| `/guide/technical/signals` | Every Jido signal / directive / telemetry event / `WorldModels.Event` type |
| `/guide/technical/data` | Every struct, typespec, Mnesia table, PubSub topic |
| `/guide/technical/config` | Every Application env key, `config/*.exs` entry, defaults |
| `/guide/technical/api/:module` | Per-module doc page (from `Code.fetch_docs/1`) |
| `/guide/technical/verification` | Verified / scaffolded / uncertain honesty manifest |

## Generated API docs (ExDoc)

```bash
cd active_inference && mix docs && open doc/index.html
```

Groups modules by umbrella app. The in-app `/guide/technical/api/:module` links into the same introspection data; ExDoc HTML is the static-site version.

## Reference material (upstream Jido)

| Doc | Scope |
|---|---|
| [`knowledgebase/jido/MASTER-INDEX.md`](../knowledgebase/jido/MASTER-INDEX.md) | Curated reference to the Jido framework (26 topic files) |
| [`jido/guides/`](../jido/guides/) | Upstream Jido guides (git submodule; 1:1 with hexdocs) |
| [`jido/lib/`](../jido/lib/) | Upstream Jido API |
| [`jido/usage-rules.md`](../jido/usage-rules.md), [`jido/AGENTS.md`](../jido/AGENTS.md) | Canonical Jido author rules |

## ADRs (Architecture Decision Records)

| ADR | Topic |
|---|---|
| [`active_inference/docs/decisions/canvas-library.md`](../active_inference/docs/decisions/canvas-library.md) | Composition canvas library choice (litegraph.js vs rete.js) |
| Inline ADRs in [`DELIVERABLE.md`](../active_inference/DELIVERABLE.md) §6 | Umbrella architecture, blanket contracts, native Jido, Phoenix LiveView, etc. |

## Documentation conventions

Every ReadmeAI.MD uses this skeleton: **Purpose → Contents → Public API surface → Data types & schemas → Constants & config keys → Telemetry / signals / events → Dependencies → Verification status → Related**. Every table, every bullet, every claim cites a real `file:line`. No prose without code backing.

Verification-status vocabulary is `:verified` / `:scaffolded` / `:uncertain` — borrowed from [`ActiveInferenceCore.Equation.verification_status`](../active_inference/apps/active_inference_core/lib/active_inference_core/equation.ex) so the whole documentation corpus reads consistently.

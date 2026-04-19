# ADR-001: Composition canvas library for the Agent Builder

**Date:** 2026-04-17
**Phase:** §12 Phase 0, spike S-0.1
**Status:** Accepted

## Context

The Agent Builder UI (plan §5) ships a drag-and-drop node canvas in Phase 7.
The canvas is wrapped in a Phoenix LiveView hook — the server holds topology
JSON authoritatively and the library is a dumb renderer/interaction layer.
The plan's default pick was rete.js v2 with litegraph.js as fallback.

## Candidates re-evaluated

**rete.js v2** (https://retejs.org/docs)
- Requires a framework adapter: React, Vue, Angular, Svelte, or Lit.
  No headless / vanilla-JS mode is documented.
- Plugin-based architecture (core + renderer + connection plugin + …).
- MIT. 2018–2026 copyright, active.
- No stated typed-socket validation system in the v2 intro docs.
- Bundle size not documented.
- **Blocker:** pulls in React or Vue just for the builder canvas. The plan
  explicitly rejects framework coupling for one UI surface — esbuild +
  tailwind + plain JS hooks is the assets baseline.

**litegraph.js** (https://github.com/jagenjo/litegraph.js)
- Pure Canvas2D rendering, no framework required.
- Typed input/output slots: `addInput("A", "number")` with type-checked
  connections.
- Single file, no dependencies.
- MIT.
- Production-proven in ComfyUI (large AI workflow tool); ~8k GitHub stars.
- JSON import/export is a first-class feature.
- Built-in interactions: search box, keyboard shortcuts, multi-select,
  context menu, zoom/pan.
- Last release March 2024; repo active.

## Decision

**Adopt litegraph.js for the `CompositionCanvas` LiveView hook.**

Reverses the plan's default. Rationale:

1. **No framework coupling.** Fits the project's "plain Phoenix LiveView +
   esbuild" assets baseline. Reté.js would bring React or Vue as a
   transitive requirement for the Builder alone.
2. **Typed sockets built in.** The port-type guard requirement in plan
   §5 (B-4: "connecting a belief output port to an action input port is
   rejected") maps directly to litegraph's slot-type system.
3. **Canvas2D integrates cleanly** with Phoenix hooks: a single `<canvas>`
   element, events via `pushEvent("topology_changed", json)`.
4. **Production-proven.** ComfyUI runs very large graphs on litegraph;
   the 50-node MVP cap is trivial in comparison.
5. **Single-file distribution** makes the dev build simpler.

## Consequences

- Canvas hook implementation in Phase 7b (§12) uses `litegraph.js` as an
  npm dep in `apps/workbench_web/assets/package.json`.
- The library-swap contract (topology JSON + `topology_changed` event)
  remains library-agnostic, so fallback to rete.js remains possible if
  litegraph reveals a blocker mid-Phase 7.
- Tests for the canvas (§12 Phase 7b JS-T1..JS-T4) run against litegraph's
  JSON API, not its rendering internals.
- Plan updated: §5 "canvas implementation" paragraph + Appendix B #4 to
  reflect litegraph as the chosen lib (rete.js is the fallback).

## Follow-ups

- Phase 7 first task: add `litegraph.js` to `assets/package.json` and
  scaffold the empty hook.
- No runtime behavior is observable from this decision alone — the
  decision becomes observable in Phase 7b when the Builder canvas
  renders and accepts drag input.

# workbench_web/lib/workbench_web/components/ — ReadmeAI

## Purpose

Phoenix function components and layouts used across every LiveView. All styling is inline CSS in `layouts.ex` (no Tailwind / esbuild pipeline).

## Contents

| File | Module | Purpose |
|---|---|---|
| [`core_components.ex`](core_components.ex) | `WorkbenchWeb.CoreComponents` | `tag/1`, `prob_bars/1`, `formula/1` |
| [`layouts.ex`](layouts.ex) | `WorkbenchWeb.Layouts` | `root/1`, `app/1`; inline CSS; CDN scripts (phoenix, phoenix_live_view, litegraph) |
| [`policy_visual.ex`](policy_visual.ex) | `WorkbenchWeb.Components.PolicyVisual` | `policy_bars/1`, `trajectory_overlay/1` |
| [`error_html.ex`](error_html.ex) | `WorkbenchWeb.Components.ErrorHTML` | Standard error pages |

## Public function components

| Function | Attrs / slots | Used by |
|---|---|---|
| `CoreComponents.tag/1` | `value` | All LiveViews that render verification status / equation type / model type (small coloured span) |
| `CoreComponents.prob_bars/1` | `probs`, `labels` (default sequential), `width` (default 300) | Equations / models / world / labs (horizontal probability bars) |
| `CoreComponents.formula/1` | `latex`, `caption` (optional) | Equation detail pages |
| `Layouts.root/1` | (root layout) | Every LiveView |
| `Layouts.app/1` | (inner wrapper) | Every LiveView |
| `PolicyVisual.policy_bars/1` | `summary` | `WorldLive`, `LabsLive`, `RunLive` (four-direction policy bars with winner highlight) |
| `PolicyVisual.trajectory_overlay/1` | `maze`, `summary` | ibid — predicted belief trajectory overlay on maze grid |

## JS hooks loaded from `Layouts.root/1`

- `phoenix.min.js` (CDN)
- `phoenix_live_view.min.js` (CDN)
- `litegraph.min.js` (CDN) — canvas library for Builder
- `/assets/composition_canvas.js` — Builder `CompositionCanvas` hook (litegraph integration)
- `/assets/app.js` — generic app JS

## Verification status

- `:verified` — every component is used by a tested LiveView; rendered snapshots covered by [`../../../../test/live/`](../../../../test/live/).

## Related

- Static assets: [`../../../priv/static/`](../../../priv/static/)
- Builder hook: [Canvas ADR](../../../../../docs/decisions/canvas-library.md)

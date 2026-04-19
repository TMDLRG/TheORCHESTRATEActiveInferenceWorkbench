# Screenshot Capture Checklist

**Ticket C15.** Every shipped `/guide/*` and `/cookbook*` page expects PNGs under
`active_inference/apps/workbench_web/priv/static/guide/screenshots/<feature>/<slug>.png`.
The capture pipeline uses the `Claude_in_Chrome` MCP to drive a running workbench
and snapshot each route.

## Pre-flight

1. Boot the full 5-service stack per [RUN_LOCAL.md](../RUN_LOCAL.md):
   - Qwen 3.6 direct (port 8090)
   - ClaudeSpeak HTTP (port 7712)
   - ClaudeSpeak MCP SSE (port 8877)
   - LibreChat (port 3080)
   - Phoenix workbench (port 4000)
2. Confirm all health endpoints return 200.
3. Make sure at least one cookbook recipe is loaded (`mix cookbook.validate`
   should report ≥50 recipes).

## Capture list

Each entry: route → target filename.  Run the capture MCP
(`Claude_in_Chrome` → `navigate` then `computer` screenshot or `upload_image`)
and save to the specified path.

### Home + branding

| Route | Target file |
|---|---|
| `/` | `screenshots/home/landing.png` |
| `/guide` | `screenshots/guide/index.png` |
| `/guide/creator` | `screenshots/guide/creator.png` |
| `/guide/orchestrate` | `screenshots/guide/orchestrate.png` |
| `/guide/level-up` | `screenshots/guide/level-up.png` |
| `/guide/credits` | `screenshots/guide/credits.png` |

### Honest state

| Route | Target file |
|---|---|
| `/guide/features` | `screenshots/guide/features.png` |

### Learning flow

| Route | Target file |
|---|---|
| `/learn` | `screenshots/learning/hub.png` |
| `/learn/chapter/4` | `screenshots/learning/chapter-4.png` |
| `/learn/session/4/generative-models__s1_setup` | `screenshots/learning/session.png` |
| `/learn/progress` | `screenshots/learning/progress.png` |
| `/guide/learning` | `screenshots/guide/learning.png` |

### Workbench surfaces

| Route | Target file |
|---|---|
| `/builder/new` | `screenshots/workbench/builder.png` |
| `/world` | `screenshots/workbench/world.png` |
| `/labs` | `screenshots/workbench/labs.png` |
| `/glass` | `screenshots/workbench/glass.png` |
| `/equations` | `screenshots/workbench/equations.png` |
| `/models` | `screenshots/workbench/models.png` |
| `/guide/workbench` | `screenshots/guide/workbench.png` |

### Labs (7 + index)

| Route | Target file |
|---|---|
| `/guide/labs` | `screenshots/guide/labs-index.png` |
| `/learn/lab/bayes` | `screenshots/labs/bayes.png` |
| `/learn/lab/pomdp` | `screenshots/labs/pomdp.png` |
| `/learn/lab/forge` | `screenshots/labs/forge.png` |
| `/learn/lab/tower` | `screenshots/labs/tower.png` |
| `/learn/lab/anatomy` | `screenshots/labs/anatomy.png` |
| `/learn/lab/atlas` | `screenshots/labs/atlas.png` |
| `/learn/lab/frog` | `screenshots/labs/frog.png` |

### Voice + chat

| Route | Target file |
|---|---|
| `/guide/voice` | `screenshots/guide/voice.png` |
| `/learn/voice-autoplay` | `screenshots/voice/autoplay-install.png` |
| `/guide/chat` | `screenshots/guide/chat.png` |

### Jido

| Route | Target file |
|---|---|
| `/guide/jido` | `screenshots/jido/index.png` |
| `/guide/jido/10-persistence` | `screenshots/jido/topic-persistence.png` |
| `/guide/jido/docs` | `screenshots/jido/docs-index.png` |

### Cookbook

| Route | Target file |
|---|---|
| `/cookbook` | `screenshots/cookbook/index.png` |
| `/cookbook/pomdp-tiny-corridor` | `screenshots/cookbook/recipe-wave1.png` |
| `/cookbook/epistemic-info-gain-vs-reward` | `screenshots/cookbook/recipe-wave2.png` |
| `/cookbook/predictive-coding-two-level-pass` | `screenshots/cookbook/recipe-wave3.png` |
| `/guide/cookbook` | `screenshots/guide/cookbook.png` |

## Post-capture

1. Verify every filename above has a real PNG.
2. Commit the PNGs as part of a `screenshots: capture pass` commit.
3. Update this file when routes or features change so the capture stays authoritative.

# LinkedIn IamHITL — Content Plan

**Page:** IamHITL (Michael Polzin's LinkedIn business page)
**Cadence:** 4 daily posts (2 text, 2 video) + 1 bonus video/day for 11 days
**Source assets:** All already produced and sitting in the repo. Nothing to generate.

---

## 1. Daily pattern

Every day from 2026-04-20 forward, IamHITL posts **4 standing slots**:

| Slot | Time (local) | Type | Notes |
|------|---|------|-------|
| A | 09:00 | **Short text** | 150–400 char hook + link to blog post of the day |
| B | 11:30 | **Video** | One of the 100 Active Inference Shorts, re-posted as native LinkedIn video |
| C | 14:00 | **Long text** | Full blog post repeated as LinkedIn article-style long post |
| D | 17:00 | **Video** | A second Short, different tone from slot B |

**Days 1–11 only** add one more slot:

| Slot | Time (local) | Type | Notes |
|------|---|------|-------|
| E | 19:30 | **Bonus video** | Short #101–#111 in order: the philosophical bonus + 10-part Abstractionist's Papers series |

After Day 11, the standing 4/day continues indefinitely, cycling through the 50 blog posts and the 100 Shorts.

## 2. Source material

### Bonus videos (Days 1–11, slot E)
Already produced + staged:

| Day | Date | Short # | File | Theme |
|---|---|---|---|---|
| 1 | 2026-04-20 | **101** | `/app/content/media/shorts/101/short-101.mp4` | Is this the meaning of life? (bonus) |
| 2 | 2026-04-21 | **102** | `.../shorts/102/short-102.mp4` | Red + Blue Space |
| 3 | 2026-04-22 | **103** | `.../shorts/103/short-103.mp4` | The Blindfold |
| 4 | 2026-04-23 | **104** | `.../shorts/104/short-104.mp4` | Orthogonality |
| 5 | 2026-04-24 | **105** | `.../shorts/105/short-105.mp4` | Parallel minds |
| 6 | 2026-04-25 | **106** | `.../shorts/106/short-106.mp4` | Induction / message passing |
| 7 | 2026-04-26 | **107** | `.../shorts/107/short-107.mp4` | Living inside the model |
| 8 | 2026-04-27 | **108** | `.../shorts/108/short-108.mp4` | Learning through paradox |
| 9 | 2026-04-28 | **109** | `.../shorts/109/short-109.mp4` | Emergence / hierarchy |
| 10 | 2026-04-29 | **110** | `.../shorts/110/short-110.mp4` | Natural Causality |
| 11 | 2026-04-30 | **111** | `.../shorts/111/short-111.mp4` | The synthesis (philosophy + math) |

### Standing video slots (daily, slots B + D)
Cycle through Shorts **#1–#100** in order. Two per day = finishes in 50 days.
File pattern: `/app/content/media/shorts/NN/short-NN.mp4` where NN is zero-padded (e.g. `01`, `27`).

Pairing for same-day: slot B = odd-numbered short, slot D = next even-numbered short (Day 1 posts #1 + #2; Day 2 posts #3 + #4; etc).

### Standing text slots (daily, slots A + C)
Cycle through the 50 Dev.to blog posts at <https://dev.to/tmdlrg>:

- Slot A (short text): pull the hook line + one beat from the blog post of the day; add `Read the full post → <URL>`.
- Slot C (long text): repost the blog body (trimmed to LinkedIn's 3000-char limit) with attribution, hashtags, and link.

Day N's blog = Part N of The Learn Arc (1-indexed). Repeat cycle after Day 50.

## 3. Post copy templates

**Slot A — Short text (<400 chars):**
```
{HOOK} — the one-line claim from Part {N}.

{One beat: single sentence expansion.}

Full post: {DEVTO_URL}

#ActiveInference #FreeEnergyPrinciple #Neuroscience
```

**Slot B / D — Short video:**
```
🎬 Active Inference Shorts — Part {N}: {TITLE}

{One-sentence hook pulled from the short's intro.}

Watch the full arc (blog + shorts + workbench):
📝 https://dev.to/tmdlrg
🎥 https://www.youtube.com/@tmdlrg/shorts
🤖 https://github.com/TMDLRG/TheORCHESTRATEActiveInferenceWorkbench

#ActiveInference #Shorts #AI
```

**Slot C — Long text (≤3000 chars, 1 post or carousel fallback):**
```
{BLOG_TITLE}

{BLOG_BODY_TRIMMED — keep sections, drop code blocks that exceed char limits}

Originally published: {DEVTO_URL}

The Learn Arc is a 50-post series + 100-short video arc + open-source workbench. If you're in cognitive science, AI, or neuroscience — follow along.

#ActiveInference #FreeEnergyPrinciple #KarlFriston #Neuroscience #AI
```

**Slot E — Bonus (Days 1–11 only):**
```
🌊 The Abstractionist's Papers meet Active Inference — Bonus {N}/11.

{Short-specific hook sentence from narration.}

📘 Read the full papers (by Von Paumgartten):
   https://welcometothebluespace.com/the-abstractionists-papers/

🧭 Explore the Natural Reality lens (Omega app):
   https://app-omega-gray.vercel.app/

🙏 Huge thanks to Von Paumgartten for the framework —
   https://www.linkedin.com/in/vonpaumgartten/

#ActiveInference #Abstractionists #NaturalReality #FreeEnergyPrinciple
```

## 4. Scheduling mechanics — MCP tools

All five slots use `mcp__orchestrate-linkedin__linkedin_schedule_post` (or `linkedin_create_post` → `linkedin_schedule_post`). The MCP's orchestrate-scheduler container handles the actual posting — no Claude wake-ups required.

**Post-object shape required:**
```json
{
  "id": "IAMHITL-2026-04-20-A",
  "title": "Slot-A short",
  "copy": "<the actual LinkedIn copy>",
  "hook": "<first-line hook>",
  "body": "<long-form body — same as copy for short posts>",
  "cta": "Read the post",
  "hashtags": ["ActiveInference", "Neuroscience"],
  "asset_type": "text" | "image" | "video" | "carousel",
  "page_id": "iamhitl",
  "compliance": {"notes": "First-person, Michael Polzin voice. Links to dev.to and Omega allowed. No medical/financial advice."}
}
```

For videos (slots B, D, E): `asset_type: "video"`, include a `media_path` field pointing at the `short-NN.mp4` file under `/app/content/media/shorts/NN/`.

**Call sequence:**
1. `linkedin_create_post(post)` — validates and queues
2. `linkedin_schedule_post(post, scheduled_time)` — sets the fire time

If `linkedin_schedule_post` accepts an already-queued `post_id`, use it directly. Otherwise pass the full post object.

**Page:** set `page_id` to the IamHITL page's MCP identifier. Discover via `linkedin_list_pages` first.

## 5. Numbering rules

Use deterministic post IDs so reruns are idempotent:

```
IAMHITL-YYYY-MM-DD-{SLOT}
```

where `{SLOT}` is `A`, `B`, `C`, `D`, or `E`. Example: `IAMHITL-2026-04-20-E` = today's bonus video.

## 6. What's already ready vs. what needs fresh generation

| Need | Status |
|---|---|
| 11 bonus MP4s | ✅ Already built and mounted in `/app/content/media/shorts/101..111/` |
| 100 Shorts MP4s | ✅ Already built (1–100) |
| 50 blog posts | ✅ Already live on dev.to/tmdlrg |
| LinkedIn copy | ✳️ Generate from templates above (templated — no LLM required) |
| Day-by-day schedule | ✳️ Derivable by formula (see §1–§2) |
| IamHITL page_id | ❓ Call `linkedin_list_pages` to discover |

## 7. Resume-friendly recipe for a fresh chat

The executor in a new chat should:

1. Call `linkedin_list_pages` → get IamHITL's `page_id`.
2. For each day D from 2026-04-20 forward:
   - Compute blog number `blog_N = ((D - 2026-04-20) mod 50) + 1`.
   - Compute short numbers `vid_odd = 2*(D - 2026-04-20) + 1 (mod 100, then shift to 1-index)`, `vid_even = vid_odd + 1`.
   - Compute bonus number `bonus_N = (D - 2026-04-20) + 101` if D ≤ 2026-04-30.
   - Pull blog copy from dev.to via the devto MCP.
   - Fill templates.
   - `linkedin_create_post` for each slot.
   - `linkedin_schedule_post` for each with its scheduled_time.

3. Stop when a reasonable horizon is covered (e.g. schedule 4 weeks ahead = 28 days × 4 slots + 11 bonus = 123 posts).

4. Record the scheduled IDs + times in `shorts/linkedin_queue.json` so future runs can resume without double-scheduling.

---

## 8. Prompt to paste into a new chat

See **`shorts/LINKEDIN_PROMPT.md`** — that's the self-contained instruction the executor agent will run.

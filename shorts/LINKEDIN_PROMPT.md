# LinkedIn IamHITL — Paste-Ready Executor Prompt

Copy everything between the `====` lines below and paste it into a new chat. It is self-contained and will produce a scheduled LinkedIn content calendar on the IamHITL business page.

```
=============================================================================
LinkedIn IamHITL content scheduling — self-contained executor brief

You have access to the `orchestrate-linkedin` MCP. All assets are already
produced. Your ONLY job is to compose post copy from templates and schedule
it through the MCP. No new content creation. No LLM generation beyond
trivial templating.

==== SETUP ====
Working directory: C:\Users\mpolz\Documents\WorldModels
Read first: shorts/LINKEDIN_PLAN.md — this is the authoritative spec.
Existing queue file: shorts/linkedin_queue.json (create if missing).

==== GOAL ====
Schedule 28 days of LinkedIn posts on the IamHITL page, starting 2026-04-20.
Daily pattern (local time, US Central):
  09:00  Slot A  short text      (<400 chars; hook + link to blog Part N)
  11:30  Slot B  video (MP4)     (Shorts #{2*day-1} from /app/content/media/shorts/NN)
  14:00  Slot C  long text       (blog post Part N body, trimmed ≤3000 chars)
  17:00  Slot D  video (MP4)     (Short #{2*day})
  19:30  Slot E  bonus video     (only days 1–11; Shorts #101-111 in order)

Where day index is 1-based starting 2026-04-20.
Blog Part N  = ((day - 1) mod 50) + 1.
Short numbers cycle through 1..100.

==== STEP-BY-STEP ====

1. Confirm page + MCP health.
   - Call `mcp__orchestrate-linkedin__linkedin_list_pages` → find the
     page whose name contains "IamHITL". Record its page_id.
   - Call `mcp__orchestrate-linkedin__linkedin_status` — expect connected.
   - If anything fails, STOP and report to the user.

2. Load or create shorts/linkedin_queue.json.
   Schema: { "posts": [ {post_id, day, slot, scheduled_time, status}, ... ] }
   Start empty if file doesn't exist. Never re-schedule a post_id already
   marked "scheduled" or "published".

3. For each day D from 2026-04-20 through 2026-05-17 (28 days):
   For each slot S in [A, B, C, D, E]:
     - Skip slot E if D > 2026-04-30 (bonus only runs days 1-11).
     - Compute post_id = "IAMHITL-YYYY-MM-DD-{S}".
     - If post_id already in queue as scheduled/published → skip.
     - Build the post object using the template (below).
     - Call `mcp__orchestrate-linkedin__linkedin_schedule_post` with
       { post: <built object>, scheduled_time: "<ISO8601 local, +00:00 offset>" }.
       Convert local 09:00/11:30/14:00/17:00/19:30 CDT to UTC
       (CDT = UTC−5 from 2026-03 onward).
         09:00 local → 14:00 UTC
         11:30 local → 16:30 UTC
         14:00 local → 19:00 UTC
         17:00 local → 22:00 UTC
         19:30 local → 00:30 UTC next day
     - Record the result in shorts/linkedin_queue.json with status
       "scheduled" (or "failed" with the error) and write immediately.

4. Stop when all 28 days are scheduled. Report:
   - Number of posts scheduled
   - Any failures
   - Next actions the user should review

==== POST OBJECT TEMPLATES ====

All posts share:
  page_id:       <IamHITL id from step 1>
  compliance:    { notes: "First-person, Michael Polzin voice. Educational
                   content on Active Inference / cognitive science. Links
                   to dev.to, GitHub, Omega app, welcometothebluespace.com
                   allowed. No medical/financial/legal advice." }

SLOT A — Short text (asset_type="text"):
  id:        IAMHITL-YYYY-MM-DD-A
  title:     "Learn Arc — Part {N}: {BLOG_HOOK_LINE}"
  hook:      first line of blog Part N
  copy:      "{BLOG_HOOK_LINE}\n\n{ONE_BEAT_SENTENCE_FROM_BLOG}\n\nFull post → https://dev.to/tmdlrg"
  body:      same as copy
  cta:       "Read the full post"
  hashtags:  ["ActiveInference", "FreeEnergyPrinciple", "Neuroscience", "AI"]
  asset_type: "text"

SLOT B / D — Video (asset_type="video"):
  id:        IAMHITL-YYYY-MM-DD-{SLOT}
  title:     "Active Inference Shorts — Part {SHORT_N}"
  hook:      one-sentence hook from the short (see shorts/queue.json for source title)
  copy:      "🎬 Active Inference Shorts — Part {SHORT_N}: {TITLE}\n\n{ONE_LINE_HOOK}\n\nWatch the full arc:\n📝 https://dev.to/tmdlrg\n🎥 https://www.youtube.com/@tmdlrg/shorts\n🤖 https://github.com/TMDLRG/TheORCHESTRATEActiveInferenceWorkbench\n\n#ActiveInference #Shorts #AI"
  body:      same as copy
  cta:       "Watch the full series"
  hashtags:  ["ActiveInference", "Shorts", "AI"]
  asset_type: "video"
  media_path: "/app/content/media/shorts/{NN}/short-{NN}.mp4"

SLOT C — Long text (asset_type="text" — if the text exceeds 3000 chars,
switch asset_type to "carousel" and split):
  id:        IAMHITL-YYYY-MM-DD-C
  title:     "{BLOG_TITLE}"
  hook:      first sentence of blog body
  copy:      "{BLOG_TITLE}\n\n{BLOG_BODY_TRIMMED_TO_2800_CHARS}\n\nOriginally published: {DEVTO_URL}\n\n#ActiveInference #FreeEnergyPrinciple #KarlFriston #Neuroscience"
  body:      same as copy
  cta:       "Read the full post"
  hashtags:  ["ActiveInference", "FreeEnergyPrinciple", "KarlFriston", "Neuroscience", "AI"]
  asset_type: "text"

SLOT E — Bonus video (Days 1-11, Shorts #101-111):
  id:        IAMHITL-YYYY-MM-DD-E
  title:     "Abstractionist's Papers × Active Inference — Bonus {N}/11"
  hook:      one-line hook from the short's narration
  copy:      "🌊 The Abstractionist's Papers meet Active Inference — Bonus {N}/11.\n\n{SHORT_HOOK}\n\n📘 Read the full papers by Von Paumgartten:\nhttps://welcometothebluespace.com/the-abstractionists-papers/\n\n🧭 Explore with the Omega app:\nhttps://app-omega-gray.vercel.app/\n\n🙏 Thanks Von Paumgartten:\nhttps://www.linkedin.com/in/vonpaumgartten/\n\n#ActiveInference #Abstractionists #NaturalReality #FreeEnergyPrinciple"
  body:      same as copy
  cta:       "Watch + explore"
  hashtags:  ["ActiveInference", "Abstractionists", "NaturalReality", "FreeEnergyPrinciple"]
  asset_type: "video"
  media_path: "/app/content/media/shorts/{BONUS_N}/short-{BONUS_N}.mp4"
  where BONUS_N = 100 + day_index (so Day 1 → 101, Day 11 → 111).

Short-topic map for bonus:
  101: "Is this the meaning of life? (the big question)"
  102: "Red + Blue Space — meaning vs happening"
  103: "The Blindfold — the map that forgets it's a map"
  104: "Orthogonality — Red + Blue meet but never merge"
  105: "Parallel minds, shared causation"
  106: "Induction — bridging the gap (= message passing)"
  107: "Living inside the model (= Q)"
  108: "Learning through paradox (= F minimisation)"
  109: "Emergence — hierarchy, not evolution"
  110: "'The music made me dance' — Natural Causality"
  111: "Synthesis — philosophy + math, one idea"

==== SOURCES FOR BLOG + SHORT TITLES ====

Blog posts (1..50): dev.to/tmdlrg — titles via
  `mcp__orchestrate-linkedin__devto_manage(action="list_articles")`.

Shorts titles (1..100): shorts/queue.json in this repo. Each entry has
`n`, `title`, `description`. Use `title` as-is or strip the `| #NN #Shorts`
suffix for LinkedIn.

==== STOP CONDITIONS ====
- If `linkedin_schedule_post` returns a validation error → fix the post
  object (common issue: compliance.notes missing) and retry once, then
  skip and log the failure.
- If 5 consecutive failures → stop and report.
- Never schedule the same post_id twice.

==== REPORT FORMAT ====
At the end, output a single table:

| Date | Slot A | Slot B | Slot C | Slot D | Slot E |
|------|--------|--------|--------|--------|--------|
| 2026-04-20 | ✅ | ✅ | ✅ | ✅ | ✅ |
| …

Plus: total scheduled, total skipped, total failed.

Do not commit to git unless the user asks.
=============================================================================
```

---

## How to use

1. Open a new Claude Code session in this repo.
2. Paste the block between `====` lines above.
3. The agent will:
   - Discover the IamHITL page
   - Read the blog metadata
   - Schedule 28 days × 4–5 slots
   - Save `shorts/linkedin_queue.json` with every post_id + status
4. Review the output; if anything failed, rerun — it skips already-scheduled entries.

## Maintenance

- To extend past Day 28, edit the loop bound in the pasted prompt.
- To change slot times or template copy, edit `shorts/LINKEDIN_PLAN.md` and regenerate the prompt.
- To pause posting, use `mcp__orchestrate-linkedin__linkedin_clear_queue(status="queued")` or targeted `linkedin_reschedule_post` calls.

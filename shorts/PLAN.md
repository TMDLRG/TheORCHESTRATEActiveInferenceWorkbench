# The Learn Arc — 100 YouTube Shorts: Plan, Recipe, Status

**Series:** The Learn Arc — 100 × ~50–75s YouTube Shorts teaching Active Inference.
**Channel:** `UC_I-d6cICifM567STunNqfw` (ORCHESTRATE Master).
**Source curriculum:** [dev.to/tmdlrg](https://dev.to/tmdlrg) (50 blog parts already live).
**Repo:** this repo (`WorldModels/`). All production assets live under `blog-assets/shorts/NN/`.
**Date opened:** 2026-04-19.
**Last updated:** keep this line current — use ISO-8601, and bump whenever you ship a short.

---

## 0. Resume protocol (read this first if picking this up cold)

1. Open this file. Read sections 1–4 end-to-end.
2. `cd <repo>` and `ls blog-assets/shorts/` — each `NN/` directory is one completed short.
3. Scan **§7 Status Log** to find the next short number to produce.
4. Read **§3 Production Recipe** and follow it verbatim for the next short.
5. When the short is uploaded, append a row to §7 with its video ID and URL.
6. Do not change the visual template, voice, or footer without the user's approval.

**Key invariants** (do not drift from these without the user's explicit approval):
- Voice: Piper `en_GB-alba-medium` (UK female, warm).
- Resolution: 1080 × 1920, 30 fps, h264 + aac 192k.
- Palette: `#1B1D3A` indigo (bg) / `#F5EFE1` cream (text) / `#FF6F61` coral (accent).
- Font: Inter (400, 600, 800, 900). Loaded from Google Fonts in `_base.css`.
- Footer on every slide: `ACTIVE INFERENCE · PART N`.
- Kicker on every slide: short 2–4 word tag, uppercase, 4px letter-spacing, coral.
- 6-slide structure per short: Hook · Problem · Payoff · Detail · Proof · CTA.
- Narration length: 50–75s. Written to be spoken, not read.
- Every Short's description cross-links to **Parts 1–N-1** so the chain never breaks.
- Privacy: `public`. Category: `27` (Education).

---

## 1. The 100-short content map

| Range | N | Type | Source material |
|---|---|------|-----------------|
| 1–10 | 10 | **Hooks / cold opens** — each one a standalone "wait, what?" idea. Designed to pull strangers in. No prerequisites. | Derived from series spine. |
| 11–20 | 10 | **Chapter heroes** — one Short per book chapter (0..10). | Blog Parts 1–11 |
| 21–58 | 38 | **Session-each** — one Short per session from the 39-session curriculum. | Blog Parts 12–49 |
| 59 | 1 | **Series recap + Chapter-7 capstone thumbnail** | Blog Part 39 |
| 60 | 1 | **Capstone** | Blog Part 50 |
| 61–75 | 15 | **Lab clips** — record `Bayes Chips`, `PoMDP Machine`, `Jumping Frog`, `Anatomy Studio`, `Atlas`, `Laplace Tower`, `Free Energy Forge` live. 2–3 per lab. | Phoenix `/labs/*` |
| 76–85 | 10 | **"One equation in 90 seconds"** — Eq 4.13, Eq 4.14, Eq 4.19, Eq 7.10, Eq 2.1 Bayes, Eq 2.5 VFE, Eq 2.6 surprise bound, Eq 4.10 F, Eq 4.11, Eq B.5 message passing. | Blog content + figures |
| 86–95 | 10 | **Paired comparisons / myth-busting** — "Active Inference vs RL", "Free Will", "Consciousness claim", "Why not deep RL", "Is FEP falsifiable?" | Post 48 + public discourse |
| 96–100 | 5 | **Meta / payoff** — series trailer, "what to keep", reader map, book-in-5-minutes, call to action for workbench forks. | Post 50 |

### Hooks 1–10 (current working titles)

1. **Your brain doesn't see the world. It predicts it.** — perception as prediction.
2. **You don't decide what to do — you descend gradients.** — action as inference.
3. **Surprise is the only thing your brain is trying to kill.** — free-energy minimization named.
4. **Curiosity isn't a personality trait. It's an equation.** — epistemic value / EFE.
5. **Confidence is just a number your neurons multiply by.** — precision.
6. **Boredom and panic are the same failure.** — miscalibrated precision.
7. **Your brain models itself. That's what "I" is.** — self-modeling / hierarchy.
8. **Pain is a prediction, not a sensation.** — predictive coding extended.
9. **Dreams are your brain running the model backwards.** — generative model reversal.
10. **The one equation Karl Friston built his career on.** — Eq 4.13 preview / series pivot to math.

### Chapters 11–20

| # | Chapter | Hero line |
|---|---------|-----------|
| 11 | Preface | Why this book exists — and how to read it. |
| 12 | 1 Overview | Perception, action, learning — one loop, one theory. |
| 13 | 2 Low Road | From Bayes' rule to free energy. |
| 14 | 3 High Road | EFE — a plan's bill in two columns. |
| 15 | 4 Generative Models | A, B, C, D — the whole framework in four matrices. |
| 16 | 5 Cortex | The cortex as a factor graph. |
| 17 | 6 Recipe | How you actually ship an agent. |
| 18 | 7 Discrete time | POMDPs, Dirichlet learning, hierarchy. |
| 19 | 8 Continuous time | Generalized coords, Eq 4.19. |
| 20 | 9 Data analysis | Fit it, compare models, report the Bayes factor. |

### Sessions 21–58 (direct port of blog Parts 12–49; see dev.to/tmdlrg)

| Short # | Blog Part | Slug | Title |
|---|---|---|---|
| 21 | 12 | `s1_what_is_ai` | §1.1 What Active Inference actually claims |
| 22 | 13 | `s2_perception_and_action` | §1.2 Perception and action, one loop up close |
| 23 | 14 | `s3_why_one_theory` | §1.3 Why one theory |
| 24 | 15 | `s1_inference_as_bayes` | §2.1 Inference as Bayes |
| 25 | 16 | `s2_why_free_energy` | §2.2 Why free energy |
| 26 | 17 | `s3_cost_of_being_wrong` | §2.3 The cost of being wrong |
| 27 | 18 | `s4_action_as_inference` | §2.4 Action as inference |
| 28 | 19 | `s1_expected_free_energy` | §3.1 EFE in one page |
| 29 | 20 | `s2_epistemic_pragmatic` | §3.2 Epistemic vs pragmatic |
| 30 | 21 | `s3_softmax_policy` | §3.3 Softmax policy + precision |
| 31 | 22 | `s4_what_makes_an_agent_active` | §3.4 What makes an agent active |
| 32 | 23 | `s1_setup` | §4.1 States / observations / actions |
| 33 | 24 | `s2_a_matrix` | §4.2 The A matrix |
| 34 | 25 | `s3_efe_intro` | §4.3 EFE introduced |
| 35 | 26 | `s4_mdp_world` | §4.4 The MDP world |
| 36 | 27 | `s5_practice` | §4.5 Practice — ship one |
| 37 | 28 | `s1_factor_graphs` | §5.1 Cortex as factor graph |
| 38 | 29 | `s2_predictive_coding` | §5.2 Predictive coding |
| 39 | 30 | `s3_neuromodulation` | §5.3 Neuromodulation |
| 40 | 31 | `s4_brain_map` | §5.4 Brain map |
| 41 | 32 | `s1_states_obs_actions` | §6.1 States / obs / actions (design) |
| 42 | 33 | `s2_ab_c_d` | §6.2 Filling A, B, C, D |
| 43 | 34 | `s3_run_and_inspect` | §6.3 Run and inspect |
| 44 | 35 | `s1_discrete_refresher` | §7.1 Discrete-time refresher |
| 45 | 36 | `s2_message_passing_4_13` | §7.2 Message passing, Eq 4.13 |
| 46 | 37 | `s3_learning_a_b` | §7.3 Learning A and B |
| 47 | 38 | `s4_hierarchical` | §7.4 Hierarchical |
| 48 | 39 | `s5_worked_example` | §7.5 Worked example |
| 49 | 40 | `s1_generalized_coords` | §8.1 Generalized coordinates |
| 50 | 41 | `s2_eq_4_19` | §8.2 Eq 4.19 quadratic F |
| 51 | 42 | `s3_action_on_sensors` | §8.3 Action on sensors |
| 52 | 43 | `s4_continuous_play` | §8.4 Continuous play |
| 53 | 44 | `s1_fit_to_data` | §9.1 Fit to data |
| 54 | 45 | `s2_comparing_models` | §9.2 Comparing models |
| 55 | 46 | `s3_case_study` | §9.3 Case study |
| 56 | 47 | `s1_perception_action_learning` | §10.1 Synthesis |
| 57 | 48 | `s2_limitations` | §10.2 Limitations |
| 58 | 49 | `s3_where_next` | §10.3 Where next |
| 59 | — | recap | Ch-7 capstone retrospective |
| 60 | 50 | capstone | Reader's map / what to keep |

### Lab clips 61–75

Record live in the workbench at 1080×1920 (9:16 crop). Each clip ≈ 40s, narrated over.

| Short | Lab | Beat to capture |
|---|---|---|
| 61 | Bayes Chips | 1-step belief update |
| 62 | Bayes Chips | Sequential evidence |
| 63 | Jumping Frog | Perception loop closing |
| 64 | Jumping Frog | EFE scoring for next hop |
| 65 | PoMDP Machine | Beat 1 — A,B,C,D set |
| 66 | PoMDP Machine | Beat 5 — EFE policy choice |
| 67 | PoMDP Machine | Beat 7 — Dirichlet learning |
| 68 | Anatomy Studio | EFE decomposed |
| 69 | Anatomy Studio | Preference C swap |
| 70 | Atlas | Brain-map region click |
| 71 | Atlas | Neuromodulator precision demo |
| 72 | Laplace Tower | Generalized-coord tower |
| 73 | Laplace Tower | Order truncation effect |
| 74 | Free Energy Forge | Building F piece by piece |
| 75 | Free Energy Forge | Term ablation |

### Equations 76–85

Each one 40–60s: "What this equation says in plain English." Use `slide-03-fep.html` template (equation big + sub).

| # | Equation | One-liner |
|---|---|---|
| 76 | Eq 2.1 Bayes | The identity every posterior inherits. |
| 77 | Eq 2.5 VFE | Surprise is one non-negative quantity away. |
| 78 | Eq 2.6 surprise bound | `F ≥ -log P(o)` — why minimizing F ⇒ minimising surprise. |
| 79 | Eq 4.10 F | The discrete-time free energy. |
| 80 | Eq 4.11 | The per-step F. |
| 81 | Eq 4.13 message passing | Softmax is not a design choice. |
| 82 | Eq 4.14 policy posterior | Why policies, not actions, are first-class. |
| 83 | Eq 4.19 quadratic F | The continuous-time twin. |
| 84 | Eq 7.10 Dirichlet | Learning is the same Bayes update, slow. |
| 85 | Eq B.5 | The belief-propagation primitive. |

### Myth-busting 86–95

| # | Claim | Counter |
|---|---|---|
| 86 | "Active Inference = reinforcement learning." | Different loss, different primitive, overlaps in limit. |
| 87 | "FEP is not falsifiable." | Normative vs constructive — constructive IS. |
| 88 | "Active Inference only works on toy mazes." | Scaling paths (tree search, amortised policies). |
| 89 | "Predictive coding is just Kalman filters." | Generalised to hierarchy + action. |
| 90 | "Active Inference explains consciousness." | No — it's agnostic. |
| 91 | "Free will disappears." | What actually disappears is a specific folk-psych story. |
| 92 | "The brain minimises prediction error." | Close, but wrong target — it minimises *expected* surprise under its model. |
| 93 | "You need dopamine to explain reward." | You need precision. Reward falls out. |
| 94 | "Hierarchy is a trick to scale." | No — hierarchy is the same equation taller. |
| 95 | "Active Inference can't fit data." | It does — Chapter 9 shows how. |

### Meta 96–100

| # | Frame |
|---|---|
| 96 | Series trailer — 60s recap of the arc. |
| 97 | "Five things to keep from this series." |
| 98 | "The book in five minutes." |
| 99 | "Fork the workbench — here's what I'd build next." |
| 100 | Thank-you + what's coming after the Arc. |

---

## 2. What makes these Shorts pop

- **Hook in 0–1.5s.** On-screen bold text + voice. Stops the scroll.
- **Faces/contrast first frame.** Never a logo. YouTube's feed algorithm heavily weights first-frame-attention.
- **Captions always on.** 80% of Shorts watches are muted.
- **Pattern interrupt at 3s, 8s, 20s.** Slide cut, color flip, equation reveal.
- **One idea per Short.** Two ideas = 50% retention.
- **Cliffhanger close.** Final line teases the next short.
- **Consistent identity.** Same palette, footer, kicker — viewers learn the brand in ~4 exposures.
- **Daily cadence.** Algorithm rewards predictability.

---

## 3. Production Recipe (canonical)

Follow this exactly. Each step works; deviations have cost the project time before (see §6 "Known hazards").

### 3.1 Setup (one-time per session)

- Phoenix Workbench running at `http://localhost:4000` (for any screenshot or lab-clip shorts).
- Chrome at `C:/Program Files/Google/Chrome/Application/chrome.exe`.
- ffmpeg at `C:/Users/mpolz/AppData/Local/Microsoft/WinGet/Packages/Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe/ffmpeg-8.0-full_build/bin/ffmpeg.exe`.
- Docker container `tts-sidecar` up (Piper voices on `linkedin-orchestrate-campaign_shared-audio` volume).
- Docker container `orchestrate-api` up (YouTube uploader).
- Alba Piper model present at host `C:\Users\mpolz\Documents\ORCHESTRATE Publish\linkedin-orchestrate-campaign\models\tts\en_GB-alba-medium.onnx(.json)`.

### 3.2 Per-short steps

**Step 1 — Script (5 min).** Write 150–225 words of narration. Target 50–75s at Alba's ~2.7 wps. Keep it spoken, not read. Hook in first sentence. End with "Part N of one hundred. Follow The Learn Arc."

**Step 2 — Narration (1 min).** Call MCP:

```
mcp__orchestrate-linkedin__audio_manage(
  action="synthesize",
  text=<script>,
  engine="piper",
  voice_id="en_GB-alba-medium",
  quality="production",
  output_format="mp3"
)
```

Returns `audio_path` in `/app/audio/` of `tts-sidecar`. Duration returned.

Copy to repo:
```bash
mkdir -p blog-assets/shorts/NN/slides
docker cp tts-sidecar:<audio_path> blog-assets/shorts/NN/narration.mp3
cp blog-assets/shorts/01/slides/_base.css blog-assets/shorts/NN/slides/_base.css
```

**Step 3 — Slides (10 min).** Six HTML files under `blog-assets/shorts/NN/slides/`:
- `slide-01-hook.html` — headline + kicker `N/100`.
- `slide-02-*.html` — problem / "the wrong model."
- `slide-03-*.html` — payoff (often an equation).
- `slide-04-*.html` — detail / split card / extension.
- `slide-05-*.html` — proof (reuse a blog-asset screenshot as full-bleed with overlay).
- `slide-06-cta.html` — `N / 100`, "Follow The Learn Arc."

Use `_base.css` classes (`.slide`, `.kicker`, `.headline`, `.sub`, `.split`, `.equation`, `.foot`, `.full-img`, `.overlay`, `.above`).

**Step 4 — Render to PNG (1 min).**
```bash
CHROME="/c/Program Files/Google/Chrome/Application/chrome.exe"
DIR="C:/Users/mpolz/Documents/WorldModels/blog-assets/shorts/NN/slides"
for html in blog-assets/shorts/NN/slides/slide-*.html; do
  name=$(basename "$html" .html)
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
    --window-size=1080,1920 --default-background-color=1B1D3Aff \
    "--screenshot=$DIR/$name.png" \
    "file:///$DIR/$name.html"
done
```

**Step 5 — Concat + mux (1 min).** Build `blog-assets/shorts/NN/concat.txt`:
```
file 'slides/slide-01-hook.png'
duration <s>
file 'slides/slide-02-...png'
duration <s>
...
file 'slides/slide-06-cta.png'
duration <s>
file 'slides/slide-06-cta.png'
```

The last line (file without duration) is **required** — ffmpeg's concat demuxer drops the last entry's trailing frames otherwise.

Budget slide durations so the narration ends ~2s before the CTA hold. Approx:
- Hook 3.5–4s · Problem 10–12s · Payoff 11–15s · Detail 13–16s · Proof 7–9s · CTA 5s hold.

Then:
```bash
cd blog-assets/shorts/NN
FF=".../ffmpeg.exe"
MSYS_NO_PATHCONV=1 "$FF" -y -f concat -safe 0 -i concat.txt \
  -vf "scale=1080:1920,format=yuv420p,fps=30" \
  -c:v libx264 -preset medium -crf 20 video.mp4
MSYS_NO_PATHCONV=1 "$FF" -y -i video.mp4 -i narration.mp3 \
  -c:v copy -c:a aac -b:a 192k -shortest short-NN.mp4
```

**Step 6 — Copy to media mount (10s).**
```bash
MEDIA="/c/Users/mpolz/Documents/ORCHESTRATE Publish/linkedin-orchestrate-campaign/content/media"
mkdir -p "$MEDIA/shorts/NN"
cp blog-assets/shorts/NN/short-NN.mp4 "$MEDIA/shorts/NN/short-NN.mp4"
```

**Step 7 — Upload (30s).**
```
mcp__orchestrate-linkedin__youtube_manage(
  action="upload",
  file_path="/app/content/media/shorts/NN/short-NN.mp4",
  title="<Hook> | Active Inference #N #Shorts",
  description=<description with cross-links to all prior shorts>,
  tags=["Active Inference", "Free Energy Principle", ...],
  privacy="public",
  category_id="27"
)
```

If the MCP 401s, fall back to direct YouTube API — see §6.

**Step 8 — Record status (30s).** Append a row to **§7 Status Log** with the video ID, URL, duration, and date.

**Typical per-short time:** 7–10 minutes.

---

## 4. Description template (canonical — MUST include all five anchor links)

Paste into every Short. Replace `{N}`, `{HOOK}`, `{KEY_IDEA}` and prior-shorts list. Every description must end with the Books + Blog + Workbench + LinkedIn + hashtags block unchanged.

```
Part {N} of 100 — The Learn Arc.

{HOOK sentence.} {2-3 sentence expansion.}

{Optional contrast / proof sentence.}

— — —
📚 The books behind this series (by Michael Polzin):
· ORCHESTRATE Prompting: https://www.amazon.com/ORCHESTRATE-Prompting-Professional-AI-Outputs-ebook/dp/B0G2B9LG6V
· LEVEL UP — the AI Usage Maturity Model: https://www.amazon.com/Level-Usage-Maturity-Model-Excellence-ebook/dp/B0GS4WDVFZ

📝 Full 50-post blog series: https://dev.to/tmdlrg
🤖 Open-source Workbench (Phoenix / LiveView / pure Jido on the BEAM):
   https://github.com/TMDLRG/TheORCHESTRATEActiveInferenceWorkbench
🤝 Connect with Michael on LinkedIn: https://www.linkedin.com/in/mpolzin/

Book reference: Active Inference — Parr, Pezzulo, Friston (MIT Press, 2022)

#ActiveInference #FreeEnergyPrinciple #Neuroscience #AI #Shorts
```

**Screenshot rule:** whenever a short's topic overlaps with the suite we built (Chs 4, 6, 7, 9; sessions §4–§10; every cookbook/lab-clip/equation-in-workbench short), use real screenshots from `blog-assets/series-01/*.png` as the full-bleed background on at least one slide (usually `slide-04` or `slide-05`). Do not substitute stock visuals.

**CTA rotation rule (IMPORTANT):** Do NOT stack all five links on every Short's `slide-06-cta.html`. Pick ONE focused CTA per Short, rotating through the list below. The description still carries the full link block, but the on-screen ask stays single and strong so viewers actually act on it.

**Rotation schedule** (cycle of 8 — apply mod-8 from Short 26 onwards):

| Slot | On-screen CTA | Description emphasis |
|---|---|---|
| 1 | 📕 **Get "ORCHESTRATE Prompting"** — Michael's book | Amazon link top |
| 2 | 📗 **Get "LEVEL UP"** — Michael's AI-UMM book | Amazon link top |
| 3 | 🤝 **Connect with Michael on LinkedIn** | LinkedIn top |
| 4 | ⭐ **Fork / star the Workbench on GitHub** | GitHub top |
| 5 | 📝 **Read the full blog series on dev.to** | Dev.to top |
| 6 | 💬 **Drop your take in the comments** | Engagement — reply to every comment |
| 7 | 🔁 **Share with someone who'd love this** | Engagement |
| 8 | 👍 **Like + Subscribe — Part N+1 coming** | Retention |

Mapping:
- Short 26 → slot 1 (ORCHESTRATE Prompting)
- Short 27 → slot 2 (LEVEL UP)
- Short 28 → slot 3 (LinkedIn)
- Short 29 → slot 4 (GitHub)
- Short 30 → slot 5 (Blog)
- Short 31 → slot 6 (Comments)
- Short 32 → slot 7 (Share)
- Short 33 → slot 8 (Subscribe)
- Short 34 → slot 1 (ORCHESTRATE Prompting) … and so on.

Shorts 1–25 predate this rule and can stay as-is.

The book / blog / workbench / LinkedIn footer block is still fine in every description — the rotation only governs the ON-SCREEN ask.

---

## 5. Visual template reference

`_base.css` lives at `blog-assets/shorts/01/slides/_base.css`. **Do not modify** without approval — copy to every new short's slides dir.

Classes:
- `.slide` — 1080×1920, flex column, coral kicker at top, dark footer.
- `.kicker` — 36px, coral, uppercase, 4px spacing.
- `.headline` — 96px, 900 weight, -2px letter-spacing. `em` inside → coral no italic.
- `.sub` — 48px, 600 weight.
- `.equation` — 140px, italic, coral, Times/Cambria Math.
- `.split` — two-column side-by-side cards with left coral rule.
- `.full-img` + `.overlay` + `.above` — full-bleed image with gradient vignette and text layered on top.
- `.foot` — 28px, 600, 65% opacity at bottom.

---

## 6. Known hazards + fixes

| Hazard | Symptom | Fix |
|---|---|---|
| MCP `video_manage compose` silently drops `duration_s`. | Output MP4 is 60ms instead of 50s, all six slides collapsed to single frame. | **Bypass.** Use host ffmpeg + concat demuxer per §3.5. Do not use MCP `compose`. |
| MCP `youtube_manage upload` 401 when access token expires. | `Server returned 401` from YouTubeUploader. | **Path A:** retry the MCP once — the fix should auto-refresh. **Path B:** direct OAuth refresh then resumable upload. Code in §6.1. |
| Piper voice registry rejects a model that's on disk. | `Voice not found in registry: <id>`. | Edit two files inside tts-sidecar container: `/app/src/piper_engine.py` (add `PiperModelManifest`) AND `/app/src/server.py` (add tuple to `_register_defaults`). `docker restart tts-sidecar`. See §6.2. |
| ffmpeg concat drops last slide's trailing frames. | CTA cut off 0.5–1s short. | Add a duplicate `file 'slides/slide-06-cta.png'` line at the bottom of concat.txt (no `duration` line). |
| Chrome headless renders white background for transparent HTML. | Slides come out on white instead of indigo. | Set `--default-background-color=1B1D3Aff` in the headless flags. |
| ffmpeg errors `-r/-fpsmax specified together with a non-CFR -vsync`. | Conflicting flags. | Drop `-vsync vfr -r 30`; put `fps=30` in the `-vf` filter instead. |
| MCP `list_articles` result > tool token limit. | `result exceeds maximum allowed tokens`. | Read from the result-cache file with `node`/`jq` — parse `body_markdown` locally. |
| Body path for update_article returns old content. | You edit, it reverts. | Always GET immediately before PUT, transform the returned `body_markdown`, and send the full transformed body back. |

### 6.1 Direct YouTube upload (fallback)

```bash
TOKEN=$(curl -sS -X POST "https://oauth2.googleapis.com/token" \
  -d "client_id=$YT_CLIENT_ID" -d "client_secret=$YT_CLIENT_SECRET" \
  -d "refresh_token=$YT_REFRESH_TOKEN" -d "grant_type=refresh_token" \
  | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>console.log(JSON.parse(d).access_token))")

SIZE=$(stat -c%s blog-assets/shorts/NN/short-NN.mp4)
INIT=$(curl -sS -i -X POST \
  "https://www.googleapis.com/upload/youtube/v3/videos?uploadType=resumable&part=snippet,status" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json; charset=UTF-8" \
  -H "X-Upload-Content-Type: video/mp4" \
  -H "X-Upload-Content-Length: $SIZE" \
  --data-binary @.tmp/yt-meta-NN.json)
UPLOAD_URL=$(echo "$INIT" | grep -i "^location:" | sed 's/^[Ll]ocation: //' | tr -d '\r\n')
curl -sS -X PUT "$UPLOAD_URL" -H "Content-Type: video/mp4" \
  --data-binary @blog-assets/shorts/NN/short-NN.mp4
```

Credentials at runtime are in the `orchestrate-api` env:
- `YOUTUBE_CLIENT_ID`, `YOUTUBE_CLIENT_SECRET`, `YOUTUBE_REFRESH_TOKEN`.

### 6.2 Register a new Piper voice

```bash
# 1. Download the model (onnx + onnx.json) to host models/tts/.
#    URL pattern: https://huggingface.co/rhasspy/piper-voices/resolve/main/<lang>/<variant>/<quality>/<model>.onnx
# 2. Patch registry:
MSYS_NO_PATHCONV=1 docker exec tts-sidecar python -c "
p='/app/src/piper_engine.py'; s=open(p).read()
new='    \"<voice_id>\": PiperModelManifest(model_id=\"<voice_id>\", onnx_file=\"<voice_id>.onnx\", config_file=\"<voice_id>.onnx.json\", size_mb=75.0, sample_rate=22050, language=\"<lang>\", quality=\"<q>\"),\n'
s=s.replace('    \"de_DE-thorsten-medium\":', new + '    \"de_DE-thorsten-medium\":')
open(p,'w').write(s)
p='/app/src/server.py'; s=open(p).read()
s=s.replace('(\"en_GB-alba-medium\", \"Alba Medium (UK English)\", 75.0),',
            '(\"en_GB-alba-medium\", \"Alba Medium (UK English)\", 75.0),\n            (\"<voice_id>\", \"<Display>\", 75.0),')
open(p,'w').write(s)
"
docker restart tts-sidecar
```

Note: container-internal edits are ephemeral. For durable registration, fork the tts-sidecar image or mount the two `.py` files as bind mounts.

---

## 7. Status Log

**Total:** 100 · **Live:** 27 · **Built + staged (pending upload):** 73 · **Remaining to produce:** 0.
**Last updated:** 2026-04-20.

**Scheduled upload pipeline:** `scheduled-tasks/learn-arc-shorts-daily-upload` fires 9:05 AM local daily. Reads `shorts/queue.json`, uploads next 20 pending entries via `youtube_manage` MCP (with direct-API fallback in `shorts/upload.sh`), updates statuses, commits. Full recipe in `shorts/upload_batch.md`.

**Pipeline at a glance:**
- Specs: `shorts/specs/NN.json` — one per short, spec-driven.
- Generator: `shorts/gen.js` — renders 6 HTML slides per spec.
- Builder: `shorts/build.sh NN` — Chrome → PNG, ffmpeg concat + aac mux.
- Queue: `shorts/queue.json` — 73 entries awaiting upload.
- Fallback uploader: `shorts/upload.sh NN` + `shorts/meta/NN.json`.
- Rotation rule (§4): CTAs rotate through 8 slots mod-8 from Short 26 onward.

**Drip schedule:** 20/day × 4 days = all 73 live by roughly 2026-04-24 (4 days from now).

| # | Title | Duration | Video ID | URL | Published (UTC) |
|---|---|---|---|---|---|
| 1 | Your brain doesn't see the world — it predicts it | 50.6s | `1iqMVSIfaP4` | https://www.youtube.com/shorts/1iqMVSIfaP4 | 2026-04-20 04:11 |
| 2 | You don't decide what to do — you descend gradients | 52.3s | `mjTubFiR8PY` | https://www.youtube.com/shorts/mjTubFiR8PY | 2026-04-20 04:44 |
| 3 | Surprise is the one thing your brain is trying to kill | 57.2s | `9lJSifZ09aM` | https://www.youtube.com/shorts/9lJSifZ09aM | 2026-04-20 05:00 |
| 4 | Curiosity isn't a personality trait — it's an equation | 51.9s | `8QyDVFLcrfk` | https://www.youtube.com/shorts/8QyDVFLcrfk | 2026-04-20 |
| 5 | Confidence is just a number your neurons multiply by | 53.5s | `qP9D-_1tV3o` | https://www.youtube.com/shorts/qP9D-_1tV3o | 2026-04-20 |
| 6 | Boredom and panic are the same failure | 57.3s | `GMdymZSVYzQ` | https://www.youtube.com/shorts/GMdymZSVYzQ | 2026-04-20 |
| 7 | Your brain models itself — that's what "I" is | 51.1s | `-w8Zud1wi_A` | https://www.youtube.com/shorts/-w8Zud1wi_A | 2026-04-20 |
| 8 | Pain is a prediction, not a sensation | 48.3s | `ptQMJz7e6eM` | https://www.youtube.com/shorts/ptQMJz7e6eM | 2026-04-20 |
| 9 | Dreams are your brain running the model backwards | 54.7s | `iA2DBc6kdBg` | https://www.youtube.com/shorts/iA2DBc6kdBg | 2026-04-20 |
| 10 | The one equation Karl Friston built his career on | 51.9s | `Ma8sHv5EaKE` | https://www.youtube.com/shorts/Ma8sHv5EaKE | 2026-04-20 |
| 11 | Preface — why this book exists | 59.7s | `Aos9oBJGako` | https://www.youtube.com/shorts/Aos9oBJGako | 2026-04-20 |
| 12 | Ch 1: Perception, action, learning — one loop, one theory | 55.9s | `jzNr3IlDy8I` | https://www.youtube.com/shorts/jzNr3IlDy8I | 2026-04-20 |
| 13 | Ch 2: Bayes' rule to free energy in four moves | 59.2s | `MuyRD8t_pZo` | https://www.youtube.com/shorts/MuyRD8t_pZo | 2026-04-20 |

Fill the empty rows as you ship each short. **Append new rows at the bottom when you finish batch N — do not rebuild the table.**

---

## 8. Publishing cadence

- **Week 1 (this week):** Shorts 1–10 live. (Currently: 3 of 10.)
- **Week 2:** Shorts 11–20.
- **Weeks 3–7:** Shorts 21–58 at ~1/day.
- **Week 8:** Shorts 59–75 (lab clips — record + edit heavy).
- **Week 9:** Shorts 76–85 (equations).
- **Week 10:** Shorts 86–95 (myth-busting).
- **Week 11:** Shorts 96–100 + playlist polish + pinned trailer.

Target: all 100 live within ~11 weeks at 1–2/day.

---

## 9. Open decisions (ask before deviating)

1. **Cadence:** 1/day or 2–3/day?
2. **Thumbnails:** auto-generated first frame, or invest ~60s/short for `flux_schnell` custom?
3. **Voice 2?** Keep Alba throughout, or intersperse a second voice for variety at, say, every 10th?
4. **Cross-post:** same MP4 to TikTok / LinkedIn / X via `cross_platform_manage`?
5. **Playlist structure:** one mega-playlist "The Learn Arc", or split into "Hooks · Chapters · Sessions · Labs · Equations · Myths"?

---

## 10. Directory layout

```
blog-assets/shorts/
  PLAN.md                  <- you are here (symlinked from shorts/PLAN.md)
  01/
    concat.txt
    narration.mp3
    short-01.mp4
    video.mp4              (intermediate, can be deleted)
    slides/
      _base.css
      slide-01-hook.html
      slide-01-hook.png
      slide-02-...html
      slide-02-...png
      ...
  02/  same structure
  03/  same structure
  ...
```

Keep `video.mp4` (silent) in each folder for the first week or two — useful for audio swaps. Delete after cadence is proven.

---

## 11. Cross-chat resume crib

If a fresh agent picks this up:

1. Read **§0 Resume protocol**.
2. Check **§7 Status Log** → next `#`.
3. Use **§3 Production Recipe** verbatim.
4. Ensure **§3.1 Setup** is healthy before starting.
5. Watch for the hazards in **§6**.
6. If MCP tools fail, fall back to direct APIs per **§6.1 / §6.2**.
7. When done, append the row to §7, bump the "Last updated" line at the top, commit.

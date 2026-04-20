# Upload Batch Runner

This is the prompt that the scheduled-tasks cron fires on every run. It picks the next N pending shorts from `shorts/queue.json`, uploads them to YouTube, and marks them live.

---

# Task: Upload the next 20 pending shorts from the queue

You are resuming the Learn Arc Shorts upload pipeline. Everything has been pre-produced — this run is purely upload-and-record.

## Step 1 — Read the queue

```bash
cd /c/Users/mpolz/Documents/WorldModels
cat shorts/queue.json | node -e "
let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{
  const q=JSON.parse(d);
  const pending=q.filter(x=>x.status==='pending').slice(0,20);
  console.log('To upload this run:', pending.length);
  pending.forEach(p=>console.log(' #'+p.n+' '+p.title.slice(0,60)));
});
"
```

If 0 pending, stop. Report done.

## Step 2 — For each pending short (up to 20)

Call `mcp__orchestrate-linkedin__youtube_manage` with:
- `action=upload`
- `file_path` from the queue entry
- `title` from the queue entry
- `description` from the queue entry
- `tags` from the queue entry
- `privacy=public`
- `category_id=27`

**If MCP 401/500 → fall back to `bash shorts/upload.sh NN`** after writing `shorts/meta/NN.json` from the queue entry's title/description/tags (see existing meta files for format).

## Step 3 — On success, update the queue

Set `status="live"` and `video_id=<returned id>` and `url=https://www.youtube.com/shorts/<id>` on that queue entry. Save `shorts/queue.json`.

## Step 4 — On upload-limit error (400 uploadLimitExceeded)

Stop immediately. The daily quota is hit. Do NOT mark the remaining shorts as failed. Leave them pending. Report the stop reason.

## Step 5 — Spacing

Sleep 60 seconds between uploads to avoid abuse flags. `await` between calls (or `sleep 60` in shell).

## Step 6 — Update PLAN.md

After uploading, append live rows to the status log in `shorts/PLAN.md` (§7).

## Step 7 — Commit

```bash
git add shorts/queue.json shorts/PLAN.md
git commit -m "feat(shorts): batch N uploaded — shorts XX-YY live

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
git push
```

## Exit codes

Report at the end:
- Count uploaded this run
- Count remaining pending
- Any failures (with reason)
- Next scheduled run (automatic — cron handles)

---

**Rules:**
- Uploads go ONLY from entries with `status=pending`.
- Never re-upload an entry marked `live`.
- Do not change title/description/tags — they're fixed by queue.json.
- On any doubt, stop and leave pending.

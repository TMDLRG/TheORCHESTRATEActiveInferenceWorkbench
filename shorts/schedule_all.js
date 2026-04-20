// shorts/schedule_all.js — schedule every pending queue entry via /api/youtube/schedule.
// Plan:
//   20 per day, starting 2026-04-21.
//   Each day: 20 slots from 14:00 UTC (9 AM CDT) spaced 36 min apart → last at ~25:24 UTC.
// After each successful POST, updates shorts/queue.json with status="scheduled",
// schedule_id and scheduled_time.

const fs = require('fs');
const http = require('http');

const QUEUE_PATH = 'shorts/queue.json';
const CHANNEL_ID = 'UC_I-d6cICifM567STunNqfw';
const START_UTC = new Date('2026-04-21T14:00:00Z');
const SLOT_MIN = 36;
const SLOTS_PER_DAY = 20;
const DAY_MS = 24 * 60 * 60 * 1000;

function post(path, body) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const req = http.request({ host: 'localhost', port: 3847, path, method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) }
    }, (res) => {
      let chunks = '';
      res.on('data', c => chunks += c);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(chunks) }); }
        catch(e) { resolve({ status: res.statusCode, body: chunks }); }
      });
    });
    req.on('error', reject);
    req.write(data); req.end();
  });
}

function slotToTime(i) {
  const day = Math.floor(i / SLOTS_PER_DAY);
  const slotInDay = i % SLOTS_PER_DAY;
  const t = new Date(START_UTC.getTime() + day * DAY_MS + slotInDay * SLOT_MIN * 60000);
  return t.toISOString();
}

async function main() {
  const queue = JSON.parse(fs.readFileSync(QUEUE_PATH, 'utf-8'));
  const pending = queue.filter(q => q.status === 'pending');
  console.log(`${pending.length} pending entries to schedule\n`);

  let ok = 0, fail = 0;
  for (let i = 0; i < pending.length; i++) {
    const entry = pending[i];
    const scheduled_time = slotToTime(i);
    const payload = {
      channel_id: CHANNEL_ID,
      file_path: entry.file_path,
      title: entry.title,
      description: entry.description,
      tags: entry.tags,
      privacy_status: 'public',
      category_id: entry.category_id || '27',
      scheduled_time
    };
    try {
      const r = await post('/api/youtube/schedule', payload);
      if (r.status === 200 && r.body.success) {
        entry.status = 'scheduled';
        entry.schedule_id = r.body.id;
        entry.scheduled_time = scheduled_time;
        ok++;
        console.log(`  #${entry.n}  →  ${r.body.id}  @ ${scheduled_time}`);
      } else {
        fail++;
        console.log(`  #${entry.n}  FAIL  ${r.status}  ${JSON.stringify(r.body).slice(0,120)}`);
      }
    } catch (e) {
      fail++;
      console.log(`  #${entry.n}  ERR  ${e.message}`);
    }
    // Write queue after each scheduling to survive crashes
    fs.writeFileSync(QUEUE_PATH, JSON.stringify(queue, null, 2));
  }
  console.log(`\nScheduled: ${ok}  Failed: ${fail}  Total pending now: ${queue.filter(q=>q.status==='pending').length}`);
}

main().catch(e => { console.error(e); process.exit(1); });

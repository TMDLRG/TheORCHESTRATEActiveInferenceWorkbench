// shorts/schedule_101_111.js — add 101-111 to queue.json and schedule via the MCP API.
// Continues pacing: last prior slot was 2026-04-24 at 21:12 UTC (slot 12).
// Slots 13-19 of day 3 (2026-04-24) + slots 0-3 of day 4 (2026-04-25).

const fs = require('fs');
const http = require('http');

const QUEUE_PATH = 'shorts/queue.json';
const CHANNEL_ID = 'UC_I-d6cICifM567STunNqfw';

// Continue pacing from 2026-04-24T21:48:00Z onward (36-min slot spacing)
// Slots for 11 new shorts:
const SCHEDULE_TIMES = [
  '2026-04-24T21:48:00Z', // #101
  '2026-04-24T22:24:00Z', // #102
  '2026-04-24T23:00:00Z', // #103
  '2026-04-24T23:36:00Z', // #104
  '2026-04-25T00:12:00Z', // #105
  '2026-04-25T00:48:00Z', // #106
  '2026-04-25T01:24:00Z', // #107
  '2026-04-25T14:00:00Z', // #108
  '2026-04-25T14:36:00Z', // #109
  '2026-04-25T15:12:00Z', // #110
  '2026-04-25T15:48:00Z', // #111
];

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

const FOOTER = `

— — —
📘 The Abstractionist's Papers — Von Paumgartten:
   https://welcometothebluespace.com/the-abstractionists-papers/
🧭 Omega — explore the Natural Reality lens:
   https://app-omega-gray.vercel.app/
🤝 Connect with Michael Polzin on LinkedIn:
   https://www.linkedin.com/in/mpolzin/
🙏 Thanks Von: https://www.linkedin.com/in/vonpaumgartten/

📚 Books behind this series (by Michael Polzin):
· ORCHESTRATE Prompting: https://www.amazon.com/ORCHESTRATE-Prompting-Professional-AI-Outputs-ebook/dp/B0G2B9LG6V
· LEVEL UP — AI Usage Maturity Model: https://www.amazon.com/Level-Usage-Maturity-Model-Excellence-ebook/dp/B0GS4WDVFZ

📝 Full 50-post blog series: https://dev.to/tmdlrg
🤖 Open-source Workbench: https://github.com/TMDLRG/TheORCHESTRATEActiveInferenceWorkbench`;

const META = {
  101: {
    title: "Is this the meaning of life? | Active Inference — BONUS #101",
    topic: "Is everything just electricity finding the path of least resistance? Could Active Inference stem cells self-organise with no priors? Was the Big Bang the flip of the switch that laid down the equation everything since has been minimising? Bonus episode — the big question. Teases the Omega app + the Abstractionist's Papers."
  },
  102: { title: "Red Space & Blue Space — meaning vs happening | Abstractionists 1/10 · #102", topic: "The Abstractionist split. Blue Space = causation (never observed directly). Red Space = what your mind builds. In Active Inference terms: Red = Q, Blue = the true world the agent infers. You never touch Blue." },
  103: { title: "The Blindfold — the map that forgets it's a map | Abstractionists 2/10 · #103", topic: "Your mind builds Q and forgets it's building Q. The construction is invisible. Every hallucination, every stubborn belief, every phantom limb — the blindfold still operating." },
  104: { title: "Orthogonality — Red and Blue meet but never merge | Abstractionists 3/10 · #104", topic: "Perpendicular axes. Shared boundary. You can't think your way out. The Markov blanket makes the interface precise." },
  105: { title: "Parallel minds, shared causation | Abstractionists 4/10 · #105", topic: "Three people, same gesture, three meanings. Different generative models produce different inferences from identical signals. Why communication is structurally hard." },
  106: { title: "Induction — bridging Blue and Red | Abstractionists 5/10 · #106", topic: "How signals cross the boundary. In Active Inference: message passing (Eq 4.13). Continuous-time: the quadratic gradient. Two domains, continuously linked." },
  107: { title: "Living inside the model | Abstractionists 6/10 · #107", topic: "Every moment of experience happens inside Q. Not 'my interpretation of text' — text. The model doesn't announce itself." },
  108: { title: "Learning through paradox | Abstractionists 7/10 · #108", topic: "Contradiction is the engine of growth. Small mismatch = micro-update. Large = reorganisation. Paradox IS surprise. You learn by minimising F." },
  109: { title: "Emergence — hierarchy, not evolution | Abstractionists 8/10 · #109", topic: "The hard problem of novelty. Active Inference says: hierarchy. Upper layer represents patterns lower layers can't. Same equation, taller graph, new capabilities." },
  110: { title: "'The music made me dance' — it didn't | Abstractionists 9/10 · #110", topic: "Causation is in Blue Space. It never arrives whole in experience. What you feel as the cause is always Q's best inference. Bayesian causal inference." },
  111: { title: "Philosophy + math, one idea | Abstractionists 10/10 — synthesis · #111", topic: "Von Paumgartten says it in philosophy. Friston says it in math. Red=Q, Blue=P, Markov blanket=yellow boundary, induction=message passing. One theory, two languages." }
};

async function main() {
  const queue = JSON.parse(fs.readFileSync(QUEUE_PATH, 'utf-8'));

  // Append new entries 101-111
  for (let i = 0; i < 11; i++) {
    const n = 101 + i;
    const meta = META[n];
    if (!meta) continue;
    const desc = `${meta.topic}${FOOTER}\n\n#ActiveInference #Abstractionists #FreeEnergyPrinciple #Neuroscience #Shorts`;
    queue.push({
      n,
      file_path: `/app/content/media/shorts/${n}/short-${n}.mp4`,
      title: meta.title,
      description: desc,
      tags: ["Active Inference","Abstractionists","Natural Reality","Von Paumgartten","Free Energy Principle","Omega","Shorts"],
      privacy: "public",
      category_id: "27",
      status: "pending"
    });
  }

  // Schedule
  const toSchedule = queue.filter(q => q.n >= 101 && q.n <= 111 && q.status === 'pending');
  console.log(`Scheduling ${toSchedule.length} new entries...\n`);
  let ok = 0, fail = 0;
  for (let i = 0; i < toSchedule.length; i++) {
    const entry = toSchedule[i];
    const scheduled_time = SCHEDULE_TIMES[i];
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
        console.log(`  #${entry.n}  FAIL  ${r.status}  ${JSON.stringify(r.body).slice(0,160)}`);
      }
    } catch (e) {
      fail++;
      console.log(`  #${entry.n}  ERR  ${e.message}`);
    }
    fs.writeFileSync(QUEUE_PATH, JSON.stringify(queue, null, 2));
  }
  console.log(`\nScheduled: ${ok}  Failed: ${fail}  Total in queue: ${queue.length}`);
}

main().catch(e => { console.error(e); process.exit(1); });

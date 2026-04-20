// build_queue.js — assemble shorts/queue.json with metadata for scheduled uploads.
// Reads each spec JSON (for title/topic hints) + the canned description template.
const fs = require('fs');

const LIVE_IDS = {
  1: '1iqMVSIfaP4', 2: 'mjTubFiR8PY', 3: '9lJSifZ09aM',
  4: '8QyDVFLcrfk', 5: 'qP9D-_1tV3o', 6: 'GMdymZSVYzQ',
  7: '-w8Zud1wi_A', 8: 'ptQMJz7e6eM', 9: 'iA2DBc6kdBg',
  10: 'Ma8sHv5EaKE', 11: 'Aos9oBJGako', 12: 'jzNr3IlDy8I',
  13: 'MuyRD8t_pZo', 14: 'XinGSE99ICE', 15: 'NapGrAWCWdU',
  16: 'wLn1jIFmw5g', 17: 'a0QQdnWZM3o', 18: 'hpUjlQyfTTY',
  19: 'W1vozjivDtU', 20: 'SmlRNkCSTFI', 21: '3OKx3bgZ_Kw',
  22: 'qUA2uNJRKAk', 23: 'sqcYG_UrBks', 24: 'B9AsIZnO1io',
  25: 'u-fFsDKQsB0', 26: 'uTgqv_L-x1U', 27: 'jvd3VjPb7RI'
};

// Titles + topic for each short 28-100 (from specs + session map)
const INDEX = {
  28: { title: "Expected Free Energy in one page | §3.1 · #28 #Shorts", topic: "EFE in one page — G per policy, softmax picks" },
  29: { title: "Epistemic vs pragmatic — exploration for free | §3.2 · #29 #Shorts", topic: "EFE splits into pragmatic + epistemic value" },
  30: { title: "The softmax policy and its precision knob γ | §3.3 · #30 #Shorts", topic: "π ∝ exp(-γG); γ = dopamine" },
  31: { title: "What makes an agent actually active | §3.4 · #31 #Shorts", topic: "Agent picks its own observations; curiosity for free" },
  32: { title: "States, observations, actions — the three sets | §4.1 · #32 #Shorts", topic: "The primitives you write first" },
  33: { title: "The A matrix — where perception lives | §4.2 · #33 #Shorts", topic: "A = likelihood; engine of belief update" },
  34: { title: "Expected Free Energy, introduced | §4.3 · #34 #Shorts", topic: "G decomposed; derive on one page" },
  35: { title: "The MDP world — where ABCD runs together | §4.4 · #35 #Shorts", topic: "Classical MDP + AI's preferences swap" },
  36: { title: "Ship your first agent — the 9-step workflow | §4.5 · #36 #Shorts", topic: "Sketch, fill, step, iterate" },
  37: { title: "The cortex as a factor graph | §5.1 · #37 #Shorts", topic: "Columns, synapses, spikes = variables, factors, messages" },
  38: { title: "Predictive coding — where the gradient lives | §5.2 · #38 #Shorts", topic: "Descending predictions, ascending errors" },
  39: { title: "Neuromodulation — the precision knobs | §5.3 · #39 #Shorts", topic: "Dopamine, ACh, NE, 5-HT = precision" },
  40: { title: "The brain map — which role lives where | §5.4 · #40 #Shorts", topic: "Visual cortex, hippocampus, BG, midbrain" },
  41: { title: "States, obs, actions — the design session | §6.1 · #41 #Shorts", topic: "Operational definitions; carve at joints" },
  42: { title: "Fill the four matrices A,B,C,D | §6.2 · #42 #Shorts", topic: "One column at a time; probabilities" },
  43: { title: "Run and inspect — the debugging loop | §6.3 · #43 #Shorts", topic: "Read belief, policy, surprise; fix matrix; iterate" },
  44: { title: "Discrete-time refresher before the muscle | §7.1 · #44 #Shorts", topic: "Ch 7 begins; recite Q, π, G" },
  45: { title: "Eq 4.13 in depth — softmax derived | §7.2 · #45 #Shorts", topic: "Belief propagation → exact Eq 4.13" },
  46: { title: "Learn A and B — Dirichlet updates Eq 7.10 | §7.3 · #46 #Shorts", topic: "Counts as memory; conjugate update" },
  47: { title: "Hierarchical — stack two POMDPs | §7.4 · #47 #Shorts", topic: "Upper = intent, lower = step; messages both ways" },
  48: { title: "Chapter 7 worked example — the capstone | §7.5 · #48 #Shorts", topic: "Two layers + Dirichlet + live EFE" },
  49: { title: "Generalized coordinates — the tower | §8.1 · #49 #Shorts", topic: "State + derivatives; bundled" },
  50: { title: "Eq 4.19 — quadratic free energy | §8.2 · #50 #Shorts", topic: "Weighted squared prediction errors" },
  51: { title: "Action on sensors — ∂F/∂a | §8.3 · #51 #Shorts", topic: "Reflex arcs, motor cortex, same gradient" },
  52: { title: "Continuous play — turn the knobs | §8.4 · #52 #Shorts", topic: "Laplace Tower hands-on" },
  53: { title: "Fit the model to real data | §9.1 · #53 #Shorts", topic: "Promote parameters to latents" },
  54: { title: "Comparing models — Occam's razor in F | §9.2 · #54 #Shorts", topic: "Lower F wins; complexity built in" },
  55: { title: "Case study — the empirical workflow | §9.3 · #55 #Shorts", topic: "Three candidate models, one winner" },
  56: { title: "Synthesis — perception, action, learning | §10.1 · #56 #Shorts", topic: "One equation, three minimisations" },
  57: { title: "Honest limitations of Active Inference | §10.2 · #57 #Shorts", topic: "Scalability, interpretability, falsifiability" },
  58: { title: "Where next — the frontier | §10.3 · #58 #Shorts", topic: "Continuous, deep gen, multi-agent, clinical" },
  59: { title: "Chapters 4–7 recap in one minute | #59 #Shorts", topic: "Recap the core" },
  60: { title: "The capstone — 50 sessions in one takeaway | #60 #Shorts", topic: "One equation, three jobs, one place to stand" },
  61: { title: "Bayes Chips — one-step belief update | Lab · #61 #Shorts", topic: "Two urns, one sample" },
  62: { title: "Bayes Chips — sequential evidence | Lab · #62 #Shorts", topic: "Evidence accumulates" },
  63: { title: "Jumping Frog — perception loop closing | Lab · #63 #Shorts", topic: "Noisy grid world; belief sharpens" },
  64: { title: "Jumping Frog — EFE scores the next hop | Lab · #64 #Shorts", topic: "Four candidate hops scored" },
  65: { title: "PoMDP Machine — set up A,B,C,D | Lab · #65 #Shorts", topic: "Beat 1: build the agent" },
  66: { title: "PoMDP Machine — EFE policy choice | Lab · #66 #Shorts", topic: "Beat 5: live softmax over policies" },
  67: { title: "PoMDP Machine — Dirichlet learning | Lab · #67 #Shorts", topic: "Beat 7: matrices adapt" },
  68: { title: "Anatomy Studio — EFE decomposed | Lab · #68 #Shorts", topic: "Every subterm visible" },
  69: { title: "Anatomy Studio — swap C, watch behaviour change | Lab · #69 #Shorts", topic: "C shapes behaviour without retraining" },
  70: { title: "Atlas — click a brain region, see its math | Lab · #70 #Shorts", topic: "Clickable brain map → AI role" },
  71: { title: "Atlas — neuromodulator precision sliders | Lab · #71 #Shorts", topic: "γ made physical" },
  72: { title: "Laplace Tower — generalised coords live | Lab · #72 #Shorts", topic: "Position, velocity, acceleration live" },
  73: { title: "Laplace Tower — order truncation | Lab · #73 #Shorts", topic: "How many levels do you need?" },
  74: { title: "Free Energy Forge — build F piece by piece | Lab · #74 #Shorts", topic: "Add/remove F terms with a dropdown" },
  75: { title: "Free Energy Forge — term ablation | Lab · #75 #Shorts", topic: "Remove one; see what breaks" },
  76: { title: "Eq 2.1 Bayes' rule in plain English | Equation · #76 #Shorts", topic: "The identity everything inherits" },
  77: { title: "Eq 2.5 Variational free energy | Equation · #77 #Shorts", topic: "F = E_Q[log Q − log P]" },
  78: { title: "Eq 2.6 The surprise bound | Equation · #78 #Shorts", topic: "F ≥ surprise; the key inequality" },
  79: { title: "Eq 4.10 Per-step free energy | Equation · #79 #Shorts", topic: "F_t as three dot products" },
  80: { title: "Eq 4.11 Trajectory free energy | Equation · #80 #Shorts", topic: "F summed across time" },
  81: { title: "Eq 4.13 Perception in one line | Equation · #81 #Shorts", topic: "Softmax of log A·o + log prior" },
  82: { title: "Eq 4.14 Policy posterior | Equation · #82 #Shorts", topic: "π ∝ exp(−γG); utility → probability" },
  83: { title: "Eq 4.19 Quadratic free energy | Equation · #83 #Shorts", topic: "Continuous-time, Gaussian beliefs" },
  84: { title: "Eq 7.10 Dirichlet update — learning in one line | Equation · #84 #Shorts", topic: "a = A + n; conjugate prior magic" },
  85: { title: "Eq B.5 Message passing primitive | Equation · #85 #Shorts", topic: "The general form behind all of it" },
  86: { title: "Myth: it's just RL rebranded — no | Myths · #86 #Shorts", topic: "Different primitives, different commitments" },
  87: { title: "Myth: FEP is unfalsifiable — careful | Myths · #87 #Shorts", topic: "Framework vs specific model" },
  88: { title: "Myth: only works on toy mazes | Myths · #88 #Shorts", topic: "Intros ≠ research frontier" },
  89: { title: "Myth: predictive coding is just Kalman | Myths · #89 #Shorts", topic: "Kalman inside, but not the whole story" },
  90: { title: "Myth: Active Inference explains consciousness — it doesn't | Myths · #90 #Shorts", topic: "Framework is agnostic" },
  91: { title: "Myth: free will disappears — agency doesn't | Myths · #91 #Shorts", topic: "Homunculus dies; agency survives" },
  92: { title: "Myth: the brain minimises prediction error — close | Myths · #92 #Shorts", topic: "Complexity term matters" },
  93: { title: "Myth: dopamine = reward — actually precision | Myths · #93 #Shorts", topic: "Dopamine is trust in reward" },
  94: { title: "Myth: hierarchy is a scaling trick — no | Myths · #94 #Shorts", topic: "Same equation on deeper model" },
  95: { title: "Myth: can't fit real data — it does | Myths · #95 #Shorts", topic: "OCD, psychosis, ADHD studies" },
  96: { title: "The Learn Arc — series trailer | #96 #Shorts", topic: "100 videos, 10 chapters, one equation" },
  97: { title: "Five things to keep from Active Inference | #97 #Shorts", topic: "The takeaways worth keeping" },
  98: { title: "The Active Inference book in 5 minutes | #98 #Shorts", topic: "Parr, Pezzulo, Friston — reading guide" },
  99: { title: "Fork the workbench — three directions | #99 #Shorts", topic: "Sample efficiency, multi-agent, clinical sandbox" },
  100: { title: "Thank you — The Learn Arc, part 100 | #100 #Shorts", topic: "The arc is done; the work continues" }
};

const FOOTER = `

— — —
📚 Books by Michael Polzin:
· ORCHESTRATE Prompting: https://www.amazon.com/ORCHESTRATE-Prompting-Professional-AI-Outputs-ebook/dp/B0G2B9LG6V
· LEVEL UP — AI Usage Maturity Model: https://www.amazon.com/Level-Usage-Maturity-Model-Excellence-ebook/dp/B0GS4WDVFZ

📝 Full 50-post blog series: https://dev.to/tmdlrg
🤖 Open-source Workbench (Phoenix / LiveView / pure Jido on the BEAM):
   https://github.com/TMDLRG/TheORCHESTRATEActiveInferenceWorkbench
🤝 Connect with Michael on LinkedIn: https://www.linkedin.com/in/mpolzin/

Book reference: Active Inference — Parr, Pezzulo, Friston (MIT Press, 2022)`;

const TAGS_BASE = ["Active Inference","Free Energy Principle","Neuroscience","AI","Karl Friston","ORCHESTRATE","Shorts"];

// Prior-parts list helper for cross-linking. For any N, put ALL previously-live shorts as "Part 1..N-1" links.
function priorPartsBlock(n) {
  const prior = Object.entries(LIVE_IDS).map(([k,v])=>({k:parseInt(k),v})).sort((a,b)=>a.k-b.k);
  const lines = prior.filter(p => p.k < n).slice(-10).map(p => `· Part ${p.k}: https://www.youtube.com/shorts/${p.v}`);
  // After upload goes live, queue.json entries will gradually get IDs too; for now limit to last 10 live
  return lines.length ? `\n\nPrior parts (recent):\n${lines.join('\n')}` : '';
}

const queue = [];
for (let n = 28; n <= 100; n++) {
  const meta = INDEX[n];
  if (!meta) continue;
  const desc = `Part ${n} of 100 — The Learn Arc.\n\n${meta.topic}.${priorPartsBlock(n)}${FOOTER}\n\n#ActiveInference #Shorts`;
  queue.push({
    n,
    file_path: `/app/content/media/shorts/${String(n).padStart(2, '0')}/short-${String(n).padStart(2, '0')}.mp4`,
    title: meta.title,
    description: desc,
    tags: TAGS_BASE,
    privacy: "public",
    category_id: "27",
    status: "pending"   // pending | uploading | live | failed
  });
}

fs.writeFileSync('shorts/queue.json', JSON.stringify(queue, null, 2));
console.log(`queue.json written: ${queue.length} entries pending (shorts 28-100).`);

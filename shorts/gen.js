#!/usr/bin/env node
// gen.js — generate 6 HTML slides from a short spec JSON.
// Usage: node shorts/gen.js shorts/specs/NN.json
//
// Spec JSON format:
// {
//   "n": 29,
//   "kicker_main": "The Learn Arc · 29/100",
//   "foot": "ACTIVE INFERENCE · PART 29",
//   "hook_kicker": "...",
//   "hook_headline": "Short two-liner with <em>coral</em>.",
//   "hook_sub": "optional",
//   "slides": [
//     // 4 middle slides (slides 2-5); slide 1 is hook, slide 6 is CTA
//     { "kind": "text", "kicker": "...", "headline": "...", "sub": "...", "coral_emphasis": "..." },
//     { "kind": "split", "kicker": "...", "left": {"h": "...", "p": "..."}, "right": {"h":"","p":""} },
//     { "kind": "equation", "kicker": "...", "equation": "F = ...", "sub": "..." },
//     { "kind": "image", "screenshot": "../../series-01/XX.png", "kicker": "...", "headline": "...", "sub": "" }
//   ],
//   "cta_slot": 1,
//   "cta_custom": null   // optional; overrides the slot-based CTA
// }

const fs = require('fs');
const path = require('path');

const BASE_CSS_IMPORT = '<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="_base.css"></head>\n';
const BODY_OPEN = '<body><div class="slide">';
const BODY_IMAGE = (src) => `<body><div class="slide" style="padding:0;align-items:stretch;justify-content:stretch">\n<img class="full-img" src="${src}">\n<div class="overlay"></div>\n<div class="above" style="position:absolute;bottom:140px;left:80px;right:80px">`;
const BODY_CENTER = '<body><div class="slide" style="justify-content:center;align-items:center;text-align:center">';
const CLOSE = '</div></body></html>\n';

// CTA rotation slots. Input `n` is short number; slot = ((n - 26) mod 8) + 1 for n >= 26.
function ctaForSlot(n, customOverride) {
  if (customOverride) return customOverride;
  if (n < 26) return ctaDefault(n);
  const slot = ((n - 26) % 8) + 1;
  return ctaTable[slot];
}
function ctaDefault(n) { return ctaTable[1]; }

const ctaTable = {
  1: {
    kind: 'book-orchestrate',
    primary_line1: 'Like the way<br>I break down<br>big math?',
    primary_line2_kicker: 'Get my book',
    primary_line2: 'ORCHESTRATE<br><em>Prompting</em>',
    primary_sub: 'Link in description.<br>— Michael Polzin'
  },
  2: {
    kind: 'book-levelup',
    primary_line1: 'Want to level<br>up how you<br>work with AI?',
    primary_line2_kicker: 'Get my book',
    primary_line2: 'LEVEL UP',
    primary_sub: 'The AI Usage<br>Maturity Model.<br>— Michael Polzin'
  },
  3: {
    kind: 'linkedin',
    primary_line1: 'Working on<br>something<br>like this?',
    primary_line2_kicker: "Let's connect",
    primary_line2: 'LinkedIn:<br>mpolzin',
    primary_sub: 'Link in description.'
  },
  4: {
    kind: 'github',
    primary_line1: 'Want to<br>run this<br>yourself?',
    primary_line2_kicker: 'Fork / star',
    primary_line2: 'The Workbench<br>on <em>GitHub</em>',
    primary_sub: 'MIT licensed.<br>Link in description.'
  },
  5: {
    kind: 'blog',
    primary_line1: 'Want the<br>full write-up?',
    primary_line2_kicker: 'Read the series',
    primary_line2: '50 posts on<br><em>dev.to</em>',
    primary_sub: 'dev.to/tmdlrg<br>— Michael Polzin'
  },
  6: {
    kind: 'comments',
    primary_line1: 'Which part<br>hit you<br>hardest?',
    primary_line2_kicker: 'Drop it',
    primary_line2: 'In the<br><em>comments</em>',
    primary_sub: 'I reply to<br>every thoughtful one.'
  },
  7: {
    kind: 'share',
    primary_line1: 'Know someone<br>who would<br>love this?',
    primary_line2_kicker: 'Share it',
    primary_line2: '<em>Right now</em>',
    primary_sub: 'Takes ten seconds.'
  },
  8: {
    kind: 'subscribe',
    primary_line1: 'Part ' + 'N+1' + '<br>drops tomorrow.',
    primary_line2_kicker: 'Do the thing',
    primary_line2: '👍 + <em>Subscribe</em>',
    primary_sub: "So you don't miss it."
  }
};

function slideHook(spec) {
  const s = `${BASE_CSS_IMPORT}${BODY_OPEN}\n` +
    `<div class="kicker">${spec.kicker_main}</div>\n` +
    `<div class="headline">${spec.hook_headline}</div>\n` +
    (spec.hook_sub ? `<div class="sub" style="margin-top:60px;font-size:46px">${spec.hook_sub}</div>\n` : '') +
    `<div class="foot">${spec.foot}</div>\n` +
    CLOSE;
  return s;
}

function slideText(spec, slide) {
  const hl = slide.headline ? `<div class="headline" style="font-size:${slide.hl_size||80}px">${slide.headline}</div>\n` : '';
  const sub = slide.sub ? `<div class="sub" style="margin-top:50px;font-size:${slide.sub_size||44}px">${slide.sub}</div>\n` : '';
  const coral = slide.coral ? `<div class="headline" style="margin-top:50px;font-size:${slide.coral_size||76}px;color:#FF6F61">${slide.coral}</div>\n` : '';
  return `${BASE_CSS_IMPORT}${BODY_OPEN}\n` +
    (slide.kicker ? `<div class="kicker">${slide.kicker}</div>\n` : '') +
    hl + sub + coral +
    `<div class="foot">${spec.foot}</div>\n` +
    CLOSE;
}

function slideSplit(spec, slide) {
  const cells = (slide.cells || [slide.left, slide.right]).map(c =>
    `  <div>\n    <h3>${c.h}</h3>\n    <p>${c.p}</p>\n  </div>`
  ).join('\n');
  const after = slide.after_coral ? `<div class="headline" style="margin-top:80px;font-size:${slide.after_size||72}px;color:#FF6F61">${slide.after_coral}</div>\n` : '';
  const cols = slide.columns === 1 ? 'grid-template-columns:1fr;gap:18px' : '';
  return `${BASE_CSS_IMPORT}${BODY_OPEN}\n` +
    (slide.kicker ? `<div class="kicker">${slide.kicker}</div>\n` : '') +
    (slide.headline ? `<div class="headline" style="font-size:${slide.hl_size||80}px">${slide.headline}</div>\n` : '') +
    `<div class="split" style="margin-top:${slide.mt||60}px${cols ? ';'+cols : ''}">\n${cells}\n</div>\n` +
    after +
    `<div class="foot">${spec.foot}</div>\n` +
    CLOSE;
}

function slideEquation(spec, slide) {
  return `${BASE_CSS_IMPORT}${BODY_OPEN}\n` +
    (slide.kicker ? `<div class="kicker">${slide.kicker}</div>\n` : '') +
    (slide.headline ? `<div class="headline" style="font-size:${slide.hl_size||76}px">${slide.headline}</div>\n` : '') +
    `<div class="equation" style="font-size:${slide.eq_size||96}px;margin:40px 0">${slide.equation}</div>\n` +
    (slide.sub ? `<div class="sub" style="margin-top:20px;font-size:${slide.sub_size||44}px">${slide.sub}</div>\n` : '') +
    (slide.coral ? `<div class="headline" style="margin-top:50px;font-size:${slide.coral_size||68}px;color:#FF6F61">${slide.coral}</div>\n` : '') +
    `<div class="foot">${spec.foot}</div>\n` +
    CLOSE;
}

function slideImage(spec, slide) {
  return `${BASE_CSS_IMPORT}${BODY_IMAGE(slide.screenshot)}\n` +
    (slide.kicker ? `<div class="kicker">${slide.kicker}</div>\n` : '') +
    (slide.headline ? `<div class="headline" style="font-size:${slide.hl_size||84}px">${slide.headline}</div>\n` : '') +
    (slide.sub ? `<div class="sub" style="margin-top:30px;font-size:${slide.sub_size||44}px">${slide.sub}</div>\n` : '') +
    `</div>\n<div class="foot">${spec.foot}</div>\n` +
    CLOSE;
}

function slideCTA(spec) {
  const cta = ctaForSlot(spec.n, spec.cta_custom);
  const l1 = cta.primary_line1.replace('N+1', String(spec.n + 1));
  return `${BASE_CSS_IMPORT}${BODY_CENTER}\n` +
    `<div class="kicker" style="align-self:center">${spec.n} / 100</div>\n` +
    `<div class="headline" style="text-align:center;font-size:76px">${l1}</div>\n` +
    `<div class="sub" style="text-align:center;margin-top:50px;font-size:44px;color:#FF6F61"><em style="font-style:normal;font-weight:900">${cta.primary_line2_kicker}</em></div>\n` +
    `<div class="headline" style="text-align:center;margin-top:20px;font-size:64px">${cta.primary_line2}</div>\n` +
    `<div class="sub" style="text-align:center;margin-top:30px;font-size:34px">${cta.primary_sub}</div>\n` +
    `<div class="foot" style="left:0;right:0;text-align:center">ACTIVE INFERENCE · THE LEARN ARC</div>\n` +
    CLOSE;
}

// ---- main ----
const specPath = process.argv[2];
const spec = JSON.parse(fs.readFileSync(specPath, 'utf-8'));
const n = spec.n;
const nn = String(n).padStart(2, '0');
const outDir = `blog-assets/shorts/${nn}/slides`;
fs.mkdirSync(outDir, { recursive: true });
// Copy base CSS if missing
const baseCss = 'blog-assets/shorts/01/slides/_base.css';
if (!fs.existsSync(`${outDir}/_base.css`)) fs.copyFileSync(baseCss, `${outDir}/_base.css`);

const renderers = { text: slideText, split: slideSplit, equation: slideEquation, image: slideImage };

// slide-01 is always the hook
fs.writeFileSync(`${outDir}/slide-01-hook.html`, slideHook(spec));
// middle slides (expect 4 entries, slides 2-5)
spec.slides.forEach((slide, i) => {
  const num = String(i + 2).padStart(2, '0');
  const html = renderers[slide.kind](spec, slide);
  const label = slide.label || slide.kind;
  fs.writeFileSync(`${outDir}/slide-${num}-${label}.html`, html);
});
// slide-06 CTA
fs.writeFileSync(`${outDir}/slide-06-cta.html`, slideCTA(spec));

// Write concat.txt with provided timings
const durations = spec.durations || [4, 13, 13, 13, 7, 5.5];
const names = ['slide-01-hook'].concat(spec.slides.map((s, i) => `slide-${String(i+2).padStart(2, '0')}-${s.label || s.kind}`)).concat(['slide-06-cta']);
let concat = '';
names.forEach((n2, i) => {
  concat += `file 'slides/${n2}.png'\nduration ${durations[i]}\n`;
});
concat += `file 'slides/slide-06-cta.png'\n`;
fs.writeFileSync(`blog-assets/shorts/${nn}/concat.txt`, concat);

console.log(`  generated ${spec.slides.length + 2} slide HTMLs for #${nn}`);

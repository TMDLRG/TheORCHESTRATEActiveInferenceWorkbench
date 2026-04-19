    /* ================================================================
       Learning Shell — singleton namespace `LS` below; per-sim content
       (terms, analogies, exercises, beats, equation panels) passed in
       via LS.init({ ... }). Drop-in reusable across all 7 sims.
       ================================================================ */
    (function(){
      const LS = window.LS = {};
      const state = { path: 'real', cfg: null, eqTab: 'equation', beatIdx: 0 };
      const pathbar = document.querySelector('.ls-pathbar');
      const picker = document.getElementById('lsPickerOverlay');
      const pickerDismiss = document.getElementById('lsPickerDismiss');
      const pickerBtn = document.getElementById('lsPickerBtn');
      const dysBtn = document.getElementById('lsDysBtn');
      const dockG = document.getElementById('lsDockGlossary');
      const dockA = document.getElementById('lsDockAnalogies');
      const dockX = document.getElementById('lsDockExercises');
      const panel = document.getElementById('lsPanel');
      const panelOv = document.getElementById('lsPanelOverlay');
      const panelTitle = document.getElementById('lsPanelTitle');
      const panelBody = document.getElementById('lsPanelBody');
      const panelClose = document.getElementById('lsPanelClose');
      const eqBody = document.getElementById('lsEqBody');
      const eqTabs = [...document.querySelectorAll('[data-ls-tab]')];
      const beatHost = document.getElementById('lsBeatHost');
      const tooltip = document.getElementById('lsTooltip');
      const printRoot = document.getElementById('lsPrintRoot');

      LS.init = function(cfg) {
        state.cfg = cfg;
        const key = 'ls.' + cfg.simKey + '.path';
        const dysKey = 'ls.' + cfg.simKey + '.dys';
        const saved = localStorage.getItem(key);
        if (localStorage.getItem(dysKey) === '1') {
          document.body.classList.add('ls-dys');
          if (dysBtn) dysBtn.setAttribute('aria-pressed', 'true');
        }
        if (!saved) {
          if (picker) picker.classList.add('on');
          state.path = 'real';
        } else {
          state.path = saved;
        }
        applyPathButtons();
        renderEqPanel();
        renderBeat();
        wireTooltipTerms(document.body);
        if (cfg.onPathChange) cfg.onPathChange(state.path);
      };

      LS.setPath = function(p, opts) {
        opts = opts || {};
        state.path = p;
        if (state.cfg) localStorage.setItem('ls.' + state.cfg.simKey + '.path', p);
        applyPathButtons();
        renderEqPanel();
        renderBeat();
        if (!opts.silent && state.cfg && state.cfg.onPathChange) state.cfg.onPathChange(p);
      };

      LS.getPath = function() { return state.path; };

      function applyPathButtons() {
        document.querySelectorAll('[data-ls-path]').forEach(b => {
          b.setAttribute('aria-pressed', b.dataset.lsPath === state.path ? 'true' : 'false');
        });
      }

      if (pathbar) pathbar.addEventListener('click', e => {
        const b = e.target.closest('[data-ls-path]');
        if (!b) return;
        LS.setPath(b.dataset.lsPath);
      });
      if (picker) picker.addEventListener('click', e => {
        const b = e.target.closest('[data-ls-path]');
        if (b) { picker.classList.remove('on'); LS.setPath(b.dataset.lsPath); return; }
      });
      if (pickerDismiss) pickerDismiss.addEventListener('click', () => {
        picker.classList.remove('on');
        LS.setPath('real');
      });
      if (pickerBtn) pickerBtn.addEventListener('click', () => picker.classList.add('on'));
      if (dysBtn) dysBtn.addEventListener('click', () => {
        document.body.classList.toggle('ls-dys');
        const on = document.body.classList.contains('ls-dys');
        dysBtn.setAttribute('aria-pressed', on ? 'true' : 'false');
        if (state.cfg) localStorage.setItem('ls.' + state.cfg.simKey + '.dys', on ? '1' : '0');
      });

      function openPanel(title, bodyHTML) {
        panelTitle.textContent = title;
        panelBody.innerHTML = bodyHTML;
        panel.classList.add('on');
        panelOv.classList.add('on');
        panel.setAttribute('aria-hidden', 'false');
        panelOv.setAttribute('aria-hidden', 'false');
        wireTooltipTerms(panelBody);
      }
      function closePanel() {
        panel.classList.remove('on');
        panelOv.classList.remove('on');
        panel.setAttribute('aria-hidden', 'true');
        panelOv.setAttribute('aria-hidden', 'true');
      }
      if (panelClose) panelClose.addEventListener('click', closePanel);
      if (panelOv) panelOv.addEventListener('click', closePanel);
      document.addEventListener('keydown', e => {
        if (e.key === 'Escape') { closePanel(); if (picker) picker.classList.remove('on'); hideTooltip(); }
      });

      function escapeHTML(s) {
        return (s || '').replace(/[&<>"']/g, c => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;' }[c]));
      }
      function tierFor(term) {
        if (!state.cfg || !state.cfg.terms) return null;
        return state.cfg.terms[term] || null;
      }
      function showTooltip(el) {
        const term = el.dataset.term;
        const entry = tierFor(term);
        if (!entry) {
          tooltip.innerHTML = `<div class="ls-term-name">${escapeHTML(term)}</div><div class="ls-term-tier">No glossary entry yet.</div>`;
        } else {
          const p = state.path;
          const order = { kid:['kid','adult','phd'], real:['adult','kid','phd'], equation:['adult','phd','kid'], derivation:['phd','adult','kid'] }[p] || ['adult','phd','kid'];
          const labels = { kid:'For a 5th grader', adult:'For a curious adult', phd:'For a PhD' };
          let html = `<div class="ls-term-name">${escapeHTML(entry.name || term)}</div>`;
          for (const t of order) {
            if (entry[t]) html += `<div class="ls-term-tier"><b>${labels[t]}:</b> ${escapeHTML(entry[t])}</div>`;
          }
          tooltip.innerHTML = html;
        }
        const r = el.getBoundingClientRect();
        const tw = 320, th = 140;
        let left = window.scrollX + r.left;
        let top = window.scrollY + r.bottom + 6;
        if (left + tw > window.scrollX + window.innerWidth - 8) left = window.scrollX + window.innerWidth - tw - 8;
        if (top + th > window.scrollY + window.innerHeight - 8) top = window.scrollY + r.top - th - 6;
        tooltip.style.left = Math.max(8, left) + 'px';
        tooltip.style.top = Math.max(8, top) + 'px';
        tooltip.classList.add('on');
      }
      function hideTooltip() { if (tooltip) tooltip.classList.remove('on'); }
      function wireTooltipTerms(root) {
        if (!root) return;
        root.querySelectorAll('[data-term]:not([data-ls-wired])').forEach(el => {
          el.classList.add('ls-term');
          el.setAttribute('tabindex', '0');
          el.setAttribute('data-ls-wired', '1');
          el.setAttribute('aria-label', 'Definition of ' + el.dataset.term);
          el.addEventListener('mouseenter', () => showTooltip(el));
          el.addEventListener('mouseleave', hideTooltip);
          el.addEventListener('focus', () => showTooltip(el));
          el.addEventListener('blur', hideTooltip);
          el.addEventListener('click', e => { e.stopPropagation(); showTooltip(el); });
        });
      }
      document.addEventListener('click', e => {
        if (!e.target.closest('[data-term]') && !e.target.closest('.ls-tooltip')) hideTooltip();
      });
      LS.wireTooltipTerms = wireTooltipTerms;

      if (dockG) dockG.addEventListener('click', () => {
        const terms = (state.cfg && state.cfg.terms) || {};
        const rows = Object.keys(terms).sort();
        let html = '<input class="ls-glossary-search" id="lsGSearch" placeholder="Search terms…" />';
        html += '<div id="lsGList">' + rows.map(k => glossaryRow(k, terms[k])).join('') + '</div>';
        openPanel('Glossary · ' + rows.length + ' terms', html);
        const input = document.getElementById('lsGSearch');
        const list = document.getElementById('lsGList');
        input.addEventListener('input', () => {
          const q = input.value.trim().toLowerCase();
          list.innerHTML = rows.filter(k => {
            const e = terms[k]; const hay = (k + ' ' + (e.name||'') + ' ' + (e.kid||'') + ' ' + (e.adult||'') + ' ' + (e.phd||'')).toLowerCase();
            return q === '' || hay.includes(q);
          }).map(k => glossaryRow(k, terms[k])).join('');
        });
      });
      function glossaryRow(k, e) {
        return `<div class="ls-glossary-entry">
          <span class="ls-glossary-sym">${escapeHTML(e.name || k)}</span>
          <span style="color:var(--muted);font-size:11px;">${escapeHTML(k === (e.name||k) ? '' : '(' + k + ')')}</span>
          <div class="ls-glossary-tier"><b>Kid:</b> ${escapeHTML(e.kid || '—')}</div>
          <div class="ls-glossary-tier"><b>Adult:</b> ${escapeHTML(e.adult || '—')}</div>
          <div class="ls-glossary-tier"><b>PhD:</b> ${escapeHTML(e.phd || '—')}</div>
        </div>`;
      }

      if (dockA) dockA.addEventListener('click', () => {
        const an = (state.cfg && state.cfg.analogies) || [];
        const html = an.map(a => `
          <div class="ls-analogy">
            <h6><span class="ls-analogy-persona">${escapeHTML(a.persona || '')}</span>${escapeHTML(a.title || '')}</h6>
            <div class="ls-analogy-scenario">${a.scenario || ''}</div>
            ${a.map ? `<div class="ls-analogy-map"><b style="color:var(--brass-2);font-size:11px;display:block;margin-bottom:2px;">Variable map</b><table>${Object.entries(a.map).map(([k,v])=>`<tr><td>${escapeHTML(k)}</td><td>${escapeHTML(v)}</td></tr>`).join('')}</table></div>` : ''}
            ${a.exercise ? `<div class="ls-analogy-ex"><b>Micro-exercise:</b> ${escapeHTML(a.exercise)}</div>` : ''}
          </div>`).join('');
        openPanel('Analogy library · ' + an.length + ' analogies', html || '<div>No analogies defined.</div>');
      });

      if (dockX) dockX.addEventListener('click', () => {
        const ex = (state.cfg && state.cfg.exercises) || [];
        const html = ex.map((e, i) => `
          <div class="ls-exercise" data-ex-index="${i}">
            <h6>${escapeHTML(e.title || 'Exercise ' + (i+1))}</h6>
            <div class="ls-ex-meta">${escapeHTML(e.time || '2–5 minutes')} · ${escapeHTML(e.materials || 'Household objects')}</div>
            <div class="ls-ex-sect"><b>What you need</b><ul>${(e.need||[]).map(x=>`<li>${escapeHTML(x)}</li>`).join('')}</ul></div>
            <div class="ls-ex-sect"><b>Do this</b><ol>${(e.steps||[]).map(x=>`<li>${escapeHTML(x)}</li>`).join('')}</ol></div>
            <div class="ls-ex-sect"><b>What you should see</b><div style="font-size:12px;color:var(--ink)">${escapeHTML(e.outcome || '')}</div></div>
            <div class="ls-ex-sect"><b>Back to the sim</b><div style="font-size:12px;color:var(--muted)">${escapeHTML(e.back || '')}</div></div>
            <button class="ls-ex-print" data-ex-print="${i}">Print this card (half-letter)</button>
          </div>`).join('');
        openPanel('Physical exercises · ' + ex.length + ' cards', html || '<div>No exercises defined.</div>');
        panelBody.addEventListener('click', e => {
          const b = e.target.closest('[data-ex-print]');
          if (!b) return;
          const i = parseInt(b.dataset.exPrint, 10);
          printExercise(ex[i]);
        });
      });
      function printExercise(e) {
        if (!e || !printRoot) return;
        printRoot.style.display = 'block';
        printRoot.innerHTML = `
          <h3 style="margin:0 0 4px; font-size:14pt;">${escapeHTML(e.title || 'Exercise')}</h3>
          <div style="font-size:10pt; margin-bottom:8px;">${escapeHTML(e.time || '')} · ${escapeHTML(e.materials || '')}</div>
          <div style="margin-bottom:8px;"><b>What you need</b><ul style="margin:2px 0 0 18px;">${(e.need||[]).map(x=>`<li>${escapeHTML(x)}</li>`).join('')}</ul></div>
          <div style="margin-bottom:8px;"><b>Do this</b><ol style="margin:2px 0 0 18px;">${(e.steps||[]).map(x=>`<li>${escapeHTML(x)}</li>`).join('')}</ol></div>
          <div style="margin-bottom:8px;"><b>What you should see</b><div>${escapeHTML(e.outcome || '')}</div></div>
          <div><b>Back to the sim</b><div>${escapeHTML(e.back || '')}</div></div>`;
        setTimeout(() => { window.print(); printRoot.style.display = 'none'; }, 50);
      }

      eqTabs.forEach(t => t.addEventListener('click', () => {
        state.eqTab = t.dataset.lsTab;
        renderEqPanel();
      }));
      function renderEqPanel() {
        eqTabs.forEach(t => t.setAttribute('aria-pressed', t.dataset.lsTab === state.eqTab ? 'true' : 'false'));
        const ep = (state.cfg && state.cfg.equationPanel) || {};
        const body = ep[state.eqTab];
        if (!eqBody) return;
        if (!body) { eqBody.innerHTML = '<div style="color:var(--muted)">(no content)</div>'; return; }
        if (typeof body === 'string') eqBody.innerHTML = body;
        else if (body.html) eqBody.innerHTML = body.html;
        else eqBody.textContent = JSON.stringify(body);
        wireTooltipTerms(eqBody);
      }

      function renderBeat() {
        if (!beatHost) return;
        const beats = (state.cfg && state.cfg.beats) || [];
        if (!beats.length) { beatHost.innerHTML = '<div style="color:var(--muted);font-size:13px;">No beats defined.</div>'; return; }
        state.beatIdx = Math.max(0, Math.min(beats.length - 1, state.beatIdx));
        const b = beats[state.beatIdx];
        const p = state.path;
        const text = (b.text && (b.text[p] || b.text.adult || b.text.real || b.text.kid || b.text.equation || b.text.derivation)) || b.hero || '';
        const heroLabel = b.hero || '';
        beatHost.innerHTML = `
          <div class="ls-beat">
            <div class="ls-beat-body">
              <span class="ls-beat-head">Beat <span class="ls-beat-idx">${state.beatIdx + 1} / ${beats.length}</span> · ${escapeHTML(heroLabel)}</span>
              <span>${text}</span>
            </div>
            <div class="ls-beat-ctrl">
              <button id="lsBeatPrev">◀</button>
              <button class="primary" id="lsBeatDo">${escapeHTML(b.action || 'Do this')}</button>
              <button id="lsBeatNext">▶</button>
            </div>
          </div>`;
        wireTooltipTerms(beatHost);
        document.getElementById('lsBeatPrev').addEventListener('click', () => { state.beatIdx--; renderBeat(); });
        document.getElementById('lsBeatNext').addEventListener('click', () => { state.beatIdx++; renderBeat(); });
        document.getElementById('lsBeatDo').addEventListener('click', () => {
          if (b.do) { try { b.do(); } catch(_) {} }
        });
      }
      LS.renderBeat = renderBeat;
      LS.setBeat = function(i) { state.beatIdx = i; renderBeat(); };

      const strip = document.querySelector('.stageStrip');
      if (strip) { strip.setAttribute('aria-live', 'polite'); strip.setAttribute('role', 'status'); }
    })();

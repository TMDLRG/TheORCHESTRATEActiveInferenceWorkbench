// Plan §12 Phase 7 — Phoenix LiveView bootstrap + composition canvas hook.
//
// Loaded as a classic <script> tag; `Phoenix.Socket` and
// `Phoenix.LiveView.LiveSocket` are expected to be on window via the
// previously-loaded phoenix / phoenix_live_view scripts.
(function () {
  const csrfToken = document
    .querySelector("meta[name='csrf-token']")
    .getAttribute("content");

  // -------- PodcastSegment: clamp playback to [data-start, data-end] --------
  const PodcastSegment = {
    mounted() {
      const el = this.el;
      const startS = parseFloat(el.dataset.start || "0");
      const endStr = (el.dataset.end || "").trim();
      const endS = endStr === "" ? Infinity : parseFloat(endStr);
      let seeded = false;

      const seedStart = () => {
        if (!seeded && isFinite(el.duration)) {
          try { el.currentTime = startS; } catch (_) {}
          seeded = true;
        }
      };
      el.addEventListener("loadedmetadata", seedStart);
      el.addEventListener("play", seedStart);
      el.addEventListener("timeupdate", () => {
        if (el.currentTime < startS - 0.2) {
          try { el.currentTime = startS; } catch (_) {}
        }
        if (isFinite(endS) && el.currentTime >= endS) {
          el.pause();
          try { el.currentTime = startS; } catch (_) {}
        }
      });
    },
  };

  // -------- Narrator: speak a text block via /speech/speak with full playback controls. --------
  // Single Play/Pause/Stop cluster with progress bar + voice picker, all
  // injected into the DOM next to the element marked `phx-hook="Narrator"`.
  //
  // Element attrs:
  //   phx-hook="Narrator"
  //   data-target="CSS selector for the text to narrate"
  //   data-default-voice="piper_jenny"   (optional)
  //
  // Layout rendered below the trigger button:
  //   [▶ Play]  [⏸ Pause]  [⏹ Stop]   voice: [select...]   [progress bar]  00:04 / 00:12
  const Narrator = {
    async mounted() {
      const btn = this.el;
      btn.dataset.labelIdle = btn.innerText || "🔊 Narrate";

      const wrapperId = `narr-wrap-${Math.random().toString(36).slice(2, 8)}`;
      const wrap = document.createElement("div");
      wrap.id = wrapperId;
      wrap.className = "narrator-controls";
      wrap.style.cssText =
        "display:none; gap:8px; align-items:center; margin-top:6px; flex-wrap:wrap;" +
        "font-family:ui-monospace,Menlo,monospace; font-size:12px; color:#9cb0d6;";
      btn.insertAdjacentElement("afterend", wrap);

      const mkBtn = (t, handler, dim = false) => {
        const b = document.createElement("button");
        b.type = "button";
        b.textContent = t;
        b.style.cssText =
          "padding:4px 10px; border-radius:5px; border:1px solid #263257; " +
          "background:" + (dim ? "transparent" : "#1d4ed8") + "; color:" +
          (dim ? "#9cb0d6" : "#fff") + "; cursor:pointer; font-family:inherit; font-size:11px;";
        b.addEventListener("click", handler);
        return b;
      };

      const playBtn = mkBtn("▶ Resume", () => audio && audio.play(), true);
      const pauseBtn = mkBtn("⏸ Pause", () => audio && audio.pause(), true);
      const stopBtn = mkBtn("⏹ Stop", () => stop(), true);

      const voiceSel = document.createElement("select");
      voiceSel.style.cssText =
        "background:#121a33; color:#e8ecf1; border:1px solid #263257;" +
        "border-radius:5px; padding:3px 6px; font-family:inherit; font-size:11px;";

      const progWrap = document.createElement("div");
      progWrap.style.cssText = "flex:1 1 120px; min-width:80px; height:6px; background:#121a33;" +
        "border:1px solid #263257; border-radius:4px; overflow:hidden;";
      const progBar = document.createElement("div");
      progBar.style.cssText = "height:100%; width:0%; background:#b3863a; transition:width 0.25s linear;";
      progWrap.appendChild(progBar);

      const timeEl = document.createElement("span");
      timeEl.style.cssText = "min-width:70px; text-align:right; font-variant-numeric:tabular-nums;";
      timeEl.textContent = "00:00 / 00:00";

      wrap.appendChild(playBtn);
      wrap.appendChild(pauseBtn);
      wrap.appendChild(stopBtn);
      wrap.appendChild(voiceSel);
      wrap.appendChild(progWrap);
      wrap.appendChild(timeEl);

      let audio = null;
      let objUrl = null;
      let rafId = null;

      const fmt = (s) => {
        if (!isFinite(s)) return "--:--";
        const m = Math.floor(s / 60), r = Math.floor(s % 60);
        return `${String(m).padStart(2, "0")}:${String(r).padStart(2, "0")}`;
      };

      const tick = () => {
        if (!audio) return;
        const dur = audio.duration || 0;
        const cur = audio.currentTime || 0;
        progBar.style.width = dur > 0 ? `${Math.min(100, (cur / dur) * 100)}%` : "0%";
        timeEl.textContent = `${fmt(cur)} / ${fmt(dur)}`;
        rafId = requestAnimationFrame(tick);
      };

      const stop = () => {
        if (audio) { audio.pause(); audio.currentTime = 0; audio = null; }
        window.speechSynthesis?.cancel();
        if (objUrl) { URL.revokeObjectURL(objUrl); objUrl = null; }
        if (rafId) cancelAnimationFrame(rafId);
        wrap.style.display = "none";
        btn.innerText = btn.dataset.labelIdle;
      };

      // Load voice list for dropdown.
      try {
        const vr = await fetch("/speech/voices");
        if (vr.ok) {
          const voices = await vr.json();
          const wanted = btn.dataset.defaultVoice || "piper_jenny";
          for (const v of voices) {
            const opt = document.createElement("option");
            opt.value = v.short_name;
            opt.textContent = `${v.name || v.short_name}  [${v.engine || 'piper'}]`;
            if (v.short_name === wanted) opt.selected = true;
            voiceSel.appendChild(opt);
          }
        }
      } catch (_) { /* voices optional */ }

      const speak = async () => {
        const targetSel = btn.dataset.target;
        const target = targetSel ? document.querySelector(targetSel) : document.body;
        if (!target) return;
        const text = target.innerText.trim();
        if (!text) return;

        stop();
        wrap.style.display = "flex";
        btn.innerText = "⏳ Synthesising…";

        try {
          const res = await fetch("/speech/speak", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ text: text.slice(0, 5000), voice: voiceSel.value }),
          });
          if (!res.ok) throw new Error(`upstream ${res.status}`);
          const blob = await res.blob();
          objUrl = URL.createObjectURL(blob);
          audio = new Audio(objUrl);
          audio.addEventListener("play", () => { btn.innerText = "🔊 Narrating…"; rafId = requestAnimationFrame(tick); });
          audio.addEventListener("pause", () => { btn.innerText = "⏸ Paused"; });
          audio.addEventListener("ended", () => { stop(); });
          audio.addEventListener("error", () => { stop(); });
          await audio.play();
        } catch (err) {
          // Browser-TTS fallback.
          try {
            const u = new SpeechSynthesisUtterance(text.slice(0, 5000));
            u.rate = 1.0;
            u.onend = () => stop();
            btn.innerText = "🔊 Narrating (browser TTS)…";
            window.speechSynthesis.speak(u);
          } catch (_) {
            stop();
            alert("Narration unavailable. Start the voice service, or enable browser TTS.");
          }
        }
      };

      btn.addEventListener("click", () => { audio ? stop() : speak(); });
    },
  };

  // -------- ProgressTracker: mark-complete events → cookie --------
  // Listens for {chapter, session, done} and merges into the suite_progress
  // cookie (URL-safe base64 JSON).
  function readProgressCookie() {
    const m = document.cookie.match(/(?:^|;\s*)suite_progress=([^;]+)/);
    if (!m) return {};
    try { return JSON.parse(decodeURIComponent(m[1])); } catch (_) { return {}; }
  }
  function writeProgressCookie(p) {
    const v = encodeURIComponent(JSON.stringify(p));
    document.cookie = `suite_progress=${v}; path=/; max-age=${60 * 60 * 24 * 365}; samesite=lax`;
  }
  window.addEventListener("phx:progress_mark", function (e) {
    if (!e?.detail) return;
    const { chapter, session, done } = e.detail;
    const p = readProgressCookie();
    p[chapter] = p[chapter] || {};
    p[chapter][session] = { done: !!done, at: new Date().toISOString() };
    writeProgressCookie(p);
  });

  // -------- navigate_external: follow an external URL from LV --------
  window.addEventListener("phx:navigate_external", function (e) {
    if (e?.detail?.url) window.location.href = e.detail.url;
  });

  // Persona chip live-update when the hub path picker fires.
  window.addEventListener("phx:suite_chip_update", function (e) {
    const chip = document.getElementById("persona-chip-nav");
    if (chip && e?.detail?.label) chip.textContent = e.detail.label;
  });

  // Progress clear from /learn/progress.
  window.addEventListener("phx:progress_clear", function () {
    document.cookie = "suite_progress=; path=/; max-age=0; samesite=lax";
  });

  // Narrate a whole chapter via the /speech/narrate/chapter/:num endpoint.
  // Plays audio in an <audio> element appended to the page; fallback to
  // browser TTS if the speech wrapper is offline.
  let chapterNarrationAudio = null;
  window.addEventListener("phx:narrate_chapter", async function (e) {
    const num = e?.detail?.num;
    if (num === undefined || num === null) return;
    if (chapterNarrationAudio) {
      chapterNarrationAudio.pause();
      chapterNarrationAudio = null;
    }
    try {
      const res = await fetch(`/speech/narrate/chapter/${num}`);
      if (!res.ok) throw new Error("non-200");
      const blob = await res.blob();
      chapterNarrationAudio = new Audio(URL.createObjectURL(blob));
      chapterNarrationAudio.play();
    } catch (err) {
      // Fallback: fetch chapter text and use browser TTS.
      try {
        const txtRes = await fetch(`/book/chapters/ch${String(num).padStart(2, "0")}.txt`);
        const txt = txtRes.ok ? await txtRes.text() : "";
        const u = new SpeechSynthesisUtterance(txt.slice(0, 4000) || "Chapter text unavailable.");
        window.speechSynthesis.speak(u);
      } catch (_) {
        alert("Narration unavailable. Start ClaudeSpeak, or enable browser TTS.");
      }
    }
  });

  // -------- UberHelp open: echo event for the drawer in root layout --------
  window.addEventListener("phx:uber_open", function (e) {
    const drawer = document.getElementById("uber-help-drawer");
    if (!drawer) return;
    drawer.classList.add("on");
    if (e?.detail) {
      if (e.detail.seed) drawer.dataset.seed = e.detail.seed;
      if (e.detail.session) drawer.dataset.session = e.detail.session;
    }
    const input = drawer.querySelector("input,textarea");
    if (input) setTimeout(() => input.focus(), 50);
  });

  // -------- UberHelp drawer wiring (open/close/submit, calls /api/uber-help) --------
  function initUberHelp() {
    const fab = document.getElementById("uber-help-fab");
    const drawer = document.getElementById("uber-help-drawer");
    if (!fab || !drawer) return;
    const closeBtn = document.getElementById("uber-help-close");
    const form = document.getElementById("uber-help-form");
    const input = document.getElementById("uber-help-input");
    const log = document.getElementById("uber-help-log");
    const chips = drawer.querySelectorAll(".chips button");

    const openDrawer = () => {
      drawer.classList.add("on");
      drawer.setAttribute("aria-hidden", "false");
      setTimeout(() => input && input.focus(), 50);
    };
    const closeDrawer = () => {
      drawer.classList.remove("on");
      drawer.setAttribute("aria-hidden", "true");
    };

    fab.addEventListener("click", openDrawer);
    closeBtn.addEventListener("click", closeDrawer);
    document.addEventListener("keydown", (e) => { if (e.key === "Escape") closeDrawer(); });

    const appendMsg = (role, text) => {
      const el = document.createElement("div");
      el.className = "msg " + role;
      el.textContent = text;
      log.appendChild(el);
      log.scrollTop = log.scrollHeight;
      return el;
    };

    const sendMessage = async (text) => {
      appendMsg("user", text);
      const pendingEl = appendMsg("assistant", "⏳ …");
      const pathMatch = document.cookie.match(/(?:^|;\s*)suite_path=([^;]+)/);
      const path = pathMatch ? decodeURIComponent(pathMatch[1]) : "real";
      // Best-effort session inference from the current URL.
      const m = location.pathname.match(/^\/learn\/session\/(\d+)\/([^/]+)/);
      const chapter = m ? parseInt(m[1], 10) : null;
      const session = m ? m[2] : null;
      const seed = drawer.dataset.seed || "";
      try {
        const res = await fetch("/api/uber-help", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ user_msg: text, path, chapter, session, seed }),
        });
        const j = await res.json();
        if (res.ok && j.reply) {
          pendingEl.textContent = j.reply;
        } else {
          pendingEl.className = "msg error";
          pendingEl.textContent = j.hint || j.error || "Qwen error";
        }
      } catch (err) {
        pendingEl.className = "msg error";
        pendingEl.textContent = "Network error. Is Qwen running? ./Qwen3.6/scripts/start_qwen.ps1";
      }
    };

    form.addEventListener("submit", (e) => {
      e.preventDefault();
      const text = (input.value || "").trim();
      if (!text) return;
      input.value = "";
      sendMessage(text);
    });
    chips.forEach((b) => {
      b.addEventListener("click", () => sendMessage(b.dataset.chip || b.textContent));
    });
  }
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initUberHelp);
  } else {
    initUberHelp();
  }

  const hooks = {
    CompositionCanvas: window.CompositionCanvas,
    PodcastSegment: PodcastSegment,
    Narrator: Narrator,
  };

  const { Socket } = window.Phoenix;
  const { LiveSocket } = window.LiveView;

  const liveSocket = new LiveSocket("/live", Socket, {
    params: { _csrf_token: csrfToken },
    hooks: hooks,
  });

  liveSocket.connect();
  window.liveSocket = liveSocket;
})();

// Voice auto-play shim for LibreChat (Phase J of LIBRECHAT_EXTENSIONS_PLAN.md).
//
// LibreChat renders MCP tool-call results as JSON code blocks in the chat.
// Phase B queues synthesis: the first tool result has a `job_id` (and
// `audio_url` is null until `speak_status` reports done).  This script polls
// `GET /voice/status/:id` on the voice HTTP port until the WAV is ready, and
// also picks up literal `audio_url` strings when they appear.  Playback uses a
// small <audio> dock with stop/pause/progress.
//
// Two install paths:
//   1. Bookmarklet  — visit /learn/voice-autoplay in Phoenix, drag the
//      "Voice autoplay" link into your bookmarks bar, then click it once
//      per LibreChat tab.
//   2. TamperMonkey — install the userscript header below at @match
//      http://localhost:3080/* — auto-runs on every tab.
//
// ==UserScript==
// @name        Workshop Voice Autoplay
// @match       http://localhost:3080/*
// @run-at      document-idle
// @grant       none
// ==/UserScript==

(function () {
  if (window.__workshopVoiceAutoplay) return;
  window.__workshopVoiceAutoplay = true;

  const PROGRESS_ID = "workshop-voice-progress";
  /** URLs that have finished playing successfully (or permanently failed). */
  const seen = new Set();
  /** job_ids we are already polling for completion. */
  const pendingJobPoll = new Set();
  let player = null;
  let playerLabel = null;
  let playerBar = null;
  let playerTime = null;
  let rafId = null;

  const fmt = (s) => {
    if (!isFinite(s)) return "--:--";
    const m = Math.floor(s / 60), r = Math.floor(s % 60);
    return `${String(m).padStart(2, "0")}:${String(r).padStart(2, "0")}`;
  };

  function ensurePanel() {
    if (player) return;
    const wrap = document.createElement("div");
    wrap.id = PROGRESS_ID;
    wrap.style.cssText =
      "position:fixed; right:12px; bottom:12px; z-index:99999;" +
      "background:rgba(11,16,32,0.95); color:#e8ecf1; border:1px solid #b3863a;" +
      "border-radius:8px; padding:10px 14px; font-family:ui-monospace,Menlo,monospace;" +
      "font-size:12px; min-width:240px; box-shadow:0 4px 18px rgba(0,0,0,0.5);";
    wrap.innerHTML = `
      <div style="display:flex; justify-content:space-between; gap:8px; align-items:center;">
        <strong style="color:#b3863a;">🎙 voice autoplay</strong>
        <button id="wva-close" style="background:transparent;border:0;color:#9cb0d6;cursor:pointer;font-size:14px;">×</button>
      </div>
      <div id="wva-label" style="margin-top:4px; color:#9cb0d6; font-size:11px;">idle</div>
      <div style="margin-top:6px; height:6px; background:#121a33; border-radius:3px; overflow:hidden;">
        <div id="wva-bar" style="height:100%; width:0%; background:#b3863a; transition:width 0.25s linear;"></div>
      </div>
      <div style="display:flex; justify-content:space-between; margin-top:4px;">
        <div>
          <button id="wva-pause" style="background:transparent;border:1px solid #263257;color:#9cb0d6;border-radius:4px;padding:2px 6px;cursor:pointer;font-size:11px;">⏸</button>
          <button id="wva-stop"  style="background:transparent;border:1px solid #263257;color:#9cb0d6;border-radius:4px;padding:2px 6px;cursor:pointer;font-size:11px;">⏹</button>
        </div>
        <span id="wva-time" style="font-variant-numeric:tabular-nums;">00:00 / 00:00</span>
      </div>
    `;
    document.body.appendChild(wrap);
    playerLabel = wrap.querySelector("#wva-label");
    playerBar = wrap.querySelector("#wva-bar");
    playerTime = wrap.querySelector("#wva-time");
    wrap.querySelector("#wva-close").onclick = () => { stop(); wrap.remove(); player = null; };
    wrap.querySelector("#wva-pause").onclick = () => {
      if (!player) return;
      player.paused ? player.play() : player.pause();
    };
    wrap.querySelector("#wva-stop").onclick = stop;
    player = new Audio();
    player.addEventListener("play", () => playerLabel.textContent = "playing…");
    player.addEventListener("pause", () => playerLabel.textContent = "paused");
    player.addEventListener("ended", () => { playerLabel.textContent = "done"; cancelAnimationFrame(rafId); playerBar.style.width = "100%"; });
    player.addEventListener("error", () => playerLabel.textContent = "error");
    const tick = () => {
      if (!player) return;
      const dur = player.duration || 0;
      const cur = player.currentTime || 0;
      playerBar.style.width = dur > 0 ? `${Math.min(100, (cur / dur) * 100)}%` : "0%";
      playerTime.textContent = `${fmt(cur)} / ${fmt(dur)}`;
      rafId = requestAnimationFrame(tick);
    };
    player.addEventListener("play", () => { rafId = requestAnimationFrame(tick); });
  }

  function stop() {
    if (player) { player.pause(); player.currentTime = 0; }
    if (rafId) cancelAnimationFrame(rafId);
    if (playerLabel) playerLabel.textContent = "stopped";
    if (playerBar) playerBar.style.width = "0%";
    if (playerTime) playerTime.textContent = "00:00 / 00:00";
  }

  function voiceHttpBase() {
    // LibreChat is usually :3080; voice HTTP is :7712 on the same host.
    const { protocol, hostname } = window.location;
    return `${protocol}//${hostname}:7712`;
  }

  /**
   * Poll the voice HTTP API until the job is done, then play once.
   * Phase B returns 425 from /voice/play/... until synthesis finishes; the old
   * shim marked URLs as "seen" before verifying playback and never retried.
   */
  function pollJobUntilPlay(jobId) {
    if (pendingJobPoll.has(jobId) || seen.has(`job:${jobId}`)) return;
    pendingJobPoll.add(jobId);
    const base = voiceHttpBase();
    let attempts = 0;
    const maxAttempts = 720; // ~6 min @ 500ms (XTTS on CPU)

    const tick = async () => {
      attempts++;
      if (attempts > maxAttempts) {
        pendingJobPoll.delete(jobId);
        seen.add(`job:${jobId}`);
        return;
      }
      try {
        const st = await fetch(`${base}/voice/status/${jobId}`, {
          cache: "no-store",
        });
        if (!st.ok) {
          setTimeout(tick, 500);
          return;
        }
        const j = await st.json();
        if (j.status === "done" && j.audio_url) {
          pendingJobPoll.delete(jobId);
          seen.add(`job:${jobId}`);
          const browserUrl = String(j.audio_url).replace(
            "host.docker.internal",
            "localhost"
          );
          playOnceWhenReady(browserUrl, `job ${jobId}`);
          return;
        }
        if (j.status === "error" || j.status === "stopped") {
          pendingJobPoll.delete(jobId);
          seen.add(`job:${jobId}`);
          return;
        }
      } catch (_) {
        /* network glitch — keep polling */
      }
      setTimeout(tick, 500);
    };
    tick();
  }

  function playOnceWhenReady(url, label, retries) {
    if (retries === undefined) retries = 0;
    if (seen.has(url)) return;
    ensurePanel();
    if (!player) return;
    const maxRetries = 15;

    player.src = url;
    if (playerLabel) playerLabel.textContent = label || url;

    const onErr = () => {
      player.removeEventListener("error", onErr);
      player.removeEventListener("canplaythrough", onOk);
      if (retries >= maxRetries) {
        seen.add(url);
        return;
      }
      setTimeout(
        () => playOnceWhenReady(url, label, retries + 1),
        750
      );
    };
    const onOk = () => {
      player.removeEventListener("error", onErr);
      player.removeEventListener("canplaythrough", onOk);
      seen.add(url);
      const m = url.match(/\/voice\/play\/([0-9a-f]+)\.wav/);
      if (m) seen.add(`job:${m[1]}`);
      player.play().catch(() => {});
    };
    player.addEventListener("error", onErr, { once: true });
    player.addEventListener("canplaythrough", onOk, { once: true });
    player.load();
  }

  // Scan the page for playback URLs and for job_ids (Phase B speak returns
  // job_id immediately; audio_url is filled in speak_status when done).
  function scan() {
    const text = document.body.innerText || "";

    const urlRe =
      /(https?:\/\/[^\s"'<>]*\/voice\/play\/([0-9a-f]{8,})\.wav)/g;
    let m;
    while ((m = urlRe.exec(text)) !== null) {
      const url = m[1];
      if (seen.has(url)) continue;
      const browserUrl = url.replace("host.docker.internal", "localhost");
      playOnceWhenReady(browserUrl, `auto-play job ${m[2]}`);
    }

    const jobRe = /"job_id"\s*:\s*"([0-9a-f]{12})"/g;
    while ((m = jobRe.exec(text)) !== null) {
      pollJobUntilPlay(m[1]);
    }

    collapseToolResponses();
  }

  // Tool-call JSON blocks in LibreChat render as verbose <pre><code> blocks
  // that dominate the chat viewport.  For every block that looks like a
  // speak~voice result (has job_id or audio_url), hide it behind a tiny
  // flyout chip ("🎙 voice result") the learner can toggle.
  //
  // IMPORTANT: this function must never detach or replace nodes React's
  // reconciler owns — doing so triggers "removeChild on Node" crashes when
  // React re-renders and the fiber tree thinks the node is still attached.
  // We only toggle inline CSS + insert a sibling chip BEFORE the block.
  const collapsed = new WeakSet();
  function collapseToolResponses() {
    const candidates = document.querySelectorAll("pre, code, .hljs, [class*='language-json']");
    candidates.forEach((el) => {
      if (collapsed.has(el)) return;
      const text = (el.innerText || "").trim();
      if (!text) return;
      const jobMatch = text.match(/"job_id"\s*:\s*"([0-9a-f]{12})"/);
      const urlMatch = text.match(/\/voice\/(?:play|status)\//);
      if (!jobMatch && !urlMatch) return;
      collapsed.add(el);
      const jid = jobMatch ? jobMatch[1] : "?";
      const host = el.closest("pre") || el;
      if (host.dataset.wvaFlyout) return;
      host.dataset.wvaFlyout = "1";

      // Preserve prior display so the toggle can restore it.
      host.dataset.wvaPrevDisplay = host.style.display || "";
      host.style.display = "none";

      const chip = document.createElement("button");
      chip.type = "button";
      chip.className = "wva-flyout-chip";
      chip.style.cssText =
        "display:inline-block; margin:4px 0; padding:2px 10px;" +
        "background:rgba(179,134,58,0.18); color:#b3863a;" +
        "border:1px solid #b3863a; border-radius:999px;" +
        "font:inherit; font-family:ui-monospace,Menlo,monospace;" +
        "font-size:11px; cursor:pointer;";
      let open = false;
      const render = () => {
        chip.textContent = `🎙 voice tool result (job ${jid.slice(0, 6)}…) ${open ? "▾" : "▸"}`;
      };
      chip.addEventListener("click", (ev) => {
        ev.preventDefault();
        ev.stopPropagation();
        open = !open;
        host.style.display = open ? (host.dataset.wvaPrevDisplay || "") : "none";
        render();
      });
      render();
      // Insert the chip as a sibling BEFORE the pre — parent stays intact so
      // React's reconciler is never surprised by a moved child.
      try {
        host.parentNode && host.parentNode.insertBefore(chip, host);
      } catch (_) {
        /* if the parent changed between detection and insertion, just skip */
      }
    });
  }

  const obs = new MutationObserver(() => { try { scan(); } catch (_) {} });
  obs.observe(document.body, { subtree: true, childList: true, characterData: true });
  scan();
})();

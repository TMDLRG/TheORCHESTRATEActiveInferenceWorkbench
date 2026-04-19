"""Local HTTP UI for browsing and replaying spoken transcripts.

Runs in a background thread inside the MCP server process.  Uses only the
Python standard library (``http.server``) to avoid adding dependencies.

Replay is deliberately handled in the browser via an HTML5 ``<audio>``
element: the MCP server streams the WAV bytes and the browser plays them on
its own audio pipeline.  This means replays NEVER touch the sounddevice
output stream used for live MCP speech, so the two can coexist without
colliding.
"""

from __future__ import annotations

import json
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Optional
from urllib.parse import unquote

from .logging_setup import get_logger
from .transcript_store import TranscriptStore

logger = get_logger("ui_server")


INDEX_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>ClaudeSpeak - Transcript</title>
<style>
  :root {
    --bg: #0f1115;
    --panel: #1a1d24;
    --border: #2a2f3a;
    --text: #e6e9ef;
    --muted: #8a92a3;
    --accent: #7fc7ff;
    --accent-hover: #a4d7ff;
  }
  * { box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    margin: 0;
    padding: 0;
    background: var(--bg);
    color: var(--text);
    min-height: 100vh;
  }
  header {
    position: sticky;
    top: 0;
    background: var(--panel);
    border-bottom: 1px solid var(--border);
    padding: 16px 24px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    z-index: 10;
  }
  h1 {
    margin: 0;
    font-size: 18px;
    color: var(--accent);
    font-weight: 600;
  }
  .status {
    color: var(--muted);
    font-size: 13px;
  }
  main {
    max-width: 960px;
    margin: 0 auto;
    padding: 20px;
  }
  .controls {
    display: flex;
    gap: 12px;
    margin-bottom: 16px;
    align-items: center;
  }
  input[type="search"] {
    flex: 1;
    background: var(--panel);
    border: 1px solid var(--border);
    color: var(--text);
    padding: 8px 12px;
    border-radius: 6px;
    font-size: 14px;
    outline: none;
  }
  input[type="search"]:focus { border-color: var(--accent); }
  button {
    background: var(--panel);
    color: var(--text);
    border: 1px solid var(--border);
    padding: 8px 14px;
    border-radius: 6px;
    cursor: pointer;
    font-size: 13px;
  }
  button:hover { background: #242832; border-color: var(--accent); }
  .entry {
    background: var(--panel);
    border: 1px solid var(--border);
    border-left: 3px solid var(--accent);
    padding: 14px 18px;
    margin-bottom: 10px;
    border-radius: 6px;
  }
  .entry-head {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 8px;
  }
  .ts { color: var(--muted); font-size: 12px; font-variant-numeric: tabular-nums; }
  .id { color: var(--muted); font-size: 11px; }
  .text {
    margin: 6px 0 10px 0;
    font-size: 15px;
    line-height: 1.5;
    white-space: pre-wrap;
    word-wrap: break-word;
  }
  .meta {
    display: flex;
    gap: 14px;
    color: var(--muted);
    font-size: 11px;
    margin-bottom: 8px;
  }
  .player-row {
    display: flex;
    align-items: center;
    gap: 10px;
  }
  audio {
    flex: 1;
    height: 32px;
  }
  .empty {
    text-align: center;
    color: var(--muted);
    padding: 60px 20px;
  }
</style>
</head>
<body>
<header>
  <h1>&#x1F5E3; ClaudeSpeak &mdash; Spoken History</h1>
  <div class="status" id="status">Loading...</div>
</header>
<main>
  <div class="controls">
    <input type="search" id="search" placeholder="Filter transcripts..." />
    <button onclick="load()">Refresh</button>
    <label style="color:var(--muted);font-size:12px;display:flex;align-items:center;gap:6px;">
      <input type="checkbox" id="auto" checked />Auto
    </label>
  </div>
  <div id="list"></div>
</main>

<script>
// Keep a map of id -> DOM element so we can update the list incrementally
// without replacing existing .entry nodes.  Replacing nodes would destroy
// any currently playing <audio> element, cutting off playback mid-stream.
const rendered = new Map();
let filterText = "";

function escapeHtml(s) {
  return (s || '').replace(/[&<>]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));
}

function buildEntry(e) {
  const div = document.createElement('div');
  div.className = 'entry';
  div.dataset.id = e.id;
  const d = new Date(e.timestamp * 1000);
  const ts = d.toLocaleString();
  const dur = (e.duration_ms / 1000).toFixed(1) + 's';
  div.innerHTML = `
    <div class="entry-head">
      <span class="ts">${ts}</span>
      <span class="id">#${e.id}</span>
    </div>
    <div class="text">${escapeHtml(e.text)}</div>
    <div class="meta">
      <span>voice: ${escapeHtml(e.voice) || '-'}</span>
      <span>rate: ${escapeHtml(e.rate) || '-'}</span>
      <span>duration: ${dur}</span>
    </div>
    <div class="player-row">
      <audio controls preload="metadata" src="/api/transcripts/${e.id}/audio"></audio>
    </div>
  `;
  return div;
}

function applyFilter() {
  const q = filterText.toLowerCase();
  for (const [, node] of rendered) {
    const text = node.querySelector('.text').textContent.toLowerCase();
    node.style.display = q && !text.includes(q) ? 'none' : '';
  }
}

async function load() {
  try {
    const r = await fetch('/api/transcripts');
    if (!r.ok) throw new Error('HTTP ' + r.status);
    const data = await r.json();
    const entries = data.entries || [];
    document.getElementById('status').textContent = entries.length + ' entries';

    const list = document.getElementById('list');
    const empty = list.querySelector('.empty');
    if (empty) empty.remove();

    if (entries.length === 0 && rendered.size === 0) {
      list.innerHTML = '<div class="empty">No transcripts yet. Speak something from Claude.</div>';
      return;
    }

    // Entries come newest-first from the API.
    const seen = new Set();
    // Walk from oldest to newest so prepending yields the correct order.
    for (let i = entries.length - 1; i >= 0; i--) {
      const e = entries[i];
      seen.add(e.id);
      if (!rendered.has(e.id)) {
        const node = buildEntry(e);
        list.prepend(node);
        rendered.set(e.id, node);
      }
    }
    // Remove entries that have vanished from the backend (e.g. DB pruned).
    for (const [id, node] of rendered) {
      if (!seen.has(id)) {
        node.remove();
        rendered.delete(id);
      }
    }
    applyFilter();
  } catch (e) {
    document.getElementById('status').textContent = 'Error: ' + e.message;
  }
}

document.getElementById('search').addEventListener('input', e => {
  filterText = e.target.value;
  applyFilter();
});

setInterval(() => {
  if (document.getElementById('auto').checked) load();
}, 3000);

load();
</script>
</body>
</html>
"""


class TranscriptUIServer:
    """Background HTTP server exposing transcript list + audio replay."""

    def __init__(
        self,
        store: TranscriptStore,
        host: str = "127.0.0.1",
        port: int = 5858,
    ) -> None:
        self.store = store
        self.host = host
        self.port = port
        self._httpd: Optional[ThreadingHTTPServer] = None
        self._thread: Optional[threading.Thread] = None

    def start(self) -> None:
        store_ref = self.store
        _logger = logger

        class Handler(BaseHTTPRequestHandler):
            # Silence the default stderr access log
            def log_message(self, format, *args):  # noqa: A002
                return

            # --- routes ---
            def do_GET(self):
                try:
                    path = unquote(self.path.split("?", 1)[0])
                    if path in ("/", "/index.html"):
                        self._send_html(INDEX_HTML)
                    elif path == "/api/transcripts":
                        self._send_json(
                            {"entries": store_ref.list_entries(limit=500)}
                        )
                    elif path.startswith("/api/transcripts/") and path.endswith(
                        "/audio"
                    ):
                        self._serve_audio(path)
                    elif path == "/api/health":
                        self._send_json(
                            {"ok": True, "count": store_ref.count()}
                        )
                    else:
                        self.send_error(404, "Not Found")
                except Exception as e:  # pragma: no cover - defensive
                    _logger.warning(f"UI handler error: {e}")
                    try:
                        self.send_error(500, "Internal Error")
                    except Exception:
                        pass

            def _serve_audio(self, path: str) -> None:
                parts = path.split("/")
                # /api/transcripts/{id}/audio -> ['', 'api', 'transcripts', '{id}', 'audio']
                if len(parts) < 5:
                    self.send_error(404)
                    return
                try:
                    entry_id = int(parts[3])
                except ValueError:
                    self.send_error(404)
                    return

                audio_path = store_ref.get_audio_path(entry_id)
                if not audio_path:
                    self.send_error(404, "Audio not found")
                    return

                file_size = audio_path.stat().st_size

                # Parse Range header - Chrome's <audio> element requires a
                # proper 206 Partial Content response, otherwise playback
                # cuts out after a few seconds.
                range_header = self.headers.get("Range")
                start, end = 0, file_size - 1
                is_range = False

                if range_header and range_header.startswith("bytes="):
                    try:
                        spec = range_header[len("bytes=") :].split(",", 1)[0].strip()
                        s, _, e = spec.partition("-")
                        if s == "" and e:
                            # Suffix range: last N bytes
                            length = int(e)
                            start = max(0, file_size - length)
                            end = file_size - 1
                        else:
                            start = int(s)
                            end = int(e) if e else file_size - 1
                        if start > end or start >= file_size:
                            self.send_response(416)
                            self.send_header(
                                "Content-Range", f"bytes */{file_size}"
                            )
                            self.end_headers()
                            return
                        end = min(end, file_size - 1)
                        is_range = True
                    except ValueError:
                        # Malformed Range - fall back to full response
                        start, end, is_range = 0, file_size - 1, False

                length = end - start + 1

                if is_range:
                    self.send_response(206)
                    self.send_header("Content-Range", f"bytes {start}-{end}/{file_size}")
                else:
                    self.send_response(200)

                self.send_header("Content-Type", "audio/wav")
                self.send_header("Accept-Ranges", "bytes")
                self.send_header("Content-Length", str(length))
                self.send_header("Cache-Control", "no-store")
                self.end_headers()

                # Stream from disk so we don't hold large files in memory
                # and so large Range responses don't exhaust the socket buffer.
                try:
                    with audio_path.open("rb") as f:
                        if start:
                            f.seek(start)
                        remaining = length
                        chunk = 64 * 1024
                        while remaining > 0:
                            buf = f.read(min(chunk, remaining))
                            if not buf:
                                break
                            self.wfile.write(buf)
                            remaining -= len(buf)
                except (BrokenPipeError, ConnectionAbortedError, ConnectionResetError):
                    # Browser closed the connection (normal during seek) - ignore
                    pass

            def _send_html(self, body: str) -> None:
                data = body.encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(data)))
                self.send_header("Cache-Control", "no-store")
                self.end_headers()
                self.wfile.write(data)

            def _send_json(self, obj: dict) -> None:
                data = json.dumps(obj).encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self.send_header("Content-Length", str(len(data)))
                self.send_header("Cache-Control", "no-store")
                self.end_headers()
                self.wfile.write(data)

        try:
            self._httpd = ThreadingHTTPServer((self.host, self.port), Handler)
        except OSError as e:
            logger.warning(
                f"Transcript UI could not bind {self.host}:{self.port}: {e}"
            )
            self._httpd = None
            return

        self._thread = threading.Thread(
            target=self._httpd.serve_forever,
            name="transcript-ui",
            daemon=True,
        )
        self._thread.start()
        logger.info(f"Transcript UI serving on http://{self.host}:{self.port}")

    def stop(self) -> None:
        if self._httpd is not None:
            try:
                self._httpd.shutdown()
                self._httpd.server_close()
            except Exception as e:  # pragma: no cover - defensive
                logger.warning(f"UI server shutdown error: {e}")
            self._httpd = None
            self._thread = None

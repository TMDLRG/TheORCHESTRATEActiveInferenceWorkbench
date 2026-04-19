#!/usr/bin/env python3
"""
Thin HTTP wrapper around the Piper TTS engine shipped with
`claude-voice-connector-stdio`.  Exposes two endpoints:

    GET  /voices         -> JSON list of {short_name, name, gender, locale, description}
    POST /speak          -> audio/wav bytes

The companion STDIO MCP server plays audio through the host sounddevice;
that is the right path for LibreChat, Claude Code, and Qwen-as-agent.  For
a browser narrator we need raw audio bytes, which this server provides.

Usage:
    cd ClaudeSpeak/claude-voice-connector-http
    python server.py                  # binds 127.0.0.1:7712 by default
    PORT=7712 python server.py

Or via uvicorn if preferred:
    uvicorn server:app --host 127.0.0.1 --port 7712

Dependencies: fastapi, uvicorn, plus whatever the STDIO connector already
requires (piper-tts, onnxruntime, pyyaml, …).  The sibling venv at
`ClaudeSpeak/claude-voice-connector-stdio/.venv` is expected to contain
them; this script imports from the STDIO source tree directly.
"""
from __future__ import annotations

import asyncio
import io
import os
import sys
import struct
import wave
from pathlib import Path
from typing import Optional

HERE = Path(__file__).resolve().parent
STDIO_SRC = HERE.parent / "claude-voice-connector-stdio" / "src"
if str(STDIO_SRC) not in sys.path:
    sys.path.insert(0, str(STDIO_SRC))

from fastapi import FastAPI, HTTPException  # noqa: E402
from fastapi.middleware.cors import CORSMiddleware  # noqa: E402
from fastapi.responses import Response, JSONResponse  # noqa: E402
from pydantic import BaseModel, Field  # noqa: E402

from claude_voice_connector.config import ConnectorConfig  # noqa: E402
from claude_voice_connector.piper_tts import PiperTTS  # noqa: E402
from claude_voice_connector.piper_tts import VOICE_CATALOG as PIPER_CATALOG  # noqa: E402
from jobs import JOBS, audio_url, estimate_ms  # noqa: E402
from voice_catalog import VOICE_CATALOG, canonicalize  # noqa: E402

app = FastAPI(title="ClaudeSpeak HTTP", version="0.1.0")

# CORS permissive locally — the Phoenix reverse proxy at /speech/* means the
# browser request is same-origin, but in case someone hits the port directly.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=[
        "X-Duration-Ms",
        "X-Voice",
        "X-Engine",
        "X-Sample-Rate",
    ],
)

_tts: Optional[PiperTTS] = None


def tts() -> PiperTTS:
    global _tts
    if _tts is None:
        cfg = ConnectorConfig()
        _tts = PiperTTS(cfg)
    return _tts


class SpeakRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=16000)
    voice: Optional[str] = Field(None, description="Voice short_name (e.g. en_GB-jenny_dioco-medium)")
    rate: Optional[str] = Field(None, description="Rate like '+10%' / '-5%'")


def pcm16_to_wav_bytes(pcm: bytes, sample_rate: int) -> bytes:
    """Wrap raw int16 mono PCM in a minimal WAV container."""
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)  # int16
        w.setframerate(sample_rate)
        w.writeframes(pcm)
    return buf.getvalue()


@app.get("/assets/voice-autoplay.js")
async def autoplay_shim():
    """Serve the browser-side autoplay shim.

    Mounted into LibreChat via the mounted index.html override — every page
    load injects a `<script src="http://<host>:7712/assets/voice-autoplay.js">`
    so `speak~voice` tool calls auto-play without the learner having to
    install a bookmarklet or userscript."""
    import pathlib
    candidates = [
        pathlib.Path("/app/claude-voice-connector-http/voice-autoplay.js"),
        pathlib.Path(__file__).resolve().parent / "voice-autoplay.js",
    ]
    for p in candidates:
        if p.exists():
            return Response(
                content=p.read_bytes(),
                media_type="application/javascript; charset=utf-8",
                headers={
                    "Cache-Control": "no-store",
                    "Access-Control-Allow-Origin": "*",
                },
            )
    raise HTTPException(status_code=404, detail="voice-autoplay.js not in image")


@app.get("/voices")
async def list_voices():
    return JSONResponse(
        [
            {"short_name": k, **{kk: vv for kk, vv in v.items() if kk != "piper_voice"}}
            for k, v in VOICE_CATALOG.items()
        ]
    )


@app.get("/healthz")
async def healthz():
    return {"ok": True, "voices": list(VOICE_CATALOG.keys())}


@app.get("/voice/play/{job_id}.wav")
async def voice_play(job_id: str):
    """Stream a completed job's rendered WAV back to the caller.

    The MCP `speak` tool returns an `audio_url` pointing here; the learner's
    browser (Phoenix Narrator or a LibreChat client-side autoplay shim) fetches
    the bytes from this endpoint and plays them.  Returns 404 if the job isn't
    known, 425 (Too Early) if it's still queued/synthesizing."""
    job = JOBS.status(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="unknown job_id")
    if job.status == "error":
        raise HTTPException(status_code=500, detail=job.error or "synthesis failed")
    if job.status != "done":
        raise HTTPException(status_code=425, detail=f"job not done: {job.status}")
    return Response(
        content=job.wav,
        media_type="audio/wav",
        headers={
            "Cache-Control": "no-store",
            "X-Duration-Ms": str(job.duration_ms),
            "X-Voice": job.voice,
            "X-Sample-Rate": str(job.sample_rate),
        },
    )


@app.get("/voice/status/{job_id}")
async def voice_status(job_id: str):
    job = JOBS.status(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="unknown job_id")
    return JSONResponse(
        {
            "job_id": job.id,
            "status": job.status,
            "duration_ms": job.duration_ms,
            "voice": job.voice,
            "audio_url": audio_url(job.id),
            "error": job.error,
        }
    )


@app.get("/voice/queue")
async def voice_queue():
    return JSONResponse({"jobs": JOBS.list_queue()})


@app.post("/voice/submit")
async def voice_submit(req: SpeakRequest):
    """Enqueue a job via HTTP (parity with the MCP `speak` tool).

    Phoenix + the client-side audio autoplay shim can POST here directly
    when they don't want to drive MCP.  Returns the same payload shape the
    MCP tool returns, including the host-reachable `audio_url`."""
    voice = canonicalize(req.voice or "piper_jenny")
    try:
        submission = JOBS.submit(req.text, voice, req.rate)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    if submission is None:
        raise HTTPException(status_code=429, detail="queue_full")
    job, queued_behind = submission
    return JSONResponse(
        {
            "job_id": job.id,
            "status": "queued" if queued_behind > 0 else "synthesizing",
            "queued_behind": queued_behind,
            "estimated_ms": estimate_ms(req.text, job.engine),
            # URL is valid even before synthesis completes — the playback
            # endpoint returns HTTP 425 until `done`, which the shim
            # interprets as "retry".
            "audio_url": audio_url(job.id),
            "voice": voice,
        }
    )


@app.post("/speak")
async def speak(req: SpeakRequest):
    """Synchronous `speak` — kept for Phoenix Narrator's blob playback path.

    For Piper voices this renders inline (2-3s typical) and streams the WAV
    back to the browser.  XTTS voices go through the job queue and this
    endpoint polls until done — the browser can show its own spinner.
    """
    requested = req.voice or "piper_jenny"
    voice = canonicalize(requested)
    if voice not in VOICE_CATALOG:
        raise HTTPException(status_code=400, detail=f"unknown voice: {requested}")
    entry = VOICE_CATALOG[voice]

    if entry["engine"] == "piper":
        piper_voice = entry["piper_voice"]
        # PIPER_CATALOG only lists the 3 voices that ship with the stdio
        # package; the Dockerfile downloads more (ryan, lessac).  We rely on
        # PiperVoice.load() to FileNotFoundError if the .onnx is missing.
        try:
            result = await tts().synthesize_all(req.text, voice=piper_voice, rate=req.rate)
        except Exception as exc:  # noqa: BLE001
            raise HTTPException(status_code=500, detail=f"synth failed: {exc}") from exc
        pcm = result if not isinstance(result, tuple) else result[0]
        sr = tts().get_sample_rate(piper_voice)
        duration_ms = int(1000 * (len(pcm) / 2) / max(sr, 1)) if pcm else 0
        wav = pcm16_to_wav_bytes(pcm, sr)
        return Response(
            content=wav,
            media_type="audio/wav",
            headers={
                "Cache-Control": "no-store",
                "X-Duration-Ms": str(duration_ms),
                "X-Voice": voice,
                "X-Engine": "piper",
                "X-Sample-Rate": str(sr),
            },
        )

    # XTTS path — submit through the queue, wait for completion, stream WAV.
    try:
        submission = JOBS.submit(req.text, voice, req.rate)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    if submission is None:
        raise HTTPException(status_code=429, detail="queue_full")
    job, _ = submission
    # Poll for completion (XTTS on CPU can take 20-40s per sentence).
    import asyncio as _asyncio
    for _ in range(300):
        s = JOBS.status(job.id)
        if s is None:
            raise HTTPException(status_code=500, detail="job vanished")
        if s.status == "error":
            raise HTTPException(status_code=500, detail=s.error or "xtts error")
        if s.status == "done":
            return Response(
                content=s.wav,
                media_type="audio/wav",
                headers={
                    "Cache-Control": "no-store",
                    "X-Duration-Ms": str(s.duration_ms),
                    "X-Voice": voice,
                    "X-Engine": "xtts",
                    "X-Sample-Rate": str(s.sample_rate),
                },
            )
        await _asyncio.sleep(0.5)
    raise HTTPException(status_code=504, detail="xtts synth timed out")


def main():
    import uvicorn

    port = int(os.environ.get("CLAUDE_SPEAK_PORT", "7712"))
    host = os.environ.get("CLAUDE_SPEAK_HOST", "127.0.0.1")
    uvicorn.run(app, host=host, port=port, log_level="info")


if __name__ == "__main__":
    main()

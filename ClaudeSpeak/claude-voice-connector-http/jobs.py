"""Shared job queue + dual-engine dispatch for the `voice` service.

Phase B of LIBRECHAT_EXTENSIONS_PLAN.md + the user's addendum (both Piper TTS
and Coqui XTTS supported, >=5 voices available).

Architecture:
- One in-memory queue, one worker per engine so Piper (fast) doesn't sit
  behind a 20s XTTS synthesis.
- Rate limit: MAX_INFLIGHT + MAX_QUEUED across the whole service.
- `audio_url()` (used in speak_status and HTTP once status is `done`) points at
  `http://host.docker.internal:7712/voice/play/{id}.wav` for LibreChat on Docker Desktop;
  browsers rewrite to localhost in the autoplay shim.
- Jobs retain WAV for 5 min then GC.
"""
from __future__ import annotations

import asyncio
import io
import time
import uuid
import wave
from dataclasses import dataclass, field
from typing import Literal, Optional

from voice_catalog import VOICE_CATALOG, canonicalize

JobStatus = Literal["queued", "synthesizing", "done", "error", "stopped"]

JOB_TTL_SECONDS = 300
MAX_INFLIGHT = 2  # one piper + one xtts can run concurrently
MAX_QUEUED = 8


@dataclass
class Job:
    id: str
    text: str
    voice: str
    rate: Optional[str]
    engine: Literal["piper", "xtts"] = "piper"
    status: JobStatus = "queued"
    wav: bytes = b""
    duration_ms: int = 0
    sample_rate: int = 0
    queued_at: float = field(default_factory=time.time)
    started_at: Optional[float] = None
    finished_at: Optional[float] = None
    error: Optional[str] = None


def _pcm_to_wav(pcm: bytes, sample_rate: int) -> bytes:
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sample_rate)
        w.writeframes(pcm)
    return buf.getvalue()


def _float_to_pcm16(samples) -> bytes:
    import numpy as np
    arr = np.asarray(samples, dtype=np.float32)
    if arr.ndim > 1:
        arr = arr.reshape(-1)
    clipped = (arr * 32767.0).clip(-32768, 32767).astype(np.int16)
    return clipped.tobytes()


class JobStore:
    def __init__(self) -> None:
        self._jobs: dict[str, Job] = {}
        self._queues: dict[str, asyncio.Queue[str]] = {
            "piper": asyncio.Queue(),
            "xtts": asyncio.Queue(),
        }
        self._workers: dict[str, Optional[asyncio.Task]] = {"piper": None, "xtts": None}
        self._gc: Optional[asyncio.Task] = None
        self._piper = None
        self._xtts = None

    # ---- lazy engine loaders ----

    def _piper_lazy(self):
        if self._piper is None:
            from claude_voice_connector.config import ConnectorConfig
            from claude_voice_connector.piper_tts import PiperTTS
            self._piper = PiperTTS(ConnectorConfig())
        return self._piper

    def _xtts_lazy(self):
        if self._xtts is None:
            # Heavy import — only load when an XTTS job actually runs.
            from TTS.api import TTS
            self._xtts = TTS(
                model_name="tts_models/multilingual/multi-dataset/xtts_v2",
                progress_bar=False,
                gpu=False,
            )
        return self._xtts

    def _ensure_background(self) -> None:
        loop = asyncio.get_event_loop()
        for engine in ("piper", "xtts"):
            w = self._workers[engine]
            if w is None or w.done():
                self._workers[engine] = loop.create_task(self._worker_loop(engine))
        if self._gc is None or self._gc.done():
            self._gc = loop.create_task(self._gc_loop())

    # ---- worker loops ----

    async def _worker_loop(self, engine: str) -> None:
        q = self._queues[engine]
        while True:
            try:
                job_id = await q.get()
            except asyncio.CancelledError:
                return
            job = self._jobs.get(job_id)
            if job is None or job.status == "stopped":
                continue
            job.status = "synthesizing"
            job.started_at = time.time()
            try:
                if job.engine == "piper":
                    wav, sr, dur_ms = await asyncio.to_thread(self._run_piper, job)
                else:
                    wav, sr, dur_ms = await asyncio.to_thread(self._run_xtts, job)
                job.wav = wav
                job.sample_rate = sr
                job.duration_ms = dur_ms
                job.status = "done"
            except Exception as exc:  # noqa: BLE001
                job.status = "error"
                job.error = f"{exc!s}"
            finally:
                job.finished_at = time.time()

    def _run_piper(self, job: Job) -> tuple[bytes, int, int]:
        entry = VOICE_CATALOG[job.voice]
        tts = self._piper_lazy()
        piper_voice = entry["piper_voice"]
        result = asyncio.run(tts.synthesize_all(job.text, voice=piper_voice, rate=job.rate))
        pcm = result if not isinstance(result, tuple) else result[0]
        sr = tts.get_sample_rate(piper_voice)
        dur_ms = int(1000 * (len(pcm) / 2) / max(sr, 1)) if pcm else 0
        return _pcm_to_wav(pcm, sr), sr, dur_ms

    def _run_xtts(self, job: Job) -> tuple[bytes, int, int]:
        entry = VOICE_CATALOG[job.voice]
        tts = self._xtts_lazy()
        samples = tts.tts(
            text=job.text,
            speaker=entry.get("xtts_speaker", "Claribel Dervla"),
            language=entry.get("xtts_language", "en"),
        )
        sr = tts.synthesizer.output_sample_rate
        pcm = _float_to_pcm16(samples)
        dur_ms = int(1000 * (len(pcm) / 2) / max(sr, 1)) if pcm else 0
        return _pcm_to_wav(pcm, sr), sr, dur_ms

    async def _gc_loop(self) -> None:
        while True:
            try:
                await asyncio.sleep(60)
            except asyncio.CancelledError:
                return
            cutoff = time.time() - JOB_TTL_SECONDS
            stale = [jid for jid, j in self._jobs.items() if j.finished_at and j.finished_at < cutoff]
            for jid in stale:
                self._jobs.pop(jid, None)

    # ---- public API ----

    def queue_depth(self) -> tuple[int, int]:
        queued = sum(1 for j in self._jobs.values() if j.status == "queued")
        inflight = sum(1 for j in self._jobs.values() if j.status == "synthesizing")
        return queued, inflight

    def submit(self, text: str, voice: str, rate: Optional[str]) -> Optional[tuple[Job, int]]:
        key = canonicalize(voice)
        if key not in VOICE_CATALOG:
            raise ValueError(f"unknown voice: {voice}")
        queued, inflight = self.queue_depth()
        if queued + inflight >= MAX_INFLIGHT + MAX_QUEUED:
            return None
        self._ensure_background()
        engine = VOICE_CATALOG[key]["engine"]
        job = Job(
            id=uuid.uuid4().hex[:12],
            text=text,
            voice=key,
            rate=rate,
            engine=engine,
        )
        self._jobs[job.id] = job
        self._queues[engine].put_nowait(job.id)
        return job, queued

    def status(self, job_id: str) -> Optional[Job]:
        return self._jobs.get(job_id)

    def stop(self, job_id: Optional[str]) -> list[str]:
        stopped = []
        for jid, job in list(self._jobs.items()):
            if job_id is None or jid == job_id:
                if job.status in ("queued", "synthesizing"):
                    job.status = "stopped"
                    if job.finished_at is None:
                        job.finished_at = time.time()
                    stopped.append(jid)
        return stopped

    def list_queue(self) -> list[dict]:
        piper_pos = 0
        xtts_pos = 0
        out: list[dict] = []
        for jid, job in self._jobs.items():
            pos: Optional[int] = None
            if job.status == "queued":
                if job.engine == "piper":
                    piper_pos += 1
                    pos = piper_pos
                else:
                    xtts_pos += 1
                    pos = xtts_pos
            out.append(
                {
                    "job_id": jid,
                    "engine": job.engine,
                    "voice": job.voice,
                    "position": pos,
                    "status": job.status,
                    "text_head": job.text[:80],
                }
            )
        return out


JOBS = JobStore()


def estimate_ms(text: str, engine: str = "piper") -> int:
    """Rough synthesis-duration estimate.

    Piper is near real-time; XTTS on CPU is much slower."""
    base_ms = max(500, len(text) * 50)
    return base_ms * 4 if engine == "xtts" else base_ms


def audio_url(job_id: str) -> str:
    """Return the browser-reachable playback URL.

    Inside Docker `host.docker.internal:7712` resolves; from the learner's
    browser it does not — Chrome cannot look it up and the autoplay shim
    must rewrite it.  To avoid that rewrite and make the URL work in every
    context (browser, mobile, curl), default to `localhost:7712` and let an
    operator override via `VOICE_PUBLIC_BASE_URL` (e.g. a reverse-proxied
    HTTPS hostname).  Container-to-container traffic (LibreChat → voice)
    never uses this field — it goes through MCP SSE directly."""
    import os
    base = os.environ.get("VOICE_PUBLIC_BASE_URL", "http://localhost:7712").rstrip("/")
    return f"{base}/voice/play/{job_id}.wav"

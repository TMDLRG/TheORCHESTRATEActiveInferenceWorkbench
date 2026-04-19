#!/usr/bin/env python3
"""Workshop `voice` MCP server — Piper TTS over MCP SSE transport at /sse.

Phase B: job-based `speak` API.  Every tool call returns within <100 ms.
The agent receives a `job_id` immediately; synthesis runs on a background
worker.  The agent can poll `speak_status`, stop a job via `stop_speaking`,
or inspect the backlog with `list_queue`.  The emitted `audio_url` points
at the host-mapped HTTP endpoint served by `server.py`
(`GET /voice/play/{job_id}.wav`).

Register in `librechat.yaml`:

    mcpServers:
      voice:
        type: sse
        url: http://voice:7711/sse
        timeout: 30000

Start (inside the Docker image, alongside server.py):

    python run.py
"""
from __future__ import annotations

import asyncio  # noqa: F401  (kept for callers that import from here)
import json
import os
import sys
import time
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
STDIO_SRC = HERE.parent / "claude-voice-connector-stdio" / "src"
if STDIO_SRC.exists() and str(STDIO_SRC) not in sys.path:
    sys.path.insert(0, str(STDIO_SRC))

from voice_catalog import VOICE_CATALOG, canonicalize  # noqa: E402

from mcp.server import Server  # type: ignore  # noqa: E402
from mcp.server.sse import SseServerTransport  # type: ignore  # noqa: E402
import mcp.types as types  # type: ignore  # noqa: E402
import uvicorn  # noqa: E402

from jobs import JOBS, MAX_INFLIGHT, MAX_QUEUED, audio_url, estimate_ms  # noqa: E402

SERVER_NAME = "voice"
SERVER_VERSION = "1.1.0"

server = Server(SERVER_NAME)


def _json(obj: Any) -> types.TextContent:
    return types.TextContent(type="text", text=json.dumps(obj))


# ------- Tool listing -------

@server.list_tools()
async def list_tools() -> list[types.Tool]:
    return [
        types.Tool(
            name="speak",
            description=(
                "Queue text for TTS synthesis.  Returns a job_id within <100 ms "
                "(audio_url is null until synthesis finishes — use speak_status to poll). "
                "The LibreChat autoplay shim polls by job_id in the browser without blocking the model. "
                "Use stop_speaking to cancel; list_queue to inspect backlog."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "text": {"type": "string", "description": "Text to synthesize."},
                    "voice": {
                        "type": "string",
                        "description": (
                            "Voice short_name.  Piper (fast): piper_jenny (default), piper_amy, "
                            "piper_alba, piper_ryan, piper_lessac.  XTTS (high quality, slower): "
                            "xtts_female_warm, xtts_male_calm."
                        ),
                        "default": "piper_jenny",
                    },
                    "rate": {
                        "type": "string",
                        "description": "Relative rate like '+10%' / '-5%' (optional).",
                    },
                },
                "required": ["text"],
            },
        ),
        types.Tool(
            name="speak_status",
            description=(
                "Poll the status of a prior speak() job.  Returns status "
                "(queued/synthesizing/done/error/stopped), elapsed_ms, "
                "remaining_ms, duration_ms, and audio_url once done."
            ),
            inputSchema={
                "type": "object",
                "properties": {"job_id": {"type": "string"}},
                "required": ["job_id"],
            },
        ),
        types.Tool(
            name="stop_speaking",
            description="Stop a specific job (by job_id) or every in-flight/queued job when omitted.",
            inputSchema={
                "type": "object",
                "properties": {
                    "job_id": {
                        "type": "string",
                        "description": "Optional job id.  Omit to stop every queued + in-flight job.",
                    }
                },
            },
        ),
        types.Tool(
            name="list_queue",
            description="Inspect the voice service queue: job_id, position, status, text_head for every known job.",
            inputSchema={"type": "object", "properties": {}},
        ),
        types.Tool(
            name="list_voices",
            description="List the voices available to the speak tool.",
            inputSchema={"type": "object", "properties": {}},
        ),
    ]


# ------- Tool invocation -------

@server.call_tool()
async def call_tool(name: str, arguments: dict[str, Any]) -> list[types.TextContent]:
    args = arguments or {}

    if name == "speak":
        text = args.get("text") or ""
        voice = args.get("voice") or "piper_jenny"
        rate = args.get("rate")
        if not text:
            return [_json({"error": "text required"})]
        try:
            submission = JOBS.submit(text, voice, rate)
        except ValueError as e:
            return [_json({"error": str(e), "known_voices": list(VOICE_CATALOG.keys())})]
        if submission is None:
            return [
                _json(
                    {
                        "error": "queue_full",
                        "max_inflight": MAX_INFLIGHT,
                        "max_queued": MAX_QUEUED,
                        "hint": "wait for speak_status or call stop_speaking",
                    }
                )
            ]
        job, queued_behind = submission
        # Do not emit audio_url until the WAV exists.  The HTTP endpoint returns
        # 425 while queued/synthesizing; browsers that fetch the URL immediately
        # (LibreChat autoplay shim) would error once and never retry.  Callers
        # poll speak_status for audio_url when status is "done".
        return [
            _json(
                {
                    "job_id": job.id,
                    "status": "queued" if queued_behind > 0 else "synthesizing",
                    "queued_behind": queued_behind,
                    "engine": job.engine,
                    "estimated_ms": estimate_ms(text, job.engine),
                    "audio_url": None,
                    "voice": canonicalize(voice),
                }
            )
        ]

    if name == "speak_status":
        jid = args.get("job_id") or ""
        job = JOBS.status(jid)
        if job is None:
            return [_json({"error": "unknown job_id", "job_id": jid})]
        now = time.time()
        anchor = job.started_at or job.queued_at
        elapsed_ms = int((now - anchor) * 1000) if anchor else 0
        remaining_ms = 0
        if job.status == "synthesizing":
            remaining_ms = max(0, estimate_ms(job.text) - elapsed_ms)
        return [
            _json(
                {
                    "job_id": jid,
                    "status": job.status,
                    "elapsed_ms": elapsed_ms,
                    "remaining_ms": remaining_ms,
                    "duration_ms": job.duration_ms,
                    "error": job.error,
                    "audio_url": audio_url(jid) if job.status == "done" else None,
                    "voice": job.voice,
                }
            )
        ]

    if name == "stop_speaking":
        jid = args.get("job_id")
        stopped = JOBS.stop(jid if jid else None)
        return [_json({"stopped": stopped, "count": len(stopped)})]

    if name == "list_queue":
        return [_json({"jobs": JOBS.list_queue()})]

    if name == "list_voices":
        return [
            _json(
                {
                    "voices": [
                        {"short_name": k, **{kk: vv for kk, vv in v.items() if kk != "piper_voice"}}
                        for k, v in VOICE_CATALOG.items()
                    ]
                }
            )
        ]

    return [_json({"error": f"unknown tool {name}"})]


# ------- SSE wiring -------

sse = SseServerTransport("/messages/")


async def mcp_sse_app(scope, receive, send):
    if scope["type"] == "lifespan":
        message = await receive()
        if message["type"] == "lifespan.startup":
            await send({"type": "lifespan.startup.complete"})
        while True:
            message = await receive()
            if message["type"] == "lifespan.shutdown":
                await send({"type": "lifespan.shutdown.complete"})
                return

    if scope["type"] != "http":
        return

    path = scope.get("path", "")
    if path == "/sse":
        async with sse.connect_sse(scope, receive, send) as streams:
            read_stream, write_stream = streams
            await server.run(read_stream, write_stream, server.create_initialization_options())
        return

    if path.startswith("/messages/"):
        await sse.handle_post_message(scope, receive, send)
        return

    body = b'{"error":"not found; expected /sse or /messages/"}'
    await send({"type": "http.response.start", "status": 404,
                "headers": [(b"content-type", b"application/json")]})
    await send({"type": "http.response.body", "body": body})


app = mcp_sse_app


def main() -> None:
    host = os.environ.get("SPEECH_MCP_HOST", "0.0.0.0")
    port = int(os.environ.get("SPEECH_MCP_PORT", "7711"))
    uvicorn.run(app, host=host, port=port, log_level="info")


if __name__ == "__main__":
    main()

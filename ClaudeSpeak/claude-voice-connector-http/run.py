#!/usr/bin/env python3
"""Container entrypoint — runs the FastAPI /speech HTTP server (7712) and the
MCP SSE server (7711) in the same asyncio event loop.  Host speakers are
unreachable from inside the container, so the HTTP server streams WAV bytes
to the browser (Phoenix Narrator) and the MCP server returns playback
metadata + (Phase B) audio_urls that the agent can surface to the client."""
from __future__ import annotations

import asyncio
import os

import uvicorn

from server import app as http_app
from mcp_sse_server import mcp_sse_app


def _cfg(app, port_env: str, default_port: int) -> uvicorn.Config:
    return uvicorn.Config(
        app,
        host="0.0.0.0",
        port=int(os.environ.get(port_env, str(default_port))),
        log_level=os.environ.get("VOICE_LOG_LEVEL", "info"),
        access_log=False,
    )


async def main() -> None:
    servers = [
        uvicorn.Server(_cfg(http_app, "CLAUDE_SPEAK_PORT", 7712)),
        uvicorn.Server(_cfg(mcp_sse_app, "SPEECH_MCP_PORT", 7711)),
    ]
    await asyncio.gather(*(s.serve() for s in servers))


if __name__ == "__main__":
    asyncio.run(main())

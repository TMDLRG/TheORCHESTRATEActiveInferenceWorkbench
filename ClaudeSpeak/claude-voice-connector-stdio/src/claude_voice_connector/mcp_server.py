"""MCP Server for Claude Voice Connector.

Exposes Piper TTS as tools for Claude Desktop.
Clean, simple implementation focused on reliability.
"""

from __future__ import annotations

import asyncio
import json
import sys
from typing import Any

from .logging_setup import setup_logging, get_logger
from .transcript_store import TranscriptStore
from .ui_server import TranscriptUIServer
from .voice_orchestrator import VoiceOrchestrator

logger = get_logger("mcp_server")

# Invisible / BOM / zero-width characters that Piper may mispronounce
# if they leak into the start of a speak request. Stripped defensively.
_INVISIBLE_CHARS = (
    "\ufeff"  # BOM / zero-width no-break space
    "\u200b"  # zero-width space
    "\u200c"  # zero-width non-joiner
    "\u200d"  # zero-width joiner
    "\u2060"  # word joiner
    "\u00a0"  # non-breaking space (handled by strip, but listed for clarity)
)


def _sanitize_text(text: str) -> str:
    """Strip BOM and zero-width characters that Piper may mispronounce.

    These characters can leak in via clients that prepend a UTF-8 BOM or
    zero-width separators, and Piper renders them as odd phonetic artefacts
    (the classic "euro circumflex" mojibake at the start of speech).
    """
    if not text:
        return text
    # Remove invisible chars anywhere in the string, not just leading
    for ch in _INVISIBLE_CHARS:
        if ch in text:
            text = text.replace(ch, "")
    return text.strip()


class MCPServer:
    """MCP Server for voice synthesis."""

    def __init__(self) -> None:
        self.orchestrator: VoiceOrchestrator | None = None
        self.transcript_store: TranscriptStore | None = None
        self.ui_server: TranscriptUIServer | None = None
        self._ready = False

    async def _ensure_ready(self) -> None:
        """Initialize orchestrator if needed."""
        if not self._ready:
            self.orchestrator = await VoiceOrchestrator.create()

            # Best-effort transcript store + UI server.  If either fails
            # we log and continue - live TTS must always work even if the
            # history/replay UI can't start (e.g. port in use).
            try:
                self.transcript_store = TranscriptStore()
                self.orchestrator.transcript_store = self.transcript_store
            except Exception as e:
                logger.warning(f"TranscriptStore disabled: {e}")
                self.transcript_store = None

            if self.transcript_store is not None:
                try:
                    self.ui_server = TranscriptUIServer(self.transcript_store)
                    self.ui_server.start()
                except Exception as e:
                    logger.warning(f"Transcript UI disabled: {e}")
                    self.ui_server = None

            self._ready = True
            logger.info("MCP Server ready")

    async def handle(self, request: dict[str, Any]) -> dict[str, Any] | None:
        """Handle an MCP JSON-RPC request.

        Args:
            request: JSON-RPC request dict

        Returns:
            Response dict, or None for notifications
        """
        method = request.get("method", "")
        req_id = request.get("id")  # None = notification
        params = request.get("params", {})

        # Notifications (no id) - don't respond
        if req_id is None:
            logger.debug(f"Notification: {method}")
            return None

        try:
            result = await self._dispatch(method, params)
            return {"jsonrpc": "2.0", "id": req_id, "result": result}

        except Exception as e:
            logger.exception(f"Error handling {method}: {e}")
            return {
                "jsonrpc": "2.0",
                "id": req_id,
                "error": {"code": -32603, "message": str(e)},
            }

    async def _dispatch(self, method: str, params: dict) -> dict:
        """Dispatch method to handler."""

        if method == "initialize":
            await self._ensure_ready()
            return {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "claude-voice-connector", "version": "1.0.0"},
            }

        elif method == "ping":
            return {}

        elif method == "tools/list":
            return {"tools": self._get_tools()}

        elif method == "tools/call":
            return await self._call_tool(params)

        elif method == "resources/list":
            return {"resources": []}

        else:
            raise ValueError(f"Unknown method: {method}")

    def _get_tools(self) -> list[dict]:
        """Return tool definitions."""
        return [
            {
                "name": "speak",
                "description": "Speak text aloud using Piper TTS (local neural TTS). Default voice: en_GB-jenny_dioco-medium",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "text": {
                            "type": "string",
                            "description": "Text to speak",
                        },
                        "voice": {
                            "type": "string",
                            "description": "Voice: en_GB-jenny_dioco-medium (default), en_US-amy-medium, en_GB-alba-medium",
                            "default": "en_GB-jenny_dioco-medium",
                        },
                        "rate": {
                            "type": "string",
                            "description": "Speech rate: -10% slower, +10% faster, default -5%",
                            "default": "-5%",
                        },
                    },
                    "required": ["text"],
                },
            },
            {
                "name": "stop_speaking",
                "description": "Stop current speech",
                "inputSchema": {"type": "object", "properties": {}},
            },
            {
                "name": "list_voices",
                "description": "List available voices",
                "inputSchema": {"type": "object", "properties": {}},
            },
        ]

    async def _call_tool(self, params: dict) -> dict:
        """Execute a tool call."""
        await self._ensure_ready()

        name = params.get("name")
        args = params.get("arguments", {})

        if name == "speak":
            result = await self._speak(args)
        elif name == "stop_speaking":
            result = await self._stop()
        elif name == "list_voices":
            result = await self._list_voices()
        else:
            raise ValueError(f"Unknown tool: {name}")

        return {"content": [{"type": "text", "text": json.dumps(result)}]}

    async def _speak(self, args: dict) -> dict:
        """Handle speak tool."""
        text = _sanitize_text(args.get("text", ""))
        voice = args.get("voice", "en_GB-jenny_dioco-medium")
        rate = args.get("rate", "-5%")

        if not text:
            return {"success": False, "error": "No text provided"}

        result = {"success": False, "played_ms": 0}

        async for event in self.orchestrator.speak(text, voice, rate):
            if event["type"] == "complete":
                result["success"] = True
                result["played_ms"] = event.get("played_ms", 0)
            elif event["type"] == "error":
                result["error"] = event.get("message", "Unknown error")

        return result

    async def _stop(self) -> dict:
        """Handle stop tool."""
        if self.orchestrator:
            await self.orchestrator.stop()
        return {"success": True}

    async def _list_voices(self) -> dict:
        """Handle list_voices tool."""
        voices = await self.orchestrator.voices()
        return {"voices": voices}

    async def run(self) -> None:
        """Run the MCP server on stdio."""
        logger.info("MCP Server starting")

        reader = asyncio.StreamReader()

        if sys.platform == "win32":
            import threading
            loop = asyncio.get_running_loop()

            def read_stdin():
                # Read BINARY from stdin.buffer to avoid Windows codepage
                # (cp1252) corrupting UTF-8 JSON-RPC payloads.  The previous
                # text-mode read + re-encode caused mojibake of smart quotes
                # and em-dashes, which Piper then read aloud as the
                # "euro circumflex" artefact at the start of speech.
                try:
                    stdin_buf = sys.stdin.buffer
                    while True:
                        line = stdin_buf.readline()
                        if not line:
                            loop.call_soon_threadsafe(reader.feed_eof)
                            break
                        loop.call_soon_threadsafe(reader.feed_data, line)
                except Exception as e:
                    logger.error(f"Stdin error: {e}")
                    loop.call_soon_threadsafe(reader.feed_eof)

            threading.Thread(target=read_stdin, daemon=True).start()
        else:
            loop = asyncio.get_running_loop()
            protocol = asyncio.StreamReaderProtocol(reader)
            await loop.connect_read_pipe(lambda: protocol, sys.stdin)

        # Main loop
        while True:
            try:
                line = await reader.readline()
                if not line:
                    break

                text = line.decode().strip()
                if not text:
                    continue

                request = json.loads(text)
                response = await self.handle(request)

                if response is not None:
                    sys.stdout.write(json.dumps(response) + "\n")
                    sys.stdout.flush()

            except json.JSONDecodeError as e:
                logger.error(f"Invalid JSON: {e}")
            except Exception as e:
                logger.exception(f"Loop error: {e}")

        logger.info("MCP Server shutdown")
        if self.ui_server:
            self.ui_server.stop()
        if self.orchestrator:
            await self.orchestrator.shutdown()


async def main() -> None:
    """Entry point."""
    setup_logging("INFO")
    server = MCPServer()
    await server.run()


def main_sync() -> None:
    """Sync entry point."""
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(line_buffering=True)
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main_sync()

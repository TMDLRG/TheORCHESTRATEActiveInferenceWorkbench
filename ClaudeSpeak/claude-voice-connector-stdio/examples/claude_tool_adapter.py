#!/usr/bin/env python3
"""Claude Tool Adapter for Voice Connector.

This module provides a Claude tool that launches the voice connector as a child
process and exchanges NDJSON messages over STDIO to synthesize and play speech.

Usage:
    1. Import the adapter and create an instance
    2. Use as a Claude tool definition
    3. The tool accepts SSML and returns playback status

Example:
    adapter = VoiceConnectorAdapter()
    result = await adapter.speak("Hello, world!")
"""

from __future__ import annotations

import asyncio
import json
import os
import subprocess
import sys
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any, AsyncIterator, Optional


@dataclass
class SpeakResult:
    """Result from a speak operation."""

    request_id: str
    success: bool
    played_ms: int = 0
    segments: int = 0
    error: Optional[str] = None

    def to_dict(self) -> dict[str, Any]:
        result = {
            "request_id": self.request_id,
            "success": self.success,
            "played_ms": self.played_ms,
            "segments": self.segments,
        }
        if self.error:
            result["error"] = self.error
        return result


class VoiceConnectorAdapter:
    """Adapter for using Voice Connector as a Claude tool."""

    def __init__(
        self,
        connector_path: Optional[Path] = None,
        config_path: Optional[Path] = None,
        voice: str = "en-US-AriaNeural",
        timeout: float = 120.0,
    ) -> None:
        """Initialize the adapter.

        Args:
            connector_path: Path to connector directory
            config_path: Path to config.yaml
            voice: Default voice
            timeout: Timeout for operations in seconds
        """
        self.connector_path = connector_path or Path(__file__).parent.parent
        self.config_path = config_path
        self.default_voice = voice
        self.timeout = timeout

        self._process: Optional[asyncio.subprocess.Process] = None
        self._lock = asyncio.Lock()

    async def _ensure_process(self) -> asyncio.subprocess.Process:
        """Ensure the connector process is running.

        Returns:
            Running subprocess
        """
        if self._process is not None and self._process.returncode is None:
            return self._process

        # Build command
        python_exe = sys.executable
        cmd = [
            python_exe,
            "-u",
            "-m",
            "claude_voice_connector.stdio_main",
        ]

        if self.config_path:
            cmd.extend(["--config", str(self.config_path)])

        # Set up environment
        env = os.environ.copy()
        src_path = str(self.connector_path / "src")
        if "PYTHONPATH" in env:
            env["PYTHONPATH"] = src_path + os.pathsep + env["PYTHONPATH"]
        else:
            env["PYTHONPATH"] = src_path

        # Start process
        self._process = await asyncio.create_subprocess_exec(
            *cmd,
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            cwd=str(self.connector_path),
            env=env,
        )

        # Wait briefly for startup
        await asyncio.sleep(0.3)

        return self._process

    async def _send_message(self, msg: dict[str, Any]) -> None:
        """Send a message to the connector.

        Args:
            msg: Message to send
        """
        proc = await self._ensure_process()
        line = json.dumps(msg) + "\n"
        proc.stdin.write(line.encode("utf-8"))
        await proc.stdin.drain()

    async def _read_events(self, request_id: str) -> AsyncIterator[dict[str, Any]]:
        """Read events for a request.

        Args:
            request_id: Request ID to match

        Yields:
            Event dictionaries
        """
        proc = await self._ensure_process()

        while True:
            try:
                line = await asyncio.wait_for(
                    proc.stdout.readline(),
                    timeout=self.timeout,
                )
            except asyncio.TimeoutError:
                yield {"type": "error", "code": "TIMEOUT", "message": "Response timeout"}
                break

            if not line:
                yield {"type": "error", "code": "EOF", "message": "Connector closed"}
                break

            line_str = line.decode("utf-8").strip()
            if not line_str:
                continue

            try:
                event = json.loads(line_str)
            except json.JSONDecodeError:
                continue

            # Check if this event is for our request
            event_id = event.get("id")
            if event_id and event_id != request_id:
                continue

            yield event

            # Stop on terminal events
            if event.get("type") in ("complete", "error"):
                if not event.get("retryable", False):
                    break

    async def speak(
        self,
        text: str,
        voice: Optional[str] = None,
        rate: Optional[str] = None,
        pitch: Optional[str] = None,
        ssml: bool = False,
        stream: bool = True,
    ) -> SpeakResult:
        """Synthesize and play speech.

        Args:
            text: Text or SSML to speak
            voice: Voice to use
            rate: Speech rate
            pitch: Pitch adjustment
            ssml: If True, text is treated as SSML
            stream: Use streaming mode

        Returns:
            SpeakResult with playback information
        """
        async with self._lock:
            request_id = str(uuid.uuid4())

            # Build SSML if needed
            if not ssml:
                # Escape text for SSML
                import html

                escaped = html.escape(text)
                text = f'<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US">{escaped}</speak>'

            # Build request
            msg = {
                "type": "speak",
                "id": request_id,
                "ssml": text,
                "voice": voice or self.default_voice,
                "stream": stream,
            }
            if rate:
                msg["rate"] = rate
            if pitch:
                msg["pitch"] = pitch

            # Send request
            await self._send_message(msg)

            # Collect result
            result = SpeakResult(request_id=request_id, success=False)

            async for event in self._read_events(request_id):
                event_type = event.get("type")

                if event_type == "ack":
                    pass  # Acknowledged

                elif event_type == "progress":
                    pass  # Still playing

                elif event_type == "complete":
                    result.success = True
                    result.played_ms = event.get("played_ms", 0)
                    result.segments = len(event.get("segments", []))

                elif event_type == "error":
                    result.error = event.get("message", "Unknown error")

            return result

    async def stop(self) -> None:
        """Stop current playback."""
        async with self._lock:
            await self._send_message({"type": "stop"})
            # Read stopped confirmation
            proc = await self._ensure_process()
            try:
                line = await asyncio.wait_for(proc.stdout.readline(), timeout=1.0)
            except asyncio.TimeoutError:
                pass

    async def get_status(self) -> dict[str, Any]:
        """Get connector status.

        Returns:
            Status dictionary
        """
        async with self._lock:
            await self._send_message({"type": "status"})
            proc = await self._ensure_process()

            try:
                line = await asyncio.wait_for(proc.stdout.readline(), timeout=1.0)
                if line:
                    return json.loads(line.decode("utf-8"))
            except (asyncio.TimeoutError, json.JSONDecodeError):
                pass

            return {"error": "No response"}

    async def list_voices(self) -> list[dict[str, Any]]:
        """List available voices.

        Returns:
            List of voice dictionaries
        """
        async with self._lock:
            await self._send_message({"type": "voices"})
            proc = await self._ensure_process()

            try:
                line = await asyncio.wait_for(proc.stdout.readline(), timeout=5.0)
                if line:
                    event = json.loads(line.decode("utf-8"))
                    return event.get("items", [])
            except (asyncio.TimeoutError, json.JSONDecodeError):
                pass

            return []

    async def close(self) -> None:
        """Close the connector process."""
        if self._process:
            self._process.stdin.close()
            await self._process.stdin.wait_closed()

            try:
                self._process.terminate()
                await asyncio.wait_for(self._process.wait(), timeout=2.0)
            except asyncio.TimeoutError:
                self._process.kill()

            self._process = None

    async def __aenter__(self) -> "VoiceConnectorAdapter":
        """Async context manager entry."""
        return self

    async def __aexit__(self, *args) -> None:
        """Async context manager exit."""
        await self.close()


# Claude tool definition
CLAUDE_TOOL_DEFINITION = {
    "name": "speak",
    "description": "Synthesize and play text as speech using Microsoft Edge TTS. Supports plain text or SSML markup for control over prosody, emphasis, and breaks.",
    "input_schema": {
        "type": "object",
        "properties": {
            "text": {
                "type": "string",
                "description": "The text to speak. Can be plain text or SSML markup.",
            },
            "voice": {
                "type": "string",
                "description": "Voice to use (e.g., 'en-US-AriaNeural', 'en-US-GuyNeural'). Defaults to en-US-AriaNeural.",
            },
            "rate": {
                "type": "string",
                "description": "Speech rate adjustment (e.g., '+20%', '-10%', 'fast', 'slow'). Defaults to normal rate.",
            },
            "pitch": {
                "type": "string",
                "description": "Pitch adjustment (e.g., '+5Hz', '-10Hz', 'high', 'low'). Defaults to normal pitch.",
            },
            "ssml": {
                "type": "boolean",
                "description": "If true, text is treated as SSML markup. Defaults to false.",
            },
        },
        "required": ["text"],
    },
}


async def handle_claude_tool_call(
    adapter: VoiceConnectorAdapter,
    tool_input: dict[str, Any],
) -> dict[str, Any]:
    """Handle a Claude tool call.

    Args:
        adapter: Voice connector adapter
        tool_input: Tool input from Claude

    Returns:
        Tool result dictionary
    """
    result = await adapter.speak(
        text=tool_input["text"],
        voice=tool_input.get("voice"),
        rate=tool_input.get("rate"),
        pitch=tool_input.get("pitch"),
        ssml=tool_input.get("ssml", False),
    )

    return result.to_dict()


# Example usage
async def main():
    """Example usage of the adapter."""
    print("Claude Voice Connector Tool Adapter Example")
    print("-" * 50)

    async with VoiceConnectorAdapter() as adapter:
        # Simple text
        print("\n1. Speaking simple text...")
        result = await adapter.speak("Hello! This is a test of the voice connector.")
        print(f"   Result: {result.to_dict()}")

        await asyncio.sleep(1)

        # With prosody
        print("\n2. Speaking with SSML prosody...")
        ssml = '''<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US">
            <prosody rate="fast">This is spoken quickly.</prosody>
            <break time="500ms"/>
            <prosody rate="slow">And this is spoken slowly.</prosody>
        </speak>'''
        result = await adapter.speak(ssml, ssml=True)
        print(f"   Result: {result.to_dict()}")

        # Get status
        print("\n3. Connector status:")
        status = await adapter.get_status()
        print(f"   {status}")

    print("\nDone!")


if __name__ == "__main__":
    asyncio.run(main())

#!/usr/bin/env python3
"""Demo client for Claude Voice Connector.

Spawns the connector process, sends SSML, prints events, and computes metrics.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import subprocess
import sys
import time
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional


@dataclass
class DemoMetrics:
    """Metrics collected during demo."""

    request_id: str = ""
    sent_at: float = 0.0
    ack_at: float = 0.0
    first_progress_at: float = 0.0
    complete_at: float = 0.0
    total_played_ms: int = 0
    progress_count: int = 0
    segment_count: int = 0
    underruns: int = 0
    overruns: int = 0
    errors: list[str] = field(default_factory=list)

    @property
    def time_to_ack_ms(self) -> float:
        if self.ack_at and self.sent_at:
            return (self.ack_at - self.sent_at) * 1000
        return 0.0

    @property
    def time_to_first_progress_ms(self) -> float:
        if self.first_progress_at and self.sent_at:
            return (self.first_progress_at - self.sent_at) * 1000
        return 0.0

    @property
    def total_duration_ms(self) -> float:
        if self.complete_at and self.sent_at:
            return (self.complete_at - self.sent_at) * 1000
        return 0.0


def find_connector_script() -> Path:
    """Find the connector start script."""
    base = Path(__file__).parent.parent

    if sys.platform == "win32":
        script = base / "start.ps1"
        if script.exists():
            return script
    else:
        script = base / "start.sh"
        if script.exists():
            return script

    # Fall back to direct Python execution
    return base / "src" / "claude_voice_connector" / "stdio_main.py"


def load_ssml(path: str) -> str:
    """Load SSML from file."""
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


async def run_demo(
    ssml: str,
    voice: Optional[str] = None,
    stream: bool = True,
    verbose: bool = False,
) -> DemoMetrics:
    """Run the demo.

    Args:
        ssml: SSML content to speak
        voice: Voice to use
        stream: Use streaming mode
        verbose: Print verbose output

    Returns:
        Collected metrics
    """
    metrics = DemoMetrics()

    # Build command
    base_dir = Path(__file__).parent.parent
    python_exe = sys.executable

    if sys.platform == "win32":
        cmd = [
            python_exe,
            "-u",
            "-m",
            "claude_voice_connector.stdio_main",
        ]
    else:
        cmd = [
            python_exe,
            "-u",
            "-m",
            "claude_voice_connector.stdio_main",
        ]

    # Add src to PYTHONPATH
    env = os.environ.copy()
    src_path = str(base_dir / "src")
    if "PYTHONPATH" in env:
        env["PYTHONPATH"] = src_path + os.pathsep + env["PYTHONPATH"]
    else:
        env["PYTHONPATH"] = src_path

    print(f"Starting connector: {' '.join(cmd)}")
    print(f"Working directory: {base_dir}")
    print()

    # Start process
    proc = await asyncio.create_subprocess_exec(
        *cmd,
        stdin=asyncio.subprocess.PIPE,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
        cwd=str(base_dir),
        env=env,
    )

    # Give it time to start
    await asyncio.sleep(0.5)

    # Build speak request
    request_id = str(uuid.uuid4())
    metrics.request_id = request_id

    speak_msg = {
        "type": "speak",
        "id": request_id,
        "ssml": ssml,
        "stream": stream,
    }
    if voice:
        speak_msg["voice"] = voice

    # Send request
    metrics.sent_at = time.monotonic()
    message = json.dumps(speak_msg) + "\n"
    proc.stdin.write(message.encode("utf-8"))
    await proc.stdin.drain()
    print(f"Sent speak request: {request_id[:8]}...")

    # Read responses
    complete = False
    while not complete:
        try:
            line = await asyncio.wait_for(
                proc.stdout.readline(),
                timeout=60.0,  # 60 second timeout
            )
        except asyncio.TimeoutError:
            print("Timeout waiting for response")
            break

        if not line:
            print("Connector closed stdout")
            break

        line_str = line.decode("utf-8").strip()
        if not line_str:
            continue

        try:
            event = json.loads(line_str)
        except json.JSONDecodeError:
            print(f"Invalid JSON: {line_str}")
            continue

        event_type = event.get("type")

        if event_type == "ack":
            metrics.ack_at = time.monotonic()
            print(f"ACK: mode={event.get('mode')}, accepted_at={event.get('accepted_at')}")

        elif event_type == "progress":
            if metrics.first_progress_at == 0:
                metrics.first_progress_at = time.monotonic()
            metrics.progress_count += 1
            if verbose:
                print(
                    f"PROGRESS: played={event.get('played_ms')}ms, "
                    f"buffered={event.get('buffered_ms')}ms"
                )

        elif event_type == "complete":
            metrics.complete_at = time.monotonic()
            metrics.total_played_ms = event.get("played_ms", 0)
            metrics.segment_count = len(event.get("segments", []))
            print(f"COMPLETE: played={metrics.total_played_ms}ms, segments={metrics.segment_count}")
            complete = True

        elif event_type == "error":
            metrics.errors.append(event.get("message", "Unknown error"))
            print(f"ERROR: {event.get('code')} - {event.get('message')}")
            if not event.get("retryable", False):
                complete = True

        elif event_type == "status":
            if verbose:
                print(f"STATUS: {event}")

    # Send status to get final metrics
    status_msg = json.dumps({"type": "status"}) + "\n"
    proc.stdin.write(status_msg.encode("utf-8"))
    await proc.stdin.drain()

    try:
        line = await asyncio.wait_for(proc.stdout.readline(), timeout=1.0)
        if line:
            status = json.loads(line.decode("utf-8"))
            metrics.underruns = status.get("underruns", 0)
            metrics.overruns = status.get("overruns", 0)
    except (asyncio.TimeoutError, json.JSONDecodeError):
        pass

    # Clean up
    proc.stdin.close()
    await proc.stdin.wait_closed()

    try:
        proc.terminate()
        await asyncio.wait_for(proc.wait(), timeout=2.0)
    except asyncio.TimeoutError:
        proc.kill()

    return metrics


def print_summary(metrics: DemoMetrics) -> None:
    """Print metrics summary."""
    print()
    print("=" * 60)
    print("DEMO SUMMARY")
    print("=" * 60)
    print(f"Request ID:          {metrics.request_id[:8]}...")
    print(f"Time to ACK:         {metrics.time_to_ack_ms:.1f} ms")
    print(f"Time to first audio: {metrics.time_to_first_progress_ms:.1f} ms")
    print(f"Total duration:      {metrics.total_duration_ms:.1f} ms")
    print(f"Audio played:        {metrics.total_played_ms} ms")
    print(f"Segments:            {metrics.segment_count}")
    print(f"Progress events:     {metrics.progress_count}")
    print(f"Underruns:           {metrics.underruns}")
    print(f"Overruns:            {metrics.overruns}")

    if metrics.errors:
        print(f"Errors:              {len(metrics.errors)}")
        for err in metrics.errors:
            print(f"  - {err}")

    print()

    # Check against targets
    print("Target Checks:")
    first_audio = metrics.time_to_first_progress_ms
    if first_audio > 0:
        status = "PASS" if first_audio <= 800 else "FAIL"
        print(f"  First audio <= 800ms: {status} ({first_audio:.1f}ms)")

    status = "PASS" if metrics.underruns == 0 else "FAIL"
    print(f"  Zero underruns:       {status} ({metrics.underruns})")

    print("=" * 60)


def main() -> None:
    """Main entry point."""
    parser = argparse.ArgumentParser(description="Demo client for Claude Voice Connector")
    parser.add_argument(
        "--ssml",
        default=str(Path(__file__).parent / "sample.ssml"),
        help="Path to SSML file",
    )
    parser.add_argument(
        "--voice",
        default=None,
        help="Voice to use (e.g., en-US-AriaNeural)",
    )
    parser.add_argument(
        "--no-stream",
        action="store_true",
        help="Use batch mode instead of streaming",
    )
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Verbose output",
    )
    parser.add_argument(
        "--text",
        help="Plain text to speak (instead of SSML file)",
    )

    args = parser.parse_args()

    # Load SSML
    if args.text:
        ssml = f'<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US">{args.text}</speak>'
    else:
        ssml_path = Path(args.ssml)
        if not ssml_path.exists():
            print(f"SSML file not found: {ssml_path}")
            sys.exit(1)
        ssml = load_ssml(str(ssml_path))

    print("Claude Voice Connector Demo")
    print("-" * 40)

    # Run demo
    metrics = asyncio.run(
        run_demo(
            ssml=ssml,
            voice=args.voice,
            stream=not args.no_stream,
            verbose=args.verbose,
        )
    )

    # Print summary
    print_summary(metrics)


if __name__ == "__main__":
    main()

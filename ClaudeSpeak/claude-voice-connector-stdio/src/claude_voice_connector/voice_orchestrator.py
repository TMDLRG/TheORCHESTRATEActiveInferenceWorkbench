"""Voice Orchestrator - Coordinates TTS and audio playback.

Simple, clean orchestration for Piper TTS synthesis and playback.
"""

from __future__ import annotations

import asyncio
import time
import uuid
from dataclasses import dataclass, field
from typing import Any, AsyncIterator, Optional

from .audio_player import AudioPlayer
from .config import ConnectorConfig, load_config
from .logging_setup import get_logger
from .piper_tts import PiperTTS, MODELS_DIR

logger = get_logger("orchestrator")


@dataclass
class PlaybackState:
    """Current playback state."""
    request_id: str
    started_at: float = field(default_factory=time.monotonic)
    total_played_ms: int = 0
    cancelled: bool = False


class VoiceOrchestrator:
    """Orchestrates TTS synthesis and audio playback.
    
    Provides a simple interface to convert text to speech
    and play it through the audio system.
    """

    def __init__(
        self,
        config: ConnectorConfig,
        tts: PiperTTS,
        player: AudioPlayer,
    ) -> None:
        self.config = config
        self.tts = tts
        self.player = player
        self._current: Optional[PlaybackState] = None
        self._lock = asyncio.Lock()

        # Optional transcript store - set externally by the MCP server.
        # When present, every successful speak() call is persisted with
        # its PCM audio so the transcript UI can replay it later.
        self.transcript_store = None  # type: ignore[var-annotated]

        logger.info("VoiceOrchestrator initialized")

    @classmethod
    async def create(cls, config_path: Optional[str] = None) -> "VoiceOrchestrator":
        """Create orchestrator from config.

        Args:
            config_path: Optional path to config.yaml

        Returns:
            Initialized VoiceOrchestrator
        """
        config = load_config(config_path)
        
        tts = PiperTTS(
            config=config,
            models_dir=MODELS_DIR,
            default_voice=config.voice,
        )
        
        player = AudioPlayer(config)
        
        logger.info(f"Created orchestrator with voice: {config.voice}")
        return cls(config, tts, player)

    async def speak(
        self,
        text: str,
        voice: Optional[str] = None,
        rate: Optional[str] = None,
    ) -> AsyncIterator[dict[str, Any]]:
        """Synthesize and play text.

        Args:
            text: Text to speak
            voice: Voice to use (default from config)
            rate: Speech rate (e.g., "-5%", "+10%")

        Yields:
            Event dicts with progress and completion info
        """
        request_id = str(uuid.uuid4())[:8]
        voice = voice or self.config.voice
        rate = rate or "-5%"

        logger.info(f"[{request_id}] Speaking: {text[:50]}...")

        async with self._lock:
            # Cancel any current playback
            if self._current and not self._current.cancelled:
                self._current.cancelled = True
                self.player.stop()

            self._current = PlaybackState(request_id=request_id)

        try:
            # Start audio stream
            self.player.start()

            # Accumulate raw PCM so we can persist the utterance to the
            # transcript store after playback completes.
            captured_pcm = bytearray()

            # Synthesize and stream to player
            async for chunk in self.tts.synthesize(text, voice, rate):
                if self._current.cancelled:
                    break

                if chunk.data:
                    await self.player.write(chunk.data)
                    captured_pcm.extend(chunk.data)
                    self._current.total_played_ms += chunk.duration_ms

            # Wait for playback to complete
            await self.player.drain()
            self.player.stop()

            # Persist the utterance (best-effort; never fails the speak call)
            if (
                self.transcript_store is not None
                and captured_pcm
                and not self._current.cancelled
            ):
                try:
                    self.transcript_store.add_entry(
                        text=text,
                        voice=voice,
                        rate=rate,
                        audio_pcm=bytes(captured_pcm),
                        sample_rate=self.config.sample_rate_hz,
                        duration_ms=self._current.total_played_ms,
                    )
                except Exception as store_err:
                    logger.warning(
                        f"[{request_id}] transcript store failed: {store_err}"
                    )

            # Yield completion event
            yield {
                "type": "complete",
                "request_id": request_id,
                "played_ms": self._current.total_played_ms,
            }

            logger.info(f"[{request_id}] Complete: {self._current.total_played_ms}ms")

        except Exception as e:
            logger.error(f"[{request_id}] Error: {e}")
            yield {
                "type": "error",
                "request_id": request_id,
                "message": str(e),
            }

        finally:
            async with self._lock:
                if self._current and self._current.request_id == request_id:
                    self._current = None


    async def stop(self) -> None:
        """Stop current playback."""
        async with self._lock:
            if self._current:
                self._current.cancelled = True
        self.player.stop()
        logger.info("Playback stopped")

    async def voices(self) -> list[dict]:
        """List available voices."""
        voice_list = await self.tts.list_voices()
        return [v.to_dict() for v in voice_list]

    async def shutdown(self) -> None:
        """Clean shutdown."""
        await self.stop()
        logger.info("Orchestrator shutdown")


# Backwards compatibility alias
async def create_orchestrator(config_path: Optional[str] = None) -> VoiceOrchestrator:
    """Create a voice orchestrator."""
    return await VoiceOrchestrator.create(config_path)

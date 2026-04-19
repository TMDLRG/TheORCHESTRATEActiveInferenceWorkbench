"""Piper TTS Engine - Fast, local neural text-to-speech.

This is the core TTS engine for claude-voice-connector.
Piper runs completely offline with no network dependency.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import AsyncIterator, Optional

from .config import ConnectorConfig
from .logging_setup import get_logger

logger = get_logger("piper_tts")

# Default models directory
MODELS_DIR = Path(__file__).resolve().parent.parent.parent / "models"


@dataclass
class AudioChunk:
    """A chunk of synthesized PCM audio."""
    data: bytes          # PCM int16 mono
    duration_ms: int
    is_final: bool = False


@dataclass
class VoiceInfo:
    """Voice model information."""
    name: str
    short_name: str
    gender: str
    locale: str

    def to_dict(self) -> dict:
        return {
            "name": self.name,
            "short_name": self.short_name,
            "gender": self.gender,
            "locale": self.locale,
        }


# Available voice models
VOICE_CATALOG = {
    "en_GB-jenny_dioco-medium": {
        "name": "Jenny DioCo",
        "gender": "Female",
        "locale": "en-GB",
        "description": "British female, natural and warm",
    },
    "en_US-amy-medium": {
        "name": "Amy", 
        "gender": "Female",
        "locale": "en-US",
        "description": "American female, clear and professional",
    },
    "en_GB-alba-medium": {
        "name": "Alba",
        "gender": "Female", 
        "locale": "en-GB",
        "description": "British female, gentle tone",
    },
}


class PiperTTS:
    """Piper Text-to-Speech engine.
    
    Uses ONNX models for fast, local neural TTS synthesis.
    Supports streaming output for low-latency playback.
    """

    def __init__(
        self,
        config: ConnectorConfig,
        models_dir: Optional[Path] = None,
        default_voice: str = "en_GB-jenny_dioco-medium",
    ) -> None:
        """Initialize Piper TTS.

        Args:
            config: Connector configuration
            models_dir: Directory containing .onnx voice models
            default_voice: Default voice to use
        """
        self.config = config
        self.models_dir = Path(models_dir) if models_dir else MODELS_DIR
        self.default_voice = default_voice
        self._voice_cache: dict = {}
        
        logger.info(f"PiperTTS initialized, models: {self.models_dir}")

    def _get_model_path(self, voice: str) -> Path:
        """Get path to voice model file."""
        return self.models_dir / f"{voice}.onnx"

    def _load_voice(self, voice: str):
        """Load a PiperVoice model with caching."""
        if voice in self._voice_cache:
            return self._voice_cache[voice]
        
        from piper.voice import PiperVoice
        
        model_path = self._get_model_path(voice)
        if not model_path.exists():
            raise FileNotFoundError(f"Voice model not found: {model_path}")
        
        logger.info(f"Loading voice: {voice}")
        piper_voice = PiperVoice.load(str(model_path))
        self._voice_cache[voice] = piper_voice
        return piper_voice

    def _parse_rate(self, rate: Optional[str]) -> float:
        """Convert rate string to Piper length_scale.
        
        Rate like "-10%" means slower speech = higher length_scale.
        Rate like "+10%" means faster speech = lower length_scale.
        """
        if not rate:
            return 1.0
        
        try:
            rate_str = rate.replace("%", "").replace("+", "").strip()
            rate_pct = float(rate_str)
            # -10% rate -> 1.1 length_scale (slower)
            # +10% rate -> 0.9 length_scale (faster)
            length_scale = 1.0 - (rate_pct / 100.0)
            return max(0.5, min(2.0, length_scale))
        except ValueError:
            return 1.0


    async def synthesize(
        self,
        text: str,
        voice: Optional[str] = None,
        rate: Optional[str] = None,
    ) -> AsyncIterator[AudioChunk]:
        """Synthesize text to audio with streaming output.

        Args:
            text: Plain text to synthesize
            voice: Voice name (defaults to jenny)
            rate: Speech rate adjustment (e.g., "-10%", "+5%")

        Yields:
            AudioChunk objects with PCM int16 mono data
        """
        voice = voice or self.default_voice
        text = text.strip()
        
        if not text:
            logger.warning("Empty text, nothing to synthesize")
            yield AudioChunk(data=b"", duration_ms=0, is_final=True)
            return

        logger.debug(f"Synthesizing: voice={voice}, len={len(text)}")

        try:
            piper_voice = self._load_voice(voice)
            length_scale = self._parse_rate(rate)
            sample_rate = piper_voice.config.sample_rate
            
            # Configure synthesis
            from piper.config import SynthesisConfig
            syn_config = SynthesisConfig(length_scale=length_scale)
            
            total_ms = 0
            
            # Piper yields audio per sentence
            for audio_chunk in piper_voice.synthesize(text, syn_config):
                audio_bytes = audio_chunk.audio_int16_bytes
                samples = len(audio_bytes) // 2
                duration_ms = int(samples * 1000 / sample_rate)
                total_ms += duration_ms
                
                yield AudioChunk(
                    data=audio_bytes,
                    duration_ms=duration_ms,
                    is_final=False,
                )
            
            # Final marker
            yield AudioChunk(data=b"", duration_ms=0, is_final=True)
            logger.debug(f"Synthesis complete: {total_ms}ms")

        except Exception as e:
            logger.error(f"Synthesis error: {e}")
            raise

    async def synthesize_all(
        self,
        text: str,
        voice: Optional[str] = None,
        rate: Optional[str] = None,
    ) -> bytes:
        """Synthesize text and return complete audio.

        Args:
            text: Plain text to synthesize
            voice: Voice name
            rate: Speech rate adjustment

        Returns:
            Complete PCM int16 mono audio data
        """
        chunks = []
        async for chunk in self.synthesize(text, voice, rate):
            if chunk.data:
                chunks.append(chunk.data)
        return b"".join(chunks)

    async def list_voices(self) -> list[VoiceInfo]:
        """List available voices.

        Returns:
            List of installed voice models
        """
        voices = []
        for voice_id, meta in VOICE_CATALOG.items():
            if self._get_model_path(voice_id).exists():
                voices.append(VoiceInfo(
                    name=meta["name"],
                    short_name=voice_id,
                    gender=meta["gender"],
                    locale=meta["locale"],
                ))
        return voices

    async def voice_exists(self, voice: str) -> bool:
        """Check if a voice model is installed."""
        return self._get_model_path(voice).exists()

    def get_sample_rate(self, voice: Optional[str] = None) -> int:
        """Get sample rate for a voice model."""
        voice = voice or self.default_voice
        piper_voice = self._load_voice(voice)
        return piper_voice.config.sample_rate

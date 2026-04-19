"""Claude Voice Connector - Piper TTS for Claude Desktop.

A fast, local neural text-to-speech system using Piper.
No network required - runs completely offline.

Usage:
    from claude_voice_connector import VoiceOrchestrator
    
    orchestrator = await VoiceOrchestrator.create()
    async for event in orchestrator.speak("Hello world"):
        print(event)
"""

__version__ = "1.0.0"

from .config import ConnectorConfig, load_config
from .piper_tts import PiperTTS, AudioChunk, VoiceInfo
from .voice_orchestrator import VoiceOrchestrator
from .audio_player import AudioPlayer

__all__ = [
    "ConnectorConfig",
    "load_config",
    "PiperTTS",
    "AudioChunk", 
    "VoiceInfo",
    "VoiceOrchestrator",
    "AudioPlayer",
]

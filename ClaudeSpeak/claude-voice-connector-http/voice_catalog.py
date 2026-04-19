"""Voice catalog for the dual-engine voice service.

Lists every voice the LLM agent can pick, keyed by short_name.  Each entry
declares its engine (`piper` or `xtts`) + the engine-specific parameters.

Target per user addendum: both TTS (Piper) and XTTS engines supported, with
at least 5 total voices bundled and ready to use.
"""
from __future__ import annotations

from typing import Literal, TypedDict


class VoiceEntry(TypedDict, total=False):
    engine: Literal["piper", "xtts"]
    name: str
    gender: str
    locale: str
    description: str
    # Piper-only
    piper_voice: str
    # XTTS-only
    xtts_speaker: str
    xtts_language: str


VOICE_CATALOG: dict[str, VoiceEntry] = {
    # --- Piper voices (fast, CPU, ~1x real-time) ---
    "piper_jenny": {
        "engine": "piper",
        "name": "Jenny (Piper)",
        "gender": "Female",
        "locale": "en-GB",
        "description": "British female, natural and warm (fast Piper TTS).",
        "piper_voice": "en_GB-jenny_dioco-medium",
    },
    "piper_amy": {
        "engine": "piper",
        "name": "Amy (Piper)",
        "gender": "Female",
        "locale": "en-US",
        "description": "American female, clear and professional (fast Piper TTS).",
        "piper_voice": "en_US-amy-medium",
    },
    "piper_alba": {
        "engine": "piper",
        "name": "Alba (Piper)",
        "gender": "Female",
        "locale": "en-GB",
        "description": "British female, gentle tone (fast Piper TTS).",
        "piper_voice": "en_GB-alba-medium",
    },
    "piper_ryan": {
        "engine": "piper",
        "name": "Ryan (Piper)",
        "gender": "Male",
        "locale": "en-US",
        "description": "American male, warm narration (fast Piper TTS).",
        "piper_voice": "en_US-ryan-high",
    },
    "piper_lessac": {
        "engine": "piper",
        "name": "Lessac (Piper)",
        "gender": "Female",
        "locale": "en-US",
        "description": "American female, bright and articulate (fast Piper TTS).",
        "piper_voice": "en_US-lessac-medium",
    },
    # --- XTTS-v2 voices (higher quality, slower, CPU ~15-25s/sentence) ---
    "xtts_female_warm": {
        "engine": "xtts",
        "name": "Claribel (XTTS)",
        "gender": "Female",
        "locale": "en-multi",
        "description": "High-quality multi-lingual XTTS voice — warm female.",
        "xtts_speaker": "Claribel Dervla",
        "xtts_language": "en",
    },
    "xtts_male_calm": {
        "engine": "xtts",
        "name": "Damien (XTTS)",
        "gender": "Male",
        "locale": "en-multi",
        "description": "High-quality multi-lingual XTTS voice — calm male.",
        "xtts_speaker": "Damien Black",
        "xtts_language": "en",
    },
}

# Backwards-compat: if an old voice short_name is passed (`en_GB-jenny_dioco-medium`),
# map to the new canonical id (`piper_jenny`) so existing bookmarks keep working.
LEGACY_ALIASES: dict[str, str] = {
    "en_GB-jenny_dioco-medium": "piper_jenny",
    "en_US-amy-medium": "piper_amy",
    "en_GB-alba-medium": "piper_alba",
}


def canonicalize(voice: str) -> str:
    """Map a caller-provided voice name to a canonical catalog key."""
    if voice in VOICE_CATALOG:
        return voice
    return LEGACY_ALIASES.get(voice, voice)

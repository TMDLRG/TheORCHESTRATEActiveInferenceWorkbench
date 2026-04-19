"""Test the clean Piper TTS implementation."""

import asyncio
import sys
sys.path.insert(0, "src")

from claude_voice_connector import VoiceOrchestrator


async def test_speak():
    print("Creating orchestrator...")
    orchestrator = await VoiceOrchestrator.create()
    
    print("Speaking test message...")
    async for event in orchestrator.speak(
        "Hello Michael! This is the clean Piper implementation. "
        "No more SSML, just pure text to speech.",
        voice="en_GB-jenny_dioco-medium",
        rate="-5%"
    ):
        print(f"Event: {event}")
    
    print("\nListing voices...")
    voices = await orchestrator.voices()
    for v in voices:
        print(f"  - {v['short_name']}: {v['name']} ({v['locale']})")
    
    await orchestrator.shutdown()
    print("\nDone!")


if __name__ == "__main__":
    asyncio.run(test_speak())

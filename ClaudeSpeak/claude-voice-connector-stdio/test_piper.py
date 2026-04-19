"""Test script for Piper TTS with audio playback."""

import asyncio
import sys
from pathlib import Path

# Add src to path
src_path = Path(__file__).parent / "src"
sys.path.insert(0, str(src_path))

from claude_voice_connector.tts_piper import PiperTTSWrapper
from claude_voice_connector.audio_player import AudioPlayer
from claude_voice_connector.config import load_config


async def test_piper_playback():
    """Test Piper TTS synthesis with audio playback."""
    print("Loading config...")
    config = load_config()
    
    print("Initializing Piper TTS...")
    models_dir = Path(__file__).parent / "models"
    tts = PiperTTSWrapper(config, models_dir)
    
    print("Initializing Audio Player...")
    # Override sample rate to match Piper (22050 Hz)
    config.sample_rate_hz = 22050
    player = AudioPlayer(config)
    
    # List available voices
    print("\nAvailable voices:")
    voices = await tts.list_voices()
    for v in voices:
        print(f"  - {v.short_name} ({v.name}, {v.gender}, {v.locale})")
    
    # Test synthesis with playback
    test_text = "Hello Michael! This is Piper text to speech running locally on your computer. No internet connection required. The audio quality should be much smoother than before."
    
    print(f"\nSynthesizing and playing: '{test_text[:50]}...'")
    print("Voice: en_GB-jenny_dioco-medium")
    
    # Start player
    player.start()
    
    total_bytes = 0
    chunk_count = 0
    
    async for chunk in tts.synthesize_streaming(test_text, voice="en_GB-jenny_dioco-medium", rate="-5%"):
        if chunk.data:
            total_bytes += len(chunk.data)
            chunk_count += 1
            print(f"  Chunk {chunk_count}: {len(chunk.data)} bytes, {chunk.duration_ms}ms")
            # Write to audio player
            await player.write_pcm_async(chunk.data)
        if chunk.is_final:
            print("  [Final chunk received]")
    
    print(f"\nTotal: {total_bytes} bytes in {chunk_count} chunks")
    
    # Calculate duration
    duration_ms = total_bytes / 2 / 22050 * 1000
    print(f"Audio duration: {duration_ms:.0f}ms ({duration_ms/1000:.1f}s)")
    
    # Wait for playback to complete
    print("\nWaiting for playback to complete...")
    await player.wait_for_drain(timeout=30.0)
    
    player.stop()
    print("\nPiper TTS test completed successfully!")


if __name__ == "__main__":
    asyncio.run(test_piper_playback())

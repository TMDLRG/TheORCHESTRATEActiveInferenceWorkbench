"""Debug test - trace full MCP path to find the voice issue."""

import asyncio
import sys
from pathlib import Path

# Add src to path
src_path = Path(__file__).parent / "src"
sys.path.insert(0, str(src_path))

from claude_voice_connector.config import load_config
from claude_voice_connector.tts_piper import PiperTTSWrapper
from claude_voice_connector.audio_player import AudioPlayer
from claude_voice_connector.segmenter import extract_text

async def debug_test():
    print("=" * 60)
    print("DEBUG: Tracing full voice path")
    print("=" * 60)
    
    # Load config
    config = load_config()
    print(f"\n1. Config loaded:")
    print(f"   tts_engine: {getattr(config, 'tts_engine', 'NOT SET')}")
    print(f"   voice: {config.voice}")
    print(f"   sample_rate_hz: {config.sample_rate_hz}")
    
    # Create TTS wrapper
    models_dir = Path(__file__).resolve().parent / "models"
    print(f"\n2. Models directory: {models_dir}")
    print(f"   Exists: {models_dir.exists()}")
    print(f"   Files: {list(models_dir.glob('*.onnx'))}")
    
    tts = PiperTTSWrapper(config, models_dir)
    print(f"\n3. TTS Wrapper created:")
    print(f"   default_voice: {tts.default_voice}")
    print(f"   models_dir: {tts.models_dir}")
    
    # Create SSML like MCP server does
    text = "Hello Michael, this is a debug test."
    rate = "-5%"
    ssml = f'<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US"><prosody rate="{rate}">{text}</prosody></speak>'
    print(f"\n4. SSML created: {ssml[:80]}...")
    
    # Extract text like tts_piper does
    extracted = extract_text(ssml)
    print(f"\n5. Extracted text: '{extracted}'")
    
    # Create audio player
    player = AudioPlayer(config)
    print(f"\n6. Audio player created:")
    print(f"   sample_rate: {player.sample_rate}")
    
    # Start player
    player.start()
    
    # Synthesize with explicit voice
    voice = "en_GB-jenny_dioco-medium"
    print(f"\n7. Calling synthesize_streaming with voice={voice}")
    
    chunk_count = 0
    total_bytes = 0
    async for chunk in tts.synthesize_streaming(ssml, voice=voice, rate=rate):
        if chunk.data:
            chunk_count += 1
            total_bytes += len(chunk.data)
            print(f"   Chunk {chunk_count}: {len(chunk.data)} bytes, {chunk.duration_ms}ms")
            await player.write_pcm_async(chunk.data)
    
    print(f"\n8. Total: {total_bytes} bytes in {chunk_count} chunks")
    print(f"   Duration: {total_bytes / 2 / 22050 * 1000:.0f}ms")
    
    # Wait for playback
    print("\n9. Waiting for playback...")
    await player.wait_for_drain(timeout=15)
    player.stop()
    
    print("\n" + "=" * 60)
    print("DEBUG TEST COMPLETE - Did you hear Jenny (British female)?")
    print("=" * 60)

if __name__ == "__main__":
    asyncio.run(debug_test())

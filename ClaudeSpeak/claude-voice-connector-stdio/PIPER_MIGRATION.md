# Claude Voice Connector - Piper TTS Migration Complete

## Summary
Successfully migrated from Edge-TTS (Microsoft cloud) to Piper TTS (local neural TTS).

## Benefits
- **Completely Offline**: No network dependency, runs 100% locally
- **Smoother Audio**: Native PCM output (no MP3 decoding artifacts)
- **Faster**: Neural inference on CPU is faster than network round-trips
- **Privacy**: All TTS processing happens on your machine

## Installed Voices
1. **en_GB-jenny_dioco-medium** (default) - British female, natural
2. **en_US-amy-medium** - American female
3. **en_GB-alba-medium** - British female (Scottish accent)

## Configuration Changes
- `config.yaml`: sample_rate_hz changed to 22050 (Piper native)
- `mcp_server.py`: Tool descriptions updated for Piper
- `orchestrator.py`: Now uses PiperTTSWrapper instead of EdgeTTSWrapper

## New Files
- `src/claude_voice_connector/tts_piper.py` - Piper TTS wrapper
- `models/` - Voice model files (.onnx and .onnx.json)

## Testing
- `test_piper.py` - Direct Piper TTS test with audio playback
- `test_mcp.py` - Full MCP server integration test

## Usage
After restarting Claude Desktop, use the speak tool:
```
speak(text="Hello world", voice="en_GB-jenny_dioco-medium", rate="-5%")
```

## Rate Control
- `-10%` to `-20%` = slower speech
- `+10%` to `+20%` = faster speech
- Default is `-5%` for natural pacing

## Next Steps
1. Restart Claude Desktop to pick up the changes
2. Test the voice-connector speak tool
3. Add more Piper voices if desired (download from HuggingFace)

## Voice Download URLs (if needed)
```
https://huggingface.co/rhasspy/piper-voices/tree/v1.0.0/en
```

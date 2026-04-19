# Claude Voice Connector (STDIO)

A local connector process that communicates via STDIO (NDJSON) for text-to-speech synthesis using Microsoft Edge TTS with low-latency streaming playback.

## Features

- **STDIO Transport**: NDJSON protocol over stdin/stdout for easy integration
- **Streaming Playback**: Low-latency audio streaming with target ≤800ms to first audio
- **SSML Support**: Full SSML support with prosody, breaks, emphasis, and more
- **Automatic Segmentation**: SSML-aware splitting for long content (2-5 minute segments)
- **Backpressure Control**: Intelligent buffer management to prevent overflows
- **Event-Driven**: ACK, PROGRESS, and COMPLETE events for monitoring
- **Cross-Platform**: Windows, macOS, and Linux support

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Claude Tool Adapter                              │
│                    (examples/claude_tool_adapter.py)                     │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                          NDJSON over STDIO
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           stdio_main.py                                  │
│                         (NDJSON Protocol)                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                        orchestrator.py                           │    │
│  │                    (Coordination & Events)                       │    │
│  └───────────────────────────────┬─────────────────────────────────┘    │
│                                  │                                       │
│         ┌────────────────────────┼────────────────────────┐             │
│         │                        │                        │             │
│         ▼                        ▼                        ▼             │
│  ┌─────────────┐         ┌─────────────┐         ┌─────────────┐       │
│  │ segmenter   │         │  tts_edge   │         │audio_player │       │
│  │  (SSML)     │────────▶│  (Edge TTS) │────────▶│(Ring Buffer)│       │
│  └─────────────┘         └─────────────┘         └─────────────┘       │
│         │                                                │              │
│         ▼                                                ▼              │
│  ┌─────────────┐                                  ┌─────────────┐       │
│  │ sanitizer   │                                  │ sounddevice │       │
│  │  (SSML)     │                                  │ (PortAudio) │       │
│  └─────────────┘                                  └─────────────┘       │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Message Flow

```
Caller                    Connector                    Audio Device
  │                           │                              │
  │──── speak (SSML) ────────▶│                              │
  │                           │                              │
  │◀──── ack ─────────────────│                              │
  │                           │──── TTS synthesis ──────────▶│
  │                           │                              │
  │◀──── progress ────────────│◀─── audio stream ───────────│
  │◀──── progress ────────────│                              │
  │◀──── progress ────────────│                              │
  │                           │                              │
  │◀──── complete ────────────│                              │
  │                           │                              │
```

## Quick Start

### Prerequisites

- Python 3.10+
- PortAudio (for sounddevice)
- Internet connection (for Edge TTS)

### Installation

```bash
# Clone or extract the repository
cd claude-voice-connector-stdio

# Create virtual environment
python -m venv venv

# Activate (Windows)
.\venv\Scripts\activate
# Activate (Unix)
source venv/bin/activate

# Install dependencies
pip install -e .

# Optional: Install pydub for MP3 decoding (recommended)
pip install pydub

# Install ffmpeg (required for pydub)
# Windows: choco install ffmpeg
# macOS: brew install ffmpeg
# Linux: sudo apt install ffmpeg
```

### Running the Connector

**Windows (PowerShell):**
```powershell
.\start.ps1
```

**Unix (Bash):**
```bash
./start.sh
```

**Direct Python:**
```bash
python -u -m claude_voice_connector.stdio_main
```

### Demo

```bash
# Run the demo client
python examples/demo_client.py

# With custom SSML file
python examples/demo_client.py --ssml path/to/file.ssml

# With plain text
python examples/demo_client.py --text "Hello, world!"

# With specific voice
python examples/demo_client.py --text "Hello" --voice en-US-GuyNeural
```

## NDJSON Protocol

### Commands (stdin)

#### speak
```json
{
  "type": "speak",
  "id": "uuid-string",
  "ssml": "<speak>...</speak>",
  "voice": "en-US-AriaNeural",
  "rate": "+0%",
  "pitch": "+0Hz",
  "volume": "+0%",
  "stream": true,
  "priority": 5,
  "metadata": {}
}
```

#### stop
```json
{"type": "stop"}
```

#### flush
```json
{"type": "flush"}
```

#### status
```json
{"type": "status"}
```

#### voices
```json
{"type": "voices"}
```

### Events (stdout)

#### ack
```json
{
  "type": "ack",
  "id": "request-id",
  "mode": "stream",
  "accepted_at": "2024-01-01T00:00:00Z"
}
```

#### progress
```json
{
  "type": "progress",
  "id": "request-id",
  "played_ms": 1240,
  "buffered_ms": 4320
}
```

#### complete
```json
{
  "type": "complete",
  "id": "request-id",
  "played_ms": 60321,
  "segments": [
    {"seq": 0, "duration_ms": 30000, "ok": true},
    {"seq": 1, "duration_ms": 30321, "ok": true}
  ]
}
```

#### error
```json
{
  "type": "error",
  "id": "request-id",
  "code": "TTS_ERROR",
  "message": "Synthesis failed",
  "retryable": true
}
```

## Claude Tool Integration

Use `examples/claude_tool_adapter.py` to integrate with Claude:

```python
from examples.claude_tool_adapter import VoiceConnectorAdapter

async with VoiceConnectorAdapter() as adapter:
    result = await adapter.speak("Hello from Claude!")
    print(f"Played {result.played_ms}ms of audio")
```

### Tool Definition

```python
CLAUDE_TOOL_DEFINITION = {
    "name": "speak",
    "description": "Synthesize and play text as speech",
    "input_schema": {
        "type": "object",
        "properties": {
            "text": {"type": "string"},
            "voice": {"type": "string"},
            "rate": {"type": "string"},
            "pitch": {"type": "string"},
            "ssml": {"type": "boolean"}
        },
        "required": ["text"]
    }
}
```

## Configuration

Edit `config.yaml`:

```yaml
# Audio settings
sample_rate_hz: 16000
channels: 1

# Voice defaults
voice: en-US-AriaNeural
rate: "+0%"
pitch: "+0Hz"

# Streaming
stream: true

# Segmentation (for long content)
segment_target_sec: 180
segment_max_sec: 300

# Buffer management
max_buffer_ms: 5000
min_buffer_ms: 1000
ring_buffer_ms: 10000

# Events
progress_interval_ms: 250

# Logging
log_level: INFO
```

### Environment Overrides

```bash
CLAUDE_VOICE_VOICE=en-US-GuyNeural
CLAUDE_VOICE_LOG_LEVEL=DEBUG
CLAUDE_VOICE_DEVICE=1
```

## Tuning Guide

### Buffer Sizes

| Setting | Description | Tuning |
|---------|-------------|--------|
| `ring_buffer_ms` | Total playback buffer | Increase for stability, decrease for lower latency |
| `max_buffer_ms` | Pause TTS threshold | Lower = more responsive backpressure |
| `min_buffer_ms` | Resume TTS threshold | Buffer headroom before resuming |

### Latency Targets

- **Time to first audio**: ≤800ms (streaming mode)
- **Segment gap**: ≤300ms average
- **Progress interval**: 250ms default

### Device Selection

```yaml
# Use default device
device_index: null

# Use specific device by index
device_index: 1

# Use device by name (partial match)
device_index: "Speakers"
```

List devices:
```python
from claude_voice_connector.audio_player import AudioPlayer
for d in AudioPlayer.list_devices():
    print(f"[{d['index']}] {d['name']}")
```

## Troubleshooting

### PortAudio Installation

**Windows:**
- Usually bundled with sounddevice
- If issues: Install via conda: `conda install portaudio`

**macOS:**
```bash
brew install portaudio
pip install sounddevice
```

**Linux:**
```bash
sudo apt install libportaudio2 portaudio19-dev
pip install sounddevice
```

### Common Issues

| Issue | Solution |
|-------|----------|
| No audio output | Check `device_index` in config, run device list |
| Underruns | Increase `ring_buffer_ms` and `max_buffer_ms` |
| High latency | Decrease buffer sizes, use streaming mode |
| TTS errors | Check internet connection, verify voice name |

### Logs

Logs are written to stderr in JSON format:
```json
{"ts": "2024-01-01T00:00:00Z", "level": "INFO", "logger": "orchestrator", "msg": "Processing request"}
```

## Tests

```bash
# Install dev dependencies
pip install -e ".[dev]"

# Run tests
pytest

# Run with coverage
pytest --cov=claude_voice_connector

# Run specific test file
pytest tests/test_segmenter.py
```

## Performance Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| Time to first audio | ≤800ms | From ACK to first progress |
| Segment gap | ≤300ms avg | Between segment completions |
| Underruns | 0 | During normal operation |
| Memory | <100MB | Steady state |

## License

MIT License - see LICENSE file.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

---

## DONE Checklist

### PASS 1 (Specification)
- [x] SMART targets defined
- [x] STDIO protocol specified
- [x] Segmentation rules documented
- [x] Event schemas defined
- [x] Repo structure complete

### PASS 2 (Implementation)
- [x] All modules implemented
- [x] Tests written
- [x] Demo client works
- [x] Documentation complete

### PASS 3 (Validation)
- [ ] Three consecutive demos meet latency targets
- [ ] Zero unhandled exceptions
- [ ] Deterministic ordering verified

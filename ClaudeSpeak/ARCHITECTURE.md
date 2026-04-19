# ClaudeSpeak Accessibility Extension - Architecture Design

## Executive Summary

Extend the existing Claude Voice Connector into a full accessibility suite with:
1. **Speech-to-Text (STT)** - Local, free, real-time transcription
2. **UI Control Modal** - System tray with mic/TTS controls
3. **Prompt Enhancement Layer** - LLM-powered prompt optimization

---

## Current Architecture (Baseline)

```
┌─────────────────────────────────────────────────────────────────┐
│                    Claude Desktop (MCP Client)                   │
└─────────────────────────────┬───────────────────────────────────┘
                              │ STDIO (JSON-RPC)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         MCP Server                               │
│                      (mcp_server.py)                             │
│  Tools: speak, stop_speaking, list_voices                        │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     VoiceOrchestrator                            │
│                  (voice_orchestrator.py)                         │
│                                                                   │
│    ┌─────────────┐              ┌─────────────────┐             │
│    │  PiperTTS   │──── PCM ────▶│  AudioPlayer    │             │
│    │  (Local)    │              │  (Ring Buffer)  │             │
│    └─────────────┘              └────────┬────────┘             │
│                                          │                       │
└──────────────────────────────────────────┼───────────────────────┘
                                           ▼
                                    🔊 Speakers
```

---

## Proposed Architecture (Extended)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Claude Desktop (MCP Client)                          │
└───────────────────────────────────┬─────────────────────────────────────────┘
                                    │ STDIO (JSON-RPC)
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              MCP Server                                      │
│                           (mcp_server.py)                                    │
│                                                                              │
│  TTS Tools:        STT Tools:           UI Tools:        Enhancement:       │
│  ├─ speak          ├─ start_listening   ├─ show_modal    ├─ enhance_prompt  │
│  ├─ stop_speaking  ├─ stop_listening    ├─ hide_modal    └─ set_enhancement │
│  └─ list_voices    ├─ get_transcript    └─ get_ui_state                     │
│                    └─ clear_buffer                                           │
└───────────────────────────────────┬─────────────────────────────────────────┘
                                    │
        ┌───────────────────────────┼───────────────────────────┐
        │                           │                           │
        ▼                           ▼                           ▼
┌───────────────────┐   ┌───────────────────────┐   ┌───────────────────────┐
│  VoiceOrchestrator│   │   STTOrchestrator     │   │   PromptEnhancer      │
│                   │   │                       │   │                       │
│  ┌─────────────┐  │   │  ┌─────────────────┐  │   │  ┌─────────────────┐  │
│  │  PiperTTS   │  │   │  │  FasterWhisper  │  │   │  │  Local LLM      │  │
│  └──────┬──────┘  │   │  └────────┬────────┘  │   │  │  (Ollama/etc)   │  │
│         │         │   │           │           │   │  └────────┬────────┘  │
│  ┌──────▼──────┐  │   │  ┌────────▼────────┐  │   │           │           │
│  │ AudioPlayer │  │   │  │  AudioCapture   │  │   │  Prompt Templates     │
│  │ (Output)    │  │   │  │  (Input)        │  │   │  Context Management   │
│  └──────┬──────┘  │   │  └────────┬────────┘  │   └───────────────────────┘
│         │         │   │           │           │
└─────────┼─────────┘   └───────────┼───────────┘
          │                         │
          ▼                         ▼
    🔊 Speakers               🎤 Microphone
          │                         │
          └────────────┬────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          UI Controller                                       │
│                       (System Tray App)                                      │
│                                                                              │
│   ┌──────────────────────────────────────────────────────────────────────┐  │
│   │                        Control Modal                                  │  │
│   │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │  │
│   │  │  🎤 Mic     │  │  🔊 TTS     │  │  ✨ Enhance │  │  ⚙️ Settings│  │  │
│   │  │  ON/OFF    │  │  ON/OFF     │  │  ON/OFF     │  │             │  │  │
│   │  │  [Push2Talk]│  │  [Voice]    │  │  [Model]    │  │  [Config]   │  │  │
│   │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘  │  │
│   │                                                                        │  │
│   │  Status: "Listening..." | "Speaking..." | "Ready"                      │  │
│   │  Last Transcript: "..."                                                │  │
│   └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│   System Tray Icon: 🎙️ (with tooltip status)                                │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Component Details

### 1. Speech-to-Text (STT) - Faster-Whisper

**Why Faster-Whisper:**
- 4x faster than OpenAI Whisper (CTranslate2 backend)
- Runs locally - no API costs, no data leaving machine
- Supports real-time streaming with VAD (Voice Activity Detection)
- GPU acceleration (CUDA) or CPU-only mode
- Small model (~150MB) with excellent accuracy

**Implementation:**

```python
# src/claude_voice_connector/stt_engine.py

from faster_whisper import WhisperModel
import numpy as np

class STTEngine:
    """Speech-to-text using faster-whisper."""

    def __init__(self, model_size="base", device="cpu", compute_type="int8"):
        self.model = WhisperModel(model_size, device=device, compute_type=compute_type)
        self._buffer = []

    async def transcribe_stream(self, audio_chunk: bytes) -> AsyncIterator[TranscriptChunk]:
        """Real-time transcription of audio chunks."""
        # Accumulate audio
        self._buffer.append(audio_chunk)

        # Process when enough audio (e.g., 1 second)
        if self._buffer_duration_ms() >= 1000:
            audio = self._combine_buffer()
            segments, info = self.model.transcribe(audio, beam_size=5)

            for segment in segments:
                yield TranscriptChunk(
                    text=segment.text,
                    start=segment.start,
                    end=segment.end,
                    confidence=segment.avg_logprob
                )
```

**Audio Capture (mirrors AudioPlayer):**

```python
# src/claude_voice_connector/audio_capture.py

class AudioCapture:
    """Microphone capture with ring buffer (inverse of AudioPlayer)."""

    def __init__(self, config: ConnectorConfig):
        self.sample_rate = 16000  # Whisper expects 16kHz
        self.ring_buffer = RingBuffer(capacity_samples=sample_rate * 30)  # 30s buffer
        self._stream = None

    def _audio_callback(self, indata, frames, time_info, status):
        """Callback for sounddevice input stream."""
        self.ring_buffer.write(indata[:, 0])  # Mono

    async def start(self):
        """Start microphone capture."""
        self._stream = sd.InputStream(
            samplerate=self.sample_rate,
            channels=1,
            dtype=np.int16,
            callback=self._audio_callback
        )
        self._stream.start()

    async def read(self, samples: int) -> np.ndarray:
        """Read audio from buffer."""
        return self.ring_buffer.read(samples)
```

**Dependencies:**
```
faster-whisper>=1.0.0
```

---

### 2. UI Control Modal - System Tray App

**Technology Stack:**
- **pystray** - System tray icon management
- **tkinter** - Modal window (built-in, no extra deps)
- **threading** - Separate UI thread from MCP server

**Implementation:**

```python
# src/claude_voice_connector/ui_controller.py

import pystray
from PIL import Image
import tkinter as tk
from tkinter import ttk
import threading

class UIController:
    """System tray app with control modal."""

    def __init__(self, orchestrator):
        self.orchestrator = orchestrator
        self.tray_icon = None
        self.modal = None
        self.state = UIState(
            mic_enabled=False,
            tts_enabled=True,
            enhance_enabled=True,
            status="Ready"
        )

    def create_tray_icon(self):
        """Create system tray icon with menu."""
        icon_image = self._create_icon()

        menu = pystray.Menu(
            pystray.MenuItem("Open Controls", self.show_modal),
            pystray.MenuItem("Toggle Mic", self.toggle_mic),
            pystray.MenuItem("Toggle TTS", self.toggle_tts),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("Quit", self.quit)
        )

        self.tray_icon = pystray.Icon(
            "ClaudeSpeak",
            icon_image,
            "ClaudeSpeak - Ready",
            menu
        )

    def show_modal(self):
        """Show the control modal window."""
        if self.modal and self.modal.winfo_exists():
            self.modal.lift()
            return

        self.modal = tk.Toplevel()
        self.modal.title("ClaudeSpeak Controls")
        self.modal.geometry("400x300")
        self.modal.attributes("-topmost", True)

        # Mic control
        mic_frame = ttk.LabelFrame(self.modal, text="Microphone")
        mic_frame.pack(fill="x", padx=10, pady=5)

        self.mic_btn = ttk.Button(
            mic_frame,
            text="🎤 Start Listening",
            command=self.toggle_mic
        )
        self.mic_btn.pack(pady=5)

        # Push-to-talk
        self.ptt_btn = ttk.Button(mic_frame, text="Push to Talk")
        self.ptt_btn.bind("<ButtonPress>", self.start_ptt)
        self.ptt_btn.bind("<ButtonRelease>", self.stop_ptt)
        self.ptt_btn.pack(pady=5)

        # TTS control
        tts_frame = ttk.LabelFrame(self.modal, text="Text-to-Speech")
        tts_frame.pack(fill="x", padx=10, pady=5)

        self.tts_var = tk.BooleanVar(value=self.state.tts_enabled)
        ttk.Checkbutton(
            tts_frame,
            text="Enable TTS",
            variable=self.tts_var,
            command=self.toggle_tts
        ).pack()

        # Voice selector
        ttk.Label(tts_frame, text="Voice:").pack()
        self.voice_combo = ttk.Combobox(tts_frame, values=self._get_voices())
        self.voice_combo.pack()

        # Enhancement control
        enhance_frame = ttk.LabelFrame(self.modal, text="Prompt Enhancement")
        enhance_frame.pack(fill="x", padx=10, pady=5)

        self.enhance_var = tk.BooleanVar(value=self.state.enhance_enabled)
        ttk.Checkbutton(
            enhance_frame,
            text="Enhance prompts before sending",
            variable=self.enhance_var
        ).pack()

        # Status bar
        self.status_label = ttk.Label(
            self.modal,
            text=f"Status: {self.state.status}"
        )
        self.status_label.pack(pady=10)

        # Transcript display
        self.transcript_text = tk.Text(self.modal, height=4)
        self.transcript_text.pack(fill="x", padx=10, pady=5)

    def run(self):
        """Run the UI in its own thread."""
        threading.Thread(target=self._run_tray, daemon=True).start()

    def _run_tray(self):
        self.create_tray_icon()
        self.tray_icon.run()
```

**Modal Layout:**

```
┌─────────────────────────────────────────┐
│  ClaudeSpeak Controls               [X] │
├─────────────────────────────────────────┤
│  ┌─ Microphone ───────────────────────┐ │
│  │  [🎤 Start Listening]              │ │
│  │  [  Push to Talk  ]                │ │
│  │  ○ Voice-activated  ○ Push-to-talk │ │
│  └────────────────────────────────────┘ │
│  ┌─ Text-to-Speech ───────────────────┐ │
│  │  [✓] Enable TTS                    │ │
│  │  Voice: [en_GB-jenny_dioco ▼]      │ │
│  │  Rate:  [-5%        ━━━━━●━━━━━━]  │ │
│  └────────────────────────────────────┘ │
│  ┌─ Prompt Enhancement ───────────────┐ │
│  │  [✓] Enhance prompts before send   │ │
│  │  Model: [Local Ollama ▼]           │ │
│  └────────────────────────────────────┘ │
│                                         │
│  Status: Ready                          │
│  ┌─ Last Transcript ─────────────────┐  │
│  │ "Hello Claude, can you help me..."│  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

---

### 3. Prompt Enhancement Layer

**Purpose:** Transform spoken input into well-structured prompts that yield better LLM responses.

**Pipeline:**

```
User Speech → STT → Raw Transcript → Enhancement → Optimized Prompt → Claude
     │                    │                │                │
     │                    │                │                │
  "um, can you          "um can you      "Explain DNS     "Could you provide
   like explain          like explain     propagation      a clear explanation
   how DNS works,        how DNS works    clearly with     of DNS propagation,
   the propagation       the propagation  examples"        including specific
   thing?"               thing"                            examples of how it
                                                           works in practice?"
```

**Enhancement Steps:**
1. **Cleanup** - Remove filler words (um, uh, like, you know)
2. **Structure** - Identify intent and add clarity
3. **Enrich** - Add context and specificity

**Implementation:**

```python
# src/claude_voice_connector/prompt_enhancer.py

class PromptEnhancer:
    """Enhance raw speech into optimized prompts."""

    def __init__(self, llm_provider: str = "ollama"):
        self.provider = llm_provider
        self.templates = self._load_templates()

    async def enhance(self, raw_text: str, context: dict = None) -> EnhancedPrompt:
        """
        Transform raw speech into an optimized prompt.

        Uses a fast local LLM for quick enhancement.
        """
        # Step 1: Clean up filler words
        cleaned = self._remove_fillers(raw_text)

        # Step 2: Quick LLM enhancement (fast model)
        enhanced = await self._llm_enhance(cleaned, context)

        return EnhancedPrompt(
            original=raw_text,
            cleaned=cleaned,
            enhanced=enhanced,
            enhancement_time_ms=elapsed
        )

    def _remove_fillers(self, text: str) -> str:
        """Remove common filler words."""
        fillers = [
            r'\bum+\b', r'\buh+\b', r'\blike\b', r'\byou know\b',
            r'\bso+\b', r'\bbasically\b', r'\bactually\b'
        ]
        for filler in fillers:
            text = re.sub(filler, '', text, flags=re.IGNORECASE)
        return ' '.join(text.split())

    async def _llm_enhance(self, text: str, context: dict) -> str:
        """Use local LLM to enhance the prompt."""

        system_prompt = """You are a prompt optimizer. Transform the user's
casual spoken request into a clear, specific prompt for an AI assistant.

Rules:
1. Preserve the user's intent exactly
2. Add clarity and structure
3. Be concise - don't over-elaborate
4. Output ONLY the enhanced prompt, nothing else

Example:
Input: "can you help me with my code its broken"
Output: "Help me debug my code. I'm encountering an error and need assistance identifying and fixing the issue."
"""

        if self.provider == "ollama":
            response = await self._call_ollama(system_prompt, text)
        else:
            response = await self._call_api(system_prompt, text)

        return response.strip()
```

**LLM Options (Local/Free):**

| Provider | Model | Speed | Quality | Setup |
|----------|-------|-------|---------|-------|
| **Ollama** | llama3.2:1b | ~100ms | Good | Easy |
| **Ollama** | phi3:mini | ~150ms | Better | Easy |
| **LM Studio** | Any GGUF | Varies | Varies | Moderate |
| **llama.cpp** | Phi-3 | ~80ms | Good | Harder |

**Recommended: Ollama with llama3.2:1b**
- Very fast (~100ms per enhancement)
- Runs locally, free
- Good quality for prompt restructuring
- Simple API

---

## Integration Flow

### Full Request Flow (Speech → Enhanced Prompt → Claude Response → TTS)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              USER SPEAKS                                     │
│                        "Hey um, can you like,                               │
│                         explain how DNS works?"                              │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  1. AUDIO CAPTURE                                                            │
│     AudioCapture → 16kHz mono PCM → Ring Buffer                             │
│     (50ms latency)                                                           │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  2. SPEECH-TO-TEXT (Faster-Whisper)                                          │
│     Raw: "Hey um, can you like, explain how DNS works?"                      │
│     (200-500ms latency)                                                      │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  3. PROMPT ENHANCEMENT (Local LLM - Optional)                                │
│     Enhanced: "Explain how DNS works, including the resolution process"      │
│     (100-200ms latency)                                                      │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  4. SEND TO CLAUDE (via tool response)                                       │
│     MCP tool returns enhanced prompt to Claude Desktop                       │
│     Claude processes and generates response                                  │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  5. TEXT-TO-SPEECH (Piper TTS)                                               │
│     Claude's response → Piper → Audio                                        │
│     (streaming, ~200ms to first audio)                                       │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              USER HEARS                                      │
│                         Claude's response                                    │
└─────────────────────────────────────────────────────────────────────────────┘

Total expected latency: 500ms-1000ms (speech to first audio response)
```

---

## New MCP Tools

```python
# Extended tool definitions

TOOLS = [
    # Existing TTS tools
    {"name": "speak", ...},
    {"name": "stop_speaking", ...},
    {"name": "list_voices", ...},

    # New STT tools
    {
        "name": "start_listening",
        "description": "Start listening to microphone for speech input",
        "inputSchema": {
            "type": "object",
            "properties": {
                "mode": {
                    "type": "string",
                    "enum": ["continuous", "push_to_talk", "voice_activated"],
                    "default": "voice_activated"
                },
                "language": {
                    "type": "string",
                    "default": "en"
                }
            }
        }
    },
    {
        "name": "stop_listening",
        "description": "Stop listening and return final transcript",
        "inputSchema": {"type": "object", "properties": {}}
    },
    {
        "name": "get_transcript",
        "description": "Get current transcript buffer without stopping",
        "inputSchema": {"type": "object", "properties": {}}
    },

    # Prompt enhancement tools
    {
        "name": "enhance_prompt",
        "description": "Enhance a raw prompt into a well-structured request",
        "inputSchema": {
            "type": "object",
            "properties": {
                "text": {"type": "string", "description": "Raw text to enhance"},
                "context": {"type": "object", "description": "Optional context"}
            },
            "required": ["text"]
        }
    },

    # UI tools
    {
        "name": "show_controls",
        "description": "Show the ClaudeSpeak control panel",
        "inputSchema": {"type": "object", "properties": {}}
    },
    {
        "name": "get_ui_state",
        "description": "Get current UI state (mic, tts, enhancement settings)",
        "inputSchema": {"type": "object", "properties": {}}
    }
]
```

---

## File Structure (Extended)

```
claude-voice-connector-stdio/
├── src/claude_voice_connector/
│   ├── __init__.py
│   ├── __main__.py
│   ├── mcp_server.py           # Extended with new tools
│   ├── voice_orchestrator.py   # TTS orchestration
│   ├── stt_orchestrator.py     # NEW: STT orchestration
│   ├── audio_player.py         # Audio output
│   ├── audio_capture.py        # NEW: Audio input (mic)
│   ├── piper_tts.py            # Piper synthesis
│   ├── stt_engine.py           # NEW: Faster-Whisper wrapper
│   ├── prompt_enhancer.py      # NEW: LLM enhancement
│   ├── ui_controller.py        # NEW: System tray + modal
│   ├── config.py               # Extended config
│   ├── events.py
│   ├── logging_setup.py
│   └── metrics.py
├── models/
│   └── whisper/                # NEW: Whisper models (auto-download)
├── config.yaml                 # Extended config
├── requirements.txt            # Updated deps
└── ...
```

---

## Configuration Extension

```yaml
# config.yaml (extended)

# Existing TTS config
voice: en_GB-jenny_dioco-medium
sample_rate_hz: 22050
# ...

# NEW: STT config
stt:
  enabled: true
  model: base              # tiny, base, small, medium, large
  device: cpu              # cpu or cuda
  language: en
  vad_enabled: true        # Voice Activity Detection
  vad_threshold: 0.5

# NEW: Audio capture config
capture:
  sample_rate_hz: 16000    # Whisper expects 16kHz
  channels: 1
  buffer_ms: 30000
  device_index: null       # null = default mic

# NEW: Prompt enhancement config
enhancement:
  enabled: true
  provider: ollama         # ollama, openai, none
  model: llama3.2:1b
  timeout_ms: 2000
  fallback_to_raw: true    # Use raw if enhancement fails

# NEW: UI config
ui:
  enabled: true
  start_minimized: true
  hotkey_toggle_mic: "ctrl+shift+m"
  hotkey_push_to_talk: "ctrl+space"
```

---

## Dependencies (New)

```
# requirements.txt additions

# STT
faster-whisper>=1.0.0
silero-vad>=5.0  # Voice Activity Detection

# UI
pystray>=0.19
Pillow>=10.0  # For tray icon

# Prompt Enhancement (optional - if using Ollama)
ollama>=0.1.0
httpx>=0.25  # For async HTTP to Ollama

# Audio capture (already have sounddevice)
# No new deps needed
```

---

## Implementation Plan

### Phase 1: STT Foundation (1-2 days)
1. Implement `audio_capture.py` (mirror of audio_player.py)
2. Implement `stt_engine.py` (faster-whisper wrapper)
3. Implement `stt_orchestrator.py` (coordination)
4. Add STT tools to MCP server
5. Test: Mic → Transcript → Console

### Phase 2: UI Controls (1 day)
1. Implement `ui_controller.py` (system tray + modal)
2. Add hotkey support
3. Wire UI to orchestrators
4. Test: Toggle mic/TTS from UI

### Phase 3: Prompt Enhancement (1 day)
1. Implement `prompt_enhancer.py`
2. Add Ollama integration
3. Add enhancement toggle
4. Test: Raw → Enhanced flow

### Phase 4: Integration (1 day)
1. Wire all components together
2. Add status indicators
3. Error handling and fallbacks
4. End-to-end testing

---

## STT Solution Recommendation

**Primary Choice: Faster-Whisper**

| Criteria | Faster-Whisper | Vosk | Azure STT |
|----------|----------------|------|-----------|
| Accuracy | Excellent | Good | Excellent |
| Latency | 200-500ms | 100-200ms | 100-300ms |
| Offline | Yes | Yes | No |
| Cost | Free | Free | Paid |
| Setup | Easy | Easy | Complex |
| Streaming | Yes (with VAD) | Yes | Yes |
| Languages | 99+ | 20+ | 100+ |
| Model Size | 150MB-3GB | 50MB-1.4GB | N/A |

**Recommended Model: `base` (150MB)**
- Good balance of speed and accuracy
- Works well on CPU
- Fast enough for real-time (<500ms)

---

## Sources

- [Faster-Whisper GitHub](https://github.com/SYSTRAN/faster-whisper)
- [Modal Blog: Open Source STT Models 2025](https://modal.com/blog/open-source-stt)
- [Notta: Best Free STT Engines](https://www.notta.ai/en/blog/speech-to-text-open-source)
- [pystray Documentation](https://pystray.readthedocs.io/en/latest/usage.html)
- [PySimpleGUI psgtray](https://github.com/PySimpleGUI/psgtray)

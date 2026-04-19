# Workshop `voice` service -- dual-engine (Piper + Coqui XTTS) TTS.
# Build context must be `ClaudeSpeak/` so both sibling packages are visible.
#
#   docker build -t workshop-voice:0.2.0 -f claude-voice-connector-http/Dockerfile .
#
# Layers (top-to-bottom, rarely-changed first so rebuilds stay fast):
#   - apt deps (libgomp1 for onnxruntime, libportaudio2 for sounddevice import,
#     curl for healthcheck)
#   - pip deps (largest layer: torch + coqui-tts for XTTS, ~3.5 GB)
#   - bundled Piper ONNX voices (5 total: jenny, amy, alba, ryan, lessac)
#   - pre-downloaded XTTS-v2 model (~1.8 GB)
#   - project source copied LAST
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    COQUI_TOS_AGREED=1 \
    COQUI_TTS_HOME=/opt/tts-cache \
    TORCH_HOME=/opt/torch-cache

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libgomp1 libportaudio2 ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# --- 1. Python deps (largest layer, changes rarely) ---------------------------
COPY claude-voice-connector-http/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --index-url https://download.pytorch.org/whl/cpu \
      'torch>=2.4,<2.6' 'torchaudio>=2.4,<2.6' \
 && pip install --no-cache-dir -r /tmp/requirements.txt

# --- 2. Extra Piper voices (3 bundled + 2 downloaded = 5 Piper total) ---------
# The sibling stdio package ships 3 voices; fetch 2 more from the public rhasspy
# Hugging Face mirror so we meet the >=5 voices requirement.
RUN set -eux \
 && mkdir -p /app/claude-voice-connector-stdio/models \
 && for voice_path in \
      "en/en_US/ryan/high/en_US-ryan-high" \
      "en/en_US/lessac/medium/en_US-lessac-medium"; do \
      fname=$(basename "$voice_path"); \
      curl -sSL --retry 3 --fail \
        "https://huggingface.co/rhasspy/piper-voices/resolve/main/${voice_path}.onnx" \
        -o "/app/claude-voice-connector-stdio/models/${fname}.onnx"; \
      curl -sSL --retry 3 --fail \
        "https://huggingface.co/rhasspy/piper-voices/resolve/main/${voice_path}.onnx.json" \
        -o "/app/claude-voice-connector-stdio/models/${fname}.onnx.json"; \
    done

# --- 3. Pre-download the Coqui XTTS-v2 model so the first synthesis doesn't
# stall on a 1.8 GB download.  Failure is not fatal; the model will lazy-load
# the first time the learner calls an xtts_ voice.
RUN mkdir -p "$COQUI_TTS_HOME" "$TORCH_HOME" \
 && python -c "from TTS.api import TTS; TTS(model_name='tts_models/multilingual/multi-dataset/xtts_v2', progress_bar=False, gpu=False)" \
    || echo "[voice] XTTS preload failed (non-fatal); will retry at first use."

# --- 4. Copy the source last so code edits don't invalidate the heavy layers ---
COPY claude-voice-connector-stdio /app/claude-voice-connector-stdio
COPY claude-voice-connector-http  /app/claude-voice-connector-http

ENV PYTHONPATH=/app/claude-voice-connector-stdio/src

EXPOSE 7711 7712

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD curl -sf http://127.0.0.1:7712/healthz || exit 1

WORKDIR /app/claude-voice-connector-http
CMD ["python", "run.py"]

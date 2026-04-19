"""Audio playback engine with ring buffer and callback-driven streaming."""

from __future__ import annotations

import asyncio
import threading
import time
from dataclasses import dataclass, field
from enum import Enum
from typing import Callable, Optional

import numpy as np
import sounddevice as sd

from .config import ConnectorConfig
from .logging_setup import get_logger

logger = get_logger("audio_player")


class PlayerState(Enum):
    """Player states."""

    IDLE = "idle"
    PLAYING = "playing"
    PAUSED = "paused"
    STOPPING = "stopping"


@dataclass
class PlaybackStats:
    """Playback statistics."""

    played_samples: int = 0
    underruns: int = 0
    overruns: int = 0
    peak_buffer_samples: int = 0
    sample_rate: int = 24000  # Default, will be updated

    @property
    def played_ms(self) -> int:
        """Played audio in milliseconds."""
        return int(self.played_samples * 1000 / self.sample_rate)


class RingBuffer:
    """Lock-free ring buffer for audio samples.

    Uses numpy arrays with atomic index operations for thread-safe
    producer-consumer pattern.
    """

    def __init__(self, capacity_samples: int, sample_rate: int = 24000) -> None:
        """Initialize ring buffer.

        Args:
            capacity_samples: Buffer capacity in samples
            sample_rate: Sample rate for ms calculations
        """
        self.capacity = capacity_samples
        self.sample_rate = sample_rate
        self.buffer = np.zeros(capacity_samples, dtype=np.int16)
        self._write_pos = 0
        self._read_pos = 0
        self._lock = threading.Lock()

    def write(self, data: np.ndarray) -> int:
        """Write samples to buffer.

        Args:
            data: Audio samples (int16)

        Returns:
            Number of samples actually written
        """
        with self._lock:
            available = self.capacity - self.available_read()
            to_write = min(len(data), available)

            if to_write == 0:
                return 0

            # Write in up to two chunks (wrap around)
            end_pos = (self._write_pos + to_write) % self.capacity
            if end_pos > self._write_pos:
                # Single contiguous write
                self.buffer[self._write_pos : end_pos] = data[:to_write]
            else:
                # Wrap around
                first_chunk = self.capacity - self._write_pos
                self.buffer[self._write_pos :] = data[:first_chunk]
                self.buffer[:end_pos] = data[first_chunk:to_write]

            self._write_pos = end_pos
            return to_write

    def read(self, count: int) -> np.ndarray:
        """Read samples from buffer.

        Args:
            count: Number of samples to read

        Returns:
            Audio samples (may be fewer than requested)
        """
        with self._lock:
            available = self.available_read()
            to_read = min(count, available)

            if to_read == 0:
                return np.zeros(0, dtype=np.int16)

            end_pos = (self._read_pos + to_read) % self.capacity
            if end_pos > self._read_pos:
                # Single contiguous read
                data = self.buffer[self._read_pos : end_pos].copy()
            else:
                # Wrap around
                first_chunk = self.capacity - self._read_pos
                data = np.concatenate(
                    [self.buffer[self._read_pos :], self.buffer[:end_pos]]
                )

            self._read_pos = end_pos
            return data

    def available_read(self) -> int:
        """Number of samples available to read."""
        if self._write_pos >= self._read_pos:
            return self._write_pos - self._read_pos
        return self.capacity - self._read_pos + self._write_pos

    def available_write(self) -> int:
        """Number of samples that can be written."""
        return self.capacity - self.available_read() - 1

    def clear(self) -> None:
        """Clear the buffer."""
        with self._lock:
            self._read_pos = 0
            self._write_pos = 0

    @property
    def buffered_ms(self) -> int:
        """Buffered audio in milliseconds."""
        return int(self.available_read() * 1000 / self.sample_rate)


class AudioPlayer:
    """Callback-based audio player with ring buffer."""

    def __init__(self, config: ConnectorConfig) -> None:
        """Initialize audio player.

        Args:
            config: Connector configuration
        """
        self.config = config
        self.sample_rate = config.sample_rate_hz
        self.channels = config.channels

        # Calculate buffer size in samples
        buffer_samples = int(config.ring_buffer_ms * self.sample_rate / 1000)
        self.ring_buffer = RingBuffer(buffer_samples, self.sample_rate)

        self.state = PlayerState.IDLE
        self.stats = PlaybackStats()
        self.stats.sample_rate = self.sample_rate  # Set actual sample rate

        self._stream: Optional[sd.OutputStream] = None
        self._stop_event = threading.Event()
        self._first_audio_callback: Optional[Callable[[], None]] = None
        self._underrun_callback: Optional[Callable[[], None]] = None
        self._first_audio_fired = False

        # Backpressure tracking (convert bytes to samples: bytes / bytes_per_sample)
        self._buffer_high_water = config.max_buffer_bytes // config.bytes_per_sample
        self._buffer_low_water = config.min_buffer_bytes // config.bytes_per_sample
        self._paused_for_backpressure = asyncio.Event()
        self._paused_for_backpressure.set()  # Not paused initially

        logger.info(
            f"AudioPlayer initialized: {self.sample_rate}Hz, "
            f"buffer={config.ring_buffer_ms}ms, device={config.device_index}"
        )

    def _audio_callback(
        self,
        outdata: np.ndarray,
        frames: int,
        time_info: dict,
        status: sd.CallbackFlags,
    ) -> None:
        """Audio callback called by sounddevice.

        This runs in a separate thread - must be thread-safe.
        """
        if status.output_underflow:
            self.stats.underruns += 1
            if self._underrun_callback:
                self._underrun_callback()
            logger.warning("Audio underrun detected")

        # Read from ring buffer
        data = self.ring_buffer.read(frames)

        if len(data) < frames:
            # Pad with silence
            outdata[:len(data), 0] = data
            outdata[len(data):, 0] = 0
            if len(data) > 0 and self.state == PlayerState.PLAYING:
                self.stats.underruns += 1
        else:
            outdata[:, 0] = data

        self.stats.played_samples += len(data)

        # Track peak buffer
        current = self.ring_buffer.available_read()
        if current > self.stats.peak_buffer_samples:
            self.stats.peak_buffer_samples = current

        # Fire first audio callback
        if not self._first_audio_fired and len(data) > 0:
            self._first_audio_fired = True
            if self._first_audio_callback:
                self._first_audio_callback()

    def start(self) -> None:
        """Start audio playback stream."""
        if self._stream is not None:
            return

        self._stop_event.clear()
        self._first_audio_fired = False

        try:
            device = self.config.device_index
            if device is not None and isinstance(device, str):
                # Find device by name
                devices = sd.query_devices()
                for i, d in enumerate(devices):
                    if device.lower() in d["name"].lower():
                        device = i
                        break
                else:
                    logger.warning(f"Device '{device}' not found, using default")
                    device = None

            self._stream = sd.OutputStream(
                samplerate=self.sample_rate,
                channels=self.channels,
                dtype=np.int16,
                callback=self._audio_callback,
                device=device,
                latency=0.2,    # 200ms latency for smooth local playback
                blocksize=2048,  # Large blocks for highest quality
            )
            self._stream.start()
            self.state = PlayerState.PLAYING
            logger.info("Audio stream started")

        except Exception as e:
            logger.error(f"Failed to start audio stream: {e}")
            raise

    async def start_async(self) -> None:
        """Async start (wraps sync start)."""
        self.start()

    def stop(self) -> None:
        """Stop audio playback."""
        self._stop_event.set()
        self.state = PlayerState.STOPPING

        if self._stream is not None:
            try:
                self._stream.stop()
                self._stream.close()
            except Exception as e:
                logger.warning(f"Error stopping stream: {e}")
            self._stream = None

        self.ring_buffer.clear()
        self.state = PlayerState.IDLE
        logger.info("Audio stream stopped")

    async def stop_async(self) -> None:
        """Async stop (wraps sync stop)."""
        self.stop()

    # Async aliases for cleaner API
    async def write(self, data: bytes | np.ndarray) -> int:
        """Async write with backpressure. Alias for write_pcm_async."""
        return await self.write_pcm_async(data)

    async def drain(self, timeout: float = 30.0) -> bool:
        """Wait for buffer to drain. Alias for wait_for_drain."""
        return await self.wait_for_drain(timeout)

    def write_pcm(self, data: bytes | np.ndarray) -> int:
        """Write PCM audio data to the playback buffer.

        Args:
            data: PCM audio data (int16, mono, 16kHz)

        Returns:
            Number of samples written
        """
        if isinstance(data, bytes):
            samples = np.frombuffer(data, dtype=np.int16)
        else:
            samples = data

        written = self.ring_buffer.write(samples)

        if written < len(samples):
            self.stats.overruns += 1
            logger.warning(f"Buffer overrun: dropped {len(samples) - written} samples")

        return written

    async def write_pcm_async(self, data: bytes | np.ndarray) -> int:
        """Async write with backpressure handling.

        Waits if buffer is too full.

        Args:
            data: PCM audio data

        Returns:
            Number of samples written
        """
        # Check backpressure
        while self.ring_buffer.available_read() > self._buffer_high_water:
            if self.state != PlayerState.PLAYING:
                break
            await asyncio.sleep(0.01)  # 10ms

        return self.write_pcm(data)

    def is_buffer_low(self) -> bool:
        """Check if buffer is below low water mark."""
        return self.ring_buffer.available_read() < self._buffer_low_water

    def is_buffer_high(self) -> bool:
        """Check if buffer is above high water mark."""
        return self.ring_buffer.available_read() > self._buffer_high_water

    @property
    def buffered_ms(self) -> int:
        """Current buffered audio in milliseconds."""
        return self.ring_buffer.buffered_ms

    @property
    def played_ms(self) -> int:
        """Total played audio in milliseconds."""
        return self.stats.played_ms

    @property
    def is_playing(self) -> bool:
        """Check if currently playing."""
        return self.state == PlayerState.PLAYING

    @property
    def underruns(self) -> int:
        """Total underrun count."""
        return self.stats.underruns

    @property
    def overruns(self) -> int:
        """Total overrun count."""
        return self.stats.overruns

    def set_first_audio_callback(self, callback: Callable[[], None]) -> None:
        """Set callback for first audio output.

        Args:
            callback: Function to call when first audio plays
        """
        self._first_audio_callback = callback

    def set_underrun_callback(self, callback: Callable[[], None]) -> None:
        """Set callback for underrun events.

        Args:
            callback: Function to call on underrun
        """
        self._underrun_callback = callback

    async def wait_for_drain(self, timeout: float = 30.0) -> bool:
        """Wait for buffer to drain completely.

        Args:
            timeout: Maximum wait time in seconds

        Returns:
            True if drained, False if timeout
        """
        start = time.monotonic()
        while self.ring_buffer.available_read() > 0:
            if time.monotonic() - start > timeout:
                return False
            await asyncio.sleep(0.05)
        return True

    def get_device_info(self) -> dict:
        """Get information about the current audio device."""
        try:
            device = self.config.device_index
            if device is None:
                device = sd.default.device[1]  # Output device
            info = sd.query_devices(device)
            return {
                "name": info["name"],
                "sample_rate": info["default_samplerate"],
                "channels": info["max_output_channels"],
            }
        except Exception as e:
            return {"error": str(e)}

    @staticmethod
    def list_devices() -> list[dict]:
        """List available audio devices."""
        devices = []
        for i, d in enumerate(sd.query_devices()):
            if d["max_output_channels"] > 0:
                devices.append(
                    {
                        "index": i,
                        "name": d["name"],
                        "sample_rate": d["default_samplerate"],
                        "channels": d["max_output_channels"],
                    }
                )
        return devices

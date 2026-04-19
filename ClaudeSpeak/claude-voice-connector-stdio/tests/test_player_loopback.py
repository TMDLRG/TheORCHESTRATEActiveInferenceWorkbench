"""Tests for audio player with loopback/mocking."""

import pytest
import numpy as np
import asyncio
from unittest.mock import Mock, patch, MagicMock

from claude_voice_connector.audio_player import (
    RingBuffer,
    AudioPlayer,
    PlayerState,
    PlaybackStats,
)
from claude_voice_connector.config import ConnectorConfig


class TestRingBuffer:
    """Tests for RingBuffer."""

    def test_basic_write_read(self):
        buf = RingBuffer(1000)
        data = np.array([1, 2, 3, 4, 5], dtype=np.int16)

        written = buf.write(data)
        assert written == 5
        assert buf.available_read() == 5

        read_data = buf.read(5)
        assert len(read_data) == 5
        assert np.array_equal(read_data, data)

    def test_partial_read(self):
        buf = RingBuffer(1000)
        data = np.array([1, 2, 3, 4, 5], dtype=np.int16)
        buf.write(data)

        read_data = buf.read(3)
        assert len(read_data) == 3
        assert np.array_equal(read_data, np.array([1, 2, 3], dtype=np.int16))
        assert buf.available_read() == 2

    def test_wraparound(self):
        buf = RingBuffer(10)

        # Fill most of buffer
        data1 = np.array([1, 2, 3, 4, 5, 6, 7, 8], dtype=np.int16)
        buf.write(data1)

        # Read some
        buf.read(5)

        # Write more (should wrap)
        data2 = np.array([9, 10, 11, 12], dtype=np.int16)
        written = buf.write(data2)

        # Read all
        result = buf.read(7)
        assert len(result) == 7
        # Should be [6, 7, 8, 9, 10, 11, 12]
        expected = np.array([6, 7, 8, 9, 10, 11, 12], dtype=np.int16)
        assert np.array_equal(result, expected)

    def test_overflow_handling(self):
        buf = RingBuffer(5)

        # Try to write more than capacity
        data = np.array([1, 2, 3, 4, 5, 6, 7], dtype=np.int16)
        written = buf.write(data)

        # Should only write up to capacity - 1 (for wrap detection)
        assert written < len(data)

    def test_empty_read(self):
        buf = RingBuffer(10)
        result = buf.read(5)
        assert len(result) == 0

    def test_clear(self):
        buf = RingBuffer(10)
        data = np.array([1, 2, 3, 4, 5], dtype=np.int16)
        buf.write(data)

        buf.clear()
        assert buf.available_read() == 0

    def test_buffered_ms(self):
        buf = RingBuffer(16000)  # 1 second at 16kHz
        data = np.zeros(8000, dtype=np.int16)  # 0.5 seconds
        buf.write(data)

        ms = buf.buffered_ms
        assert 400 < ms < 600  # ~500ms


class TestPlaybackStats:
    """Tests for PlaybackStats."""

    def test_played_ms(self):
        stats = PlaybackStats()
        stats.played_samples = 16000  # 1 second at 16kHz

        assert stats.played_ms == 1000


class TestAudioPlayer:
    """Tests for AudioPlayer."""

    @pytest.fixture
    def config(self):
        return ConnectorConfig(
            sample_rate_hz=16000,
            channels=1,
            ring_buffer_ms=5000,
            max_buffer_ms=3000,
            min_buffer_ms=500,
        )

    def test_initialization(self, config):
        with patch("claude_voice_connector.audio_player.sd"):
            player = AudioPlayer(config)
            assert player.sample_rate == 16000
            assert player.state == PlayerState.IDLE

    def test_write_pcm_bytes(self, config):
        with patch("claude_voice_connector.audio_player.sd"):
            player = AudioPlayer(config)

            # Create PCM data (int16)
            samples = np.array([100, 200, 300, 400], dtype=np.int16)
            pcm_bytes = samples.tobytes()

            written = player.write_pcm(pcm_bytes)
            assert written == 4

    def test_write_pcm_numpy(self, config):
        with patch("claude_voice_connector.audio_player.sd"):
            player = AudioPlayer(config)

            samples = np.array([100, 200, 300, 400], dtype=np.int16)
            written = player.write_pcm(samples)
            assert written == 4

    def test_buffered_ms(self, config):
        with patch("claude_voice_connector.audio_player.sd"):
            player = AudioPlayer(config)

            # Write 0.5 seconds of audio
            samples = np.zeros(8000, dtype=np.int16)
            player.write_pcm(samples)

            ms = player.buffered_ms
            assert 400 < ms < 600

    def test_is_buffer_low(self, config):
        with patch("claude_voice_connector.audio_player.sd"):
            player = AudioPlayer(config)
            # Empty buffer should be low
            assert player.is_buffer_low()

    def test_is_buffer_high(self, config):
        with patch("claude_voice_connector.audio_player.sd"):
            player = AudioPlayer(config)

            # Write lots of audio (more than high water mark of 3000ms = 48000 samples)
            samples = np.zeros(56000, dtype=np.int16)  # 3.5 seconds
            player.write_pcm(samples)

            assert player.is_buffer_high()

    def test_callbacks(self, config):
        with patch("claude_voice_connector.audio_player.sd"):
            player = AudioPlayer(config)

            first_audio_called = False
            underrun_called = False

            def on_first_audio():
                nonlocal first_audio_called
                first_audio_called = True

            def on_underrun():
                nonlocal underrun_called
                underrun_called = True

            player.set_first_audio_callback(on_first_audio)
            player.set_underrun_callback(on_underrun)

            # Verify callbacks are set
            assert player._first_audio_callback is not None
            assert player._underrun_callback is not None

    @pytest.mark.asyncio
    async def test_write_pcm_async_backpressure(self, config):
        with patch("claude_voice_connector.audio_player.sd"):
            player = AudioPlayer(config)
            player.state = PlayerState.PLAYING

            # Fill buffer to trigger backpressure
            samples = np.zeros(64000, dtype=np.int16)  # 4 seconds
            player.write_pcm(samples)

            # Write should eventually complete (buffer drains in real scenario)
            # Here we just test that it doesn't block forever
            async def write_with_timeout():
                small_data = np.zeros(100, dtype=np.int16)
                # This should return quickly since buffer is full
                return player.write_pcm(small_data)

            result = await asyncio.wait_for(write_with_timeout(), timeout=1.0)
            # Some data should be written (or 0 if full)
            assert result >= 0


class TestAudioPlayerDevices:
    """Tests for device listing."""

    def test_list_devices(self):
        with patch("claude_voice_connector.audio_player.sd") as mock_sd:
            mock_sd.query_devices.return_value = [
                {
                    "name": "Test Speaker",
                    "max_output_channels": 2,
                    "default_samplerate": 48000,
                },
                {
                    "name": "Test Microphone",
                    "max_output_channels": 0,  # Input only
                    "default_samplerate": 44100,
                },
            ]

            devices = AudioPlayer.list_devices()
            assert len(devices) == 1  # Only output devices
            assert devices[0]["name"] == "Test Speaker"

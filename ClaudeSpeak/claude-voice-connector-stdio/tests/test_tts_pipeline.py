"""Tests for TTS pipeline integration."""

import pytest
import asyncio
from unittest.mock import Mock, patch, AsyncMock, MagicMock

from claude_voice_connector.tts_edge import (
    EdgeTTSWrapper,
    TTSChunk,
    VoiceInfo,
    MP3Decoder,
    pcm_to_samples,
    samples_to_pcm,
)
from claude_voice_connector.config import ConnectorConfig


class TestTTSChunk:
    """Tests for TTSChunk."""

    def test_basic_chunk(self):
        chunk = TTSChunk(data=b"\x00\x01\x02\x03", duration_ms=100, is_final=False)
        assert len(chunk.data) == 4
        assert chunk.duration_ms == 100
        assert not chunk.is_final

    def test_final_chunk(self):
        chunk = TTSChunk(data=b"", duration_ms=0, is_final=True)
        assert chunk.is_final


class TestVoiceInfo:
    """Tests for VoiceInfo."""

    def test_to_dict(self):
        voice = VoiceInfo(
            name="Microsoft AriaNeural",
            short_name="en-US-AriaNeural",
            gender="Female",
            locale="en-US",
        )
        d = voice.to_dict()
        assert d["name"] == "Microsoft AriaNeural"
        assert d["short_name"] == "en-US-AriaNeural"
        assert d["gender"] == "Female"
        assert d["locale"] == "en-US"


class TestMP3Decoder:
    """Tests for MP3Decoder."""

    def test_initialization(self):
        decoder = MP3Decoder(target_rate=16000)
        assert decoder.target_rate == 16000
        assert decoder._buffer == b""

    def test_flush_empty(self):
        decoder = MP3Decoder()
        result = decoder.flush()
        assert result == b""


class TestEdgeTTSWrapper:
    """Tests for EdgeTTSWrapper."""

    @pytest.fixture
    def config(self):
        return ConnectorConfig(
            voice="en-US-AriaNeural",
            rate="+0%",
            pitch="+0Hz",
            volume="+0%",
            sample_rate_hz=16000,
        )

    def test_initialization(self, config):
        wrapper = EdgeTTSWrapper(config)
        assert wrapper.default_voice == "en-US-AriaNeural"
        assert wrapper.default_rate == "+0%"

    @pytest.mark.asyncio
    async def test_list_voices_mock(self, config):
        with patch("claude_voice_connector.tts_edge.edge_tts") as mock_edge_tts:
            mock_edge_tts.list_voices = AsyncMock(
                return_value=[
                    {
                        "Name": "Microsoft AriaNeural",
                        "ShortName": "en-US-AriaNeural",
                        "Gender": "Female",
                        "Locale": "en-US",
                    },
                    {
                        "Name": "Microsoft GuyNeural",
                        "ShortName": "en-US-GuyNeural",
                        "Gender": "Male",
                        "Locale": "en-US",
                    },
                ]
            )

            wrapper = EdgeTTSWrapper(config)
            voices = await wrapper.list_voices()

            assert len(voices) == 2
            assert voices[0].short_name == "en-US-AriaNeural"
            assert voices[1].short_name == "en-US-GuyNeural"

    @pytest.mark.asyncio
    async def test_check_voice_mock(self, config):
        with patch("claude_voice_connector.tts_edge.edge_tts") as mock_edge_tts:
            mock_edge_tts.list_voices = AsyncMock(
                return_value=[
                    {
                        "Name": "Microsoft AriaNeural",
                        "ShortName": "en-US-AriaNeural",
                        "Gender": "Female",
                        "Locale": "en-US",
                    },
                ]
            )

            wrapper = EdgeTTSWrapper(config)

            assert await wrapper.check_voice("en-US-AriaNeural")
            assert not await wrapper.check_voice("nonexistent-voice")


class TestPCMConversion:
    """Tests for PCM conversion utilities."""

    def test_pcm_to_samples(self):
        import numpy as np

        # Create PCM bytes (int16, little-endian)
        pcm = b"\x00\x01\x00\x02\x00\x03"  # 3 samples: 256, 512, 768
        samples = pcm_to_samples(pcm)

        assert len(samples) == 3
        assert samples.dtype == np.int16

    def test_samples_to_pcm(self):
        import numpy as np

        samples = np.array([256, 512, 768], dtype=np.int16)
        pcm = samples_to_pcm(samples)

        assert isinstance(pcm, bytes)
        assert len(pcm) == 6  # 3 samples * 2 bytes

    def test_round_trip(self):
        import numpy as np

        original = np.array([100, 200, 300, 400, 500], dtype=np.int16)
        pcm = samples_to_pcm(original)
        recovered = pcm_to_samples(pcm)

        assert np.array_equal(original, recovered)


class TestSynthesizeStreaming:
    """Tests for streaming synthesis with mocks."""

    @pytest.fixture
    def config(self):
        return ConnectorConfig(
            voice="en-US-AriaNeural",
            sample_rate_hz=16000,
        )

    @pytest.mark.asyncio
    async def test_synthesize_streaming_mock(self, config):
        """Test streaming synthesis with mocked edge_tts."""
        with patch("claude_voice_connector.tts_edge.edge_tts") as mock_edge_tts:
            # Mock the Communicate class
            mock_communicate = MagicMock()

            # Create async generator for stream
            async def mock_stream():
                yield {"type": "audio", "data": b"\x00" * 100}
                yield {"type": "audio", "data": b"\x00" * 100}

            mock_communicate.stream = mock_stream
            mock_edge_tts.Communicate.return_value = mock_communicate

            wrapper = EdgeTTSWrapper(config)

            chunks = []
            ssml = '<speak version="1.0">Hello world</speak>'

            # Patch MP3Decoder to return test data
            with patch(
                "claude_voice_connector.tts_edge.MP3Decoder"
            ) as mock_decoder_class:
                mock_decoder = MagicMock()
                mock_decoder.decode_chunk.return_value = b"\x00\x00" * 100
                mock_decoder.flush.return_value = b""
                mock_decoder_class.return_value = mock_decoder

                async for chunk in wrapper.synthesize_streaming(ssml):
                    chunks.append(chunk)

            # Should have received chunks
            assert len(chunks) > 0
            # Last chunk should be marked final
            assert chunks[-1].is_final

    @pytest.mark.asyncio
    async def test_synthesize_batch_mock(self, config):
        """Test batch synthesis."""
        with patch("claude_voice_connector.tts_edge.edge_tts") as mock_edge_tts:
            mock_communicate = MagicMock()

            async def mock_stream():
                yield {"type": "audio", "data": b"\x00" * 100}

            mock_communicate.stream = mock_stream
            mock_edge_tts.Communicate.return_value = mock_communicate

            wrapper = EdgeTTSWrapper(config)

            with patch(
                "claude_voice_connector.tts_edge.MP3Decoder"
            ) as mock_decoder_class:
                mock_decoder = MagicMock()
                mock_decoder.decode_chunk.return_value = b"\x00\x00" * 50
                mock_decoder.flush.return_value = b""
                mock_decoder_class.return_value = mock_decoder

                ssml = '<speak version="1.0">Hello</speak>'
                result = await wrapper.synthesize_batch(ssml)

                assert isinstance(result, bytes)
                assert len(result) > 0

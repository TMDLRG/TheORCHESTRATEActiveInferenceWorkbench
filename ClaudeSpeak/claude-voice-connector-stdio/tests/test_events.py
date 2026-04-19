"""Tests for event schemas."""

import pytest
from datetime import datetime, timezone

from claude_voice_connector.events import (
    EventType,
    ErrorCode,
    PlaybackMode,
    SegmentResult,
    AckEvent,
    ProgressEvent,
    CompleteEvent,
    ErrorEvent,
    StatusEvent,
    VoicesEvent,
    StoppedEvent,
    FlushedEvent,
    create_error,
)


class TestSegmentResult:
    """Tests for SegmentResult."""

    def test_to_dict_success(self):
        result = SegmentResult(seq=0, duration_ms=1000, ok=True)
        d = result.to_dict()
        assert d["seq"] == 0
        assert d["duration_ms"] == 1000
        assert d["ok"] is True
        assert "error" not in d

    def test_to_dict_failure(self):
        result = SegmentResult(seq=1, duration_ms=0, ok=False, error="TTS failed")
        d = result.to_dict()
        assert d["ok"] is False
        assert d["error"] == "TTS failed"


class TestAckEvent:
    """Tests for AckEvent."""

    def test_to_dict(self):
        event = AckEvent(
            id="test-id",
            mode=PlaybackMode.STREAM,
            accepted_at="2024-01-01T00:00:00Z",
        )
        d = event.to_dict()
        assert d["type"] == "ack"
        assert d["id"] == "test-id"
        assert d["mode"] == "stream"
        assert d["accepted_at"] == "2024-01-01T00:00:00Z"

    def test_default_timestamp(self):
        event = AckEvent(id="test", mode=PlaybackMode.BATCH)
        d = event.to_dict()
        # Should have a timestamp
        assert "accepted_at" in d
        assert len(d["accepted_at"]) > 0


class TestProgressEvent:
    """Tests for ProgressEvent."""

    def test_to_dict(self):
        event = ProgressEvent(id="test-id", played_ms=1000, buffered_ms=2000)
        d = event.to_dict()
        assert d["type"] == "progress"
        assert d["id"] == "test-id"
        assert d["played_ms"] == 1000
        assert d["buffered_ms"] == 2000


class TestCompleteEvent:
    """Tests for CompleteEvent."""

    def test_to_dict(self):
        segments = [
            SegmentResult(seq=0, duration_ms=1000, ok=True),
            SegmentResult(seq=1, duration_ms=1500, ok=True),
        ]
        event = CompleteEvent(id="test-id", played_ms=2500, segments=segments)
        d = event.to_dict()

        assert d["type"] == "complete"
        assert d["id"] == "test-id"
        assert d["played_ms"] == 2500
        assert len(d["segments"]) == 2
        assert d["segments"][0]["seq"] == 0
        assert d["segments"][1]["seq"] == 1


class TestErrorEvent:
    """Tests for ErrorEvent."""

    def test_to_dict_with_id(self):
        event = ErrorEvent(
            id="test-id",
            code=ErrorCode.TTS_ERROR,
            message="Synthesis failed",
            retryable=True,
        )
        d = event.to_dict()
        assert d["type"] == "error"
        assert d["id"] == "test-id"
        assert d["code"] == "TTS_ERROR"
        assert d["message"] == "Synthesis failed"
        assert d["retryable"] is True

    def test_to_dict_without_id(self):
        event = ErrorEvent(
            id=None,
            code=ErrorCode.BAD_CMD,
            message="Invalid command",
            retryable=False,
        )
        d = event.to_dict()
        assert "id" not in d
        assert d["code"] == "BAD_CMD"


class TestStatusEvent:
    """Tests for StatusEvent."""

    def test_to_dict(self):
        event = StatusEvent(
            queue_size=2,
            playing=True,
            buffered_ms=3000,
            underruns=1,
            overruns=0,
            current_request_id="active-id",
        )
        d = event.to_dict()
        assert d["type"] == "status"
        assert d["queue_size"] == 2
        assert d["playing"] is True
        assert d["buffered_ms"] == 3000
        assert d["underruns"] == 1
        assert d["overruns"] == 0
        assert d["current_request_id"] == "active-id"


class TestVoicesEvent:
    """Tests for VoicesEvent."""

    def test_to_dict(self):
        voices = [
            {"name": "en-US-AriaNeural", "locale": "en-US"},
            {"name": "en-US-GuyNeural", "locale": "en-US"},
        ]
        event = VoicesEvent(items=voices)
        d = event.to_dict()
        assert d["type"] == "voices"
        assert len(d["items"]) == 2


class TestSimpleEvents:
    """Tests for simple events."""

    def test_stopped_event(self):
        event = StoppedEvent()
        d = event.to_dict()
        assert d["type"] == "stopped"

    def test_flushed_event(self):
        event = FlushedEvent()
        d = event.to_dict()
        assert d["type"] == "flushed"


class TestCreateError:
    """Tests for create_error helper."""

    def test_with_error_code_enum(self):
        event = create_error(
            ErrorCode.AUDIO_UNDERRUN,
            "Buffer underrun",
            "req-123",
            retryable=True,
        )
        assert event.code == ErrorCode.AUDIO_UNDERRUN
        assert event.id == "req-123"
        assert event.retryable is True

    def test_with_string_code(self):
        event = create_error("TTS_ERROR", "TTS failed", None)
        assert event.code == ErrorCode.TTS_ERROR

    def test_with_invalid_string_code(self):
        event = create_error("INVALID_CODE", "Something failed", None)
        assert event.code == ErrorCode.INTERNAL_ERROR


class TestEventTypes:
    """Tests for EventType enum."""

    def test_values(self):
        assert EventType.ACK.value == "ack"
        assert EventType.PROGRESS.value == "progress"
        assert EventType.COMPLETE.value == "complete"
        assert EventType.ERROR.value == "error"
        assert EventType.STOPPED.value == "stopped"
        assert EventType.FLUSHED.value == "flushed"
        assert EventType.STATUS.value == "status"
        assert EventType.VOICES.value == "voices"


class TestErrorCodes:
    """Tests for ErrorCode enum."""

    def test_input_errors(self):
        assert ErrorCode.BAD_CMD.value == "BAD_CMD"
        assert ErrorCode.BAD_SSML.value == "BAD_SSML"
        assert ErrorCode.SSML_TOO_LARGE.value == "SSML_TOO_LARGE"

    def test_tts_errors(self):
        assert ErrorCode.TTS_UNAVAILABLE.value == "TTS_UNAVAILABLE"
        assert ErrorCode.TTS_TIMEOUT.value == "TTS_TIMEOUT"
        assert ErrorCode.TTS_ERROR.value == "TTS_ERROR"

    def test_audio_errors(self):
        assert ErrorCode.AUDIO_DEVICE_ERROR.value == "AUDIO_DEVICE_ERROR"
        assert ErrorCode.AUDIO_UNDERRUN.value == "AUDIO_UNDERRUN"
        assert ErrorCode.AUDIO_OVERRUN.value == "AUDIO_OVERRUN"

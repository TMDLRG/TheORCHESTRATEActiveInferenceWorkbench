"""Event schemas and helpers for NDJSON protocol."""

from __future__ import annotations

from dataclasses import dataclass, field, asdict
from datetime import datetime, timezone
from enum import Enum
from typing import Any, Optional


class EventType(str, Enum):
    """Event types emitted by the connector."""

    ACK = "ack"
    PROGRESS = "progress"
    COMPLETE = "complete"
    ERROR = "error"
    STOPPED = "stopped"
    FLUSHED = "flushed"
    STATUS = "status"
    VOICES = "voices"


class ErrorCode(str, Enum):
    """Error codes for error events."""

    # Input errors
    BAD_CMD = "BAD_CMD"
    BAD_SSML = "BAD_SSML"
    SSML_TOO_LARGE = "SSML_TOO_LARGE"
    MISSING_FIELD = "MISSING_FIELD"

    # TTS errors
    TTS_UNAVAILABLE = "TTS_UNAVAILABLE"
    TTS_TIMEOUT = "TTS_TIMEOUT"
    TTS_ERROR = "TTS_ERROR"
    VOICE_NOT_FOUND = "VOICE_NOT_FOUND"

    # Audio errors
    AUDIO_DEVICE_ERROR = "AUDIO_DEVICE_ERROR"
    AUDIO_UNDERRUN = "AUDIO_UNDERRUN"
    AUDIO_OVERRUN = "AUDIO_OVERRUN"

    # Internal errors
    INTERNAL_ERROR = "INTERNAL_ERROR"
    EXC = "EXC"


class PlaybackMode(str, Enum):
    """Playback modes."""

    STREAM = "stream"
    BATCH = "batch"


@dataclass
class SegmentResult:
    """Result for a single segment."""

    seq: int
    duration_ms: int
    ok: bool
    error: Optional[str] = None

    def to_dict(self) -> dict[str, Any]:
        d = {"seq": self.seq, "duration_ms": self.duration_ms, "ok": self.ok}
        if self.error:
            d["error"] = self.error
        return d


@dataclass
class AckEvent:
    """Acknowledgment event."""

    id: str
    mode: PlaybackMode
    accepted_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())

    def to_dict(self) -> dict[str, Any]:
        return {
            "type": EventType.ACK.value,
            "id": self.id,
            "mode": self.mode.value,
            "accepted_at": self.accepted_at,
        }


@dataclass
class ProgressEvent:
    """Progress event."""

    id: str
    played_ms: int
    buffered_ms: int

    def to_dict(self) -> dict[str, Any]:
        return {
            "type": EventType.PROGRESS.value,
            "id": self.id,
            "played_ms": self.played_ms,
            "buffered_ms": self.buffered_ms,
        }


@dataclass
class CompleteEvent:
    """Completion event."""

    id: str
    played_ms: int
    segments: list[SegmentResult]

    def to_dict(self) -> dict[str, Any]:
        return {
            "type": EventType.COMPLETE.value,
            "id": self.id,
            "played_ms": self.played_ms,
            "segments": [s.to_dict() for s in self.segments],
        }


@dataclass
class ErrorEvent:
    """Error event."""

    id: Optional[str]
    code: ErrorCode
    message: str
    retryable: bool = False

    def to_dict(self) -> dict[str, Any]:
        d: dict[str, Any] = {
            "type": EventType.ERROR.value,
            "code": self.code.value,
            "message": self.message,
            "retryable": self.retryable,
        }
        if self.id:
            d["id"] = self.id
        return d


@dataclass
class StatusEvent:
    """Status response event."""

    queue_size: int
    playing: bool
    buffered_ms: int
    underruns: int
    overruns: int
    current_request_id: Optional[str] = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "type": EventType.STATUS.value,
            "queue_size": self.queue_size,
            "playing": self.playing,
            "buffered_ms": self.buffered_ms,
            "underruns": self.underruns,
            "overruns": self.overruns,
            "current_request_id": self.current_request_id,
        }


@dataclass
class VoicesEvent:
    """Voice list event."""

    items: list[dict[str, Any]]

    def to_dict(self) -> dict[str, Any]:
        return {
            "type": EventType.VOICES.value,
            "items": self.items,
        }


@dataclass
class StoppedEvent:
    """Stopped confirmation event."""

    def to_dict(self) -> dict[str, Any]:
        return {"type": EventType.STOPPED.value}


@dataclass
class FlushedEvent:
    """Flushed confirmation event."""

    def to_dict(self) -> dict[str, Any]:
        return {"type": EventType.FLUSHED.value}


# Type alias for all events
Event = (
    AckEvent
    | ProgressEvent
    | CompleteEvent
    | ErrorEvent
    | StatusEvent
    | VoicesEvent
    | StoppedEvent
    | FlushedEvent
)


def create_error(
    code: ErrorCode | str,
    message: str,
    request_id: Optional[str] = None,
    retryable: bool = False,
) -> ErrorEvent:
    """Create an error event.

    Args:
        code: Error code
        message: Human-readable error message
        request_id: Optional request ID
        retryable: Whether the operation can be retried

    Returns:
        ErrorEvent instance
    """
    if isinstance(code, str):
        try:
            code = ErrorCode(code)
        except ValueError:
            code = ErrorCode.INTERNAL_ERROR

    return ErrorEvent(id=request_id, code=code, message=message, retryable=retryable)

"""ID and sequence utilities for request tracking."""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from typing import Optional


def generate_request_id() -> str:
    """Generate a unique request ID."""
    return str(uuid.uuid4())


def generate_short_id() -> str:
    """Generate a short ID for internal use."""
    return uuid.uuid4().hex[:8]


@dataclass
class SegmentId:
    """Identifier for a segment within a request."""

    request_id: str
    seq: int  # 0-indexed sequence number

    def __str__(self) -> str:
        return f"{self.request_id[:8]}:{self.seq}"

    def __hash__(self) -> int:
        return hash((self.request_id, self.seq))

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, SegmentId):
            return False
        return self.request_id == other.request_id and self.seq == other.seq


class SequenceTracker:
    """Track sequence numbers for ordered playback."""

    def __init__(self, request_id: str) -> None:
        self.request_id = request_id
        self._next_seq = 0
        self._completed: set[int] = set()
        self._total: Optional[int] = None

    def next_segment_id(self) -> SegmentId:
        """Get the next segment ID."""
        seg_id = SegmentId(self.request_id, self._next_seq)
        self._next_seq += 1
        return seg_id

    def mark_complete(self, seq: int) -> None:
        """Mark a segment as completed."""
        self._completed.add(seq)

    def set_total(self, total: int) -> None:
        """Set the total expected segment count."""
        self._total = total

    @property
    def all_complete(self) -> bool:
        """Check if all segments are complete."""
        if self._total is None:
            return False
        return len(self._completed) == self._total

    @property
    def pending_count(self) -> int:
        """Number of segments not yet completed."""
        if self._total is None:
            return self._next_seq - len(self._completed)
        return self._total - len(self._completed)

    @property
    def completed_count(self) -> int:
        """Number of completed segments."""
        return len(self._completed)


def validate_request_id(req_id: Optional[str]) -> str:
    """Validate or generate a request ID.

    Args:
        req_id: Optional request ID from caller

    Returns:
        Valid request ID (generated if not provided)
    """
    if req_id is None:
        return generate_request_id()
    # Basic validation - not empty, reasonable length
    if not req_id or len(req_id) > 256:
        return generate_request_id()
    return req_id

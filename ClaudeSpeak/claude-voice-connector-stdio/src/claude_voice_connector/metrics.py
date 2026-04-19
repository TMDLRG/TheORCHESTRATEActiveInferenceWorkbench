"""Timing and performance metrics tracking."""

from __future__ import annotations

import time
from dataclasses import dataclass, field
from typing import Optional


@dataclass
class TimingMetrics:
    """Timing metrics for a single request."""

    request_id: str
    accepted_at: float = field(default_factory=time.monotonic)

    # Key timestamps
    first_audio_at: Optional[float] = None
    complete_at: Optional[float] = None

    # Segment timings
    segment_gaps_ms: list[float] = field(default_factory=list)

    # Audio metrics
    total_played_ms: int = 0
    total_buffered_ms: int = 0

    @property
    def time_to_first_audio_ms(self) -> Optional[float]:
        """Time from accept to first audio in milliseconds."""
        if self.first_audio_at is None:
            return None
        return (self.first_audio_at - self.accepted_at) * 1000

    @property
    def avg_segment_gap_ms(self) -> float:
        """Average gap between segments in milliseconds."""
        if not self.segment_gaps_ms:
            return 0.0
        return sum(self.segment_gaps_ms) / len(self.segment_gaps_ms)

    @property
    def max_segment_gap_ms(self) -> float:
        """Maximum gap between segments in milliseconds."""
        if not self.segment_gaps_ms:
            return 0.0
        return max(self.segment_gaps_ms)

    def record_first_audio(self) -> None:
        """Record first audio timestamp."""
        if self.first_audio_at is None:
            self.first_audio_at = time.monotonic()

    def record_segment_gap(self, gap_ms: float) -> None:
        """Record a gap between segments."""
        self.segment_gaps_ms.append(gap_ms)

    def record_complete(self, played_ms: int) -> None:
        """Record completion."""
        self.complete_at = time.monotonic()
        self.total_played_ms = played_ms


@dataclass
class GlobalMetrics:
    """Global connector metrics."""

    # Counters
    requests_total: int = 0
    requests_complete: int = 0
    requests_error: int = 0
    segments_total: int = 0

    # Audio health
    underruns: int = 0
    overruns: int = 0

    # Aggregated timings
    _first_audio_times_ms: list[float] = field(default_factory=list)
    _segment_gaps_ms: list[float] = field(default_factory=list)

    def record_request_start(self) -> None:
        """Record a new request."""
        self.requests_total += 1

    def record_request_complete(self, timing: TimingMetrics) -> None:
        """Record request completion with timing data."""
        self.requests_complete += 1

        if timing.time_to_first_audio_ms is not None:
            self._first_audio_times_ms.append(timing.time_to_first_audio_ms)

        self._segment_gaps_ms.extend(timing.segment_gaps_ms)

    def record_request_error(self) -> None:
        """Record a failed request."""
        self.requests_error += 1

    def record_segment(self) -> None:
        """Record a segment processed."""
        self.segments_total += 1

    def record_underrun(self) -> None:
        """Record an audio underrun."""
        self.underruns += 1

    def record_overrun(self) -> None:
        """Record an audio overrun."""
        self.overruns += 1

    @property
    def avg_first_audio_ms(self) -> float:
        """Average time to first audio across all requests."""
        if not self._first_audio_times_ms:
            return 0.0
        return sum(self._first_audio_times_ms) / len(self._first_audio_times_ms)

    @property
    def p95_first_audio_ms(self) -> float:
        """95th percentile time to first audio."""
        if not self._first_audio_times_ms:
            return 0.0
        sorted_times = sorted(self._first_audio_times_ms)
        idx = int(len(sorted_times) * 0.95)
        return sorted_times[min(idx, len(sorted_times) - 1)]

    @property
    def avg_segment_gap_ms(self) -> float:
        """Average segment gap across all requests."""
        if not self._segment_gaps_ms:
            return 0.0
        return sum(self._segment_gaps_ms) / len(self._segment_gaps_ms)

    def to_dict(self) -> dict:
        """Convert to dictionary for status reporting."""
        return {
            "requests_total": self.requests_total,
            "requests_complete": self.requests_complete,
            "requests_error": self.requests_error,
            "segments_total": self.segments_total,
            "underruns": self.underruns,
            "overruns": self.overruns,
            "avg_first_audio_ms": round(self.avg_first_audio_ms, 2),
            "p95_first_audio_ms": round(self.p95_first_audio_ms, 2),
            "avg_segment_gap_ms": round(self.avg_segment_gap_ms, 2),
        }


class MetricsCollector:
    """Collects and manages metrics for the connector."""

    def __init__(self) -> None:
        self.global_metrics = GlobalMetrics()
        self._active_timings: dict[str, TimingMetrics] = {}

    def start_request(self, request_id: str) -> TimingMetrics:
        """Start tracking a new request.

        Args:
            request_id: The request ID

        Returns:
            TimingMetrics instance for this request
        """
        self.global_metrics.record_request_start()
        timing = TimingMetrics(request_id=request_id)
        self._active_timings[request_id] = timing
        return timing

    def get_timing(self, request_id: str) -> Optional[TimingMetrics]:
        """Get timing metrics for a request."""
        return self._active_timings.get(request_id)

    def complete_request(self, request_id: str, played_ms: int) -> Optional[TimingMetrics]:
        """Complete tracking for a request.

        Args:
            request_id: The request ID
            played_ms: Total milliseconds of audio played

        Returns:
            Final TimingMetrics for this request
        """
        timing = self._active_timings.pop(request_id, None)
        if timing:
            timing.record_complete(played_ms)
            self.global_metrics.record_request_complete(timing)
        return timing

    def error_request(self, request_id: str) -> None:
        """Record a request error."""
        self._active_timings.pop(request_id, None)
        self.global_metrics.record_request_error()

    def record_underrun(self) -> None:
        """Record an audio underrun."""
        self.global_metrics.record_underrun()

    def record_overrun(self) -> None:
        """Record an audio overrun."""
        self.global_metrics.record_overrun()

    @property
    def underruns(self) -> int:
        """Total underrun count."""
        return self.global_metrics.underruns

    @property
    def overruns(self) -> int:
        """Total overrun count."""
        return self.global_metrics.overruns

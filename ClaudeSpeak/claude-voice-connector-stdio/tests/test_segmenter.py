"""Tests for SSML segmenter."""

import pytest
from claude_voice_connector.segmenter import (
    segment_ssml,
    needs_segmentation,
    estimate_duration_sec,
    extract_text,
    find_split_points,
    balance_tags,
    Segment,
)


class TestEstimateDuration:
    """Tests for duration estimation."""

    def test_short_text(self):
        # ~150 words per minute, ~6 chars per word
        # 15 chars = 2.5 words = ~1 second
        duration = estimate_duration_sec("Hello world test")
        assert 0.5 < duration < 2.0

    def test_longer_text(self):
        # 600 chars = ~100 words = ~40 seconds
        text = "Hello world test. " * 40
        duration = estimate_duration_sec(text)
        assert 30 < duration < 60


class TestExtractText:
    """Tests for text extraction."""

    def test_simple_ssml(self):
        ssml = "<speak>Hello world</speak>"
        text = extract_text(ssml)
        assert text.strip() == "Hello world"

    def test_with_prosody(self):
        ssml = '<speak><prosody rate="fast">Hello</prosody> world</speak>'
        text = extract_text(ssml)
        assert "Hello" in text
        assert "world" in text
        assert "<prosody" not in text

    def test_with_break(self):
        ssml = '<speak>Hello<break time="500ms"/>world</speak>'
        text = extract_text(ssml)
        assert "Hello" in text
        assert "world" in text


class TestFindSplitPoints:
    """Tests for split point detection."""

    def test_finds_paragraph_boundaries(self):
        content = "First paragraph.</p><p>Second paragraph."
        points = find_split_points(content)
        # Should find the </p> as a split point
        assert len(points) > 0

    def test_finds_sentence_boundaries(self):
        content = "First sentence.</s><s>Second sentence."
        points = find_split_points(content)
        assert len(points) > 0

    def test_finds_punctuation(self):
        content = "First sentence. Second sentence."
        points = find_split_points(content)
        # Should find the period followed by space
        assert len(points) > 0

    def test_finds_breaks(self):
        content = 'Hello<break time="1s"/>world'
        points = find_split_points(content)
        assert len(points) > 0


class TestBalanceTags:
    """Tests for tag balancing."""

    def test_balanced_content(self):
        content = "<prosody>Hello</prosody>"
        closing, opening = balance_tags(content)
        assert closing == ""
        assert opening == ""

    def test_unclosed_tag(self):
        content = "<prosody rate='fast'>Hello"
        closing, opening = balance_tags(content)
        assert "</prosody>" in closing
        assert "<prosody" in opening

    def test_nested_tags(self):
        content = "<p><s>Hello"
        closing, opening = balance_tags(content)
        assert "</s></p>" == closing
        assert "<p><s>" == opening or closing.count("</") == 2

    def test_self_closing_ignored(self):
        content = '<break time="1s"/><prosody>Hello'
        closing, opening = balance_tags(content)
        # break is self-closing, shouldn't affect balance
        assert "break" not in closing


class TestNeedsSegmentation:
    """Tests for segmentation need detection."""

    def test_short_content(self):
        ssml = "<speak>Hello world</speak>"
        assert not needs_segmentation(ssml, max_sec=60)

    def test_long_content(self):
        # Create content that would take > 60 seconds
        long_text = "This is a test sentence. " * 200  # ~1000 words = ~400 seconds
        ssml = f"<speak>{long_text}</speak>"
        assert needs_segmentation(ssml, max_sec=60)


class TestSegmentSsml:
    """Tests for SSML segmentation."""

    def test_short_content_single_segment(self):
        ssml = '<speak version="1.0">Hello world</speak>'
        segments = list(segment_ssml(ssml, target_sec=60, max_sec=120))
        assert len(segments) == 1
        assert segments[0].seq == 0

    def test_long_content_multiple_segments(self):
        # Create long content
        long_text = "This is sentence number one. " * 100
        ssml = f'<speak version="1.0">{long_text}</speak>'

        segments = list(segment_ssml(ssml, target_sec=30, max_sec=60))
        assert len(segments) > 1

        # Check sequence numbers
        for i, seg in enumerate(segments):
            assert seg.seq == i

    def test_segments_are_valid_ssml(self):
        long_text = "Hello world. " * 100
        ssml = f'<speak version="1.0">{long_text}</speak>'

        segments = list(segment_ssml(ssml, target_sec=30, max_sec=60))

        for seg in segments:
            # Each segment should start with <speak
            assert seg.ssml.startswith("<speak")
            assert seg.ssml.endswith("</speak>")

    def test_preserves_speak_attributes(self):
        ssml = '<speak version="1.0" xml:lang="en-US">Hello world. ' + "Test. " * 100 + "</speak>"

        segments = list(segment_ssml(ssml, target_sec=30, max_sec=60))

        for seg in segments:
            assert 'version="1.0"' in seg.ssml
            assert 'xml:lang="en-US"' in seg.ssml

    def test_handles_prosody_across_segments(self):
        # Create content with prosody that might span segments
        content = '<prosody rate="fast">' + "Hello world. " * 100 + "</prosody>"
        ssml = f'<speak version="1.0">{content}</speak>'

        segments = list(segment_ssml(ssml, target_sec=30, max_sec=60))

        # All segments should be valid (balanced tags)
        for seg in segments:
            # Count opening and closing prosody tags
            open_count = seg.ssml.count("<prosody")
            close_count = seg.ssml.count("</prosody>")
            assert open_count == close_count

    def test_empty_content(self):
        ssml = "<speak></speak>"
        segments = list(segment_ssml(ssml, target_sec=60, max_sec=120))
        assert len(segments) == 0

    def test_estimated_duration(self):
        long_text = "Hello world. " * 50
        ssml = f'<speak version="1.0">{long_text}</speak>'

        segments = list(segment_ssml(ssml, target_sec=30, max_sec=60))

        # Each segment should have a duration estimate
        for seg in segments:
            assert seg.estimated_duration_sec > 0
            assert seg.estimated_duration_ms > 0

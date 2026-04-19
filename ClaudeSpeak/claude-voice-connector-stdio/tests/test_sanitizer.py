"""Tests for SSML sanitizer."""

import pytest
from claude_voice_connector.sanitizer import (
    sanitize,
    wrap_speak,
    strip_invalid_tags,
    escape_text_content,
    validate_ssml,
    get_voice_from_ssml,
    inject_voice,
    extract_text_length,
)


class TestWrapSpeak:
    """Tests for wrap_speak function."""

    def test_plain_text(self):
        result = wrap_speak("Hello world")
        assert result.startswith("<speak")
        assert "Hello world" in result
        assert result.endswith("</speak>")

    def test_already_wrapped(self):
        ssml = '<speak version="1.0">Hello</speak>'
        result = wrap_speak(ssml)
        assert result == ssml

    def test_partial_ssml(self):
        ssml = "<prosody rate='fast'>Hello</prosody>"
        result = wrap_speak(ssml)
        assert result.startswith("<speak")
        assert "<prosody" in result
        assert result.endswith("</speak>")

    def test_custom_lang(self):
        result = wrap_speak("Hola", lang="es-ES")
        assert 'xml:lang="es-ES"' in result

    def test_escapes_special_chars(self):
        result = wrap_speak("5 < 10 & 10 > 5")
        assert "&lt;" in result
        assert "&amp;" in result
        assert "&gt;" in result


class TestStripInvalidTags:
    """Tests for strip_invalid_tags function."""

    def test_valid_tags_preserved(self):
        ssml = "<speak><prosody rate='fast'>Hello</prosody></speak>"
        result = strip_invalid_tags(ssml)
        assert "<prosody" in result
        assert "</prosody>" in result

    def test_invalid_tags_removed(self):
        ssml = "<speak><invalid>Hello</invalid></speak>"
        result = strip_invalid_tags(ssml)
        assert "<invalid>" not in result
        assert "</invalid>" not in result

    def test_break_tag_preserved(self):
        ssml = '<speak><break time="500ms"/></speak>'
        result = strip_invalid_tags(ssml)
        assert "<break" in result

    def test_mstts_tags_preserved(self):
        ssml = '<speak><mstts:express-as style="cheerful">Hi!</mstts:express-as></speak>'
        result = strip_invalid_tags(ssml)
        assert "mstts:express-as" in result


class TestEscapeTextContent:
    """Tests for escape_text_content function."""

    def test_escapes_ampersand(self):
        ssml = "<speak>Tom & Jerry</speak>"
        result = escape_text_content(ssml)
        assert "Tom &amp; Jerry" in result

    def test_preserves_existing_entities(self):
        ssml = "<speak>5 &lt; 10</speak>"
        result = escape_text_content(ssml)
        assert "&lt;" in result
        assert "&amp;lt;" not in result  # No double-escape

    def test_leaves_tags_alone(self):
        ssml = "<speak><prosody rate='+20%'>Hello</prosody></speak>"
        result = escape_text_content(ssml)
        assert "rate='+20%'" in result


class TestValidateSsml:
    """Tests for validate_ssml function."""

    def test_valid_ssml(self):
        ssml = '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis">Hello</speak>'
        valid, errors = validate_ssml(ssml)
        assert valid
        assert len(errors) == 0

    def test_invalid_no_speak(self):
        ssml = "<prosody>Hello</prosody>"
        valid, errors = validate_ssml(ssml)
        assert not valid
        assert any("speak" in e.lower() for e in errors)

    def test_invalid_xml(self):
        ssml = "<speak>Hello<unclosed>"
        valid, errors = validate_ssml(ssml)
        assert not valid


class TestSanitize:
    """Tests for sanitize function."""

    def test_plain_text_wrapped_and_valid(self):
        result = sanitize("Hello world")
        assert result.valid
        assert "<speak" in result.ssml
        assert "Hello world" in result.ssml

    def test_empty_input(self):
        result = sanitize("")
        assert not result.valid
        assert "empty" in result.errors[0].lower()

    def test_too_large(self):
        large_text = "x" * 2_000_000
        result = sanitize(large_text, max_bytes=1_000_000)
        assert not result.valid
        assert any("size" in e.lower() for e in result.errors)

    def test_warnings_for_stripped_tags(self):
        ssml = "<speak><invalid>Hello</invalid></speak>"
        result = sanitize(ssml, wrap=False)
        # Should still be valid after stripping
        assert len(result.warnings) > 0


class TestVoiceHelpers:
    """Tests for voice extraction and injection."""

    def test_get_voice(self):
        ssml = '<speak><voice name="en-US-AriaNeural">Hello</voice></speak>'
        voice = get_voice_from_ssml(ssml)
        assert voice == "en-US-AriaNeural"

    def test_get_voice_none(self):
        ssml = "<speak>Hello</speak>"
        voice = get_voice_from_ssml(ssml)
        assert voice is None

    def test_inject_voice(self):
        ssml = "<speak>Hello</speak>"
        result = inject_voice(ssml, "en-US-GuyNeural")
        assert 'name="en-US-GuyNeural"' in result
        assert "<voice" in result

    def test_inject_voice_already_present(self):
        ssml = '<speak><voice name="en-US-AriaNeural">Hello</voice></speak>'
        result = inject_voice(ssml, "en-US-GuyNeural")
        # Should not add second voice tag
        assert result.count("<voice") == 1
        assert "AriaNeural" in result


class TestTextLength:
    """Tests for text length extraction."""

    def test_simple_text(self):
        ssml = "<speak>Hello world</speak>"
        length = extract_text_length(ssml)
        assert length == 11  # "Hello world"

    def test_with_tags(self):
        ssml = '<speak><prosody rate="fast">Hello</prosody> world</speak>'
        length = extract_text_length(ssml)
        assert length == 11

    def test_with_entities(self):
        ssml = "<speak>5 &lt; 10</speak>"
        length = extract_text_length(ssml)
        assert length == 6  # "5 < 10"

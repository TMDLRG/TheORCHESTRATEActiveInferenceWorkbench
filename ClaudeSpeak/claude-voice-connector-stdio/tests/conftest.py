"""Pytest configuration and fixtures."""

import sys
from pathlib import Path

import pytest

# Add src to path for imports
src_path = Path(__file__).parent.parent / "src"
sys.path.insert(0, str(src_path))


@pytest.fixture
def sample_ssml():
    """Simple SSML for testing."""
    return '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US">Hello world</speak>'


@pytest.fixture
def long_ssml():
    """Long SSML that requires segmentation."""
    content = "This is a test sentence. " * 200
    return f'<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US">{content}</speak>'


@pytest.fixture
def ssml_with_prosody():
    """SSML with prosody elements."""
    return '''<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US">
        <prosody rate="fast">This is fast.</prosody>
        <break time="500ms"/>
        <prosody rate="slow">This is slow.</prosody>
    </speak>'''

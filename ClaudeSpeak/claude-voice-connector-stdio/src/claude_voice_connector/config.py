"""Configuration for Claude Voice Connector.

Piper TTS settings and audio configuration.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any, Optional, Union

import yaml
from pydantic import BaseModel, Field


class ConnectorConfig(BaseModel):
    """Voice connector configuration."""

    # Voice settings
    voice: str = Field(default="en_GB-jenny_dioco-medium", description="Default Piper voice")
    
    # Audio settings  
    sample_rate_hz: int = Field(default=22050, description="Audio sample rate (Piper default)")
    channels: int = Field(default=1, description="Audio channels (mono)")
    
    # Buffer settings
    ring_buffer_ms: int = Field(default=30000, description="Ring buffer size in ms")
    max_buffer_ms: int = Field(default=10000, description="Max buffer before backpressure")
    min_buffer_ms: int = Field(default=1000, description="Min buffer before underrun warning")
    
    # Device settings
    device_index: Optional[Union[int, str]] = Field(default=None, description="Audio device")
    
    # Logging
    log_level: str = Field(default="INFO", description="Log level")

    @property
    def bytes_per_sample(self) -> int:
        """Bytes per audio sample (int16 = 2)."""
        return 2

    @property
    def bytes_per_second(self) -> int:
        """Bytes per second of audio."""
        return self.sample_rate_hz * self.channels * self.bytes_per_sample

    @property
    def max_buffer_bytes(self) -> int:
        """Max buffer in bytes."""
        return int(self.max_buffer_ms * self.bytes_per_second / 1000)

    @property
    def min_buffer_bytes(self) -> int:
        """Min buffer in bytes."""
        return int(self.min_buffer_ms * self.bytes_per_second / 1000)


def load_config(path: Optional[Union[str, Path]] = None) -> ConnectorConfig:
    """Load configuration from YAML file.

    Args:
        path: Config file path. If None, searches standard locations.

    Returns:
        ConnectorConfig instance
    """
    config_data: dict[str, Any] = {}

    if path is None:
        # Search for config.yaml
        search_paths = [
            Path.cwd() / "config.yaml",
            Path(__file__).resolve().parent.parent.parent / "config.yaml",
        ]
        for p in search_paths:
            if p.exists():
                path = p
                break

    if path is not None:
        path = Path(path)
        if path.exists():
            with open(path, "r", encoding="utf-8") as f:
                config_data = yaml.safe_load(f) or {}

    return ConnectorConfig(**config_data)

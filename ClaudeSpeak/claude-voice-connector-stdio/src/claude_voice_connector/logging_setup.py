"""Logging configuration - JSON logs to STDERR only."""

from __future__ import annotations

import json
import logging
import sys
from datetime import datetime, timezone
from typing import Any


class JSONFormatter(logging.Formatter):
    """Format log records as JSON for structured logging."""

    def format(self, record: logging.LogRecord) -> str:
        log_obj: dict[str, Any] = {
            "ts": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "msg": record.getMessage(),
        }

        if record.exc_info:
            log_obj["exc"] = self.formatException(record.exc_info)

        # Include extra fields
        for key in ("request_id", "segment_seq", "duration_ms", "error_code"):
            if hasattr(record, key):
                log_obj[key] = getattr(record, key)

        return json.dumps(log_obj, ensure_ascii=False)


class StderrHandler(logging.StreamHandler):
    """Handler that writes only to stderr."""

    def __init__(self) -> None:
        super().__init__(sys.stderr)


def setup_logging(level: str = "INFO") -> logging.Logger:
    """Configure logging to emit JSON to STDERR.

    Args:
        level: Log level string (DEBUG, INFO, WARNING, ERROR, CRITICAL)

    Returns:
        Root logger for the connector
    """
    # Get numeric level
    numeric_level = getattr(logging, level.upper(), logging.INFO)

    # Create handler for stderr
    handler = StderrHandler()
    handler.setFormatter(JSONFormatter())
    handler.setLevel(numeric_level)

    # Configure root logger for our package
    logger = logging.getLogger("claude_voice_connector")
    logger.setLevel(numeric_level)
    logger.handlers.clear()
    logger.addHandler(handler)
    logger.propagate = False

    return logger


def get_logger(name: str) -> logging.Logger:
    """Get a child logger.

    Args:
        name: Logger name (will be prefixed with claude_voice_connector.)

    Returns:
        Logger instance
    """
    return logging.getLogger(f"claude_voice_connector.{name}")

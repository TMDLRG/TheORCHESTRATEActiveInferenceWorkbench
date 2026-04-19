"""STDIO entry point for Claude Voice Connector MCP server.

This is the module referenced by pyproject.toml and start scripts.
"""

from .mcp_server import main, main_sync

__all__ = ["main", "main_sync"]

if __name__ == "__main__":
    main_sync()

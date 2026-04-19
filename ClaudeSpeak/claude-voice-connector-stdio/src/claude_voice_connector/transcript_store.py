"""Transcript store - persists every spoken utterance with audio + metadata.

Each call to ``speak`` is recorded:
  * Text, voice, rate, duration, timestamp in a SQLite DB
  * Raw PCM saved as a .wav file on disk so it can be replayed later

Storage lives under ``~/.claude-voice-connector/`` by default so it survives
across MCP server restarts.
"""

from __future__ import annotations

import sqlite3
import threading
import time
import wave
from pathlib import Path
from typing import Optional

from .logging_setup import get_logger

logger = get_logger("transcript_store")


# Storage under user home so it persists across MCP restarts
DEFAULT_DATA_DIR = Path.home() / ".claude-voice-connector"


class TranscriptStore:
    """Persistent store for spoken-transcript history.

    Writes are synchronous but fast (single SQLite row + one small WAV file
    per utterance).  The store is thread-safe via a single internal lock,
    which is fine because TTS throughput is bounded by audio playback anyway.
    """

    def __init__(self, data_dir: Optional[Path] = None) -> None:
        self.data_dir = Path(data_dir) if data_dir else DEFAULT_DATA_DIR
        self.audio_dir = self.data_dir / "audio"
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.audio_dir.mkdir(parents=True, exist_ok=True)
        self.db_path = self.data_dir / "transcripts.db"
        self._lock = threading.Lock()
        self._init_db()
        logger.info(f"TranscriptStore ready at {self.data_dir}")

    def _init_db(self) -> None:
        with self._lock:
            conn = sqlite3.connect(str(self.db_path))
            try:
                conn.execute(
                    """
                    CREATE TABLE IF NOT EXISTS transcripts (
                        id           INTEGER PRIMARY KEY AUTOINCREMENT,
                        timestamp    REAL    NOT NULL,
                        text         TEXT    NOT NULL,
                        voice        TEXT,
                        rate         TEXT,
                        duration_ms  INTEGER,
                        sample_rate  INTEGER,
                        audio_path   TEXT
                    )
                    """
                )
                conn.execute(
                    "CREATE INDEX IF NOT EXISTS idx_transcripts_ts "
                    "ON transcripts(timestamp DESC)"
                )
                conn.commit()
            finally:
                conn.close()

    # --- writes --------------------------------------------------------

    def add_entry(
        self,
        text: str,
        voice: str,
        rate: str,
        audio_pcm: bytes,
        sample_rate: int,
        duration_ms: int,
    ) -> int:
        """Record an utterance and write its audio to disk.

        Returns the new row id.
        """
        ts = time.time()
        with self._lock:
            conn = sqlite3.connect(str(self.db_path))
            try:
                cursor = conn.execute(
                    "INSERT INTO transcripts "
                    "(timestamp, text, voice, rate, duration_ms, sample_rate, audio_path) "
                    "VALUES (?, ?, ?, ?, ?, ?, ?)",
                    (ts, text, voice or "", rate or "", duration_ms, sample_rate, ""),
                )
                entry_id = cursor.lastrowid

                audio_path = self.audio_dir / f"{entry_id}.wav"
                self._write_wav(audio_path, audio_pcm, sample_rate)

                conn.execute(
                    "UPDATE transcripts SET audio_path = ? WHERE id = ?",
                    (str(audio_path), entry_id),
                )
                conn.commit()
            finally:
                conn.close()

        logger.info(f"Transcript #{entry_id} saved ({duration_ms}ms)")
        return entry_id

    @staticmethod
    def _write_wav(path: Path, pcm: bytes, sample_rate: int) -> None:
        with wave.open(str(path), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)  # int16
            w.setframerate(sample_rate)
            w.writeframes(pcm)

    # --- reads ---------------------------------------------------------

    def list_entries(self, limit: int = 500, offset: int = 0) -> list[dict]:
        with self._lock:
            conn = sqlite3.connect(str(self.db_path))
            conn.row_factory = sqlite3.Row
            try:
                rows = conn.execute(
                    "SELECT id, timestamp, text, voice, rate, duration_ms, sample_rate "
                    "FROM transcripts ORDER BY id DESC LIMIT ? OFFSET ?",
                    (limit, offset),
                ).fetchall()
            finally:
                conn.close()
        return [dict(r) for r in rows]

    def get_entry(self, entry_id: int) -> Optional[dict]:
        with self._lock:
            conn = sqlite3.connect(str(self.db_path))
            conn.row_factory = sqlite3.Row
            try:
                row = conn.execute(
                    "SELECT id, timestamp, text, voice, rate, duration_ms, "
                    "sample_rate, audio_path FROM transcripts WHERE id = ?",
                    (entry_id,),
                ).fetchone()
            finally:
                conn.close()
        return dict(row) if row else None

    def get_audio_path(self, entry_id: int) -> Optional[Path]:
        entry = self.get_entry(entry_id)
        if not entry or not entry.get("audio_path"):
            return None
        p = Path(entry["audio_path"])
        return p if p.exists() else None

    def count(self) -> int:
        with self._lock:
            conn = sqlite3.connect(str(self.db_path))
            try:
                (n,) = conn.execute("SELECT COUNT(*) FROM transcripts").fetchone()
            finally:
                conn.close()
        return int(n)

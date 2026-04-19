"""Shared helpers for the LibreChat seeders.

Handles auth state (email + password → JWT, stored in
`scripts/.suite/state/librechat.admin.json`) and provides `lc_curl()` which
wraps `requests.request` with the browser User-Agent that LibreChat's
`uaParser` middleware requires (any short UA trips NON_BROWSER_VIOLATION)."""
from __future__ import annotations

import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Optional

import requests  # noqa: F401  (re-exported for seeders)

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
STATE_DIR = REPO_ROOT / "scripts" / ".suite" / "state"
STATE_FILE = STATE_DIR / "librechat.admin.json"

LC_BASE_URL = os.environ.get("LC_BASE_URL", "http://localhost:3080")
BROWSER_UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
)


@dataclass
class AdminState:
    email: str
    password: str
    token: str
    user_id: str

    def as_dict(self) -> dict:
        return {"email": self.email, "password": self.password, "token": self.token, "user_id": self.user_id}


def _read_state() -> Optional[AdminState]:
    if not STATE_FILE.exists():
        return None
    try:
        data = json.loads(STATE_FILE.read_text(encoding="utf-8"))
        return AdminState(**data)
    except (json.JSONDecodeError, TypeError):
        return None


def _write_state(state: AdminState) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state.as_dict(), indent=2), encoding="utf-8")


def _login(email: str, password: str) -> Optional[tuple[str, str]]:
    r = requests.post(
        f"{LC_BASE_URL}/api/auth/login",
        headers={"User-Agent": BROWSER_UA, "Content-Type": "application/json"},
        json={"email": email, "password": password},
        timeout=10,
    )
    if r.status_code != 200:
        return None
    data = r.json()
    token = data.get("token")
    uid = (data.get("user") or {}).get("_id")
    if not token or not uid:
        return None
    return token, uid


_CACHED: Optional[AdminState] = None


def _token_valid(token: str) -> bool:
    r = requests.get(
        f"{LC_BASE_URL}/api/user",
        headers={"User-Agent": BROWSER_UA, "Authorization": f"Bearer {token}"},
        timeout=5,
    )
    return r.status_code == 200


def load_admin(email: str = "admin@local.test", password: str = "NotASecret123!") -> AdminState:
    """Return admin state, preferring the cached token when still valid.

    LibreChat rate-limits login to 7/5min, so we avoid re-auth when the
    token in state is still good (GET /api/user returns 200)."""
    global _CACHED
    if _CACHED is not None and _token_valid(_CACHED.token):
        return _CACHED

    existing = _read_state()
    if existing is not None:
        email, password = existing.email, existing.password
        if _token_valid(existing.token):
            _CACHED = existing
            return existing

    result = _login(email, password)
    if result is None:
        raise RuntimeError(
            f"LibreChat admin login failed for {email} (rate-limited or banned?) -- "
            "wait 5 minutes or run scripts/librechat_bootstrap.py after the window clears."
        )
    token, uid = result
    state = AdminState(email=email, password=password, token=token, user_id=uid)
    _write_state(state)
    _CACHED = state
    return state


def lc_curl(method: str, path: str, *, token: str, **kwargs: Any) -> requests.Response:
    """Authenticated request with a browser UA."""
    headers = {"User-Agent": BROWSER_UA, "Authorization": f"Bearer {token}"}
    headers.update(kwargs.pop("headers", None) or {})
    url = path if path.startswith("http") else f"{LC_BASE_URL}{path}"
    return requests.request(method, url, headers=headers, timeout=kwargs.pop("timeout", 60), **kwargs)


def list_agents(token: str) -> list[dict]:
    """Return every agent the admin can see."""
    r = lc_curl("GET", "/api/agents?requiredPermission=1", token=token)
    r.raise_for_status()
    body = r.json()
    return body.get("data", []) if isinstance(body, dict) else body

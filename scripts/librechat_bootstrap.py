#!/usr/bin/env python3
"""Bootstrap the LibreChat admin user used by the seeder scripts.

Idempotent:
  1. If `scripts/.suite/state/librechat.admin.json` exists and the stored JWT
     still authenticates, exit immediately.
  2. Else POST `/api/auth/register` with the stored (or default) email +
     password.  Ignores "email exists" / "verify" flows.
  3. `docker exec chat-mongodb mongosh` → promote the user to ADMIN.
  4. Login to capture a fresh JWT.
  5. Write the state file.

Env:
  LC_BASE_URL   (default http://localhost:3080)
  LC_ADMIN_EMAIL    (default admin@local.test)
  LC_ADMIN_PASSWORD (default NotASecret123!)"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

import requests

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent
sys.path.insert(0, str(REPO_ROOT / "tools" / "librechat_seed"))

from common import (  # noqa: E402
    BROWSER_UA,
    LC_BASE_URL,
    STATE_FILE,
    STATE_DIR,
    AdminState,
    _login,
    _write_state,
)


def _promote_to_admin(email: str) -> None:
    """Use `docker exec chat-mongodb mongosh` to set role=ADMIN."""
    cmd = [
        "docker",
        "exec",
        "chat-mongodb",
        "mongosh",
        "--quiet",
        "LibreChat",
        "--eval",
        f'db.users.updateOne({{email: "{email}"}}, {{$set: {{role: "ADMIN"}}}})',
    ]
    res = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    if res.returncode != 0:
        raise RuntimeError(
            "Failed to promote admin via mongosh. "
            "Run manually: "
            f'docker exec chat-mongodb mongosh --quiet LibreChat --eval \'db.users.updateOne({{email:"{email}"}}, {{$set:{{role:"ADMIN"}}}})\''
            f"\nstderr: {res.stderr}"
        )


def _register(email: str, password: str, name: str = "Workshop Admin", username: str = "workshopadmin") -> bool:
    r = requests.post(
        f"{LC_BASE_URL}/api/auth/register",
        headers={"User-Agent": BROWSER_UA, "Content-Type": "application/json"},
        json={
            "email": email,
            "name": name,
            "username": username,
            "password": password,
            "confirm_password": password,
        },
        timeout=20,
    )
    if r.status_code in (200, 201):
        return True
    body = (r.text or "").lower()
    # Already-registered → treat as success
    return any(s in body for s in ("already exists", "email already", "already taken"))


def main() -> int:
    email = os.environ.get("LC_ADMIN_EMAIL", "admin@local.test")
    password = os.environ.get("LC_ADMIN_PASSWORD", "NotASecret123!")

    if STATE_FILE.exists():
        try:
            existing = json.loads(STATE_FILE.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            existing = None
        if existing:
            email = existing.get("email", email)
            password = existing.get("password", password)
            result = _login(email, password)
            if result is not None:
                token, uid = result
                _write_state(AdminState(email=email, password=password, token=token, user_id=uid))
                print(f"[bootstrap] state refreshed for {email} ({uid})")
                return 0

    print(f"[bootstrap] registering {email}…")
    if not _register(email, password):
        print("[bootstrap] register request was rejected; continuing (user may already exist)", file=sys.stderr)

    try:
        _promote_to_admin(email)
    except RuntimeError as exc:
        print(f"[bootstrap] WARNING: {exc}", file=sys.stderr)

    login_result = _login(email, password)
    if login_result is None:
        raise SystemExit(
            f"[bootstrap] ERROR: login for {email} failed even after register+promote. "
            "Inspect LibreChat logs with `docker logs LibreChat --tail 60`."
        )

    token, uid = login_result
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    _write_state(AdminState(email=email, password=password, token=token, user_id=uid))
    print(f"[bootstrap] wrote {STATE_FILE} — admin {email} id={uid}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

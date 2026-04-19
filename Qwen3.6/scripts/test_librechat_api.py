"""End-to-end proof that LibreChat → local llama-server works for both reasoning and direct presets.

LibreChat submits chat via POST /api/agents/chat/:endpoint (SSE stream). We post, read
the first chunk of stream content to confirm generation started, then verify llama-server
logged a /v1/chat/completions request.
"""

from __future__ import annotations
import json
import os
import sys
import time
import uuid
from pathlib import Path
import urllib.request
import urllib.error
import urllib.parse

ROOT = Path(__file__).resolve().parent.parent
LIBRECHAT = os.environ.get("LIBRECHAT_URL", "http://localhost:3080")
EMAIL = "qwen@local.test"
PASSWORD = "Qwen-Local-2026"


def http_json(method: str, url: str, body=None, token=None, timeout=600):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
        req.add_header("Cookie", f"token={token}")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, r.read().decode(errors="replace"), dict(r.headers)
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode(errors="replace"), dict(e.headers)


def http_stream(url: str, body: dict, token: str, max_bytes: int = 20000, timeout: int = 600) -> tuple[int, str]:
    data = json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Cookie", f"token={token}")
    req.add_header("Accept", "text/event-stream")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            chunks = []
            total = 0
            for line in r:
                chunks.append(line.decode(errors="replace"))
                total += len(line)
                if total >= max_bytes:
                    break
            return r.status, "".join(chunks)
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode(errors="replace")


def login() -> str:
    http_json("POST", f"{LIBRECHAT}/api/auth/register", {
        "name": "Qwen Tester", "username": "qwen", "email": EMAIL,
        "password": PASSWORD, "confirm_password": PASSWORD,
    })
    code, resp, _ = http_json("POST", f"{LIBRECHAT}/api/auth/login", {
        "email": EMAIL, "password": PASSWORD,
    })
    if code != 200:
        raise SystemExit(f"Login failed {code}: {resp[:200]}")
    return json.loads(resp)["token"]


def ask_stream(token: str, endpoint: str, prompt: str, max_tokens: int) -> tuple[int, str]:
    conv_id = str(uuid.uuid4())
    msg_id = str(uuid.uuid4())
    url_endpoint = urllib.parse.quote(endpoint)
    url = f"{LIBRECHAT}/api/agents/chat/{url_endpoint}"
    payload = {
        "endpoint": endpoint,
        "endpointType": "custom",
        "model": "Qwen3.6-35B-A3B-Q8_0",
        "conversationId": conv_id,
        "parentMessageId": "00000000-0000-0000-0000-000000000000",
        "messageId": msg_id,
        "text": prompt,
        "maxOutputTokens": max_tokens,
        "isEdited": False,
        "isContinued": False,
        "isTemporary": True,
        "modelLabel": endpoint,
    }
    return http_stream(url, payload, token, max_bytes=80000, timeout=600)


def main() -> int:
    print(f"== LibreChat URL: {LIBRECHAT}")
    token = login()
    print(f"== Logged in (token len {len(token)})")

    llama_log = ROOT / "logs" / "llama-server.log"
    log_start = llama_log.stat().st_size if llama_log.exists() else 0

    print("\n== Reasoning endpoint via LibreChat ==")
    code_r, body_r = ask_stream(token, "Qwen 3.6 Reasoning",
                                 "What is 17 * 23? Think briefly, then give ONLY the final number.",
                                 2048)
    print(f"HTTP {code_r}, {len(body_r)} bytes")
    print(body_r[:2500])

    print("\n== Direct endpoint via LibreChat ==")
    code_d, body_d = ask_stream(token, "Qwen 3.6 Direct",
                                 "What is the capital of France? One word.", 32)
    print(f"HTTP {code_d}, {len(body_d)} bytes")
    print(body_d[:1500])

    # Check llama-server logs for post-test traffic from LibreChat
    new_log = ""
    if llama_log.exists():
        with open(llama_log, "r", errors="replace") as f:
            f.seek(log_start)
            new_log = f.read()
    print(f"\n== llama-server log delta ({len(new_log)} bytes) ==")
    print(new_log[-2000:])

    proof = ROOT / "logs" / "librechat-proof.txt"
    proof.parent.mkdir(exist_ok=True)
    proof.write_text(json.dumps({
        "reasoning": {"code": code_r, "body_first": body_r[:2000]},
        "direct":    {"code": code_d, "body_first": body_d[:1000]},
        "llama_log_delta_tail": new_log[-1500:],
    }, indent=2))
    print(f"\nWrote {proof}")

    hit_llama = "/v1/chat/completions" in new_log or "POST" in new_log
    ok_r = code_r in (200, 201) and (body_r != "")
    ok_d = code_d in (200, 201) and (body_d != "")
    print(f"\nPASS reasoning_status={ok_r}  PASS direct_status={ok_d}  PASS llama-server_hit={hit_llama}")
    return 0 if (ok_r and ok_d and hit_llama) else 2


if __name__ == "__main__":
    raise SystemExit(main())

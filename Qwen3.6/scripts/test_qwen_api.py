"""OpenAI-SDK proof that the local llama-server answers both reasoning and direct chats.

Usage (from repo root, with venv activated):
    python scripts/test_qwen_api.py
"""

from __future__ import annotations
import json
import os
import sys
from pathlib import Path

from openai import OpenAI

ROOT = Path(__file__).resolve().parent.parent
port = (ROOT / ".qwen_port").read_text().strip() if (ROOT / ".qwen_port").exists() else "8090"
base = os.environ.get("QWEN_BASE_URL", f"http://127.0.0.1:{port}/v1")

client = OpenAI(base_url=base, api_key="EMPTY")

print(f"== Base URL: {base}")

models = client.models.list()
model_ids = [m.id for m in models.data]
print(f"== /v1/models: {model_ids}")
model_id = model_ids[0] if model_ids else "Qwen3.6-35B-A3B-Q8_0"

def chat(prompt: str, enable_thinking: bool, **kwargs) -> tuple[str, str]:
    r = client.chat.completions.create(
        model=model_id,
        messages=[{"role": "user", "content": prompt}],
        extra_body={"chat_template_kwargs": {"enable_thinking": enable_thinking}},
        **kwargs,
    )
    msg = r.choices[0].message
    content = msg.content or ""
    reasoning = (msg.model_extra or {}).get("reasoning_content", "") or ""
    return content, reasoning

print("\n== Reasoning ON ==")
content, reasoning = chat(
    "What is 17 * 23? Think step by step, then give ONLY the final number.",
    enable_thinking=True,
    max_tokens=2048,
    temperature=1.0,
    top_p=0.95,
)
print(f"[reasoning_content {len(reasoning)} chars]: {reasoning[:200]}...")
print(f"[content]: {content}")
assert reasoning, "reasoning mode did not populate reasoning_content"
assert "391" in content or "391" in reasoning, "missing answer 391"
print("PASS: reasoning produced reasoning_content + answer 391")

print("\n== Reasoning OFF ==")
content, reasoning = chat(
    "What is the capital of France? Answer in one word.",
    enable_thinking=False,
    max_tokens=32,
    temperature=0.7,
    top_p=0.8,
)
print(f"[reasoning_content {len(reasoning)} chars]: {reasoning[:200] if reasoning else '(empty)'}")
print(f"[content]: {content}")
assert not reasoning, f"direct mode leaked reasoning_content: {reasoning[:200]}"
assert "paris" in content.lower(), "wrong direct answer"
print("PASS: direct mode with no reasoning_content, answered Paris")

proof = ROOT / "logs" / "api-proof.py.txt"
proof.parent.mkdir(exist_ok=True)
proof.write_text(json.dumps({"base": base, "model": model_id}, indent=2))
print(f"\nSummary written to {proof}")

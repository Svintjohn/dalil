"""Tests the AI connection with one tiny request (no document). Run from the project folder:"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "backend"))

from dalil import agent, config  # noqa: E402
from dalil.gemini import LLMError  # noqa: E402

print("backup services with a key:", ", ".join(config.fallback_keys()) or "none")
print("service:", config.provider(), "| model:", config.MODEL, "| key set:", bool(config.api_key()))
try:
    client = agent.get_client()
    resp = client.messages.create(model=config.MODEL, max_tokens=50, system="Reply with the single word: ready", messages=[{"role": "user", "content": "hello"}])
    text = "".join(getattr(b, "text", "") for b in resp.content)
    print("OK, the model answered:", text.strip() or "(empty)")
except LLMError as e:
    print("FAILED: status", e.status, "|", e.detail)
except Exception as e:  # noqa: BLE001
    print("FAILED:", type(e).__name__, str(e)[:300])

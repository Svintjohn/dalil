"""Adapter for services that speak the OpenAI chat format (Groq, Mistral, OpenRouter).

It accepts the same calls as the Gemini adapter, so the agent loop does not care which one answers.
"""
from __future__ import annotations

import hashlib
import json
import logging
from types import SimpleNamespace
from typing import Any

import httpx

from . import config, deadline
from .gemini import LLMError

log = logging.getLogger("dalil")

SERVICES = {
    "groq": {"url": "https://api.groq.com/openai/v1/chat/completions", "key": "GROQ_API_KEY", "model": "GROQ_MODEL", "default": "qwen/qwen3.8-27b"},
    "mistral": {"url": "https://api.mistral.ai/v1/chat/completions", "key": "MISTRAL_API_KEY", "model": "MISTRAL_MODEL", "default": "mistral-small-latest"},
    "openrouter": {"url": "https://openrouter.ai/api/v1/chat/completions", "key": "OPENROUTER_API_KEY", "model": "OPENROUTER_MODEL", "default": "openrouter/free"},
}


def _call_id(raw: str) -> str:
    # Mistral only accepts 9 letters or digits, so every service gets a short stable id.
    return hashlib.sha1(raw.encode()).hexdigest()[:9]


def _get(b: Any, k: str, d: Any = None) -> Any:
    return b.get(k, d) if isinstance(b, dict) else getattr(b, k, d)


def _messages(system: str, messages: list[dict]) -> list[dict]:
    out: list[dict] = [{"role": "system", "content": system}]
    for m in messages:
        c = m["content"]
        blocks = [{"type": "text", "text": c}] if isinstance(c, str) else c
        if m["role"] == "assistant":
            text = "".join(_get(b, "text", "") for b in blocks if _get(b, "type") == "text")
            calls = [
                {"id": _call_id(_get(b, "id")), "type": "function", "function": {"name": _get(b, "name"), "arguments": json.dumps(dict(_get(b, "input") or {}), ensure_ascii=False)}}
                for b in blocks
                if _get(b, "type") == "tool_use"
            ]
            msg: dict[str, Any] = {"role": "assistant", "content": text or None}
            if calls:
                msg["tool_calls"] = calls
            if text or calls:
                out.append(msg)
            continue
        parts: list[dict] = []
        for b in blocks:
            t = _get(b, "type")
            if t == "tool_result":
                content = _get(b, "content")
                out.append({"role": "tool", "tool_call_id": _call_id(_get(b, "tool_use_id")), "content": content if isinstance(content, str) else json.dumps(content, ensure_ascii=False)})
            elif t == "text":
                parts.append({"type": "text", "text": _get(b, "text", "")})
            elif t == "image":
                src = _get(b, "source", {})
                parts.append({"type": "image_url", "image_url": {"url": f"data:{src.get('media_type', 'image/jpeg')};base64,{src.get('data', '')}"}})
        if parts:
            out.append({"role": "user", "content": parts if any(p["type"] == "image_url" for p in parts) else "\n".join(p["text"] for p in parts)})
    return out


class _Messages:
    def __init__(self, service: str, key: str):
        self._svc = SERVICES[service]
        self._name = service
        self._key = key
        self.model = config.env(self._svc["model"]) or self._svc["default"]

    def create(self, *, model: str, max_tokens: int, system: str, messages: list[dict], tools: list[dict] | None = None, tool_choice: dict | None = None):
        body: dict[str, Any] = {"model": self.model, "messages": _messages(system, messages), "max_tokens": max_tokens, "temperature": 0.2}
        if tools and not (tool_choice and tool_choice.get("type") == "none"):
            body["tools"] = [{"type": "function", "function": {"name": t["name"], "description": t.get("description", ""), "parameters": t["input_schema"]}} for t in tools]
        left = deadline.remaining(config.MODEL_TIMEOUT_S)
        if left < 3:
            raise LLMError(408)  # not enough time left in this request
        try:
            r = httpx.post(self._svc["url"], json=body, headers={"Authorization": f"Bearer {self._key}"}, timeout=left)
        except httpx.TimeoutException as e:
            raise LLMError(408) from e
        except httpx.HTTPError as e:
            log.warning("%s connection problem: %s", self._name, type(e).__name__)
            raise LLMError(0, type(e).__name__) from e
        if r.status_code >= 400:
            detail = ""
            try:
                err = r.json().get("error")
                detail = str(err.get("message", "") if isinstance(err, dict) else err)[:300]
            except (ValueError, AttributeError):
                pass
            log.warning("%s said %s: %s", self._name, r.status_code, detail)
            raise LLMError(r.status_code, detail)
        try:
            choice = (r.json().get("choices") or [{}])[0]
        except ValueError as e:
            raise LLMError(502) from e
        msg = choice.get("message") or {}
        blocks = []
        if msg.get("content"):
            blocks.append(SimpleNamespace(type="text", text=msg["content"]))
        for i, call in enumerate(msg.get("tool_calls") or [], 1):
            fn = call.get("function") or {}
            try:
                args = json.loads(fn.get("arguments") or "{}")
            except ValueError:
                args = {}
            blocks.append(SimpleNamespace(type="tool_use", id=call.get("id") or f"call_{i}", name=fn.get("name", ""), input=args if isinstance(args, dict) else {}))
        if any(b.type == "tool_use" for b in blocks):
            stop = "tool_use"
        else:
            stop = "max_tokens" if choice.get("finish_reason") == "length" else "end_turn"
        return SimpleNamespace(content=blocks, stop_reason=stop)


class OpenAICompatClient:
    def __init__(self, service: str, key: str):
        self.messages = _Messages(service, key)

"""Google Gemini adapter."""
from __future__ import annotations

import re
import time
from types import SimpleNamespace
from typing import Any

import httpx

from . import config, deadline

import logging

log = logging.getLogger("dalil")

API = "https://generativelanguage.googleapis.com/v1beta/models"


class LLMError(Exception):

    def __init__(self, status: int, detail: str = ""):
        super().__init__(f"gemini_{status}")
        self.status = status
        self.detail = detail  # Google's own error text (about the model or settings, never your document)


def _clean_schema(s: Any) -> Any:
    if isinstance(s, dict):
        return {k: _clean_schema(v) for k, v in s.items() if k not in ("additionalProperties", "$schema", "default")}
    if isinstance(s, list):
        return [_clean_schema(x) for x in s]
    return s


def _tools(tools: list[dict]) -> list[dict]:
    return [{"functionDeclarations": [{"name": t["name"], "description": t.get("description", ""), "parameters": _clean_schema(t["input_schema"])} for t in tools]}]


def _block_to_parts(b: Any, names: dict[str, str]) -> list[dict]:
    t = b.get("type") if isinstance(b, dict) else getattr(b, "type", "")
    get = (lambda k, d=None: b.get(k, d)) if isinstance(b, dict) else (lambda k, d=None: getattr(b, k, d))
    if t == "text":
        return [{"text": get("text", "")}]
    if t == "image":
        src = get("source", {})
        return [{"inlineData": {"mimeType": src.get("media_type", "image/jpeg"), "data": src.get("data", "")}}]
    if t == "tool_use":
        raw = get("raw")
        if raw:
            return [raw]  # keeps Gemini's thought signature, which it asks to be sent back unchanged
        names[get("id")] = get("name")
        return [{"functionCall": {"name": get("name"), "args": dict(get("input") or {})}}]
    if t == "tool_result":
        return [{"functionResponse": {"name": names.get(get("tool_use_id"), "tool"), "response": {"result": get("content")}}}]
    return []


def _contents(messages: list[dict]) -> list[dict]:
    out, names = [], {}
    for m in messages:
        c = m["content"]
        blocks = [{"type": "text", "text": c}] if isinstance(c, str) else c
        # remember tool names so later tool_result blocks can name the function
        for b in blocks:
            if (b.get("type") if isinstance(b, dict) else getattr(b, "type", "")) == "tool_use":
                names[b["id"] if isinstance(b, dict) else b.id] = b["name"] if isinstance(b, dict) else b.name
        parts = [p for b in blocks for p in _block_to_parts(b, names)]
        if parts:
            out.append({"role": "model" if m["role"] == "assistant" else "user", "parts": parts})
    return out


_PICKED: dict[str, str] = {}  # configured model name -> a model this key can really use


def _version(name: str) -> tuple:
    return tuple(int(x) for x in re.findall(r"\d+", name.split("/")[-1])[:3])


def pick_flash(models: list[dict], exclude: str = "") -> str | None:
    ok = []
    for m in models:
        name = (m.get("name") or "").split("/")[-1]
        if "generateContent" not in (m.get("supportedGenerationMethods") or []):
            continue
        if not name.startswith("gemini-") or "flash" not in name or name == exclude:
            continue
        if any(bad in name for bad in ("lite", "image", "tts", "live", "audio", "robotics", "computer", "thinking", "embedding", "learnlm", "gemma")):
            continue
        ok.append((0 if "preview" in name or "exp" in name else 1, _version(name), name))
    return max(ok)[2] if ok else None


class _Messages:
    def __init__(self, key: str):
        self._key = key

    def _discover(self, exclude: str = "") -> str | None:
        try:
            r = httpx.get(API, headers={"x-goog-api-key": self._key}, params={"pageSize": 200}, timeout=20.0)
            if r.status_code >= 400:
                return None
            return pick_flash(r.json().get("models", []), exclude)
        except (httpx.HTTPError, ValueError):
            return None

    def create(self, *, model: str, max_tokens: int, system: str, messages: list[dict], tools: list[dict] | None = None, tool_choice: dict | None = None):
        body: dict[str, Any] = {
            "systemInstruction": {"parts": [{"text": system}]},
            "contents": _contents(messages),
            # Gemini counts its internal thinking against this limit, so leave room for it.
            "generationConfig": {"maxOutputTokens": max_tokens + 4096, "temperature": 0.2},
        }
        no_tools = bool(tool_choice and tool_choice.get("type") == "none")
        if tools and not no_tools:
            body["tools"] = _tools(tools)
        if no_tools:
            body["generationConfig"]["responseMimeType"] = "application/json"
        model = _PICKED.get(model, model)
        try:
            data = self._post(model, body)
        except LLMError as e:
            if e.status in (429, 500, 503) and not config.fallback_keys():
                # still busy after retries: try a different Gemini model once
                other = self._discover(exclude=model)
                if not other:
                    raise
                return self._to_response(self._post(other, body))
            if e.status != 404:
                raise
            # The configured model is not offered to this key (models get retired). Pick one that is.
            found = self._discover(exclude=model)  # the retired model may still be listed, so skip it
            if not found or found == model:
                raise
            _PICKED[model] = found
            data = self._post(found, body)
        return self._to_response(data)

    def _post(self, model: str, body: dict) -> dict:
        url = f"{API}/{model}:generateContent"
        tries = 1 if config.fallback_keys() else 3  # with a backup service ready, give up on a busy Gemini sooner
        for attempt in range(tries):
            left = deadline.remaining(config.MODEL_TIMEOUT_S)
            if config.fallback_keys():
                left = min(left, config.PRIMARY_TIMEOUT_S)  # a backup is ready, so do not wait the whole minute
            if left < 3:
                raise LLMError(408)  # not enough time left in this request
            try:
                r = httpx.post(url, json=body, headers={"x-goog-api-key": self._key}, timeout=left)
            except httpx.TimeoutException as e:
                raise LLMError(408) from e  # the model was too slow
            except httpx.HTTPError as e:
                log.warning("gemini connection problem: %s", type(e).__name__)
                raise LLMError(0, type(e).__name__) from e
            if r.status_code in (429, 500, 503) and attempt < tries - 1:
                time.sleep(3 + 3 * attempt)  # busy or rate limited: wait a little and try again
                continue
            if r.status_code >= 400:
                detail = ""
                try:
                    detail = str((r.json().get("error") or {}).get("message", ""))[:300]
                except (ValueError, AttributeError):
                    pass
                log.warning("gemini said %s: %s", r.status_code, detail)
                raise LLMError(r.status_code, detail)
            try:
                return r.json()
            except ValueError as e:
                raise LLMError(502) from e
        raise LLMError(429)

    @staticmethod
    def _to_response(data: dict):
        cands = data.get("candidates") or []
        if not cands:
            return SimpleNamespace(content=[], stop_reason="end_turn")
        cand = cands[0]
        blocks, n = [], 0
        for p in (cand.get("content") or {}).get("parts", []):
            if p.get("thought"):
                continue
            if "functionCall" in p:
                n += 1
                fc = p["functionCall"]
                blocks.append(SimpleNamespace(type="tool_use", id=f"call_{n}", name=fc.get("name", ""), input=fc.get("args") or {}, raw=p))
            elif "text" in p:
                blocks.append(SimpleNamespace(type="text", text=p["text"]))
        stop = "tool_use" if any(b.type == "tool_use" for b in blocks) else ("max_tokens" if cand.get("finishReason") == "MAX_TOKENS" else "end_turn")
        return SimpleNamespace(content=blocks, stop_reason=stop)


class GeminiClient:
    def __init__(self, key: str):
        self.messages = _Messages(key)

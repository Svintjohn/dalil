"""Tries several AI services in order, so one busy service does not stop the review."""
from __future__ import annotations

import logging
import time

import anthropic

from .gemini import LLMError

log = logging.getLogger("dalil")

RETRYABLE = (0, 400, 404, 408, 413, 429, 500, 502, 503, 504)  # 400/413: that model cannot take this input, so try the next
REST_S = 60.0  # how long a service that just failed is skipped

_resting: dict[str, float] = {}


def _status(e: Exception) -> int | None:
    if isinstance(e, LLMError):
        return e.status
    if isinstance(e, anthropic.APIStatusError):
        return e.status_code
    if isinstance(e, anthropic.APIConnectionError):
        return 0
    return None


class _Messages:
    def __init__(self, chain: list[tuple[str, object]]):
        self._chain = chain

    def create(self, **kwargs):
        now = time.monotonic()
        ready = [(n, c) for n, c in self._chain if _resting.get(n, 0) <= now]
        order = ready + [(n, c) for n, c in self._chain if (n, c) not in ready]  # rested ones go last, never dropped
        first_error: Exception | None = None
        for name, client in order:
            try:
                return client.messages.create(**kwargs)
            except Exception as e:  # noqa: BLE001
                st = _status(e)
                if st is None or st not in RETRYABLE:
                    raise
                if st in (0, 408, 429, 500, 502, 503, 504):
                    _resting[name] = time.monotonic() + REST_S
                log.warning("%s failed with %s, trying the next service", name, st)
                first_error = first_error or e
        assert first_error is not None
        raise first_error


class FailoverClient:
    def __init__(self, chain: list[tuple[str, object]]):
        self.messages = _Messages(chain)

"""A time budget for one request, so Dalil answers (or says it is busy) before Vercel cuts the request off."""
from __future__ import annotations

import time
from contextvars import ContextVar

_end: ContextVar[float | None] = ContextVar("dalil_deadline", default=None)


def start(budget_s: float) -> None:
    _end.set(time.monotonic() + budget_s)


def remaining(default: float) -> float:
    end = _end.get()
    if end is None:
        return default
    return max(0.0, min(default, end - time.monotonic()))

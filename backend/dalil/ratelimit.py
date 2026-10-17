"""A small in-memory per-client limiter. It resets when the server instance restarts and is not shared"""
from __future__ import annotations

import threading
import time
from collections import defaultdict, deque


class RateLimiter:
    def __init__(self, per_minute: int):
        self.per_minute = per_minute
        self.hits: dict[str, deque[float]] = defaultdict(deque)

    def allow(self, key: str, now: float | None = None) -> bool:
        if self.per_minute <= 0:
            return True
        now = time.monotonic() if now is None else now
        q = self.hits[key]
        while q and now - q[0] > 60:
            q.popleft()
        if len(q) >= self.per_minute:
            return False
        q.append(now)
        if len(self.hits) > 5000:  # keep memory bounded
            for k in [k for k, v in self.hits.items() if not v or now - v[-1] > 60][:1000]:
                self.hits.pop(k, None)
        return True


class Busy(Exception):
    def __init__(self, message: str, retry_after: int):
        super().__init__(message)
        self.message, self.retry_after = message, retry_after


class AiGate:
    """Protects the AI service: a cap on jobs running at once, on jobs per visitor and on jobs per minute overall."""

    def __init__(self, max_concurrent: int, per_ip_inflight: int, per_ip_per_min: int, global_per_min: int):
        self.max_concurrent = max_concurrent
        self.per_ip_inflight = per_ip_inflight
        self.ip_rate = RateLimiter(per_ip_per_min)
        self.all_rate = RateLimiter(global_per_min)
        self.running = 0
        self.by_ip: dict[str, int] = defaultdict(int)
        self.lock = threading.Lock()

    def acquire(self, ip: str) -> None:
        with self.lock:
            if self.by_ip[ip] >= self.per_ip_inflight:
                raise Busy("You already have a request running. Wait for it to finish.", 5)
            if self.max_concurrent > 0 and self.running >= self.max_concurrent:
                raise Busy("Dalil is busy with other people right now. Try again in a few seconds.", 8)
            if not self.ip_rate.allow(ip):
                raise Busy("You are sending requests too fast. Wait a little and try again.", 30)
            if not self.all_rate.allow("all"):
                raise Busy("Dalil is very busy right now. Try again in about a minute.", 30)
            self.running += 1
            self.by_ip[ip] += 1

    def release(self, ip: str) -> None:
        with self.lock:
            self.running = max(0, self.running - 1)
            self.by_ip[ip] = max(0, self.by_ip[ip] - 1)
            if not self.by_ip[ip]:
                self.by_ip.pop(ip, None)

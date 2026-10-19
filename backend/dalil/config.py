"""Settings, read from environment variables. Nothing secret lives in the repo."""
from __future__ import annotations

import os


def _int(name: str, default: int) -> int:
    try:
        return int(os.environ.get(name, default))
    except ValueError:
        return default


def _float(name: str, default: float) -> float:
    try:
        return float(os.environ.get(name, default))
    except ValueError:
        return default


# Which AI service to use: "anthropic" or "gemini". Left empty, Dalil uses Anthropic if
# ANTHROPIC_API_KEY is set, otherwise Gemini if GEMINI_API_KEY is set.
def provider() -> str:
    p = os.environ.get("DALIL_PROVIDER", "").strip().lower()
    if p in ("anthropic", "gemini"):
        return p
    if os.environ.get("ANTHROPIC_API_KEY"):
        return "anthropic"
    if os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY"):
        return "gemini"
    return "anthropic"


# Models. Set DALIL_MODEL / DALIL_FAST_MODEL to whatever your account offers.
def _default_models() -> tuple[str, str]:
    if provider() == "gemini":
        return "gemini-3.8-flash", "gemini-3.8-flash"
    return "claude-sonnet-5-5", "claude-haiku-5-5"


MODEL = os.environ.get("DALIL_MODEL") or _default_models()[0]
FAST_MODEL = os.environ.get("DALIL_FAST_MODEL") or _default_models()[1]
MAX_UPLOAD_BYTES = _int("DALIL_MAX_UPLOAD_MB", 8) * 1024 * 1024
MAX_IMAGES = _int("DALIL_MAX_IMAGES", 6)
MAX_TEXT_CHARS = _int("DALIL_MAX_TEXT_CHARS", 30000)
MAX_AGENT_ROUNDS = _int("DALIL_MAX_AGENT_ROUNDS", 7)
MAX_OUTPUT_TOKENS = _int("DALIL_MAX_OUTPUT_TOKENS", 4096)
MODEL_TIMEOUT_S = _float("DALIL_MODEL_TIMEOUT_S", 55.0)  # Vercel stops a request at about 60 s
PRIMARY_TIMEOUT_S = _float("DALIL_PRIMARY_TIMEOUT_S", 28.0)  # per call to the main service when a backup is ready
TOTAL_BUDGET_S = _float("DALIL_TOTAL_BUDGET_S", 52.0)  # all AI calls of one request together
FETCH_TIMEOUT_S = _float("DALIL_FETCH_TIMEOUT_S", 8.0)
FETCH_MAX_CHARS = _int("DALIL_FETCH_MAX_CHARS", 6000)

# Photo quality thresholds. Calibrate with real phone photos of real documents (see docs/ARCHITECTURE.md).
MIN_SIDE_PX = _int("DALIL_MIN_SIDE_PX", 500)
MIN_LONG_SIDE_PX = _int("DALIL_MIN_LONG_SIDE_PX", 800)
BLUR_MIN_SHARPNESS = _float("DALIL_BLUR_MIN_SHARPNESS", 60.0)
DARK_MAX_MEAN = _float("DALIL_DARK_MAX_MEAN", 60.0)
MIN_CONTRAST_SPREAD = _float("DALIL_MIN_CONTRAST_SPREAD", 50.0)
MIN_DETAIL_TILES = _float("DALIL_MIN_DETAIL_TILES", 0.02)
ALLOW_ORIGINS = [o.strip() for o in os.environ.get("DALIL_ALLOW_ORIGINS", "*").split(",") if o.strip()]
# Optional shared secret so only your own app can call the API (set the same value in the app build).
APP_TOKEN = os.environ.get("DALIL_APP_TOKEN", "")
# Per-IP request budget per minute (in-memory, per server instance).
RATE_LIMIT_PER_MIN = _int("DALIL_RATE_LIMIT_PER_MIN", 20)
# Limits for requests that call the AI service (the free Gemini tier allows only a few calls a minute).
AI_MAX_CONCURRENT = _int("DALIL_AI_MAX_CONCURRENT", 3)
AI_PER_IP_INFLIGHT = _int("DALIL_AI_PER_IP_INFLIGHT", 2)
AI_PER_IP_PER_MIN = _int("DALIL_AI_PER_IP_PER_MIN", 8)
AI_GLOBAL_PER_MIN = _int("DALIL_AI_GLOBAL_PER_MIN", 12)


# Show saved results for the built-in sample documents instead of calling the model (a demo-day safety net).
USE_SAVED = os.environ.get("DALIL_USE_SAVED", "").strip().lower() in ("1", "true", "yes")


def env(name: str) -> str:
    return os.environ.get(name, "").strip()


# Extra free services that take over when the main one is busy. Each is used only if its key is set.
FALLBACKS = ("groq", "mistral", "openrouter")
_FALLBACK_KEYS = {"groq": "GROQ_API_KEY", "mistral": "MISTRAL_API_KEY", "openrouter": "OPENROUTER_API_KEY"}


def fallback_keys() -> dict[str, str]:
    order = [x.strip().lower() for x in env("DALIL_FALLBACKS").split(",") if x.strip()] or list(FALLBACKS)
    return {n: env(_FALLBACK_KEYS[n]) for n in order if n in _FALLBACK_KEYS and env(_FALLBACK_KEYS[n])}


def ai_ready() -> bool:
    return api_key() is not None or bool(fallback_keys())


def api_key() -> str | None:
    if provider() == "gemini":
        return os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY") or None
    return os.environ.get("ANTHROPIC_API_KEY") or None

"""HTTP API (FastAPI). Runs on Vercel as a Python function and locally with uvicorn."""
from __future__ import annotations

import hmac
import json
import logging
from contextlib import contextmanager

from fastapi import FastAPI, Request, Response
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from . import __version__, agent, config, languages, privacy, quality, registry, samples
from .models import AskRequest, LetterRequest, PhotoCheckRequest, ReviewRequest, decode_image
from .ratelimit import AiGate, Busy, RateLimiter

log = logging.getLogger("dalil")

app = FastAPI(title="Dalil API", version=__version__, docs_url=None, redoc_url=None, openapi_url=None)
app.add_middleware(
    CORSMiddleware,
    allow_origins=config.ALLOW_ORIGINS,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type", "X-Dalil-Token"],
    max_age=600,
)
limiter = RateLimiter(config.RATE_LIMIT_PER_MIN)
gate = AiGate(config.AI_MAX_CONCURRENT, config.AI_PER_IP_INFLIGHT, config.AI_PER_IP_PER_MIN, config.AI_GLOBAL_PER_MIN)

PRIVACY = {
    "headline": "Your documents stay yours.",
    "points": [
        "Dalil does not save your documents or photos. Nothing you send is written to a database or a log.",
        "To read a document it is sent to an AI service (Google Gemini, Anthropic, or a backup service such as Groq, Mistral or OpenRouter) and the answer comes back. That service handles data under its own terms.",
        "Cover your passport, Emirates ID, bank and phone numbers before you take a photo. Dalil hides obvious ID, card, bank, email and phone numbers in pasted text, but it cannot hide them inside a photo.",
        "Photos are checked, straightened, shrunk and stripped of location data before they are sent on.",
        "Dalil is a guide, not a lawyer. It does not give legal advice.",
    ],
}

PHOTO_TIPS = [
    "Put the page flat on a table in good light.",
    "Fill the frame with the page and keep it straight.",
    "Hold the phone steady and let the camera focus.",
    "Avoid glare and shadows over the writing.",
    "For several pages, add one photo per page, in order.",
    "Cover ID, passport and bank numbers first.",
]

MAX_REQUEST_KB = 4000  # Vercel functions accept about 4.5 MB per request


class ApiError(Exception):
    def __init__(self, status: int, code: str, message: str, **extra):
        self.status, self.code, self.message, self.extra = status, code, message, extra


@app.exception_handler(ApiError)
async def _api_error(_: Request, e: ApiError):
    headers = {"Retry-After": str(e.extra["retry_after"])} if "retry_after" in e.extra else None
    return JSONResponse({"error": {"code": e.code, "message": e.message, **e.extra}}, status_code=e.status, headers=headers)


@app.exception_handler(RequestValidationError)
async def _bad_request(_: Request, e: RequestValidationError):
    # Report only where the problem is. Never echo the input: it may be a personal document.
    fields = [".".join(str(p) for p in err["loc"][1:]) or "body" for err in e.errors()]
    return JSONResponse({"error": {"code": "bad_request", "message": "The request was not valid.", "fields": fields}}, status_code=422)


def _client_ip(request: Request) -> str:
    fwd = request.headers.get("x-forwarded-for", "")
    return fwd.split(",")[0].strip() or (request.client.host if request.client else "unknown")


def guard(request: Request) -> None:
    if config.APP_TOKEN and not hmac.compare_digest(request.headers.get("x-dalil-token", ""), config.APP_TOKEN):
        raise ApiError(401, "unauthorized", "This app is not allowed to use this server.")
    cl = request.headers.get("content-length", "")
    if cl.isdigit() and int(cl) > config.MAX_UPLOAD_BYTES:
        raise ApiError(413, "too_large", "That upload is too large. Send fewer or smaller photos.")
    if not limiter.allow(_client_ip(request)):
        raise ApiError(429, "rate_limited", "Too many requests. Wait a minute and try again.")


@contextmanager
def ai_slot(request: Request):
    ip = _client_ip(request)
    try:
        gate.acquire(ip)
    except Busy as b:
        raise ApiError(429, "busy", b.message, retry_after=b.retry_after)
    try:
        yield
    finally:
        gate.release(ip)


def _model_problem(e: Exception) -> ApiError:
    if isinstance(e, agent.ModelUnavailable):
        if str(e) == "no_api_key":
            return ApiError(503, "model_unavailable", "Dalil's AI service is not set up on this server.")
        why = str(e)  # only a short code such as api_429, never any document text
        log.warning("model call failed: %s", why)
        hints = {
            "api_400": "The AI service rejected the request (check the model name or API key).",
            "api_401": "The AI service says the API key is not valid. Set a new key and restart the server.",
            "api_403": "The AI service refused the API key (wrong, deleted, or not allowed). Set a new key and restart the server.",
            "api_404": "The AI model name was not found. Set DALIL_MODEL to a model your key can use.",
            "api_408": "The AI took too long to answer. Try again, or set DALIL_MODEL to a faster model.",
            "api_0": "Dalil could not connect to the AI service (internet, VPN, firewall or antivirus may be blocking it).",
            "api_503": "Google's AI is overloaded right now. Wait a minute and try again.",
            "api_429": "The AI service is busy or the free limit was reached. Wait a minute and try again.",
        }
        return ApiError(503, "model_unavailable", hints.get(why, "Dalil cannot reach its AI service right now. Try again in a minute.") + f" [{why}]")
    return ApiError(502, "bad_model_output", "Dalil could not put together a clear answer. Try again, or send a clearer document.")


@app.get("/api/health")
def health():
    return {"ok": True, "version": __version__, "model_ready": config.ai_ready()}


@app.get("/api/meta")
def meta(response: Response):
    response.headers["Cache-Control"] = "public, max-age=300"
    return {
        "version": __version__,
        "model_ready": config.ai_ready(),
        "languages": languages.as_dicts(),
        "countries": registry.coverage(),
        "samples": samples.list_samples(),
        "limits": {"max_images": config.MAX_IMAGES, "max_text_chars": config.MAX_TEXT_CHARS, "max_request_kb": MAX_REQUEST_KB},
        "photo_tips": PHOTO_TIPS,
        "privacy": PRIVACY,
    }


@app.post("/api/photo-check")
def photo_check(req: PhotoCheckRequest, request: Request):
    guard(request)
    try:
        raw = decode_image(req.image)
    except ValueError:
        raise ApiError(422, "bad_image", "That file could not be read as a photo.")
    return quality.assess_image(raw).to_dict()


@app.post("/api/review")
def review(req: ReviewRequest, request: Request):
    guard(request)
    lang = languages.get_language(req.language)
    text = (req.text or "").strip()
    if not req.images and not text:
        raise ApiError(422, "empty", "Add a photo or paste the text of the document.")

    pages: list[bytes] = []
    failed = []
    for i, s in enumerate(req.images):
        try:
            raw = decode_image(s)
        except ValueError:
            raise ApiError(422, "bad_image", "One of the photos could not be read.")
        rep = quality.assess_image(raw)
        if not rep.ok:
            failed.append({"index": i, "issues": [{"code": x.code, "message": x.message} for x in rep.issues]})
            continue
        norm, _ = quality.normalize_image(raw)
        pages.append(norm)
    if failed:
        raise ApiError(422, "photo_quality", "Some photos are not clear enough to read. Retake them and try again.", pages=failed)

    masked = privacy.mask_personal_data(text) if text else None
    use_saved = bool(req.sample_id) and (config.USE_SAVED or not config.ai_ready())

    def saved() -> dict | None:
        r = samples.saved_report(req.sample_id)
        if r:
            r["saved_note"] = "This is a saved result for a sample document. It was not produced live."
        return r

    if use_saved and (r := saved()):
        return r
    try:
        with ai_slot(request):
            report = agent.review(images=pages, text=masked.text if masked else None, lang=lang, country=req.country)
    except ApiError as e:
        if e.code == "busy" and req.sample_id and (r := saved()):
            return r
        raise
    except agent.PhotoUnreadable as e:
        raise ApiError(422, "photo_unreadable", "The photo is not clear enough to read. Retake it and try again.", issues=e.issues)
    except (agent.ModelUnavailable, agent.ModelOutputError) as e:
        if req.sample_id and (r := saved()):
            return r
        raise _model_problem(e)
    report["privacy"] = {"hidden": masked.counts if masked else {}, "hidden_total": masked.total if masked else 0}
    return report


def _check_report(report: dict) -> None:
    if len(json.dumps(report, ensure_ascii=False)) > 60000:
        raise ApiError(413, "too_large", "That report is too large.")


@app.post("/api/ask")
def ask(req: AskRequest, request: Request):
    guard(request)
    _check_report(req.report)
    try:
        with ai_slot(request):
            return agent.ask(question=req.question, report=req.report, lang=languages.get_language(req.language), history=req.history)
    except (agent.ModelUnavailable, agent.ModelOutputError) as e:
        raise _model_problem(e)


@app.post("/api/letter")
def letter(req: LetterRequest, request: Request):
    guard(request)
    _check_report(req.report)
    try:
        with ai_slot(request):
            return agent.draft_letter(report=req.report, recipient=req.recipient, note=req.note, lang=languages.get_language(req.language))
    except (agent.ModelUnavailable, agent.ModelOutputError) as e:
        raise _model_problem(e)

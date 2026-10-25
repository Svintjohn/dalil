"""HTTP API (FastAPI). Runs on Vercel as a Python function and locally with uvicorn."""
from __future__ import annotations

import hmac
import json
import logging
import re
from contextlib import contextmanager
from functools import lru_cache
from pathlib import Path

from fastapi import FastAPI, Request, Response
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
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
# Compress bigger answers (the language list and the review reports shrink to about a fifth).
app.add_middleware(GZipMiddleware, minimum_size=800)
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


# People see a short, calm message. The technical reason goes into "detail" (for whoever runs the server) and the log.
def _is_busy(why: str) -> bool:
    """Temporary trouble (rate limit, overload, timeout, no connection) that is worth retrying in a minute."""
    if why == "connection":
        return True
    m = re.fullmatch(r"api_(\d+)", why)
    return bool(m) and (int(m.group(1)) in (0, 408, 429) or 500 <= int(m.group(1)) < 600)


_SETUP_HINTS = {
    "api_400": "The AI service rejected the request (check the model name or API key).",
    "api_401": "The AI service says the API key is not valid. Set a new key and redeploy.",
    "api_403": "The AI service refused the API key (wrong, deleted, or not allowed). Set a new key and redeploy.",
    "api_404": "The AI model name was not found. Set DALIL_MODEL to a model your key can use.",
}
BUSY_MESSAGE = "Dalil is very busy right now. Please try again in about a minute. Nothing you sent was saved."
# The same calm message in the main languages of the people Dalil is for. Other languages get English.
# (Short and plain on purpose; worth a check by a native speaker before a public launch.)
BUSY_MESSAGES = {
    "ar": "دليل مزدحم جدًا الآن. يُرجى المحاولة مرة أخرى بعد دقيقة تقريبًا. لم يتم حفظ أي شيء أرسلته.",
    "tl": "Napakaraming gumagamit ng Dalil ngayon. Pakisubukan ulit sa loob ng mga isang minuto. Walang na-save sa ipinadala mo.",
    "hi": "अभी दलील पर बहुत भीड़ है। कृपया लगभग एक मिनट बाद फिर कोशिश करें। आपने जो भेजा, उसमें से कुछ भी सहेजा नहीं गया।",
    "ur": "اس وقت دلیل پر بہت رش ہے۔ براہِ کرم تقریباً ایک منٹ بعد دوبارہ کوشش کریں۔ آپ کی بھیجی ہوئی کوئی چیز محفوظ نہیں کی گئی۔",
    "bn": "এখন দলিলে অনেক ভিড়। অনুগ্রহ করে প্রায় এক মিনিট পরে আবার চেষ্টা করুন। আপনি যা পাঠিয়েছেন তার কিছুই সংরক্ষিত হয়নি।",
    "ne": "अहिले दलिलमा धेरै भिड छ। कृपया करिब एक मिनेटपछि फेरि प्रयास गर्नुहोस्। तपाईंले पठाएको कुनै पनि कुरा सुरक्षित गरिएको छैन।",
    "si": "දැන් දලීල් වෙත ඉතා වැඩි පිරිසක් සිටී. කරුණාකර විනාඩියකින් පමණ නැවත උත්සාහ කරන්න. ඔබ එවූ කිසිවක් සුරකින ලද්දේ නැත.",
    "ta": "இப்போது தலீலில் அதிக கூட்டம் உள்ளது. சுமார் ஒரு நிமிடம் கழித்து மீண்டும் முயற்சிக்கவும். நீங்கள் அனுப்பியது எதுவும் சேமிக்கப்படவில்லை.",
    "ml": "ഇപ്പോൾ ദലീലിൽ വളരെ തിരക്കാണ്. ഏകദേശം ഒരു മിനിറ്റിനു ശേഷം വീണ്ടും ശ്രമിക്കുക. നിങ്ങൾ അയച്ചതൊന്നും സേവ് ചെയ്തിട്ടില്ല.",
    "fr": "Dalil est très sollicité en ce moment. Veuillez réessayer dans environ une minute. Rien de ce que vous avez envoyé n'a été enregistré.",
    "es": "Dalil tiene mucha demanda ahora mismo. Inténtalo de nuevo en aproximadamente un minuto. No se guardó nada de lo que enviaste.",
    "zh-Hans": "Dalil 现在非常繁忙。请大约一分钟后再试。您发送的内容均未被保存。",
    "ru": "Сейчас Dalil очень загружен. Пожалуйста, повторите попытку примерно через минуту. Ничего из отправленного вами не сохранено.",
}


def busy_message(lang: str = "en") -> str:
    return BUSY_MESSAGES.get(lang or "en", BUSY_MESSAGE)


def _model_problem(e: Exception, lang: str = "en") -> ApiError:
    if isinstance(e, agent.ModelUnavailable):
        why = str(e)  # only a short code such as api_429, never any document text
        if why == "no_api_key":
            return ApiError(503, "model_unavailable", "Dalil is not available right now. Please try again later.", detail="The AI service is not set up on this server (no API key).")
        log.warning("model call failed: %s", why)
        if _is_busy(why):
            return ApiError(503, "model_busy", busy_message(lang), retry_after=60, detail=f"[{why}]")
        hint = _SETUP_HINTS.get(why, "Dalil cannot reach its AI service.")
        return ApiError(503, "model_unavailable", "Dalil is not available right now. Please try again in a few minutes.", detail=f"{hint} [{why}]")
    return ApiError(502, "bad_model_output", "Dalil could not put together a clear answer this time. Please try again, or send a clearer document.")


@app.get("/api/health")
def health():
    return {"ok": True, "version": __version__, "model_ready": config.ai_ready()}


@lru_cache(maxsize=4)
def _meta_body(model_ready: bool) -> dict:
    """The page setup data. It only changes when the server restarts, so it is built once, not on every visit."""
    return {
        "version": __version__,
        "model_ready": model_ready,
        "languages": languages.as_dicts(),
        "countries": registry.coverage(),
        "samples": samples.list_samples(),
        "form_samples": samples.list_form_samples(),
        "limits": {"max_images": config.MAX_IMAGES, "max_text_chars": config.MAX_TEXT_CHARS, "max_request_kb": MAX_REQUEST_KB},
        "photo_tips": PHOTO_TIPS,
        "privacy": PRIVACY,
    }


@app.get("/api/meta")
def meta(response: Response):
    response.headers["Cache-Control"] = "public, max-age=300, stale-while-revalidate=3600"
    return _meta_body(bool(config.ai_ready()))


@app.post("/api/photo-check")
def photo_check(req: PhotoCheckRequest, request: Request):
    guard(request)
    try:
        raw = decode_image(req.image)
    except ValueError:
        raise ApiError(422, "bad_image", "That file could not be read as a photo.")
    return quality.assess_image(raw).to_dict()


def _prepare_pages(images: list[str]) -> list[bytes]:
    """Decode, check and normalise the photos. A page that is not clear enough stops the request with a calm message."""
    pages: list[bytes] = []
    failed = []
    for i, s in enumerate(images):
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
    return pages


@app.post("/api/review")
def review(req: ReviewRequest, request: Request):
    guard(request)
    lang = languages.get_language(req.language)
    text = (req.text or "").strip()
    if not req.images and not text:
        raise ApiError(422, "empty", "Add a photo or paste the text of the document.")

    pages = _prepare_pages(req.images)

    masked = privacy.mask_personal_data(text) if text else None
    use_saved = bool(req.sample_id) and (config.USE_SAVED or not config.ai_ready())

    def saved() -> dict | None:
        r = samples.saved_report(req.sample_id, req.language)
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
        raise _model_problem(e, req.language)
    report["privacy"] = {"hidden": masked.counts if masked else {}, "hidden_total": masked.total if masked else 0}
    return report


@app.post("/api/form")
def form(req: ReviewRequest, request: Request):
    """Help with filling in a form: what each box asks for. It never writes the person's details for them."""
    guard(request)
    if req.sample_id and (saved := samples.saved_form(req.sample_id)):
        return saved  # a made-up sample form: always the saved result, so trying it costs nothing
    lang = languages.get_language(req.language)
    text = (req.text or "").strip()
    if not req.images and not text:
        raise ApiError(422, "empty", "Add a photo or a PDF of the form, or paste its text.")
    pages = _prepare_pages(req.images)
    masked = privacy.mask_personal_data(text) if text else None
    try:
        with ai_slot(request):
            out = agent.form_help(images=pages, text=masked.text if masked else None, lang=lang, country=req.country)
    except agent.PhotoUnreadable as e:
        raise ApiError(422, "photo_unreadable", "The photo is not clear enough to read. Retake it and try again.", issues=e.issues)
    except (agent.ModelUnavailable, agent.ModelOutputError) as e:
        raise _model_problem(e, req.language)
    out["privacy"] = {"hidden": masked.counts if masked else {}, "hidden_total": masked.total if masked else 0}
    return out


ACCURACY_CAVEAT = (
    "The test documents were written by the developers, and the rules were tuned on them. These numbers show that the checks "
    "still work as designed. They are not proof of accuracy on real documents, which has not been measured yet."
)


@lru_cache(maxsize=1)
def _accuracy_body() -> dict:
    from evaluation import score  # the labeled test documents; only counts and case ids leave this function

    live = None
    try:
        path = Path(__file__).resolve().parent.parent / "evaluation" / "results" / "live.json"
        data = json.loads(path.read_text(encoding="utf-8"))
        if isinstance(data, dict) and all(isinstance(data.get(k), dict) for k in ("scam", "legit", "numbers")):
            live = data
    except Exception:  # noqa: BLE001 - no live run saved yet, or a damaged file
        live = None
    return {"version": __version__, "offline": score.run_offline(), "live": live, "caveat": ACCURACY_CAVEAT}


@app.get("/api/accuracy")
def accuracy(response: Response):
    response.headers["Cache-Control"] = "public, max-age=300, stale-while-revalidate=3600"
    return _accuracy_body()


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
        raise _model_problem(e, req.language)


@app.post("/api/letter")
def letter(req: LetterRequest, request: Request):
    guard(request)
    _check_report(req.report)
    if req.report.get("saved") and (sl := samples.saved_letter(str(req.report.get("sample_id") or ""), req.language)):
        return sl  # the report is a saved sample, so its letter is a saved sample too
    try:
        with ai_slot(request):
            return agent.draft_letter(report=req.report, recipient=req.recipient, note=req.note, lang=languages.get_language(req.language))
    except (agent.ModelUnavailable, agent.ModelOutputError) as e:
        raise _model_problem(e, req.language)

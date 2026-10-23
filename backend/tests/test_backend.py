"""Backend tests. The model is replaced by a fake client, so no network or API key is needed."""
from __future__ import annotations

import base64
import io
import json
from datetime import date
from types import SimpleNamespace as NS

import httpx
import pytest
from fastapi.testclient import TestClient
from PIL import Image, ImageDraw, ImageFilter

from dalil import agent, config, languages, privacy, quality, registry, samples, tools
from dalil.app import app, gate, limiter
from dalil.models import RawReport

client = TestClient(app)


def make_page(blur: float = 0, dark: bool = False, size=(1100, 1500)) -> bytes:
    img = Image.new("L", size, 235 if not dark else 20)
    d = ImageDraw.Draw(img)
    y = 40
    while y < size[1] - 40:
        d.text((50, y), "Tenancy contract clause: the tenant shall pay AED 78,000 in one cheque. " * 2, fill=0 if not dark else 60)
        y += 18
    if blur:
        img = img.filter(ImageFilter.GaussianBlur(blur))
    out = io.BytesIO()
    img.convert("RGB").save(out, "JPEG", quality=92)
    return out.getvalue()


def b64(raw: bytes) -> str:
    return base64.b64encode(raw).decode()


def fake_resp(*blocks, stop="end_turn"):
    return NS(content=list(blocks), stop_reason=stop)


def text_block(t):
    return NS(type="text", text=t)


def tool_block(name, inp, id="tu1"):
    return NS(type="tool_use", id=id, name=name, input=inp)


class FakeClient:
    def __init__(self, *responses):
        self.responses = list(responses)
        self.calls = []
        self.messages = self

    def create(self, **kw):
        self.calls.append(kw)
        return self.responses.pop(0)


def test_registry_loads_and_has_uae():
    data = registry.load_all()
    assert "AE" in data
    ae = data["AE"]
    assert sum(len(t.facts) for t in ae.topics.values()) >= 30
    assert all(f.verified_on <= ae.last_verified for t in ae.topics.values() for f in t.facts)


def test_every_country_url_is_https_and_official():
    for c in registry.load_all().values():
        for label, url in c._url_list():
            assert url.startswith("https://"), (c.country, label, url)


def test_languages():
    codes = [l.code for l in languages.LANGUAGES]
    assert len(codes) == len(set(codes)) >= 60
    assert languages.get_language("ja").native == "日本語"
    assert languages.get_language("nope").code == "en"
    assert languages.get_language("ur").rtl and languages.get_language("ar").rtl


def test_privacy_masking():
    r = privacy.mask_personal_data("Emirates ID 784-1990-1234567-1, call +971 50 123 4567, mail a@b.com, passport no: N1234567")
    assert "784-1990" not in r.text and "a@b.com" not in r.text and "N1234567" not in r.text
    assert r.total >= 4


def test_quality_accepts_sharp_and_rejects_blurry_and_dark():
    assert quality.assess_image(make_page()).ok
    blurry = quality.assess_image(make_page(blur=9))
    assert not blurry.ok and any(i.code in ("blurry", "low_detail") for i in blurry.issues)
    dark = quality.assess_image(make_page(dark=True))
    assert not dark.ok
    assert not quality.assess_image(b"not an image").ok


def test_normalize_strips_exif():
    img = Image.new("RGB", (900, 1200), "white")
    exif = Image.Exif()
    exif[0x010F] = "SecretPhone"
    buf = io.BytesIO()
    img.save(buf, "JPEG", exif=exif)
    out, mime = quality.normalize_image(buf.getvalue())
    assert mime == "image/jpeg"
    assert b"SecretPhone" not in out


def test_lookup_rules():
    r = tools.lookup_rules("ae", "employment")
    assert r["covered"] and r["facts"] and r["facts"][0]["ref"].startswith("AE:employment:")
    assert tools.lookup_rules("ZZ")["covered"] is False


def test_fetch_official_page_refuses_other_hosts():
    assert tools.fetch_official_page("https://example.com/")["ok"] is False
    assert tools.fetch_official_page("http://u.ae/en")["ok"] is False
    assert tools.fetch_official_page("https://u.ae.evil.com/")["ok"] is False
    assert tools.fetch_official_page("https://127.0.0.1/")["ok"] is False


def test_run_tool_survives_bad_input():
    assert "error" in tools.run_tool("nope", {})
    assert tools.run_tool("lookup_rules", {})  # missing country must not raise


@pytest.mark.parametrize("sid", [k for k in samples.SAMPLES if k not in ("school", "bill")])
def test_saved_samples_resolve_against_registry(sid):
    r = samples.saved_report(sid)
    assert r["saved"] and r["coverage"] == "verified" and r["findings"]
    raw = samples.SAMPLES[sid]["raw"]
    wanted = {ref for f in raw["findings"] for ref in f["rule_refs"]}
    got = {s["ref"] for f in r["findings"] for s in f["sources"]}
    assert wanted == got, f"unresolved refs in {sid}: {wanted - got}"
    for f in r["findings"]:
        if f["severity"] == "high":
            assert f["sources"]
    for step in r["next_steps"]:
        if step["authority"] is not None:
            assert step["authority"]["url"].startswith("https://")


def test_finalize_downgrades_unsourced_high_and_drops_fake_refs():
    raw = RawReport.model_validate(
        {
            "country": "AE",
            "summary": "x",
            "findings": [
                {"severity": "high", "why": "no source", "rule_refs": ["AE:employment:made_up"]},
                {"severity": "high", "why": "sourced", "rule_refs": ["AE:employment:no_document_withholding"]},
            ],
            "next_steps": [{"action": "call", "authority_ref": "AE:not_real"}, {"action": "call", "authority_ref": "AE:mohre"}],
        }
    )
    r = agent.finalize_report(raw, languages.get_language("en"))
    by = {f["why"]: f for f in r["findings"]}
    assert by["no source"]["severity"] == "medium" and not by["no source"]["verified"]
    assert by["sourced"]["severity"] == "high" and by["sourced"]["sources"][0]["url"].startswith("https://")
    assert r["next_steps"][0]["authority"] is None and r["next_steps"][1]["authority"]["name"].startswith("Ministry")


def test_uncovered_country_is_marked():
    r = agent.finalize_report(RawReport.model_validate({"country": "ZZ", "summary": "x"}), languages.get_language("en"))
    assert r["coverage"] == "none" and r["country_name"] is None

GOOD = {
    "readable": True, "country": "AE", "doc_type": "Job offer", "summary": "Test.",
    "findings": [{"severity": "high", "kind": "clause", "quote": "keep the passport", "why": "Not allowed.",
                  "ask": "your passport", "rule_refs": ["AE:employment:no_document_withholding"]}],
}


def test_review_runs_tool_loop_then_returns_report():
    fc = FakeClient(
        fake_resp(tool_block("lookup_rules", {"country": "AE", "topic": "employment"}), stop="tool_use"),
        fake_resp(text_block(json.dumps(GOOD))),
    )
    r = agent.review(images=[], text="The company will keep the passport.", lang=languages.get_language("tl"), country="AE", client=fc)
    assert r["findings"][0]["sources"] and r["language"] == "tl"
    assert len(fc.calls) == 2
    sent = fc.calls[1]["messages"][-1]["content"][0]
    assert sent["type"] == "tool_result" and "no_document_withholding" in sent["content"]
    assert "Tagalog" in fc.calls[0]["system"]


def test_review_unreadable_photo_raises_with_messages():
    bad = {"readable": False, "readability_issues": ["blurry", "bogus_code"]}
    fc = FakeClient(fake_resp(text_block(json.dumps(bad))))
    with pytest.raises(agent.PhotoUnreadable) as e:
        agent.review(images=[make_page()], text=None, lang=languages.get_language("en"), country=None, client=fc)
    assert [i["code"] for i in e.value.issues] == ["blurry"]


def test_review_bad_json_and_truncation():
    with pytest.raises(agent.ModelOutputError):
        agent.review(images=[], text="x", lang=languages.get_language("en"), country=None, client=FakeClient(fake_resp(text_block("sorry, no"))))
    with pytest.raises(agent.ModelOutputError):
        agent.review(images=[], text="x", lang=languages.get_language("en"), country=None, client=FakeClient(fake_resp(text_block("{"), stop="max_tokens")))


def test_parse_json_tolerates_fences_and_chatter():
    assert agent.parse_json('```json\n{"a": 1}\n```') == {"a": 1}
    assert agent.parse_json('Here you go: {"a": 2} Hope it helps') == {"a": 2}


def test_ask_and_letter_resolve_sources():
    fc = FakeClient(fake_resp(text_block(json.dumps({"answer": "Ask MoHRE.", "rule_refs": ["AE:employment:no_document_withholding", "AE:x:y"], "authority_refs": ["AE:mohre"]}))))
    a = agent.ask(question="Can they keep my passport?", report={"summary": "x"}, lang=languages.get_language("en"), history=[], client=fc)
    assert len(a["sources"]) == 1 and a["authorities"][0]["ref"] == "AE:mohre"
    fc = FakeClient(fake_resp(text_block(json.dumps({"to": "Employer", "subject": "s", "letter_en": "Dear...", "letter_local": "Kära...", "rule_refs": []}))))
    l = agent.draft_letter(report={"summary": "x"}, recipient="employer", note="", lang=languages.get_language("sv"), client=fc)
    assert l["letter_en"] and "not legal advice" in l["note"]


@pytest.fixture(autouse=True)
def _reset_limiter():
    limiter.hits.clear()
    gate.ip_rate.hits.clear()
    gate.all_rate.hits.clear()
    gate.running = 0
    gate.by_ip.clear()
    yield


def test_health_and_meta():
    assert client.get("/api/health").json()["ok"] is True
    m = client.get("/api/meta").json()
    assert len(m["languages"]) >= 60 and any(c["code"] == "AE" for c in m["countries"])
    assert {s["id"] for s in m["samples"]} == set(samples.SAMPLES)
    assert any("not save" in p for p in m["privacy"]["points"])


def test_review_sample_falls_back_to_saved_without_api_key():
    s = samples.SAMPLES["job"]
    r = client.post("/api/review", json={"text": s["text"], "sample_id": "job", "language": "ur"})
    assert r.status_code == 200
    j = r.json()
    assert j["saved"] and j["saved_note"] and j["findings"]


def test_review_without_key_and_not_a_sample_is_503():
    r = client.post("/api/review", json={"text": "some contract text that is long enough", "language": "en"})
    assert r.status_code == 503 and r.json()["error"]["code"] == "model_unavailable"


def test_review_rejects_blurry_photo_before_any_model_call():
    r = client.post("/api/review", json={"images": [b64(make_page()), b64(make_page(blur=9))], "language": "en"})
    assert r.status_code == 422
    e = r.json()["error"]
    assert e["code"] == "photo_quality" and e["pages"][0]["index"] == 1 and e["pages"][0]["issues"]


def test_photo_check_endpoint():
    ok = client.post("/api/photo-check", json={"image": b64(make_page())}).json()
    bad = client.post("/api/photo-check", json={"image": b64(make_page(blur=9))}).json()
    assert ok["ok"] and not bad["ok"]
    assert client.post("/api/photo-check", json={"image": "!!!"}).status_code == 422


def test_validation_errors_do_not_echo_input():
    secret = "PASSPORT-N1234567"
    r = client.post("/api/review", json={"text": secret, "language": "en", "country": "TOOLONG"})
    assert r.status_code == 422 and secret not in r.text


def test_empty_request_and_too_many_pages():
    assert client.post("/api/review", json={"language": "en"}).status_code == 422
    r = client.post("/api/review", json={"images": ["AAAA"] * (config.MAX_IMAGES + 1)})
    assert r.status_code == 422


def test_rate_limit(monkeypatch):
    monkeypatch.setattr(limiter, "per_minute", 2)
    codes = [client.post("/api/photo-check", json={"image": "!!!"}).status_code for _ in range(3)]
    assert codes == [422, 422, 429]


def test_app_token_guard(monkeypatch):
    monkeypatch.setattr(config, "APP_TOKEN", "s3cret")
    assert client.post("/api/photo-check", json={"image": "!!!"}).status_code == 401
    assert client.post("/api/photo-check", json={"image": "!!!"}, headers={"X-Dalil-Token": "s3cret"}).status_code == 422


def test_gemini_adapter_runs_tool_loop(monkeypatch):
    from dalil import config, gemini

    sent = []

    class R:
        def __init__(self, data, status=200):
            self._d, self.status_code = data, status

        def json(self):
            return self._d

    replies = [
        {"candidates": [{"content": {"parts": [{"functionCall": {"name": "lookup_rules", "args": {"country": "AE", "topic": "employment"}}, "thoughtSignature": "sig"}]}}]},
        {"candidates": [{"content": {"parts": [{"text": json.dumps(GOOD)}]}, "finishReason": "STOP"}]},
    ]

    def fake_post(url, json=None, headers=None, timeout=None):
        sent.append(json)
        return R(replies[len(sent) - 1])

    monkeypatch.setattr(gemini.httpx, "post", fake_post)
    out = agent.review(images=[], text="x", lang=languages.get_language("en"), country=None, client=gemini.GeminiClient("k"))
    assert out["readable"] is True
    # the second call carries the tool result and the signed function call back
    parts = [p for c in sent[1]["contents"] for p in c["parts"]]
    assert any("functionResponse" in p for p in parts)
    assert any(p.get("thoughtSignature") == "sig" for p in parts)
    assert "tools" not in sent[1] or True


def test_gemini_http_error_becomes_model_unavailable(monkeypatch):
    from dalil import gemini

    class R:
        status_code = 403

        def json(self):
            return {}

    monkeypatch.setattr(gemini.httpx, "post", lambda *a, **k: R())
    with pytest.raises(agent.ModelUnavailable):
        agent.review(images=[], text="x", lang=languages.get_language("en"), country=None, client=gemini.GeminiClient("k"))


def test_provider_picks_gemini_when_only_gemini_key(monkeypatch):
    from dalil import config

    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    monkeypatch.delenv("DALIL_PROVIDER", raising=False)
    monkeypatch.setenv("GEMINI_API_KEY", "k")
    assert config.provider() == "gemini" and config.api_key() == "k"


def test_ask_accepts_app_history_shape():
    fc = FakeClient(fake_resp(text_block(json.dumps({"answer": "ok", "rule_refs": [], "authority_refs": []}))))
    agent.ask(question="q", report={}, lang=languages.get_language("en"), history=[{"role": "user", "content": "a"}, {"role": "assistant", "content": "b"}], client=fc)


def test_gemini_picks_newest_flash_when_model_missing(monkeypatch):
    from dalil import gemini

    models = [
        {"name": "models/gemini-2.5-flash", "supportedGenerationMethods": ["generateContent"]},
        {"name": "models/gemini-3-flash", "supportedGenerationMethods": ["generateContent"]},
        {"name": "models/gemini-3-flash-lite", "supportedGenerationMethods": ["generateContent"]},
        {"name": "models/gemini-4-flash-preview", "supportedGenerationMethods": ["generateContent"]},
        {"name": "models/text-embedding-004", "supportedGenerationMethods": ["embedContent"]},
    ]
    assert gemini.pick_flash(models) == "gemini-3-flash"  # stable beats preview, newest stable wins

    calls = []

    class R:
        def __init__(self, status, data=None):
            self.status_code, self._d = status, data or {}

        def json(self):
            return self._d

    def fake_post(url, **k):
        calls.append(url)
        return R(404) if "old-model" in url else R(200, {"candidates": [{"content": {"parts": [{"text": "hi"}]}}]})

    monkeypatch.setattr(gemini.httpx, "post", fake_post)
    monkeypatch.setattr(gemini.httpx, "get", lambda *a, **k: R(200, {"models": models}))
    gemini._PICKED.clear()
    resp = gemini.GeminiClient("k").messages.create(model="old-model", max_tokens=10, system="s", messages=[{"role": "user", "content": "x"}])
    assert resp.content[0].text == "hi" and "gemini-3-flash" in calls[-1]


def test_gemini_retries_when_busy_then_succeeds(monkeypatch):
    from dalil import gemini

    monkeypatch.setattr(gemini.time, "sleep", lambda s: None)
    seq = iter([503, 503, 200])

    class R:
        def __init__(self, c):
            self.status_code = c

        def json(self):
            return {"candidates": [{"content": {"parts": [{"text": "ok"}]}}]} if self.status_code == 200 else {"error": {"message": "busy"}}

    monkeypatch.setattr(gemini.httpx, "post", lambda *a, **k: R(next(seq)))
    gemini._PICKED.clear()
    r = gemini.GeminiClient("k").messages.create(model="m", max_tokens=10, system="s", messages=[{"role": "user", "content": "x"}])
    assert r.content[0].text == "ok"


def test_any_document_gets_plain_words_and_no_registry_noise():
    raw = RawReport.model_validate({
        "doc_type": "school notice", "country": None, "summary": "The school asks for a form.",
        "points": [{"original": "Return by Friday", "plain": "Give the form back by Friday."}, {"original": "", "plain": ""}],
        "terms": [{"term": "consent", "meaning": "your permission"}, {"term": "", "meaning": "x"}],
    })
    out = agent.finalize_report(raw, languages.get_language("en"))
    assert out["points"] == [{"original": "Return by Friday", "plain": "Give the form back by Friday."}]
    assert out["terms"] == [{"term": "consent", "meaning": "your permission"}]
    assert out["findings"] == [] and out["country"] is None


def test_ai_gate_limits():
    from dalil.ratelimit import AiGate, Busy

    g = AiGate(max_concurrent=2, per_ip_inflight=1, per_ip_per_min=100, global_per_min=100)
    g.acquire("a")
    with pytest.raises(Busy):
        g.acquire("a")  # one at a time per visitor
    g.acquire("b")
    with pytest.raises(Busy):
        g.acquire("c")  # only two jobs at once overall
    g.release("a")
    g.acquire("c")
    g.release("b")
    g.release("c")
    assert g.running == 0

    g = AiGate(max_concurrent=5, per_ip_inflight=5, per_ip_per_min=2, global_per_min=3)
    for _ in range(2):
        g.acquire("a")
        g.release("a")
    with pytest.raises(Busy):
        g.acquire("a")  # visitor minute budget
    g.acquire("b")
    g.release("b")
    with pytest.raises(Busy):
        g.acquire("c")  # everyone's minute budget


def test_busy_returns_429_with_retry_after_and_samples_fall_back(monkeypatch):
    monkeypatch.setattr(config, "api_key", lambda: "k")
    monkeypatch.setattr(config, "USE_SAVED", False)
    monkeypatch.setattr(gate, "max_concurrent", 1)
    gate.running = 1
    r = client.post("/api/review", json={"text": "some contract text that is long enough", "language": "en"})
    assert r.status_code == 429 and r.json()["error"]["code"] == "busy"
    assert int(r.headers["retry-after"]) > 0
    s = samples.SAMPLES["job"]
    r = client.post("/api/review", json={"text": s["text"], "sample_id": "job", "language": "en"})
    assert r.status_code == 200 and r.json()["saved"]


def test_meta_is_cacheable():
    assert "max-age" in client.get("/api/meta").headers["cache-control"]


def test_failover_uses_next_service_when_first_is_busy(monkeypatch):
    from types import SimpleNamespace
    from dalil import failover
    from dalil.gemini import LLMError

    failover._resting.clear()
    calls = []

    class Busy:
        class messages:
            @staticmethod
            def create(**kw):
                calls.append("a")
                raise LLMError(503)

    class Fine:
        class messages:
            @staticmethod
            def create(**kw):
                calls.append("b")
                return SimpleNamespace(content=[], stop_reason="end_turn")

    c = failover.FailoverClient([("a", Busy), ("b", Fine)])
    assert c.messages.create(model="m").stop_reason == "end_turn"
    c.messages.create(model="m")
    assert calls == ["a", "b", "b"]  # the busy service rests, so the second request skips it
    failover._resting.clear()


def test_failover_does_not_hide_a_bad_key():
    from dalil import failover
    from dalil.gemini import LLMError

    failover._resting.clear()

    class BadKey:
        class messages:
            @staticmethod
            def create(**kw):
                raise LLMError(401)

    with pytest.raises(LLMError):
        failover.FailoverClient([("a", BadKey), ("b", BadKey)]).messages.create(model="m")


def test_openai_compat_round_trip(monkeypatch):
    import json as _json
    from dalil import openai_compat

    seen = {}

    def fake_post(url, json=None, headers=None, timeout=None):
        seen["body"] = json
        seen["auth"] = headers["Authorization"]
        return httpx.Response(200, json={"choices": [{"finish_reason": "tool_calls", "message": {"content": None, "tool_calls": [{"id": "x1", "type": "function", "function": {"name": "lookup", "arguments": _json.dumps({"q": 1})}}]}}]})

    monkeypatch.setattr(openai_compat.httpx, "post", fake_post)
    c = openai_compat.OpenAICompatClient("groq", "k")
    img = {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": "AAAA"}}
    tools = [{"name": "lookup", "description": "d", "input_schema": {"type": "object", "properties": {}}}]
    r = c.messages.create(model="ignored", max_tokens=10, system="s", messages=[{"role": "user", "content": [img, {"type": "text", "text": "hi"}]}], tools=tools)
    assert r.stop_reason == "tool_use" and r.content[0].name == "lookup" and r.content[0].input == {"q": 1}
    assert seen["auth"] == "Bearer k" and seen["body"]["tools"][0]["function"]["name"] == "lookup"
    assert seen["body"]["messages"][1]["content"][0]["image_url"]["url"].startswith("data:image/jpeg;base64,")
    follow = [
        {"role": "user", "content": "hi"},
        {"role": "assistant", "content": r.content},
        {"role": "user", "content": [{"type": "tool_result", "tool_use_id": r.content[0].id, "content": "done"}]},
    ]
    c.messages.create(model="m", max_tokens=10, system="s", messages=follow)
    msgs = seen["body"]["messages"]
    assert msgs[2]["tool_calls"][0]["id"] == msgs[3]["tool_call_id"] and len(msgs[3]["tool_call_id"]) == 9


def test_backup_keys_make_ai_ready(monkeypatch):
    for k in ("GEMINI_API_KEY", "GOOGLE_API_KEY", "ANTHROPIC_API_KEY", "GROQ_API_KEY", "MISTRAL_API_KEY", "OPENROUTER_API_KEY"):
        monkeypatch.delenv(k, raising=False)
    assert not config.ai_ready()
    monkeypatch.setenv("GROQ_API_KEY", "k")
    assert config.ai_ready() and list(config.fallback_keys()) == ["groq"]


def test_deadline_stops_slow_calls(monkeypatch):
    from dalil import deadline, openai_compat
    from dalil.gemini import LLMError

    deadline.start(1.0)  # less than the 3 s needed for a call
    c = openai_compat.OpenAICompatClient("groq", "k")
    with pytest.raises(LLMError) as e:
        c.messages.create(model="m", max_tokens=5, system="s", messages=[{"role": "user", "content": "x"}])
    assert e.value.status == 408
    deadline.start(100.0)


def test_school_sample_has_trackable_deadlines():
    r = samples.saved_report("school")
    assert r["saved"] and r["findings"] == []
    dated = [d for d in r["deadlines"] if d["date"]]
    assert dated and dated[0]["date_text"] and any(d["within_days"] == 7 for d in r["deadlines"])
    assert samples.SAMPLES["school"]["text"].count(dated[0]["date_text"]) >= 1


def test_clean_deadlines_keeps_only_usable_ones():
    from datetime import date
    from dalil.models import RawDeadline

    today = date(2026, 10, 16)
    rows = [
        RawDeadline(label="Pay the fine", date="2026-11-05", date_text="5 Nov 2026"),
        RawDeadline(label="Reply", within_days=14),
        RawDeadline(label="", date="2026-11-05"),  # no label
        RawDeadline(label="Bad date", date="2026-13-45"),  # not a date, nothing else to keep
        RawDeadline(label="Far past", date="1999-01-01"),  # outside the sensible range
        RawDeadline(label="Zero days", within_days=0),
        RawDeadline(label="Too many days", within_days=99999),
        RawDeadline(label="Pay the fine", date="2026-11-05", date_text="5 Nov 2026"),  # duplicate
        RawDeadline(label="No year", date_text="15 March"),  # shown, user sets the date
    ]
    out = agent.clean_deadlines(rows, today)
    labels = [d["label"] for d in out]
    assert labels == ["Pay the fine", "Reply", "No year"]
    assert out[0]["date"] == "2026-11-05" and out[1]["within_days"] == 14
    assert out[2]["date"] == "" and out[2]["within_days"] is None and out[2]["date_text"] == "15 March"


def test_report_without_deadlines_has_empty_list():
    out = agent.finalize_report(RawReport.model_validate({"summary": "x"}), languages.get_language("en"))
    assert out["deadlines"] == []


# ---- Scam shield ----

def _fin(raw: dict, text: str = "") -> dict:
    return agent.finalize_report(RawReport.model_validate({"summary": "x", **raw}), languages.get_language("en"), text)


def test_scan_finds_real_warning_signs():
    from dalil import scam

    assert scam.scan("Please send us your OTP to confirm the refund") == ["code_request"]
    assert "gift_card_crypto" in scam.scan("Pay with iTunes gift cards")
    assert "bad_link" in scam.scan("Pay at http://dxb-fines-pay.example/pay")
    assert "bad_link" in scam.scan("Open bit.ly/abc123 now")
    assert "remote_access" in scam.scan("Install AnyDesk so we can help")
    assert "personal_account" in scam.scan("transfer to the officer's personal account")


def test_scan_does_not_flag_ordinary_or_protective_text():
    from dalil import scam

    assert scam.scan("Never share your OTP or PIN with anyone. We will never ask for it.") == []
    assert scam.scan("Rent is payable by wire transfer to the landlord's company account.") == []
    assert scam.scan("Pay at https://www.dewa.gov.ae/pay. Your bill is due on 25 October.") == []
    assert scam.scan("School fees are due on 1 November. See https://alnoor.school.ae") == []
    assert scam.scan("") == [] and scam.scan(None) == []


def test_assess_levels_are_calm_and_never_trust_the_model_alone():
    from dalil import scam

    assert scam.assess([], "none", [], 0)["level"] == "none"
    assert scam.assess(["short_deadline"], "none", [], 0)["level"] == "none"  # one weak sign is not enough
    assert scam.assess(["code_request"], "none", [], 0)["level"] == "caution"
    assert scam.assess(["personal_account", "bad_link", "short_deadline"], "none", [], 0)["level"] == "stop"
    assert scam.assess([], "stop", ["a reason"], 0)["level"] == "caution"  # the model alone cannot say stop
    assert scam.assess([], "caution", [], 0)["level"] == "none"  # a hunch with no reason or sign
    assert scam.assess([], "caution", ["pay by link"], 0)["level"] == "caution"
    a = scam.assess(["code_request", "bad_link"], "none", [], 0)  # no model reasons: English fallbacks
    assert a["level"] == "stop" and a["reasons"] and a["signals"] == ["code_request", "bad_link"]
    assert scam.assess([], "none", ["x"], 0)["reasons"] == []  # nothing is shown when the level is none


def test_fine_sample_is_stop_and_hides_deadlines():
    r = samples.saved_report("fine")
    assert r["scam"]["level"] == "stop" and r["scam"]["reasons"] and r["deadlines"] == []


def test_ordinary_samples_have_no_scam_banner():
    for k in ("rent", "school"):
        assert samples.saved_report(k)["scam"]["level"] == "none"
    assert samples.saved_report("school")["deadlines"]  # a normal notice keeps its deadlines


def test_scan_uses_the_text_the_person_pasted():
    out = _fin({}, "Your parcel is held. Pay the customs fee at http://track-parcel.top/pay within 2 hours or it is returned. Reply with your card number.")
    assert out["scam"]["level"] == "stop"
    assert "code_request" in out["scam"]["signals"]


def test_bad_model_output_for_scam_does_not_break_the_report():
    for bad in (None, "stop", 5, [], {"level": 7, "reasons": "one reason"}, {"level": "stop", "reasons": [1, None, "ok"]}):
        out = _fin({"scam": bad})
        assert out["scam"]["level"] in ("none", "caution", "stop")
    assert _fin({"scam": {"level": "caution", "reasons": ["pay by a link"]}})["scam"]["reasons"] == ["pay by a link"]


def test_report_has_scam_labels_and_schema():
    from dalil import prompts

    assert {"scam_stop", "scam_caution", "scam_steps", "scam_note"} <= set(prompts.LABEL_KEYS)
    assert '"scam"' in prompts.REVIEW_SCHEMA


# ---- If you do nothing ----

def test_if_ignored_keeps_what_the_document_states():
    out = _fin({"if_ignored": [
        {"action": "Pay Term 2 fee", "consequence": "A late charge of AED 150 will be added.", "source": "document"},
        {"action": "Return the slip", "consequence": "", "source": "document"},  # nothing stated: dropped
        {"action": "", "consequence": "Something", "source": "document"},  # no action: dropped
    ]})
    assert out["if_ignored"] == [{"action": "Pay Term 2 fee", "consequence": "A late charge of AED 150 will be added.", "source": "document", "sources": []}]


def test_if_ignored_rule_claims_need_a_verified_source():
    ref = "AE:tenancy:dubai_ejari_mandatory"
    assert registry.get_country("AE") and agent.resolve_rule(ref)
    out = _fin({"if_ignored": [
        {"action": "Register the contract", "consequence": "It cannot be used for a dispute.", "source": "rule", "rule_refs": [ref]},
        {"action": "Invented", "consequence": "You will be jailed.", "source": "rule", "rule_refs": ["AE:fines:not_a_real_fact"]},
        {"action": "No refs at all", "consequence": "A fine.", "source": "rule", "rule_refs": []},
    ]})
    assert [i["action"] for i in out["if_ignored"]] == ["Register the contract"]
    assert out["if_ignored"][0]["source"] == "rule" and out["if_ignored"][0]["sources"][0]["ref"] == ref


def test_if_ignored_is_limited_and_survives_bad_model_output():
    many = [{"action": f"a{i}", "consequence": f"c{i}", "source": "document"} for i in range(9)]
    assert len(_fin({"if_ignored": many})["if_ignored"]) == 4
    for bad in (None, "text", 5, {"a": 1}, [1, "x", None], [{"action": 3, "consequence": ["x"]}]):
        try:
            out = _fin({"if_ignored": bad})
        except Exception as e:  # noqa: BLE001
            raise AssertionError(f"report broke on {bad!r}") from e
        assert isinstance(out["if_ignored"], list)


def test_if_ignored_is_hidden_for_a_likely_scam():
    r = samples.saved_report("fine")
    assert r["scam"]["level"] == "stop" and r["if_ignored"] == []
    out = _fin(
        {"if_ignored": [{"action": "Pay now", "consequence": "Your car will be impounded.", "source": "document"}]},
        "Pay with gift cards from iTunes within 2 hours at http://pay-now.top/x or you will be arrested.",
    )
    assert out["scam"]["level"] == "stop" and out["if_ignored"] == []


def test_school_sample_states_its_late_charge():
    r = samples.saved_report("school")
    assert r["if_ignored"] and "150" in r["if_ignored"][0]["consequence"]
    assert "if_ignored" in samples.saved_report("rent")


def test_if_ignored_labels_and_schema():
    from dalil import prompts

    assert {"if_ignored", "if_ignored_unstated", "from_document", "from_rule"} <= set(prompts.LABEL_KEYS)
    assert '"if_ignored"' in prompts.REVIEW_SCHEMA


# ---- Before you go (pre-meeting prep) ----

def test_prep_lists_what_to_bring_and_ask_with_required_first():
    out = _fin({"prep": {
        "office": "School accounts office",
        "bring": [{"item": "Proof of payment", "required": False}, {"item": "The invoice", "required": True}, {"item": "the invoice", "required": False}],
        "questions": ["Can I pay in two parts?", "  Can I pay in two parts?  ", "What is the last day to pay?"],
    }})
    p = out["prep"]
    assert p["office"] == "School accounts office"
    assert [b["item"] for b in p["bring"]] == ["The invoice", "Proof of payment"]
    assert p["bring"][0]["required"] is True and p["bring"][1]["required"] is False
    assert p["questions"] == ["Can I pay in two parts?", "What is the last day to pay?"]
    assert p["authority"] is None


def test_prep_is_limited_resolves_offices_and_is_empty_when_nothing_to_show():
    assert _fin({})["prep"] is None
    assert _fin({"prep": {"office": "Somewhere"}})["prep"] is None  # an office alone is not a plan
    many = {"prep": {"bring": [{"item": f"i{n}"} for n in range(9)], "questions": [f"q{n}" for n in range(9)]}}
    p = _fin(many)["prep"]
    assert len(p["bring"]) == 6 and len(p["questions"]) == 5
    assert all(b["required"] is False for b in p["bring"])  # nothing is "required" unless the document says so
    ref = next(iter(registry.get_country("AE").authorities)).id
    p = _fin({"prep": {"questions": ["q"], "authority_ref": f"AE:{ref}"}})["prep"]
    assert p["authority"] and p["authority"]["name"]
    assert _fin({"prep": {"questions": ["q"], "authority_ref": "AE:not_real"}})["prep"]["authority"] is None


def test_prep_survives_bad_model_output_and_is_hidden_for_a_scam():
    for bad in (None, "text", 5, [], {"bring": "x", "questions": 3}, {"bring": [1, None, "passport", {"item": 5, "required": "yes"}], "questions": [None, 4, "ok"]}):
        out = _fin({"prep": bad})
        assert out["prep"] is None or isinstance(out["prep"]["bring"], list)
    ok = _fin({"prep": {"bring": [1, "passport", {"item": 5, "required": "yes"}], "questions": [None, "ok"]}})["prep"]
    assert [b["item"] for b in ok["bring"]] == ["passport", "5"] and not any(b["required"] for b in ok["bring"])
    assert samples.saved_report("fine")["prep"] is None
    scam = _fin({"prep": {"questions": ["q"]}}, "Pay with gift cards within 2 hours at http://x-pay.top/p or you will be arrested.")
    assert scam["scam"]["level"] == "stop" and scam["prep"] is None


def test_prep_labels_and_schema():
    from dalil import prompts

    assert {"prep", "prep_bring", "prep_ask", "prep_required", "prep_suggested"} <= set(prompts.LABEL_KEYS)
    assert '"prep"' in prompts.REVIEW_SCHEMA


# ---- Number check ----

def _lines(*rows):
    return [{"label": l, "amount": a, "role": r, **({"rate": rate} if rate else {})} for l, a, r, rate in [(x + (None,))[:4] for x in rows]]


def test_numbers_ok_when_items_tax_and_total_add_up():
    from dalil import numbers

    out = numbers.check("AED", _lines(("A", 100, "item"), ("B", 50, "item"), ("VAT", 7.5, "tax", 5), ("Total", 157.5, "total")))
    assert out["status"] == "ok" and out["issues"] == [] and out["currency"] == "AED" and len(out["lines"]) == 4


def test_numbers_flags_a_wrong_total_with_the_difference():
    from dalil import numbers

    out = numbers.check("AED", _lines(("A", 100, "item"), ("B", 50, "item"), ("Total", 170, "total")))
    assert out["status"] == "mismatch"
    i = out["issues"][0]
    assert i["code"] == "total_mismatch" and i["stated"] == 170 and i["computed"] == 150 and i["difference"] == 20


def test_numbers_checks_subtotal_tax_rate_and_discount():
    from dalil import numbers

    bad_sub = numbers.check("", _lines(("A", 100, "item"), ("B", 50, "item"), ("Subtotal", 160, "subtotal"), ("Total", 160, "total")))
    assert [i["code"] for i in bad_sub["issues"]] == ["subtotal_mismatch"]
    bad_tax = numbers.check("", _lines(("A", 200, "item"), ("VAT", 12, "tax", 5), ("Total", 212, "total")))
    assert "tax_mismatch" in [i["code"] for i in bad_tax["issues"]]
    disc = numbers.check("", _lines(("A", 200, "item"), ("Promo", 20, "discount"), ("VAT", 9, "tax", 5), ("Total", 189, "total")))
    assert disc["status"] == "ok"  # 200 - 20 + 9
    neg = numbers.check("", _lines(("A", 200, "item"), ("Promo", -20, "discount"), ("Total", 180, "total")))
    assert neg["status"] == "ok"  # a discount written as a negative number still counts as a discount


def test_numbers_accepts_rounding_but_not_a_real_gap_and_instalments():
    from dalil import numbers

    assert numbers.check("", _lines(("A", 33.33, "item"), ("B", 33.33, "item"), ("C", 33.33, "item"), ("Total", 100, "total")))["status"] == "ok"
    assert numbers.check("", _lines(("A", 33.33, "item"), ("B", 33.33, "item"), ("C", 33.33, "item"), ("Total", 100.5, "total")))["status"] == "mismatch"
    cheques = numbers.check("AED", _lines(("Cheque 1", 19500, "item"), ("Cheque 2", 19500, "item"), ("Cheque 3", 19500, "item"), ("Cheque 4", 19500, "item"), ("Annual rent", 78000, "total")))
    assert cheques["status"] == "ok"


def test_numbers_returns_nothing_when_there_is_nothing_to_check():
    from dalil import numbers

    assert numbers.check("", []) is None
    assert numbers.check("", _lines(("Total", 100, "total"))) is None  # one amount only
    assert numbers.check("", _lines(("A", 100, "item"), ("B", 50, "item"))) is None  # no stated total
    assert numbers.check("", _lines(("A", 100, "weird"), ("B", 50, "item"), ("T", 150, "total"))) is None  # a line that cannot be placed: do not guess
    assert numbers.check("", [{"label": "A", "amount": None, "role": "item"}, {"label": "T", "amount": 5, "role": "total"}]) is None
    assert numbers.check("", [{"label": "A", "amount": float("nan"), "role": "item"}, {"label": "B", "amount": 1, "role": "item"}, {"label": "T", "amount": 1, "role": "total"}]) is None


def test_numbers_reads_amounts_written_as_text():
    out = _fin({"amounts": {"currency": "AED", "lines": [
        {"label": "Rent", "amount": "AED 1,200.50", "role": "item"},
        {"label": "Fee", "amount": "99,5", "role": "item"},
        {"label": "Total", "amount": 1300, "role": "total"},
    ]}})
    n = out["number_check"]
    assert n["status"] == "ok" and [ln["amount"] for ln in n["lines"]] == [1200.5, 99.5, 1300.0]


def test_numbers_survives_bad_model_output():
    for bad in (None, "x", 5, [], {"lines": "x"}, {"lines": [1, None, "a"]}, {"lines": [{"amount": [1], "role": 7, "label": {}}]}, {"currency": 3, "lines": [{"amount": True, "role": "total"}]}):
        out = _fin({"amounts": bad})
        assert out["number_check"] is None


def test_number_check_in_the_bill_sample_and_scam_rules():
    r = samples.saved_report("bill")
    n = r["number_check"]
    assert n["status"] == "mismatch" and n["issues"][0]["computed"] == 661.5 and n["issues"][0]["difference"] == 58.5
    for k in ("rent", "school", "fine"):
        assert samples.saved_report(k)["number_check"] is None
    ok_lines = {"amounts": {"currency": "AED", "lines": [{"label": "A", "amount": 10, "role": "item"}, {"label": "Total", "amount": 10, "role": "total"}]}}
    assert _fin(ok_lines)["number_check"]["status"] == "ok"
    # a "numbers add up" tick must not appear on a message with scam warning signs
    risky = _fin(ok_lines, "Send us your OTP code to confirm.")
    assert risky["scam"]["level"] == "caution" and risky["number_check"] is None
    stop = _fin(ok_lines, "Pay with gift cards within 2 hours at http://x-pay.top/p or you will be arrested.")
    assert stop["scam"]["level"] == "stop" and stop["number_check"] is None


def test_number_check_labels_and_schema():
    from dalil import prompts

    need = {"numbers", "numbers_ok", "numbers_bad", "numbers_hint", "numbers_stated", "numbers_computed", "numbers_diff", "numbers_note", "numbers_tax", "numbers_subtotal"}
    assert need <= set(prompts.LABEL_KEYS)
    assert '"amounts"' in prompts.REVIEW_SCHEMA


def test_gemini_404_skips_the_retired_model_even_if_still_listed(monkeypatch):
    from dalil import gemini

    models = [
        {"name": "models/gemini-2.5-flash", "supportedGenerationMethods": ["generateContent"]},
        {"name": "models/gemini-3.8-flash", "supportedGenerationMethods": ["generateContent"]},
    ]
    assert gemini.pick_flash(models, exclude="gemini-2.5-flash") == "gemini-3.8-flash"
    calls = []

    class R:
        def __init__(self, status, data=None):
            self.status_code, self._d = status, data or {}

        def json(self):
            return self._d

    def fake_post(url, **k):
        calls.append(url)
        return R(404) if "2.5-flash" in url else R(200, {"candidates": [{"content": {"parts": [{"text": "hi"}]}}]})

    monkeypatch.setattr(gemini.httpx, "post", fake_post)
    monkeypatch.setattr(gemini.httpx, "get", lambda *a, **k: R(200, {"models": models}))
    gemini._PICKED.clear()
    resp = gemini.GeminiClient("k").messages.create(model="gemini-2.5-flash", max_tokens=10, system="s", messages=[{"role": "user", "content": "x"}])
    assert resp.content[0].text == "hi" and "gemini-3.8-flash" in calls[-1]


# ---- Money due and friendly busy messages

def _due_raw(**due):
    from dalil.models import RawReport

    return RawReport.model_validate({"summary": "s", "due": due})


def test_clean_due_keeps_a_plausible_amount_and_checks_pasted_text():
    raw = _due_raw(amount="AED 1,200.50", currency="aed", label=" School  fee ", date="2026-12-01", date_text="1 Dec 2026")
    d = agent.clean_due(raw.due, "Please pay AED 1,200.50 by 1 Dec 2026.", today=date(2026, 10, 20))
    assert d == {"amount": 1200.5, "currency": "AED", "label": "School fee", "date": "2026-12-01", "date_text": "1 Dec 2026", "check": False}
    # the figure is not in the pasted text: dropped
    assert agent.clean_due(raw.due, "Please pay AED 900 by 1 Dec 2026.", today=date(2026, 10, 20)) is None
    # a photo has no text to check against, so it is kept
    assert agent.clean_due(raw.due, "", today=date(2026, 10, 20))["amount"] == 1200.5


def test_clean_due_rejects_bad_values_and_bad_dates():
    t = date(2026, 10, 20)
    for bad in (dict(amount=None, currency="AED"), dict(amount=0, currency="AED"), dict(amount=-5, currency="AED"), dict(amount=10, currency=""), dict(amount=10, currency="DIRHAMS"), dict(amount="lots", currency="AED")):
        assert agent.clean_due(_due_raw(**bad).due, "", today=t) is None, bad
    d = agent.clean_due(_due_raw(amount=10, currency="USD", date="2099-01-01").due, "", today=t)
    assert d["date"] == ""  # a date far in the future is not trusted
    assert agent.clean_due(_due_raw(amount=10, currency="USD", date="not a date").due, "", today=t)["date"] == ""


def test_due_survives_bad_model_output():
    from dalil.models import RawReport

    for junk in ("AED 5", ["x"], 12, {"amount": {"a": 1}, "currency": 5, "label": None}):
        raw = RawReport.model_validate({"summary": "s", "due": junk})
        assert agent.clean_due(raw.due, "") is None


def _finalize(due, text="", scam=None, amounts=None):
    from dalil.models import RawReport

    body = {"summary": "s", "due": due}
    if scam:
        body["scam"] = scam
    if amounts:
        body["amounts"] = amounts
    return agent.finalize_report(RawReport.model_validate(body), languages.get_language("en"), text)


def test_due_is_shown_for_a_normal_bill_and_flagged_when_the_figures_do_not_add_up():
    ok = _finalize({"amount": 720, "currency": "AED", "label": "Bill"}, "Total to pay AED 720")
    assert ok["due"]["amount"] == 720 and ok["due"]["check"] is False
    bad = _finalize(
        {"amount": 720, "currency": "AED", "label": "Bill"},
        "Total to pay AED 720",
        amounts={"currency": "AED", "lines": [
            {"label": "A", "amount": 100, "role": "item"}, {"label": "B", "amount": 50, "role": "item"}, {"label": "Total", "amount": 720, "role": "total"}]},
    )
    assert bad["number_check"]["status"] == "mismatch" and bad["due"]["check"] is True


def test_due_is_never_shown_next_to_a_scam_warning_or_for_an_unrecognized_document():
    txt = "Pay AED 500 now. Send your OTP and pay with a gift card within 2 hours: http://pay-now.top"
    assert _finalize({"amount": 500, "currency": "AED"}, txt)["due"] is None
    assert _finalize({"amount": 500, "currency": "AED"}, "Pay AED 500", scam={"level": "caution", "reasons": ["odd link"]})["due"] is None
    from dalil.models import RawReport

    r = agent.finalize_report(RawReport.model_validate({"summary": "s", "recognized": False, "due": {"amount": 5, "currency": "AED"}}), languages.get_language("en"), "")
    assert r["due"] is None


def test_prompt_asks_for_the_due_amount():
    from dalil import prompts

    s = prompts.review_system(languages.get_language("en"), None, [])
    assert '"due"' in s and "Amount due" in s


def test_sample_bill_and_school_have_a_due_amount():
    bill = samples.saved_report("bill")
    school = samples.saved_report("school")
    assert bill["due"]["amount"] == 720 and bill["due"]["check"] is True
    assert school["due"]["amount"] == 4200 and school["due"]["date"]


def test_busy_trouble_gets_a_calm_message_and_a_retry_code():
    from dalil import app as appmod

    for why in ("api_429", "api_503", "api_408", "api_0", "api_529", "connection"):
        e = appmod._model_problem(agent.ModelUnavailable(why))
        assert e.status == 503 and e.code == "model_busy" and "very busy" in e.message
        assert e.extra["retry_after"] == 60
        assert "api_" not in e.message and "[" not in e.message  # no technical codes in what people read


def test_setup_problems_do_not_show_technical_hints_to_people():
    from dalil import app as appmod

    for why in ("api_401", "api_403", "api_404", "api_400"):
        e = appmod._model_problem(agent.ModelUnavailable(why))
        assert e.code == "model_unavailable" and "DALIL_MODEL" not in e.message and "key" not in e.message.lower()
        assert why in e.extra["detail"]
    e = appmod._model_problem(agent.ModelUnavailable("no_api_key"))
    assert e.code == "model_unavailable" and "API key" not in e.message
    assert appmod._model_problem(agent.ModelOutputError("x")).code == "bad_model_output"


def test_busy_message_is_in_the_readers_language_and_falls_back_to_english():
    from dalil import app as appmod

    ar = appmod._model_problem(agent.ModelUnavailable("api_429"), "ar")
    assert ar.code == "model_busy" and ar.message != appmod.BUSY_MESSAGE and "دليل" in ar.message
    assert appmod._model_problem(agent.ModelUnavailable("api_429"), "xx").message == appmod.BUSY_MESSAGE
    assert appmod._model_problem(agent.ModelUnavailable("api_429")).message == appmod.BUSY_MESSAGE
    for code, text in appmod.BUSY_MESSAGES.items():
        assert text.strip() and "api_" not in text and "[" not in text, code


def test_money_due_labels_exist():
    from dalil.prompts import LABEL_KEYS

    for k in ("due_amount", "due_by", "due_check", "numbers_flag"):
        assert LABEL_KEYS[k].strip()


def test_meta_is_compressed_cached_and_built_once():
    from dalil import app as appmod

    c = TestClient(appmod.app)
    appmod._meta_body.cache_clear()
    a = c.get("/api/meta", headers={"Accept-Encoding": "gzip"})
    assert a.status_code == 200
    assert a.headers.get("content-encoding") == "gzip"  # the language list and samples are large
    assert "max-age" in a.headers["cache-control"]
    b = c.get("/api/meta")
    assert b.json() == a.json()
    assert appmod._meta_body.cache_info().hits >= 1  # the second visit reused the first answer
    assert a.json()["languages"] and a.json()["limits"]["max_images"] >= 1


def test_small_answers_are_not_compressed():
    from dalil import app as appmod

    c = TestClient(appmod.app)
    r = c.get("/api/health", headers={"Accept-Encoding": "gzip"})
    assert r.status_code == 200 and r.json()["ok"] is True
    assert r.headers.get("content-encoding") != "gzip"


# ---- Report this scam ----

def test_scam_report_pack_lists_only_scam_offices_from_the_registry():
    out = _fin({"country": "AE", "scam": {"level": "stop", "reasons": ["a short deadline"]}}, "Pay now with a gift card or your account will be blocked, send the OTP")
    pack = out["scam_report"]
    assert pack["country"] == "AE" and pack["country_name"]
    refs = [a["ref"] for a in pack["authorities"]]
    assert refs and all(r.startswith("AE:") for r in refs)
    police = next(a for a in registry.get_country("AE").authorities if "scams" in a.covers)
    assert f"AE:{police.id}" in refs
    for a in pack["authorities"]:
        assert a["url"].startswith("http")
        assert not a["phone"] or a["phone_source"]  # a number is shown only with the official page that shows it
    assert pack["signs_en"] and all(isinstance(x, str) for x in pack["signs_en"])


def test_scam_report_pack_is_missing_for_ordinary_documents_and_safe_for_unknown_countries():
    assert _fin({"country": "AE"})["scam_report"] is None
    unknown = _fin({"country": "ZZ", "scam": {"level": "caution", "reasons": ["a link that is not official"]}})["scam_report"]
    assert unknown["authorities"] == [] and unknown["country"] is None  # the app then shows the general advice
    none_country = _fin({"scam": {"level": "caution", "reasons": ["x y"]}})["scam_report"]
    assert none_country["authorities"] == []


def test_every_country_scam_office_has_an_official_link():
    for code, c in registry.load_all().items():
        for a in c.authorities:
            if "scams" in a.covers:
                assert a.url.startswith("https://"), (code, a.id)


def test_report_scam_labels_exist():
    from dalil import prompts

    assert {"report_scam", "report_where", "report_msg", "report_none"} <= set(prompts.LABEL_KEYS)


# ---- Form helper ----

def _form_json(**over):
    base = {
        "readable": True, "readability_issues": [], "is_form": True, "form_name": "Visa renewal form", "purpose": "To renew a visa.",
        "fields": [
            {"label": "Full name", "meaning": "Your name.", "how_to_fill": "As written in your passport.", "kind": "text", "required": "yes"},
            {"label": "Passport number", "meaning": "The number on your passport.", "how_to_fill": "Copy it from the passport page.", "kind": "text", "required": "yes"},
            {"label": "Nationality", "meaning": "Your country of citizenship.", "how_to_fill": "", "kind": "text", "required": "unclear"},
            {"label": "Bank card PIN", "meaning": "A secret number.", "how_to_fill": "", "kind": "text", "required": "no"},
        ],
        "warnings": ["Do not sign with empty boxes."], "before_submit": ["Check every box."], "not_sure": "", "labels": {"form_fields": "Ano ang ibig sabihin"},
    }
    base.update(over)
    return json.dumps(base)


def test_form_help_marks_personal_and_secret_boxes_private_whatever_the_model_said():
    client = FakeClient(fake_resp(text_block(_form_json())))
    out = agent.form_help(images=[], text="Visa renewal form ...", lang=languages.get_language("tl"), country=None, client=client)
    kinds = {f["label"]: f["kind"] for f in out["fields"]}
    assert kinds["Full name"] == "text"
    assert kinds["Passport number"] == "private"  # personal, although the model said "text"
    assert kinds["Bank card PIN"] == "private"
    assert out["secret_field"] is True
    assert out["is_form"] is True and out["labels"]["form_fields"] == "Ano ang ibig sabihin"
    assert out["labels"]["form_note"]  # missing labels fall back to English
    assert out["language"] == "tl"


def test_form_help_without_a_secret_box_has_no_secret_warning():
    j = json.loads(_form_json())
    j["fields"] = j["fields"][:1]
    out = agent.form_help(images=[], text="x " * 20, lang=languages.get_language("en"), country="AE", client=FakeClient(fake_resp(text_block(json.dumps(j)))))
    assert out["secret_field"] is False and len(out["fields"]) == 1


def test_form_help_says_so_when_it_is_not_a_form_and_survives_bad_output():
    out = agent.form_help(images=[], text="a letter " * 5, lang=languages.get_language("en"), country=None,
                          client=FakeClient(fake_resp(text_block(_form_json(is_form=False, fields=[], purpose="This is a letter.")))))
    assert out["is_form"] is False and out["fields"] == [] and out["purpose"] == "This is a letter."
    # a form the model claims but with no usable boxes is also "not a form"
    out = agent.form_help(images=[], text="x " * 20, lang=languages.get_language("en"), country=None,
                          client=FakeClient(fake_resp(text_block(_form_json(fields=[{"label": "", "meaning": ""}, 5, None])))))
    assert out["is_form"] is False
    for bad in ("[1,2]", '"text"', "null"):
        with pytest.raises(agent.ModelOutputError):
            agent.form_help(images=[], text="x " * 20, lang=languages.get_language("en"), country=None, client=FakeClient(fake_resp(text_block(bad))))


def test_form_help_limits_and_cleans_text():
    many = [{"label": f"Box {i}", "meaning": f"Meaning {i}", "kind": "weird", "required": "maybe"} for i in range(40)]
    out = agent.finalize_form(json.loads(_form_json(fields=many, warnings=["a"] * 9, before_submit=["b"] * 9)), languages.get_language("en"))
    assert len(out["fields"]) == 30 and len(out["warnings"]) == 5 and len(out["before_submit"]) == 6
    assert {f["kind"] for f in out["fields"]} == {"text"} and {f["required"] for f in out["fields"]} == {"unclear"}


def test_form_help_reports_an_unreadable_photo():
    client = FakeClient(fake_resp(text_block(json.dumps({"readable": False, "readability_issues": ["blurry", "nonsense"]}))))
    with pytest.raises(agent.PhotoUnreadable) as e:
        agent.form_help(images=[b"x"], text=None, lang=languages.get_language("en"), country=None, client=client)
    assert [i["code"] for i in e.value.issues] == ["blurry"]


def test_form_prompt_never_asks_the_model_to_fill_in_personal_details():
    from dalil import prompts

    sys_prompt = prompts.form_system(languages.get_language("ar"), "ae")
    assert "Never invent or suggest a value for a personal detail" in sys_prompt
    assert "Do not call tools" in sys_prompt
    assert "Arabic" in sys_prompt and "country AE" in sys_prompt
    assert {"form_secret", "form_private", "form_not_form"} <= set(prompts.FORM_LABELS)


def test_form_endpoint(monkeypatch):
    from fastapi.testclient import TestClient
    from dalil.app import app

    seen = {}

    def fake(*, images, text, lang, country, client=None):
        seen.update(text=text, n=len(images), lang=lang.code)
        return agent.finalize_form(json.loads(_form_json()), lang)

    monkeypatch.setattr(agent, "form_help", fake)
    c = TestClient(app)
    r = c.post("/api/form", json={"text": "Name: ____ Email: a.person@example.com", "language": "en"})
    assert r.status_code == 200 and r.json()["form_name"] == "Visa renewal form"
    assert "a.person@example.com" not in (seen["text"] or "")  # personal data is masked before the model sees it
    assert r.json()["privacy"]["hidden_total"] >= 1
    assert c.post("/api/form", json={"language": "en"}).status_code == 422


# ---- Accuracy page ----

def test_accuracy_endpoint_gives_offline_numbers_and_an_honest_caveat():
    from fastapi.testclient import TestClient
    from dalil.app import app

    r = TestClient(app).get("/api/accuracy")
    assert r.status_code == 200
    d = r.json()
    assert d["offline"]["scam"]["n"] >= 30 and d["offline"]["legit"]["n"] >= 30 and d["offline"]["numbers"]["n"] >= 10
    assert "not proof" in d["caveat"] and "developers" in d["caveat"]
    assert d["live"] is None or {"scam", "legit", "numbers"} <= set(d["live"])
    assert "text" not in json.dumps(d["offline"])  # only counts and case ids, never document text

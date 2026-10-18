"""The review agent: reads a document, checks it against the registry with tools, returns a report."""
from __future__ import annotations

import base64
import json
import re
from datetime import date
from typing import Any

import anthropic

from . import config, deadline, registry
from . import scam as scam_mod
from .failover import FailoverClient
from .gemini import GeminiClient, LLMError
from .openai_compat import OpenAICompatClient
from .languages import Language
from .models import READABILITY_CODES, READABILITY_MESSAGES, RawReport
from .prompts import LABEL_KEYS, ask_system, letter_system, review_system
from .tools import TOOL_DEFS, run_tool


class ModelUnavailable(Exception):
    pass


class ModelOutputError(Exception):
    pass


class PhotoUnreadable(Exception):
    def __init__(self, issues: list[dict]):
        super().__init__("photo unreadable")
        self.issues = issues


def get_client():
    chain: list[tuple[str, Any]] = []
    key = config.api_key()
    if key:
        if config.provider() == "gemini":
            chain.append(("gemini", GeminiClient(key)))
        else:
            chain.append(("anthropic", anthropic.Anthropic(api_key=key, timeout=50.0, max_retries=1)))
    for name, k in config.fallback_keys().items():
        chain.append((name, OpenAICompatClient(name, k)))
    if not chain:
        raise ModelUnavailable("no_api_key")
    return chain[0][1] if len(chain) == 1 else FailoverClient(chain)


def parse_json(text: str) -> Any:
    t = text.strip()
    if t.startswith("```"):
        t = re.sub(r"^```[a-zA-Z]*\s*", "", t)
        t = re.sub(r"\s*```$", "", t)
    try:
        return json.loads(t)
    except json.JSONDecodeError:
        i, j = t.find("{"), t.rfind("}")
        if i >= 0 and j > i:
            try:
                return json.loads(t[i : j + 1])
            except json.JSONDecodeError as e:
                raise ModelOutputError("invalid_json") from e
        raise ModelOutputError("invalid_json")


def _text_of(resp) -> str:
    return "".join(getattr(b, "text", "") for b in resp.content if getattr(b, "type", "") == "text")


def run_loop(client, *, model: str, system: str, messages: list[dict], max_rounds: int | None = None) -> str:
    rounds = max_rounds or config.MAX_AGENT_ROUNDS
    deadline.start(config.TOTAL_BUDGET_S)
    for i in range(rounds):
        kwargs: dict[str, Any] = dict(
            model=model,
            max_tokens=max(config.MAX_OUTPUT_TOKENS, 6000),
            system=system,
            tools=TOOL_DEFS,
            messages=messages,
        )
        if i == rounds - 1:
            kwargs["tool_choice"] = {"type": "none"}
        try:
            resp = client.messages.create(**kwargs)
        except anthropic.APIStatusError as e:
            raise ModelUnavailable(f"api_{e.status_code}") from e
        except anthropic.APIConnectionError as e:
            raise ModelUnavailable("connection") from e
        except LLMError as e:
            raise ModelUnavailable(f"api_{e.status}") from e
        if resp.stop_reason == "tool_use":
            messages.append({"role": "assistant", "content": resp.content})
            results = []
            for b in resp.content:
                if getattr(b, "type", "") == "tool_use":
                    results.append({"type": "tool_result", "tool_use_id": b.id, "content": run_tool(b.name, dict(b.input or {}))})
            messages.append({"role": "user", "content": results})
            continue
        if resp.stop_reason == "max_tokens":
            raise ModelOutputError("too_long")
        text = _text_of(resp)
        if not text.strip():
            raise ModelOutputError("empty")
        return text
    raise ModelOutputError("no_answer")


def resolve_rule(ref: str) -> dict | None:
    parts = (ref or "").split(":")
    if len(parts) != 3:
        return None
    code, topic, fid = parts[0].upper(), parts[1], parts[2]
    c = registry.get_country(code)
    t = c.topics.get(topic) if c else None
    f = next((x for x in (t.facts if t else []) if x.id == fid), None)
    if not f:
        return None
    return {
        "ref": f"{code}:{topic}:{fid}",
        "country": code,
        "topic": topic,
        "statement": f.statement,
        "url": f.source_url,
        "quote": f.quote,
        "confidence": f.confidence,
        "verified_on": f.verified_on.isoformat(),
    }


def resolve_authority(ref: str | None) -> dict | None:
    parts = (ref or "").split(":")
    if len(parts) != 2:
        return None
    code, aid = parts[0].upper(), parts[1]
    c = registry.get_country(code)
    a = next((x for x in (c.authorities if c else []) if x.id == aid), None)
    if not a:
        return None
    return {"ref": f"{code}:{aid}", "name": a.name, "url": a.url, "phone": a.phone, "phone_source": a.phone_source}


def clean_deadlines(raw: list, today: date | None = None) -> list[dict]:
    """Keep only deadlines that are usable: a real calendar date, or a period in days."""
    today = today or date.today()
    out, seen = [], set()
    for d in raw[:12]:
        label = " ".join((d.label or "").split())[:140]
        if not label:
            continue
        iso = ""
        text = " ".join((d.date_text or "").split())[:80]
        if d.date:
            try:
                parsed = date.fromisoformat(d.date.strip())
            except ValueError:
                parsed = None
            if parsed and today.year - 2 <= parsed.year <= today.year + 10:
                iso = parsed.isoformat()
        days = d.within_days if isinstance(d.within_days, int) and not isinstance(d.within_days, bool) and 1 <= d.within_days <= 3650 else None
        if not iso and days is None and not text:
            continue  # nothing to track and nothing to show
        key = (label.lower(), iso, days)
        if key in seen:
            continue
        seen.add(key)
        out.append({"label": label, "date": iso, "date_text": text, "within_days": None if iso else days})
    out.sort(key=lambda x: (x["date"] == "", x["date"]))
    return out[:6]


def _dedupe(rows: list[dict], key: str) -> list[dict]:
    seen, out = set(), []
    for r in rows:
        if r[key] not in seen:
            seen.add(r[key])
            out.append(r)
    return out


def finalize_report(raw: RawReport, lang: Language, doc_text: str = "") -> dict:
    code = (raw.country or "").upper() or None
    country = registry.get_country(code) if code else None
    labels = {**LABEL_KEYS, **{k: v for k, v in raw.labels.items() if k in LABEL_KEYS and isinstance(v, str) and v.strip()}}

    findings = []
    for f in raw.findings[:6]:
        if not f.why.strip():
            continue
        sources = _dedupe([r for r in (resolve_rule(x) for x in f.rule_refs) if r], "ref")
        severity = f.severity if f.severity in ("high", "medium", "low") else "medium"
        if severity == "high" and not sources:
            severity = "medium"  # 'high' needs a verified source
        findings.append(
            {
                "severity": severity,
                "kind": f.kind if f.kind in ("clause", "scam_signal", "missing") else "clause",
                "quote": f.quote[:300],
                "why": f.why,
                "ask": f.ask,
                "verified": bool(sources),
                "sources": sources,
            }
        )
    order = {"high": 0, "medium": 1, "low": 2}
    findings.sort(key=lambda f: order[f["severity"]])

    steps = []
    for s in raw.next_steps[:4]:
        if s.action.strip():
            steps.append({"action": s.action, "deadline": s.deadline, "authority": resolve_authority(s.authority_ref)})

    # "If you do nothing": only consequences the document states, or an official fact that was really found.
    ignored = []
    for it in raw.if_ignored[:8]:
        action, cons = " ".join(it.action.split())[:160], " ".join(it.consequence.split())[:300]
        if not action or not cons:
            continue
        if it.source == "rule":
            srcs = _dedupe([r for r in (resolve_rule(x) for x in it.rule_refs) if r], "ref")
            if not srcs:
                continue  # a rule claim with no verified source is not shown
            ignored.append({"action": action, "consequence": cons, "source": "rule", "sources": srcs})
        else:
            ignored.append({"action": action, "consequence": cons, "source": "document", "sources": []})
    ignored = ignored[:4]

    # "Before you go": what to bring and what to ask. Items the document did not ask for are shown as suggestions only.
    prep_bring, seen_items = [], set()
    for b in raw.prep.bring:
        item = " ".join(b.item.split())[:140]
        if item and item.lower() not in seen_items:
            seen_items.add(item.lower())
            prep_bring.append({"item": item, "required": b.required})
    prep_bring.sort(key=lambda x: not x["required"])  # what the document asks for comes first
    prep_questions, seen_q = [], set()
    for q in raw.prep.questions:
        q = " ".join(q.split())[:220]
        if q and q.lower() not in seen_q:
            seen_q.add(q.lower())
            prep_questions.append(q)
    prep = None
    if prep_bring or prep_questions:
        prep = {
            "office": " ".join(raw.prep.office.split())[:160],
            "authority": resolve_authority(raw.prep.authority_ref),
            "bring": prep_bring[:6],
            "questions": prep_questions[:5],
        }

    # Scam shield: rule-based signs from the document text and the quoted parts, plus what the model saw.
    quoted = " ".join([doc_text] + [f.quote for f in raw.findings] + [p.original for p in raw.points] + [k.value for k in raw.key_facts])
    scam = scam_mod.assess(
        scam_mod.scan(quoted), raw.scam.level, raw.scam.reasons, sum(1 for f in findings if f["kind"] == "scam_signal")
    )
    deadlines = clean_deadlines(raw.deadlines)
    if scam["level"] == "stop":
        # For a likely scam, doing nothing is the safe choice: no deadlines to track, no consequences, no visit to prepare for.
        deadlines, ignored, prep = [], [], None

    return {
        "readable": True,
        "recognized": raw.recognized,
        "doc_type": raw.doc_type,
        "country": code,
        "country_name": country.name if country else None,
        "coverage": "verified" if country else "none",
        "registry_checked": country.last_verified.isoformat() if country else None,
        "language": lang.code,
        "rtl": lang.rtl,
        "summary": raw.summary,
        "points": [p.model_dump() for p in raw.points if p.plain.strip()][:8],
        "terms": [t.model_dump() for t in raw.terms if t.term.strip() and t.meaning.strip()][:6],
        "key_facts": [k.model_dump() for k in raw.key_facts if k.label and k.value][:6],
        "findings": findings,
        "next_steps": steps,
        "checklist": [c.model_dump() for c in raw.checklist if c.task.strip()][:6],
        "deadlines": deadlines,
        "scam": scam,
        "if_ignored": ignored,
        "prep": prep,
        "not_sure": raw.not_sure,
        "closing": raw.closing,
        "labels": labels,
        "saved": False,
    }


def _image_blocks(images: list[bytes]) -> list[dict]:
    return [
        {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": base64.b64encode(b).decode()}}
        for b in images
    ]


def review(*, images: list[bytes], text: str | None, lang: Language, country: str | None, client=None) -> dict:
    client = client or get_client()
    covered = None
    if country:
        covered = registry.get_country(country) is not None
    content: list[dict] = []
    if images:
        content += _image_blocks(images)
        content.append({"type": "text", "text": f"The document is in the attached photo(s), {len(images)} page(s) in order. Review it."})
    if text:
        content.append({"type": "text", "text": "The document text is between the markers.\n<<<DOCUMENT\n" + text + "\nDOCUMENT>>>\nReview it."})
    messages = [{"role": "user", "content": content}]
    final = run_loop(client, model=config.MODEL, system=review_system(lang, country, covered), messages=messages)
    try:
        raw = RawReport.model_validate(parse_json(final))
    except ModelOutputError:
        raise
    except Exception as e:  # noqa: BLE001
        raise ModelOutputError("invalid_shape") from e
    if not raw.readable:
        issues = [c for c in raw.readability_issues if c in READABILITY_CODES] or ["blurry"]
        raise PhotoUnreadable([{"code": c, "message": READABILITY_MESSAGES[c]} for c in issues])
    return finalize_report(raw, lang, text or "")


def _report_digest(report: dict) -> str:
    keep = {k: report.get(k) for k in ("doc_type", "country", "summary", "points", "terms", "key_facts", "not_sure")}
    keep["findings"] = [{k: f.get(k) for k in ("severity", "quote", "why", "ask")} for f in report.get("findings", [])][:8]
    return json.dumps(keep, ensure_ascii=False)[:8000]


def ask(*, question: str, report: dict, lang: Language, history: list[dict], client=None) -> dict:
    client = client or get_client()
    lines = []
    for h in history[-8:]:
        if "role" in h:  # the app sends {role, content}
            who = "Person" if h.get("role") == "user" else "Dalil"
            lines.append(f"{who}: {str(h.get('content', ''))[:600]}")
        else:  # older shape {q, a}
            lines.append(f"Person: {str(h.get('q', ''))[:400]}\nDalil: {str(h.get('a', ''))[:600]}")
    hist = "\n".join(lines)
    prompt = (
        "Earlier reading of the document (JSON, produced by you):\n" + _report_digest(report)
        + ("\n\nEarlier questions:\n" + hist if hist else "")
        + "\n\nNew question: " + question
    )
    final = run_loop(client, model=config.FAST_MODEL, system=ask_system(lang), messages=[{"role": "user", "content": prompt}], max_rounds=4)
    obj = parse_json(final)
    if not isinstance(obj, dict) or not str(obj.get("answer", "")).strip():
        raise ModelOutputError("invalid_shape")
    sources = _dedupe([r for r in (resolve_rule(x) for x in obj.get("rule_refs", []) if isinstance(x, str)) if r], "ref")
    offices = _dedupe([a for a in (resolve_authority(x) for x in obj.get("authority_refs", []) if isinstance(x, str)) if a], "ref")
    return {"answer": str(obj["answer"]), "sources": sources, "authorities": offices}


def draft_letter(*, report: dict, recipient: str, note: str, lang: Language, client=None) -> dict:
    client = client or get_client()
    prompt = (
        f"Recipient type: {recipient}.\nWhat the person wants to say or ask: {note or '(not stated, base the letter on the findings)'}\n\n"
        "Earlier reading of the document (JSON, produced by you):\n" + _report_digest(report)
    )
    final = run_loop(client, model=config.MODEL, system=letter_system(lang), messages=[{"role": "user", "content": prompt}], max_rounds=4)
    obj = parse_json(final)
    if not isinstance(obj, dict) or not str(obj.get("letter_en", "")).strip():
        raise ModelOutputError("invalid_shape")
    sources = _dedupe([r for r in (resolve_rule(x) for x in obj.get("rule_refs", []) if isinstance(x, str)) if r], "ref")
    return {
        "to": str(obj.get("to", "")),
        "subject": str(obj.get("subject", "")),
        "letter_en": str(obj["letter_en"]),
        "letter_local": str(obj.get("letter_local", "")),
        "language": lang.code,
        "rtl": lang.rtl,
        "sources": sources,
        "note": "This is a draft for you to check before sending. It is not legal advice.",
    }

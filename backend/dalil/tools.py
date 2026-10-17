"""Tools the model may call. They read the registry or fetch an official page. Nothing else."""
from __future__ import annotations

import json
from urllib.parse import urljoin, urlparse

import httpx
from bs4 import BeautifulSoup

from . import config, registry

UA = "Mozilla/5.0 (compatible; Dalil/0.1; document helper)"
MAX_TOOL_CHARS = 14000

TOOL_DEFS = [
    {
        "name": "lookup_rules",
        "description": (
            "Look up verified rules for a country from Dalil's registry. Each fact has an id, a plain statement, "
            "an official source URL and the date it was checked. Use the facts' ids as rule_refs. Returns "
            "covered=false when the registry has nothing for that country."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "country": {"type": "string", "description": "ISO 3166 alpha-2 code, for example AE"},
                "topic": {
                    "type": "string",
                    "enum": list(registry.TOPICS),
                    "description": "Optional. Leave out to get every topic.",
                },
            },
            "required": ["country"],
        },
    },
    {
        "name": "list_authorities",
        "description": (
            "List the official offices for a country (name, web address, phone if an official page shows one). "
            "Use the returned ids as authority_ref in the form COUNTRY:id."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "country": {"type": "string"},
                "issue": {"type": "string", "description": "Optional topic, such as employment or tenancy."},
            },
            "required": ["country"],
        },
    },
    {
        "name": "fetch_official_page",
        "description": (
            "Read the text of one page on an official government domain from the registry. Use it only when a "
            "fact you need is missing. Many government pages need JavaScript and may return little text."
        ),
        "input_schema": {
            "type": "object",
            "properties": {"url": {"type": "string", "description": "https URL on an official domain"}},
            "required": ["url"],
        },
    },
]


def _dump(obj) -> str:
    s = json.dumps(obj, ensure_ascii=False)
    return s if len(s) <= MAX_TOOL_CHARS else s[:MAX_TOOL_CHARS] + '..."truncated"'


def lookup_rules(country: str, topic: str | None = None) -> dict:
    code = (country or "").strip().upper()
    c = registry.get_country(code)
    if not c:
        return {
            "covered": False,
            "country": code,
            "message": "No verified rules for this country yet. Do not state what its rules require.",
            "covered_countries": sorted(registry.load_all()),
        }
    if topic and topic not in c.topics:
        return {"covered": True, "country": code, "topic": topic, "facts": [], "message": f"No verified facts on {topic} for {code}."}
    facts = registry.facts_for(code, topic)
    for f in facts:
        f["ref"] = f"{code}:{f['topic']}:{f['id']}"
    return {
        "covered": True,
        "country": code,
        "name": c.name,
        "last_verified": c.last_verified.isoformat(),
        "notes": c.notes,
        "facts": facts,
    }


def list_authorities(country: str, issue: str | None = None) -> dict:
    code = (country or "").strip().upper()
    if not registry.get_country(code):
        return {"covered": False, "country": code, "authorities": []}
    rows = registry.authorities_for(code, issue)
    for r in rows:
        r["ref"] = f"{code}:{r['id']}"
    return {"covered": True, "country": code, "authorities": rows}


def _official_hosts() -> list[str]:
    hosts: list[str] = []
    for c in registry.load_all().values():
        hosts += c.official_domains
    return hosts


def _is_official(url: str) -> bool:
    p = urlparse(url)
    if p.scheme != "https" or not p.hostname:
        return False
    host = registry.host_of(url)
    return any(registry.host_matches(host, d) for d in _official_hosts())


def fetch_official_page(url: str) -> dict:
    if not _is_official(url):
        return {"ok": False, "error": "That address is not on an official domain in the registry."}
    try:
        with httpx.Client(timeout=config.FETCH_TIMEOUT_S, headers={"User-Agent": UA}, follow_redirects=False) as client:
            current = url
            for _ in range(4):
                r = client.get(current)
                if r.is_redirect and r.headers.get("location"):
                    current = urljoin(current, r.headers["location"])
                    if not _is_official(current):
                        return {"ok": False, "error": "The page redirects away from an official domain."}
                    continue
                break
            else:
                return {"ok": False, "error": "Too many redirects."}
        if r.status_code >= 400:
            return {"ok": False, "error": f"HTTP {r.status_code}"}
        ctype = r.headers.get("content-type", "")
        if "html" not in ctype and "text" not in ctype:
            return {"ok": False, "error": f"Not a text page ({ctype or 'unknown type'})."}
        soup = BeautifulSoup(r.text, "html.parser")
        for t in soup(["script", "style", "noscript", "nav", "footer", "header"]):
            t.decompose()
        text = " ".join(soup.get_text(" ").split())
        return {"ok": True, "url": current, "text": text[: config.FETCH_MAX_CHARS], "truncated": len(text) > config.FETCH_MAX_CHARS}
    except httpx.HTTPError as e:
        return {"ok": False, "error": f"Could not load the page ({type(e).__name__})."}


def run_tool(name: str, args: dict) -> str:
    try:
        if name == "lookup_rules":
            return _dump(lookup_rules(str(args.get("country", "")), args.get("topic")))
        if name == "list_authorities":
            return _dump(list_authorities(str(args.get("country", "")), args.get("issue")))
        if name == "fetch_official_page":
            return _dump(fetch_official_page(str(args.get("url", ""))))
        return _dump({"error": f"unknown tool {name}"})
    except Exception as e:  # noqa: BLE001 - a tool failure must not crash the review
        return _dump({"error": f"tool failed ({type(e).__name__})"})

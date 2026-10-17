#!/usr/bin/env python3
"""Re-open every official link in the rules registry."""
from __future__ import annotations

import argparse
import asyncio
import re
import sys
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))

import httpx  # noqa: E402
from bs4 import BeautifulSoup  # noqa: E402

from dalil.registry import Country, host_matches, host_of, load_all  # noqa: E402

UA = "Mozilla/5.0 (compatible; DalilSourceChecker/0.1; +https://github.com/your-org/dalil)"


def norm(text: str) -> str:
    text = text.replace("’", "'").replace("‘", "'").replace("“", '"').replace("”", '"')
    return re.sub(r"\s+", " ", text).strip().casefold()


@dataclass
class Result:
    country: str
    url: str
    status: str = "ok"
    detail: str = ""
    labels: list[str] = field(default_factory=list)


async def fetch(client: httpx.AsyncClient, url: str) -> tuple[int | None, str, str, str]:
    try:
        r = await client.get(url, follow_redirects=True)
        text = ""
        ctype = r.headers.get("content-type", "")
        if "html" in ctype or "text" in ctype:
            soup = BeautifulSoup(r.text, "html.parser")
            for t in soup(["script", "style", "noscript"]):
                t.decompose()
            text = soup.get_text(" ")
        return r.status_code, str(r.url), text, ""
    except httpx.HTTPError as e:
        return None, url, "", f"{type(e).__name__}: {e}"


async def check_country(c: Country, client: httpx.AsyncClient, sem: asyncio.Semaphore) -> list[Result]:
    quotes: dict[str, list[tuple[str, str]]] = {}
    labels: dict[str, list[str]] = {}
    for label, url in c._url_list():
        labels.setdefault(url, []).append(label)
    for tname, t in c.topics.items():
        for f in t.facts:
            if f.quote.strip():
                quotes.setdefault(f.source_url, []).append((f.id, f.quote))

    async def one(url: str) -> Result:
        res = Result(c.country, url, labels=labels[url])
        async with sem:
            code, final, text, err = await fetch(client, url)
        if code is None:
            res.status, res.detail = "dead", err
        elif code in (404, 410):
            res.status, res.detail = "dead", f"HTTP {code}"
        elif code in (401, 403, 429) or code >= 500:
            res.status, res.detail = "blocked", f"HTTP {code}"
        elif not host_matches(host_of(final), host_of(url)) and not any(
            host_matches(host_of(final), d) for d in c.official_domains
        ):
            res.status, res.detail = "moved", f"redirected to {final}"
        else:
            missing = [fid for fid, q in quotes.get(url, []) if norm(q) not in norm(text)]
            if missing:
                res.status, res.detail = "no-quote", "quote not found for: " + ", ".join(missing)
        return res

    return await asyncio.gather(*(one(u) for u in labels))


async def run(codes: list[str] | None, concurrency: int) -> list[Result]:
    data = load_all()
    chosen = [data[c] for c in (codes or sorted(data))]
    sem = asyncio.Semaphore(concurrency)
    headers = {"User-Agent": UA, "Accept-Language": "en"}
    async with httpx.AsyncClient(headers=headers, timeout=25, verify=True) as client:
        parts = await asyncio.gather(*(check_country(c, client, sem) for c in chosen))
    return [r for part in parts for r in part]


def write_report(results: list[Result], path: Path) -> None:
    order = {"dead": 0, "moved": 1, "no-quote": 2, "blocked": 3, "ok": 4}
    lines = [f"# Source check, {date.today().isoformat()}", ""]
    counts: dict[str, int] = {}
    for r in results:
        counts[r.status] = counts.get(r.status, 0) + 1
    lines.append(", ".join(f"{k}: {v}" for k, v in sorted(counts.items(), key=lambda kv: order[kv[0]])))
    lines.append("")
    lines.append("| Status | Country | URL | Used by | Detail |")
    lines.append("|---|---|---|---|---|")
    for r in sorted(results, key=lambda r: (order[r.status], r.country)):
        if r.status == "ok":
            continue
        lines.append(f"| {r.status} | {r.country} | {r.url} | {', '.join(r.labels)[:80]} | {r.detail} |")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--country", action="append", help="ISO code, repeatable")
    ap.add_argument("--concurrency", type=int, default=8)
    ap.add_argument("--report", type=Path)
    ap.add_argument("--strict", action="store_true", help="also fail on no-quote")
    args = ap.parse_args()
    results = asyncio.run(run([c.upper() for c in args.country] if args.country else None, args.concurrency))
    tally: dict[str, int] = {}
    for r in results:
        tally[r.status] = tally.get(r.status, 0) + 1
        if r.status != "ok":
            print(f"{r.status:9} {r.country} {r.url}  {r.detail}")
    print("\n" + ", ".join(f"{k}={v}" for k, v in sorted(tally.items())) + f"  (total {len(results)})")
    if args.report:
        write_report(results, args.report)
    fail = tally.get("dead", 0) + tally.get("moved", 0) + (tally.get("no-quote", 0) if args.strict else 0)
    return 1 if fail else 0


if __name__ == "__main__":
    raise SystemExit(main())

"""Rules registry: official sources, official domains, authorities and source-backed facts per country."""
from __future__ import annotations

import re
from datetime import date
from functools import lru_cache
from pathlib import Path
from typing import Literal
from urllib.parse import urlparse

import yaml
from pydantic import BaseModel, Field, field_validator, model_validator

TOPICS = ("tenancy", "employment", "fines", "consumer", "scams", "immigration", "privacy")

RULES_DIR = Path(__file__).resolve().parents[2] / "rules" / "countries"


def host_of(url: str) -> str:
    return (urlparse(url).hostname or "").lower().removeprefix("www.")


def host_matches(host: str, domain: str) -> bool:
    host = host.lower().removeprefix("www.")
    domain = domain.lower().removeprefix("www.")
    return host == domain or host.endswith("." + domain)


class Source(BaseModel):
    url: str
    title: str
    publisher: str
    language: str = "en"

    @field_validator("url")
    @classmethod
    def _https(cls, v: str) -> str:
        if not v.startswith(("https://", "http://")):
            raise ValueError("url must start with http:// or https://")
        return v


class Fact(BaseModel):
    id: str = Field(pattern=r"^[a-z0-9_]+$")
    statement: str = Field(min_length=10, max_length=320)
    source_url: str
    quote: str = Field(default="", max_length=300)
    confidence: Literal["quoted", "summary"] = "summary"
    verified_on: date

    @model_validator(mode="after")
    def _quote_rule(self) -> "Fact":
        if self.confidence == "quoted" and not self.quote.strip():
            raise ValueError(f"fact {self.id}: confidence 'quoted' needs a quote")
        return self


class Topic(BaseModel):
    sources: list[Source] = []
    facts: list[Fact] = []


class Authority(BaseModel):
    id: str = Field(pattern=r"^[a-z0-9_]+$")
    name: str
    url: str
    covers: list[str] = []
    phone: str | None = None
    phone_source: str | None = None

    @model_validator(mode="after")
    def _phone_needs_source(self) -> "Authority":
        if self.phone and not self.phone_source:
            raise ValueError(f"authority {self.id}: phone needs phone_source (an official page that shows it)")
        return self


class Portal(BaseModel):
    name: str
    url: str


class Country(BaseModel):
    country: str = Field(pattern=r"^[A-Z]{2}$")
    name: str
    last_verified: date
    portal: Portal
    official_domains: list[str] = Field(min_length=1)
    authorities: list[Authority] = []
    topics: dict[str, Topic] = {}
    notes: str = ""

    @field_validator("topics")
    @classmethod
    def _topic_names(cls, v: dict[str, Topic]) -> dict[str, Topic]:
        bad = [k for k in v if k not in TOPICS]
        if bad:
            raise ValueError(f"unknown topics {bad}; allowed: {list(TOPICS)}")
        return v

    @field_validator("official_domains")
    @classmethod
    def _domains(cls, v: list[str]) -> list[str]:
        out = []
        for d in v:
            d = d.strip().lower().removeprefix("www.")
            if not re.fullmatch(r"[a-z0-9.-]+\.[a-z]{2,}", d):
                raise ValueError(f"not a domain: {d!r}")
            out.append(d)
        return out

    @model_validator(mode="after")
    def _urls_are_official(self) -> "Country":
        if self.last_verified > date.today():
            raise ValueError("last_verified is in the future")
        urls: list[tuple[str, str]] = [("portal", self.portal.url)]
        urls += [(f"authority {a.id}", a.url) for a in self.authorities]
        urls += [(f"authority {a.id} phone_source", a.phone_source) for a in self.authorities if a.phone_source]
        for tname, t in self.topics.items():
            urls += [(f"{tname} source", s.url) for s in t.sources]
            urls += [(f"{tname} fact {f.id}", f.source_url) for f in t.facts]
        for label, url in urls:
            if not any(host_matches(host_of(url), d) for d in self.official_domains):
                raise ValueError(f"{label}: {url} is not on an official domain of {self.country}")
        return self

    def all_urls(self) -> list[str]:
        seen: dict[str, None] = {}
        for _, u in self._url_list():
            seen.setdefault(u)
        return list(seen)

    def _url_list(self) -> list[tuple[str, str]]:
        out = [("portal", self.portal.url)]
        out += [(f"authority:{a.id}", a.url) for a in self.authorities]
        out += [(f"authority:{a.id}:phone", a.phone_source) for a in self.authorities if a.phone_source]
        for tname, t in self.topics.items():
            out += [(f"{tname}:source", s.url) for s in t.sources]
            out += [(f"{tname}:{f.id}", f.source_url) for f in t.facts]
        return out


def load_country_file(path: Path) -> Country:
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    return Country.model_validate(data)


@lru_cache(maxsize=1)
def load_all(rules_dir: str | None = None) -> dict[str, Country]:
    base = Path(rules_dir) if rules_dir else RULES_DIR
    out: dict[str, Country] = {}
    for p in sorted(base.glob("*.yaml")):
        c = load_country_file(p)
        out[c.country] = c
    return out


def coverage() -> list[dict]:
    rows = []
    for c in load_all().values():
        rows.append(
            {
                "code": c.country,
                "name": c.name,
                "last_verified": c.last_verified.isoformat(),
                "topics": sorted(c.topics),
                "facts": sum(len(t.facts) for t in c.topics.values()),
            }
        )
    return sorted(rows, key=lambda r: r["name"])


def get_country(code: str) -> Country | None:
    return load_all().get(code.upper())


def facts_for(code: str, topic: str | None = None) -> list[dict]:
    c = get_country(code)
    if not c:
        return []
    out = []
    for tname, t in c.topics.items():
        if topic and tname != topic:
            continue
        for f in t.facts:
            out.append(
                {
                    "topic": tname,
                    "id": f.id,
                    "statement": f.statement,
                    "source_url": f.source_url,
                    "confidence": f.confidence,
                    "verified_on": f.verified_on.isoformat(),
                }
            )
    return out


def sources_for(code: str, topic: str | None = None) -> list[dict]:
    c = get_country(code)
    if not c:
        return []
    out = []
    for tname, t in c.topics.items():
        if topic and tname != topic:
            continue
        for s in t.sources:
            out.append({"topic": tname, **s.model_dump()})
    return out


def authorities_for(code: str, issue: str | None = None) -> list[dict]:
    c = get_country(code)
    if not c:
        return []
    rows = [a.model_dump() for a in c.authorities if not issue or issue in a.covers]
    return rows or [a.model_dump() for a in c.authorities]

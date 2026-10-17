#!/usr/bin/env python3
"""Check rules/countries/*.yaml against the registry model."""
from __future__ import annotations

import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))

import yaml  # noqa: E402
from pydantic import ValidationError  # noqa: E402

from dalil.registry import RULES_DIR, TOPICS, load_country_file  # noqa: E402

STALE_DAYS = 180
MIN_FACTS = 6


def check(path: Path) -> tuple[list[str], list[str], str]:
    errors: list[str] = []
    warns: list[str] = []
    try:
        c = load_country_file(path)
    except yaml.YAMLError as e:
        return [f"YAML error: {e}"], [], ""
    except ValidationError as e:
        for err in e.errors():
            loc = ".".join(str(x) for x in err["loc"])
            errors.append(f"{loc or 'file'}: {err['msg']}")
        return errors, warns, ""
    except Exception as e:  # noqa: BLE001
        return [f"{type(e).__name__}: {e}"], [], ""

    if path.stem.upper() != c.country:
        errors.append(f"file name {path.name} does not match country code {c.country}")

    total = 0
    parts = []
    for t in TOPICS:
        topic = c.topics.get(t)
        n = len(topic.facts) if topic else 0
        total += n
        if topic and not n:
            warns.append(f"topic {t} has sources but no facts")
        if n:
            parts.append(f"{t}={n}")
        if topic:
            for f in topic.facts:
                age = (date.today() - f.verified_on).days
                if age > STALE_DAYS:
                    warns.append(f"{t}/{f.id}: verified {age} days ago, re-check it")
    if total < MIN_FACTS:
        warns.append(f"only {total} facts, the brief asks for {MIN_FACTS} or more")
    for a in c.authorities:
        if not a.covers:
            warns.append(f"authority {a.id} has no 'covers'")
    return errors, warns, f"{total} facts ({', '.join(parts)})"


def main(argv: list[str]) -> int:
    paths = [Path(a) for a in argv] or sorted(RULES_DIR.glob("*.yaml"))
    if not paths:
        print("no files to check")
        return 0
    bad = 0
    for p in paths:
        errors, warns, summary = check(p)
        status = "FAIL" if errors else "ok"
        print(f"{status:4} {p.name}: {summary or '-'}  [{len(errors)} errors, {len(warns)} warnings]")
        for e in errors:
            print(f"     ERROR {e}")
        for w in warns:
            print(f"     warn  {w}")
        bad += len(errors)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

"""Personal-data masking for pasted text."""
from __future__ import annotations

import re
from dataclasses import dataclass, field

EID = re.compile(r"(?<!\d)784[-\s]?\d{4}[-\s]?\d{7}[-\s]?\d(?!\d)")
EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
PHONE_INTL = re.compile(r"(?<![\w+])(?:\+|00)\d[\d\s().-]{7,17}\d(?!\d)")
PHONE_UAE_LOCAL = re.compile(r"(?<!\d)0(?:5\d|[2-9])[\s-]?\d{3}[\s-]?\d{4}(?!\d)")
IBAN_CAND = re.compile(r"\b[A-Z]{2}\d{2}(?:[ ]?[A-Z0-9]{3,4}){3,8}\b")
CARD_CAND = re.compile(r"(?<!\d)(?:\d[ -]?){13,19}(?!\d)")
LABELLED = re.compile(
    r"(?i)\b(passport|iqama|civil\s*id|national\s*id|id\s*card|visa|residence\s*permit|uid|"
    r"account|acct|a/c|card|licen[cs]e|cheque|check)\s*(?:no\.?|number|num|#)?\s*[:#]?\s*"
    r"((?=[A-Z0-9-]*\d)[A-Z0-9][A-Z0-9-]{5,19})\b"
)


@dataclass
class MaskResult:
    text: str
    counts: dict[str, int] = field(default_factory=dict)

    @property
    def total(self) -> int:
        return sum(self.counts.values())


def luhn_ok(digits: str) -> bool:
    ds = [int(c) for c in digits if c.isdigit()]
    if not 13 <= len(ds) <= 19:
        return False
    total = 0
    for i, d in enumerate(reversed(ds)):
        if i % 2:
            d *= 2
            if d > 9:
                d -= 9
        total += d
    return total % 10 == 0


def iban_ok(s: str) -> bool:
    s = s.replace(" ", "").upper()
    if not 15 <= len(s) <= 34 or not s.isalnum():
        return False
    moved = s[4:] + s[:4]
    num = "".join(str(int(c, 36)) for c in moved)
    return int(num) % 97 == 1


def mask_personal_data(text: str) -> MaskResult:
    counts: dict[str, int] = {}

    def bump(kind: str) -> None:
        counts[kind] = counts.get(kind, 0) + 1

    def sub(pattern: re.Pattern, tag: str, kind: str, s: str, check=None) -> str:
        def repl(m: re.Match) -> str:
            if check and not check(m.group(0)):
                return m.group(0)
            bump(kind)
            return tag

        return pattern.sub(repl, s)

    out = text
    out = sub(EID, "[EMIRATES ID HIDDEN]", "emirates_id", out)
    out = sub(EMAIL, "[EMAIL HIDDEN]", "email", out)
    out = sub(IBAN_CAND, "[IBAN HIDDEN]", "iban", out, check=iban_ok)
    out = sub(CARD_CAND, "[CARD NUMBER HIDDEN]", "card", out, check=luhn_ok)

    def labelled(m: re.Match) -> str:
        bump("id_number")
        return f"{m.group(1)} [NUMBER HIDDEN]"

    out = LABELLED.sub(labelled, out)
    out = sub(PHONE_INTL, "[PHONE HIDDEN]", "phone", out)
    out = sub(PHONE_UAE_LOCAL, "[PHONE HIDDEN]", "phone", out)
    return MaskResult(out, counts)

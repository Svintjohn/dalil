"""Scam shield: rule-based warning signs, combined with what the model saw.

Dalil never says a document is a scam and never says it is safe. It can only say it sees warning signs and tell the
person to check with the real office. The rules here only look for signs; the final level is "none", "caution" or "stop".
"""
from __future__ import annotations

import re
from urllib.parse import urlparse

# code -> (points, short English text used only when the model gave no reasons of its own)
SIGNALS: dict[str, tuple[int, str]] = {
    "code_request": (2, "It asks you to share a code, PIN, password or card number."),
    "gift_card_crypto": (2, "It asks for payment with gift cards or crypto."),
    "remote_access": (2, "It asks you to install a remote-control app."),
    "personal_account": (2, "It asks you to pay into a personal account."),
    "bad_link": (1, "It has a link that does not look official or secure."),
    "short_deadline": (1, "It gives a very short deadline to make you act fast."),
    "threat": (1, "It threatens arrest, a blocked account or other serious trouble."),
    "prize_refund": (1, "It promises a prize, refund or parcel you did not ask for."),
    "secrecy": (1, "It tells you to keep this secret."),
    "money_transfer": (1, "It asks you to send money through a transfer service."),
}

_NEG = re.compile(r"(do not|don't|dont|never|won't|will not|not)\W+(?:\w+\W+){0,3}$", re.I)

_CODE_WORDS = r"(?:otp|one[- ]time (?:code|password|pin)|pin(?: code| number)?|password|passcode|cvv|cvc|card number|card details|security code|verification code|login details|bank details)"
_CODE_VERBS = r"(?:send|share|give|provide|tell|enter|reply|confirm|verify|read out|read back|submit|forward|type)"
_CODE_RE = re.compile(rf"\b{_CODE_VERBS}\b[^.\n!?]{{0,40}}?\b{_CODE_WORDS}\b", re.I)

_PATTERNS: dict[str, re.Pattern] = {
    "gift_card_crypto": re.compile(r"\bgift ?cards?\b|\bitunes\b|google play card|steam card|\bbitcoin\b|\busdt\b|\bethereum\b|\bcrypto(?:currency)?\b|\bbinance\b|\bbtc\b", re.I),
    "remote_access": re.compile(r"\banydesk\b|\bteamviewer\b|\bquicksupport\b|\bultraviewer\b|\bremote (?:access|control)\b", re.I),
    "personal_account": re.compile(r"personal (?:bank )?(?:account|iban|wallet)|officer'?s? (?:personal )?account|\bmy (?:personal )?(?:account|wallet)\b", re.I),
    "short_deadline": re.compile(r"\bwithin (?:\d{1,2}|one|two|three) (?:hours?|hrs?|minutes?|mins?)\b|\bwithin 24 ?h\b|\bfinal (?:warning|notice)\b|\blast chance\b|\burgent(?:ly)?\b|\bimmediately\b|\bright now\b", re.I),
    "threat": re.compile(r"\barrest(?:ed)?\b|\bdeport(?:ed|ation)?\b|\bblacklist(?:ed)?\b|\bimpound(?:ed)?\b|\bwarrant\b|\bjail\b|account (?:will be )?(?:blocked|suspended|closed|frozen)|\bsim (?:will be )?blocked\b|police case", re.I),
    "prize_refund": re.compile(r"you(?:'ve| have)? won\b|\bwinner\b|\blottery\b|\bprize\b|claim your (?:reward|refund|gift|prize)|unclaimed (?:refund|funds|parcel|package)|\binheritance\b|(?:parcel|package|shipment)[^.\n]{0,60}(?:fee|customs|redeliver)", re.I),
    "secrecy": re.compile(r"(?:do not|don't|dont) (?:tell|inform)\b|keep (?:this )?(?:a )?secret|tell no one|tell nobody", re.I),
    "money_transfer": re.compile(r"western union|moneygram", re.I),
}

_URL = re.compile(r"(?:https?://|www\.)[^\s<>\"')]+|\b[a-z0-9-]+(?:\.[a-z0-9-]+)*\.(?:ly|cc|top|xyz|click|icu|cfd|sbs|shop|live|rest|gq|tk|ml)\b(?:/[^\s<>\"')]*)?", re.I)
_SHORTENERS = {"bit.ly", "tinyurl.com", "t.co", "cutt.ly", "rb.gy", "is.gd", "shorturl.at", "ow.ly", "goo.gl", "tiny.cc", "buff.ly", "wa.me"}
_BAD_TLDS = {"top", "xyz", "click", "icu", "cfd", "sbs", "cc", "shop", "live", "rest", "gq", "tk", "ml", "ly"}
_OFFICIAL = re.compile(r"(?:\.|^)(?:gov(?:\.[a-z]{2})?|gob\.[a-z]{2}|gouv\.[a-z]{2}|go\.[a-z]{2}|edu(?:\.[a-z]{2})?|ac\.[a-z]{2}|mil)$", re.I)
_OFFICIAL_WORDS = ("gov", "police", "fine", "fines", "tax", "customs", "immigration", "visa", "bank", "pay", "post", "court")


def _suspicious_url(raw: str) -> bool:
    u = raw.strip().rstrip(".,;:")
    if "@" in u.split("?")[0].split("#")[0].replace("://", "", 1).split("/")[0]:
        return True
    parsed = urlparse(u if "://" in u else "http://" + u)
    host = (parsed.hostname or "").lower()
    if not host:
        return False
    if host in _SHORTENERS or host.startswith("xn--") or ".xn--" in host:
        return True
    if re.fullmatch(r"\d{1,3}(?:\.\d{1,3}){3}", host):
        return True
    tld = host.rsplit(".", 1)[-1]
    if tld in _BAD_TLDS:
        return True
    if parsed.scheme == "http" and "://" in u:
        return True  # an unsecured link, shown to pay or log in
    if host.count("-") >= 3:
        return True
    if not _OFFICIAL.search(host) and any(w in host.split(".")[0] for w in _OFFICIAL_WORDS) and "-" in host.split(".")[0]:
        return True  # looks like an official name but is not on an official domain
    return False


def _negated(text: str, start: int) -> bool:
    return bool(_NEG.search(text[max(0, start - 40) : start]))


def scan(text: str) -> list[str]:
    """Return the warning-sign codes found in a piece of document text (each code once, strongest first)."""
    text = (text or "")[:60000]
    if not text.strip():
        return []
    found: set[str] = set()
    for m in _CODE_RE.finditer(text):
        if not _negated(text, m.start()):
            found.add("code_request")
            break
    for code, rx in _PATTERNS.items():
        for m in rx.finditer(text):
            if code in ("short_deadline", "secrecy") or not _negated(text, m.start()):
                found.add(code)
                break
    for m in _URL.finditer(text):
        if _suspicious_url(m.group(0)):
            found.add("bad_link")
            break
    return sorted(found, key=lambda c: (-SIGNALS[c][0], c))


_RANK = {"none": 0, "caution": 1, "stop": 2}


def assess(codes: list[str], model_level: str, model_reasons: list[str], scam_findings: int) -> dict:
    """Combine rule signs, the model's own view and its scam findings into one calm verdict."""
    score = sum(SIGNALS[c][0] for c in codes if c in SIGNALS) + min(max(scam_findings, 0), 2)
    level = 2 if score >= 3 else 1 if score >= 2 else 0
    m = _RANK.get((model_level or "none").strip().lower(), 0)
    reasons = [r for r in (" ".join(x.split())[:220] for x in model_reasons if isinstance(x, str)) if r][:4]
    if m == 2 and score < 2 and scam_findings == 0:
        m = 1  # the model alone cannot say "stop"
    if m == 1 and not reasons and score == 0 and scam_findings == 0:
        m = 0  # a hunch with nothing behind it
    level = max(level, m)
    name = ("none", "caution", "stop")[level]
    if name != "none" and not reasons:
        reasons = [SIGNALS[c][1] for c in codes if c in SIGNALS][:4]
    return {"level": name, "reasons": reasons if name != "none" else [], "signals": codes if name != "none" else []}

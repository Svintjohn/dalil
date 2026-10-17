"""Reply languages."""
from __future__ import annotations

from dataclasses import asdict, dataclass


@dataclass(frozen=True)
class Language:
    code: str
    name: str
    native: str
    rtl: bool = False
    tier: str = "good"  # high | good | basic (estimate, unverified)
    featured: bool = False  # shown first in the picker


# Featured first (the languages most migrant workers in the Gulf read), then A to Z by English name.
_FEATURED = [
    Language("en", "English", "English", tier="high", featured=True),
    Language("ar", "Arabic", "العربية", rtl=True, tier="high", featured=True),
    Language("tl", "Filipino (Tagalog)", "Tagalog", tier="high", featured=True),
    Language("hi", "Hindi", "हिन्दी", tier="high", featured=True),
    Language("ur", "Urdu", "اردو", rtl=True, tier="high", featured=True),
    Language("bn", "Bangla", "বাংলা", tier="high", featured=True),
    Language("ne", "Nepali", "नेपाली", tier="good", featured=True),
    Language("si", "Sinhala", "සිංහල", tier="good", featured=True),
    Language("ta", "Tamil", "தமிழ்", tier="good", featured=True),
    Language("ml", "Malayalam", "മലയാളം", tier="good", featured=True),
]

_OTHERS = [
    Language("af", "Afrikaans", "Afrikaans", tier="good"),
    Language("sq", "Albanian", "Shqip", tier="good"),
    Language("am", "Amharic", "አማርኛ", tier="basic"),
    Language("hy", "Armenian", "Հայերեն", tier="good"),
    Language("az", "Azerbaijani", "Azərbaycanca", tier="good"),
    Language("bg", "Bulgarian", "Български", tier="good"),
    Language("my", "Burmese", "မြန်မာဘာသာ", tier="good"),
    Language("ceb", "Cebuano", "Cebuano", tier="good"),
    Language("zh-Hans", "Chinese (Simplified)", "简体中文", tier="high"),
    Language("zh-Hant", "Chinese (Traditional)", "繁體中文", tier="high"),
    Language("hr", "Croatian", "Hrvatski", tier="good"),
    Language("cs", "Czech", "Čeština", tier="good"),
    Language("da", "Danish", "Dansk", tier="good"),
    Language("prs", "Dari", "دری", rtl=True, tier="basic"),
    Language("nl", "Dutch", "Nederlands", tier="high"),
    Language("fi", "Finnish", "Suomi", tier="good"),
    Language("fr", "French", "Français", tier="high"),
    Language("ka", "Georgian", "ქართული", tier="good"),
    Language("de", "German", "Deutsch", tier="high"),
    Language("el", "Greek", "Ελληνικά", tier="good"),
    Language("gu", "Gujarati", "ગુજરાતી", tier="good"),
    Language("ha", "Hausa", "Hausa", tier="basic"),
    Language("he", "Hebrew", "עברית", rtl=True, tier="good"),
    Language("hu", "Hungarian", "Magyar", tier="good"),
    Language("ig", "Igbo", "Igbo", tier="basic"),
    Language("ilo", "Ilocano", "Ilokano", tier="basic"),
    Language("id", "Indonesian", "Bahasa Indonesia", tier="high"),
    Language("it", "Italian", "Italiano", tier="high"),
    Language("ja", "Japanese", "日本語", tier="high"),
    Language("kn", "Kannada", "ಕನ್ನಡ", tier="good"),
    Language("kk", "Kazakh", "Қазақша", tier="good"),
    Language("km", "Khmer", "ភាសាខ្មែរ", tier="good"),
    Language("ko", "Korean", "한국어", tier="high"),
    Language("ckb", "Kurdish (Sorani)", "کوردی", rtl=True, tier="basic"),
    Language("lo", "Lao", "ລາວ", tier="good"),
    Language("ms", "Malay", "Bahasa Melayu", tier="high"),
    Language("mr", "Marathi", "मराठी", tier="good"),
    Language("mn", "Mongolian", "Монгол", tier="basic"),
    Language("no", "Norwegian", "Norsk", tier="good"),
    Language("ps", "Pashto", "پښتو", rtl=True, tier="basic"),
    Language("fa", "Persian (Farsi)", "فارسی", rtl=True, tier="good"),
    Language("pl", "Polish", "Polski", tier="high"),
    Language("pt", "Portuguese", "Português", tier="high"),
    Language("pa", "Punjabi", "ਪੰਜਾਬੀ", tier="good"),
    Language("ro", "Romanian", "Română", tier="good"),
    Language("ru", "Russian", "Русский", tier="high"),
    Language("sr", "Serbian", "Српски", tier="good"),
    Language("sk", "Slovak", "Slovenčina", tier="good"),
    Language("so", "Somali", "Soomaali", tier="basic"),
    Language("es", "Spanish", "Español", tier="high"),
    Language("sw", "Swahili", "Kiswahili", tier="good"),
    Language("sv", "Swedish", "Svenska", tier="good"),
    Language("te", "Telugu", "తెలుగు", tier="good"),
    Language("th", "Thai", "ไทย", tier="high"),
    Language("ti", "Tigrinya", "ትግርኛ", tier="basic"),
    Language("tr", "Turkish", "Türkçe", tier="high"),
    Language("uk", "Ukrainian", "Українська", tier="high"),
    Language("uz", "Uzbek", "Oʻzbekcha", tier="good"),
    Language("vi", "Vietnamese", "Tiếng Việt", tier="high"),
    Language("yo", "Yoruba", "Yorùbá", tier="basic"),
    Language("zu", "Zulu", "isiZulu", tier="basic"),
]

LANGUAGES: list[Language] = _FEATURED + sorted(_OTHERS, key=lambda l: l.name.casefold())
BY_CODE: dict[str, Language] = {l.code: l for l in LANGUAGES}

TIER_NOTES = {
    "high": "",
    "good": "",
    "basic": "Replies in this language may be less accurate. Check important details with someone you trust or the office named in the report.",
}


def get_language(code: str | None) -> Language:
    return BY_CODE.get((code or "en").strip(), BY_CODE["en"])


def as_dicts() -> list[dict]:
    rows = []
    for l in LANGUAGES:
        d = asdict(l)
        d["note"] = TIER_NOTES[l.tier]
        rows.append(d)
    return rows

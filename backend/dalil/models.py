"""Request and report models."""
from __future__ import annotations

import base64
import binascii
import re

from pydantic import BaseModel, ConfigDict, Field, field_validator

from . import config

READABILITY_CODES = (
    "blurry",
    "cut_off",
    "glare",
    "too_dark",
    "tilted",
    "too_small_text",
    "pages_missing",
    "not_a_document",
)

READABILITY_MESSAGES = {
    "blurry": "The photo is blurry. Hold the phone steady, let the camera focus, and retake it.",
    "cut_off": "Part of the page is cut off. Fit the whole page in the frame and retake it.",
    "glare": "Glare is covering some of the writing. Tilt the page away from the light and retake it.",
    "too_dark": "The photo is too dark. Move to better light and retake it.",
    "tilted": "The page is tilted too far to read. Hold the phone straight above the page and retake it.",
    "too_small_text": "The writing is too small to read. Move closer and retake it.",
    "pages_missing": "Pages seem to be missing. Add every page of the document and send them in order.",
    "not_a_document": "This does not look like a document. Take a photo of the paper you were given.",
}


class _Lenient(BaseModel):
    model_config = ConfigDict(extra="ignore")


class ReviewRequest(BaseModel):
    images: list[str] = Field(default_factory=list)
    text: str | None = None
    language: str = "en"
    country: str | None = Field(default=None, pattern=r"^[A-Za-z]{2}$")
    sample_id: str | None = Field(default=None, max_length=40)

    @field_validator("images")
    @classmethod
    def _image_count(cls, v: list[str]) -> list[str]:
        if len(v) > config.MAX_IMAGES:
            raise ValueError(f"at most {config.MAX_IMAGES} pages at a time")
        return v

    @field_validator("text")
    @classmethod
    def _text_len(cls, v: str | None) -> str | None:
        if v and len(v) > config.MAX_TEXT_CHARS:
            raise ValueError(f"text is longer than {config.MAX_TEXT_CHARS} characters")
        return v


class PhotoCheckRequest(BaseModel):
    image: str


class AskRequest(BaseModel):
    question: str = Field(min_length=2, max_length=1500)
    report: dict
    language: str = "en"
    history: list[dict] = Field(default_factory=list, max_length=8)


class LetterRequest(BaseModel):
    report: dict
    language: str = "en"
    recipient: str = Field(default="landlord", pattern=r"^(landlord|employer|authority|seller|school|other)$")
    note: str = Field(default="", max_length=800)


_DATA_URL = re.compile(r"^data:[\w/+.-]+;base64,")


def decode_image(value: str) -> bytes:
    s = _DATA_URL.sub("", value.strip())
    try:
        raw = base64.b64decode(s, validate=True)
    except (binascii.Error, ValueError) as e:
        raise ValueError("image is not valid base64") from e
    if not raw:
        raise ValueError("image is empty")
    return raw


class KeyFact(_Lenient):
    label: str = ""
    value: str = ""


class RawPoint(_Lenient):
    original: str = ""
    plain: str = ""


class RawTerm(_Lenient):
    term: str = ""
    meaning: str = ""


class RawFinding(_Lenient):
    severity: str = "medium"
    kind: str = "clause"  # clause | scam_signal | missing
    quote: str = ""
    why: str = ""
    ask: str = ""
    rule_refs: list[str] = Field(default_factory=list)


class RawStep(_Lenient):
    action: str = ""
    deadline: str = ""
    authority_ref: str | None = None


class RawCheck(_Lenient):
    task: str = ""
    due: str = ""


class RawDeadline(_Lenient):
    label: str = ""
    date: str = ""  # YYYY-MM-DD, only when the document states a calendar date
    date_text: str = ""  # the date exactly as the document writes it
    within_days: int | None = None  # "within 14 days" when no calendar date is given


class RawReport(_Lenient):
    readable: bool = True
    readability_issues: list[str] = Field(default_factory=list)
    recognized: bool = True
    doc_type: str = ""
    country: str | None = None
    summary: str = ""
    points: list[RawPoint] = Field(default_factory=list)
    terms: list[RawTerm] = Field(default_factory=list)
    key_facts: list[KeyFact] = Field(default_factory=list)
    findings: list[RawFinding] = Field(default_factory=list)
    next_steps: list[RawStep] = Field(default_factory=list)
    checklist: list[RawCheck] = Field(default_factory=list)
    deadlines: list[RawDeadline] = Field(default_factory=list)
    not_sure: str = ""
    closing: str = ""
    labels: dict[str, str] = Field(default_factory=dict)

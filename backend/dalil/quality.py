"""Photo quality gate."""
from __future__ import annotations

import io
from dataclasses import dataclass, field

import numpy as np
from PIL import Image, ImageOps, UnidentifiedImageError

from . import config

Image.MAX_IMAGE_PIXELS = 60_000_000
TARGET_LONG_SIDE = 1200
GRID = 8

ISSUE_CODES = ("unreadable_file", "too_small", "blurry", "too_dark", "low_contrast", "low_detail")

MESSAGES_EN = {
    "unreadable_file": "This file could not be opened as a photo. Use a JPG, PNG or WebP image.",
    "too_small": "The photo is too small to read. Move closer or use a higher camera setting, then retake it.",
    "blurry": "The photo is blurry. Hold the phone steady, let the camera focus, and retake it.",
    "too_dark": "The photo is too dark. Move to better light and retake it.",
    "low_contrast": "The writing is too faint to read. Avoid glare and shadows and retake it.",
    "low_detail": "No clear text was found. Fill the frame with the document and retake it.",
}


@dataclass
class Issue:
    code: str
    message: str


@dataclass
class QualityReport:
    ok: bool
    issues: list[Issue] = field(default_factory=list)
    metrics: dict = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {
            "ok": self.ok,
            "issues": [{"code": i.code, "message": i.message} for i in self.issues],
            "metrics": self.metrics,
        }


def _open(data: bytes) -> Image.Image:
    img = Image.open(io.BytesIO(data))
    img.load()
    return ImageOps.exif_transpose(img)


def _gray(img: Image.Image) -> np.ndarray:
    w, h = img.size
    scale = TARGET_LONG_SIDE / max(w, h)
    if scale < 1:
        img = img.resize((max(1, round(w * scale)), max(1, round(h * scale))), Image.LANCZOS)
    return np.asarray(img.convert("L"), dtype=np.float32)


def _tile_sharpness(g: np.ndarray) -> tuple[float, float]:
    if g.shape[0] < 3 or g.shape[1] < 3:
        return 0.0, 0.0
    lap = -4 * g[1:-1, 1:-1] + g[:-2, 1:-1] + g[2:, 1:-1] + g[1:-1, :-2] + g[1:-1, 2:]
    h, w = lap.shape
    th, tw = max(1, h // GRID), max(1, w // GRID)
    vars_ = []
    for r in range(GRID):
        for c in range(GRID):
            tile = lap[r * th : (r + 1) * th, c * tw : (c + 1) * tw]
            if tile.size:
                vars_.append(float(tile.var()))
    arr = np.array(vars_)
    sharp = float(np.percentile(arr, 90))
    detail = float((arr > 15.0).mean())
    return sharp, detail


def assess_image(data: bytes) -> QualityReport:
    try:
        img = _open(data)
    except (UnidentifiedImageError, OSError, ValueError, Image.DecompressionBombError):
        return QualityReport(False, [Issue("unreadable_file", MESSAGES_EN["unreadable_file"])], {})

    w, h = img.size
    g = _gray(img)
    sharp, detail = _tile_sharpness(g)
    mean = float(g.mean())
    p5, p95 = (float(x) for x in np.percentile(g, [5, 95]))
    spread = p95 - p5
    metrics = {
        "width": w,
        "height": h,
        "sharpness": round(sharp, 1),
        "brightness": round(mean, 1),
        "contrast_spread": round(spread, 1),
        "detail_tiles": round(detail, 3),
    }

    codes: list[str] = []
    if min(w, h) < config.MIN_SIDE_PX or max(w, h) < config.MIN_LONG_SIDE_PX:
        codes.append("too_small")
    if mean < config.DARK_MAX_MEAN:
        codes.append("too_dark")
    elif spread < config.MIN_CONTRAST_SPREAD:
        codes.append("low_contrast")
    if detail < config.MIN_DETAIL_TILES:
        codes.append("low_detail")
    elif sharp < config.BLUR_MIN_SHARPNESS:
        codes.append("blurry")

    return QualityReport(not codes, [Issue(c, MESSAGES_EN[c]) for c in codes], metrics)


def normalize_image(data: bytes, max_side: int = 1568) -> tuple[bytes, str]:
    img = _open(data)
    if img.mode not in ("RGB", "L"):
        bg = Image.new("RGB", img.size, (255, 255, 255))
        rgba = img.convert("RGBA")
        bg.paste(rgba, mask=rgba.split()[-1])
        img = bg
    elif img.mode == "L":
        img = img.convert("RGB")
    w, h = img.size
    scale = max_side / max(w, h)
    if scale < 1:
        img = img.resize((round(w * scale), round(h * scale)), Image.LANCZOS)
    out = io.BytesIO()
    img.save(out, "JPEG", quality=88, optimize=True)
    return out.getvalue(), "image/jpeg"

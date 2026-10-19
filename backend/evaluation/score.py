"""Scoring for the labeled cases. Pure functions, no network."""
from __future__ import annotations

from dalil import numbers as numbers_mod
from dalil import scam as scam_mod

from . import cases

RANK = {"none": 0, "caution": 1, "stop": 2}


def rule_level(text: str) -> dict:
    """What the rule checks alone say about a text (no model, no findings)."""
    return scam_mod.assess(scam_mod.scan(text), "none", [], 0)


def _lines(rows) -> list[dict]:
    out = []
    for r in rows:
        label, amount, role = r[0], r[1], r[2]
        out.append({"label": label, "amount": amount, "role": role, "rate": r[3] if len(r) > 3 else None})
    return out


def numbers_status(result: dict | None) -> str:
    return "none" if not result else result["status"]


def score_scam(levels: dict[str, str]) -> dict:
    """levels: case id -> level shown for the SCAM cases."""
    rows = [{"id": c["id"], "min": c["min"], "level": levels.get(c["id"], "error")} for c in cases.SCAM]
    scored = [r for r in rows if r["level"] != "error"]
    detected = [r for r in scored if RANK[r["level"]] >= 1]
    met = [r for r in scored if RANK[r["level"]] >= RANK[r["min"]]]
    return {
        "n": len(rows), "scored": len(scored), "detected": len(detected), "met_minimum": len(met),
        "recall": len(detected) / len(scored) if scored else 0.0,
        "missed": [r["id"] for r in scored if RANK[r["level"]] < 1],
        "below_minimum": [f'{r["id"]} (got {r["level"]}, wanted {r["min"]})' for r in scored if RANK[r["level"]] < RANK[r["min"]]],
    }


def score_legit(levels: dict[str, str]) -> dict:
    rows = [{"id": c["id"], "level": levels.get(c["id"], "error")} for c in cases.LEGIT]
    scored = [r for r in rows if r["level"] != "error"]
    alarms = [r for r in scored if RANK[r["level"]] >= 1]
    stops = [r for r in scored if r["level"] == "stop"]
    return {
        "n": len(rows), "scored": len(scored), "false_alarms": len(alarms), "false_stops": len(stops),
        "false_alarm_rate": len(alarms) / len(scored) if scored else 0.0,
        "alarm_ids": [f'{r["id"]} ({r["level"]})' for r in alarms],
    }


def score_numbers(statuses: dict[str, str]) -> dict:
    rows = [{"id": c["id"], "expect": c["expect"], "got": statuses.get(c["id"], "error")} for c in cases.NUMBERS]
    scored = [r for r in rows if r["got"] != "error"]
    right = [r for r in scored if r["got"] == r["expect"]]
    # the costly mistake is a false "mismatch" (scaring someone about a correct bill) or a false "ok" (missing a real error)
    false_mismatch = [r["id"] for r in scored if r["got"] == "mismatch" and r["expect"] != "mismatch"]
    missed_mismatch = [r["id"] for r in scored if r["expect"] == "mismatch" and r["got"] != "mismatch"]
    return {
        "n": len(rows), "scored": len(scored), "correct": len(right),
        "accuracy": len(right) / len(scored) if scored else 0.0,
        "false_mismatch": false_mismatch, "missed_mismatch": missed_mismatch,
        "wrong": [f'{r["id"]} (got {r["got"]}, wanted {r["expect"]})' for r in scored if r["got"] != r["expect"]],
    }


def _subset(res: dict, prefix: str) -> dict:
    """Recompute the scam and legit numbers for only the cases whose id starts with prefix ("" means all)."""
    scam_rows = {c["id"] for c in cases.SCAM if c["id"].startswith(prefix)}
    legit_rows = {c["id"] for c in cases.LEGIT if c["id"].startswith(prefix)}
    return {"scam_ids": scam_rows, "legit_ids": legit_rows}


def run_offline() -> dict:
    """The rule checks and the arithmetic, exactly as the app uses them, on the labeled cases."""
    scam_levels = {c["id"]: rule_level(c["text"])["level"] for c in cases.SCAM}
    legit_levels = {c["id"]: rule_level(c["text"])["level"] for c in cases.LEGIT}
    statuses = {c["id"]: numbers_status(numbers_mod.check("AED", _lines(c["lines"]))) for c in cases.NUMBERS}
    return {"scam": score_scam(scam_levels), "legit": score_legit(legit_levels), "numbers": score_numbers(statuses)}


def pct(x: float) -> str:
    return f"{round(x * 100):d}%"


def to_markdown(title: str, res: dict, extra: list[str] | None = None) -> str:
    s, lg, n = res["scam"], res["legit"], res["numbers"]
    lines = [f"# {title}", ""]
    lines += extra or []
    lines += [
        "| Check | Result |", "|---|---|",
        f"| Scam-like documents warned about | {s['detected']} of {s['scored']} ({pct(s['recall'])}) |",
        f"| ...reached the expected level | {s['met_minimum']} of {s['scored']} |",
        f"| Ordinary documents with any warning (false alarms) | {lg['false_alarms']} of {lg['scored']} ({pct(lg['false_alarm_rate'])}) |",
        f"| Ordinary documents wrongly told to STOP | {lg['false_stops']} of {lg['scored']} |",
        f"| Amount checks correct | {n['correct']} of {n['scored']} ({pct(n['accuracy'])}) |",
        f"| Wrong \"does not add up\" on a correct bill | {len(n['false_mismatch'])} |",
        f"| Real error missed | {len(n['missed_mismatch'])} |",
        "",
    ]
    for name, items in (("Scam-like documents not warned about", s["missed"]), ("Scam-like documents below the expected level", s["below_minimum"]),
                        ("Ordinary documents with a warning", lg["alarm_ids"]), ("Amount checks that were wrong", n["wrong"])):
        if items:
            lines += [f"**{name}:**"] + [f"- {i}" for i in items] + [""]
    lines += ["_The cases are made-up and were written by the developers. This measures a regression check and the live model on a fixed set. It is not proof of accuracy on real documents._", ""]
    return "\n".join(lines)

"""Run the labeled cases.

    python -m evaluation.run                  # offline: the rule checks and the arithmetic only, no keys needed
    python -m evaluation.run --live           # also ask the real model to read every case (uses your AI keys)

Live mode reads GEMINI_API_KEY / ANTHROPIC_API_KEY (and the backup keys) from the environment, exactly like the app.
It sends only the made-up case texts and writes only case ids and results, never document text.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time

from . import cases, score


def run_live(pause: float, limit: int | None) -> dict:
    from dalil import agent, config, languages

    if not config.ai_ready():
        sys.exit("No AI key is set. Set GEMINI_API_KEY (or another key) in this terminal first. See the README.")
    lang = languages.get_language("en")
    todo = [("scam", c) for c in cases.SCAM] + [("legit", c) for c in cases.LEGIT] + [("numbers", c) for c in cases.NUMBERS]
    if limit:
        todo = todo[:limit]
    scam_levels, legit_levels, statuses, errors, seconds = {}, {}, {}, {}, []
    for i, (group, c) in enumerate(todo, 1):
        t0 = time.monotonic()
        try:
            rep = agent.review(images=[], text=c["text"], lang=lang, country=None)
            level = (rep.get("scam") or {}).get("level", "none")
            status = score.numbers_status(rep.get("number_check"))
            if group == "scam":
                scam_levels[c["id"]] = level
            elif group == "legit":
                legit_levels[c["id"]] = level
            else:
                statuses[c["id"]] = status
            outcome = level if group != "numbers" else status
        except Exception as e:  # noqa: BLE001 - one failed case must not stop the run
            errors[c["id"]] = type(e).__name__ + " " + str(e)[:60]
            outcome = "error " + type(e).__name__ + " " + str(e)[:60]
        dt = time.monotonic() - t0
        seconds.append(dt)
        print(f"[{i}/{len(todo)}] {group:7s} {c['id']:28s} {outcome:22s} {dt:4.1f}s", flush=True)
        if i < len(todo):
            time.sleep(pause)
    res = {"scam": score.score_scam(scam_levels), "legit": score.score_legit(legit_levels), "numbers": score.score_numbers(statuses)}
    res["errors"] = errors
    res["avg_seconds"] = sum(seconds) / len(seconds) if seconds else 0.0
    res["model"] = config.MODEL
    return res


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--live", action="store_true", help="also run the real model on every case")
    ap.add_argument("--pause", type=float, default=8.0, help="seconds to wait between live cases (free tiers allow only a few calls a minute)")
    ap.add_argument("--limit", type=int, default=0, help="live mode: only the first N cases")
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "results"), help="folder for the result files")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)

    off = score.run_offline()
    md = score.to_markdown("Offline check (rules and arithmetic, no AI model)", off)
    print(md)
    with open(os.path.join(a.out, "offline.md"), "w", encoding="utf-8") as f:
        f.write(md)
    with open(os.path.join(a.out, "offline.json"), "w", encoding="utf-8") as f:
        json.dump(off, f, indent=2)

    if a.live:
        live = run_live(a.pause, a.limit or None)
        extra = [f"Model: `{live['model']}`. Average time per document: {live['avg_seconds']:.1f} s.", f"Cases that failed to run: {len(live['errors'])}" + (f" ({', '.join(f'{k}: {v}' for k, v in live['errors'].items())})" if live["errors"] else ""), ""]
        md = score.to_markdown("Live check (the real model reads each case)", live, extra)
        print("\n" + md)
        with open(os.path.join(a.out, "live.md"), "w", encoding="utf-8") as f:
            f.write(md)
        with open(os.path.join(a.out, "live.json"), "w", encoding="utf-8") as f:
            json.dump(live, f, indent=2)


if __name__ == "__main__":
    main()

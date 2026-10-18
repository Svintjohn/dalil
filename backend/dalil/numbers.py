"""Number check: the model only reads the amounts off the paper, the arithmetic is done here.

Dalil checks whether the amounts on a document add up. It does not say whether a price is fair.
"""
from __future__ import annotations

TOLERANCE = 0.05  # documents round to cents, so a gap bigger than this is a real difference
ROLES = ("item", "subtotal", "tax", "discount", "total")
MAX_LINES = 20


def _close(a: float, b: float) -> bool:
    return abs(a - b) <= TOLERANCE


def _money(x: float) -> float:
    return round(x + 0.0, 2)


def check(currency: str, lines: list[dict]) -> dict | None:
    """lines: [{"label": str, "amount": float, "role": item|subtotal|tax|discount|total, "rate": float|None}].

    Returns None when there is nothing to check, otherwise
    {"status": "ok"|"mismatch", "currency": str, "lines": [...], "issues": [...]}.
    """
    rows = []
    for ln in lines[:MAX_LINES]:
        amt, role = ln.get("amount"), ln.get("role")
        if role not in ROLES or not isinstance(amt, (int, float)) or isinstance(amt, bool) or amt != amt or abs(amt) > 1e12:
            return None  # a line that cannot be read or placed could be the one that makes the sum right, so do not guess
        label = " ".join(str(ln.get("label") or "").split())[:100]
        rate = ln.get("rate")
        rate = float(rate) if isinstance(rate, (int, float)) and not isinstance(rate, bool) and 0 < rate <= 100 else None
        rows.append({"label": label, "amount": _money(abs(float(amt)) if role in ("discount", "tax") and amt < 0 else float(amt)), "role": role, "rate": rate})
    if len(rows) < 2:
        return None

    items = [r["amount"] for r in rows if r["role"] == "item"]
    taxes = [r for r in rows if r["role"] == "tax"]
    discounts = [r["amount"] for r in rows if r["role"] == "discount"]
    subtotals = [r["amount"] for r in rows if r["role"] == "subtotal"]
    totals = [r["amount"] for r in rows if r["role"] == "total"]
    if not totals:
        return None  # without a stated total there is nothing to compare with

    items_sum, tax_sum, disc_sum = sum(items), sum(t["amount"] for t in taxes), sum(discounts)
    stated_total = totals[-1]
    issues: list[dict] = []
    checks_run = 0

    base = items_sum
    if subtotals and items:
        checks_run += 1
        sub = subtotals[0]
        if not (_close(items_sum, sub) or _close(items_sum - disc_sum, sub)):
            issues.append({"code": "subtotal_mismatch", "stated": sub, "computed": _money(items_sum)})
        base = sub
    elif subtotals:
        base = subtotals[0]

    for t in taxes:
        if t["rate"] and (items or subtotals):
            checks_run += 1
            expected = base * t["rate"] / 100
            expected_after_discount = (base - disc_sum) * t["rate"] / 100
            if not (_close(expected, t["amount"]) or _close(expected_after_discount, t["amount"])):
                issues.append({"code": "tax_mismatch", "stated": t["amount"], "computed": _money(expected), "rate": t["rate"]})

    if items or subtotals:
        checks_run += 1
        candidates = {_money(base + tax_sum - disc_sum), _money(base + tax_sum)}
        if subtotals and items:
            candidates |= {_money(items_sum + tax_sum - disc_sum), _money(items_sum + tax_sum)}
        if not any(_close(c, stated_total) for c in candidates):
            main = _money(base + tax_sum - disc_sum)
            issues.append({"code": "total_mismatch", "stated": stated_total, "computed": main, "difference": _money(stated_total - main)})

    if checks_run == 0:
        return None
    return {"status": "mismatch" if issues else "ok", "currency": " ".join((currency or "").split())[:8], "lines": rows, "issues": issues}

"""Regression guard for the labeled cases: a rule change that breaks a known case fails here."""
from evaluation import cases, score


def test_no_ordinary_document_is_told_to_stop_or_warned():
    bad = [(c["id"], score.rule_level(c["text"])["level"]) for c in cases.LEGIT if score.rule_level(c["text"])["level"] != "none"]
    assert bad == []


def test_every_scam_case_is_warned_at_least_as_strongly_as_labeled():
    rank = {"none": 0, "caution": 1, "stop": 2}
    weak = [c["id"] for c in cases.SCAM if rank[score.rule_level(c["text"])["level"]] < rank[c["min"]]]
    assert weak == []


def test_every_amount_check_is_right():
    res = score.run_offline()
    assert res["numbers"]["correct"] == res["numbers"]["scored"] == res["numbers"]["n"]

"""Made-up sample documents and their saved results."""
from __future__ import annotations

from datetime import date, timedelta

from .agent import finalize_report
from .languages import get_language
from .models import RawReport

_DUE = date.today() + timedelta(days=20)  # the school sample always has a deadline about three weeks away
_DUE_TEXT = f"{_DUE.day} {_DUE.strftime('%B %Y')}"

SAMPLES: dict[str, dict] = {
    "rent": {
        "title": "Rental contract",
        "note": "Housing, Dubai",
        "text": (
            "TENANCY CONTRACT (extract), Dubai\n\n"
            "1. Annual rent is AED 78,000, paid in 1 cheque. A security deposit of AED 8,000 is non-refundable.\n"
            "2. The Landlord may increase the rent at any time by giving the Tenant 14 days' notice.\n"
            "3. The Tenant shall pay a brokerage and admin fee of AED 4,500 in cash to the Landlord's agent on signing.\n"
            "4. If the Tenant leaves before the end of the term, the Tenant shall pay the full rent for the whole remaining term.\n"
            "5. The Landlord may enter the unit at any time without notice.\n"
            "6. This contract does not need to be registered with Ejari."
        ),
        "raw": {
            "country": "AE",
            "doc_type": "Tenancy contract (extract)",
            "summary": "This is a one-year rental contract for AED 78,000 in Dubai. Several clauses favour the landlord, and one says the contract does not need to be registered in Ejari.",
            "key_facts": [
                {"label": "Rent per year", "value": "AED 78,000"},
                {"label": "Deposit", "value": "AED 8,000, called non-refundable"},
                {"label": "Agent fee", "value": "AED 4,500, in cash"},
                {"label": "Rent increase notice", "value": "14 days"},
            ],
            "findings": [
                {"severity": "high", "kind": "clause", "quote": "does not need to be registered with Ejari",
                 "why": "In Dubai, tenancy contracts must be registered through the Ejari system. A contract that says it does not need this is a warning sign.",
                 "ask": "registration of the contract in Ejari", "rule_refs": ["AE:tenancy:dubai_ejari_mandatory"]},
                {"severity": "medium", "kind": "clause", "quote": "increase the rent at any time by giving the Tenant 14 days' notice",
                 "why": "Dubai Land Department guidance says a change to the rent at renewal needs at least 90 days' notice before the contract ends, unless both sides agree otherwise. A right to raise the rent at any time with 14 days' notice is much shorter.",
                 "ask": "at least 90 days' written notice, and the Rental Index as the reference",
                 "rule_refs": ["AE:tenancy:dubai_rent_increase_notice", "AE:tenancy:dubai_rent_index"]},
                {"severity": "medium", "kind": "clause", "quote": "security deposit of AED 8,000 is non-refundable",
                 "why": "Dubai Land Department guidance says a deposit covers damage to the property and must be refunded at the end of the contract. Calling it non-refundable does not match that.",
                 "ask": "a deposit that is refunded at the end, less proven damage",
                 "rule_refs": ["AE:tenancy:dubai_security_deposit"]},
                {"severity": "medium", "kind": "clause", "quote": "in cash to the Landlord's agent on signing",
                 "why": "A cash payment without a receipt is hard to prove later. The registry has no verified rule on agent fees, so this is a general caution and not a rule check.",
                 "ask": "a written receipt, or a bank transfer", "rule_refs": []},
                {"severity": "medium", "kind": "clause", "quote": "pay the full rent for the whole remaining term",
                 "why": "This can cost a lot if you must leave early. The registry has no verified rule on early exit, so this is a general caution.",
                 "ask": "a cheaper, fixed way to end the contract early", "rule_refs": []},
                {"severity": "low", "kind": "clause", "quote": "enter the unit at any time without notice",
                 "why": "Entry without any notice is unusual. This is a general caution, not a rule check.",
                 "ask": "reasonable notice before entry", "rule_refs": []},
            ],
            "next_steps": [
                {"action": "Do not sign or pay yet. Ask the landlord to register the contract in Ejari and to change the clauses above.",
                 "deadline": "", "authority_ref": "AE:dld"},
                {"action": "If the landlord refuses, ask the Dubai Land Department about Ejari registration and rental disputes.",
                 "deadline": "", "authority_ref": "AE:dld"},
            ],
            "checklist": [
                {"task": "Get the contract registered in Ejari before you pay anything", "due": ""},
                {"task": "Keep a receipt for every payment, including the agent fee", "due": ""},
                {"task": "Check the rent against the Dubai Land Department Rental Index", "due": ""},
            ],
            "not_sure": "This is a made-up sample. Agent fees, early exit and landlord entry are not covered by verified rules in Dalil yet.",
            "closing": "You can ask me about any clause. This is a guide and not legal advice.",
        },
    },
    "job": {
        "title": "Job offer",
        "note": "Work, Dubai",
        "text": (
            "OFFER OF EMPLOYMENT\n\n"
            "Position: Warehouse Assistant, Dubai\n"
            "Basic salary: AED 1,200 per month plus AED 300 housing allowance.\n"
            "Probation: 12 months. During probation the Company may end employment at any time without notice or end-of-service pay.\n"
            "The Company will keep the Employee's passport for safekeeping.\n"
            "A visa and recruitment processing fee of AED 3,500 will be deducted from the first three months' salary.\n"
            "Working hours: 12 hours a day, 6 days a week. No overtime is payable.\n"
            "The Employee may not resign in the first 2 years, or must pay AED 10,000 to the Company."
        ),
        "raw": {
            "country": "AE",
            "doc_type": "Job offer",
            "summary": "This is an offer for a warehouse job in Dubai. Several terms look unusual and some do not match the official rules for private-sector workers.",
            "key_facts": [
                {"label": "Pay", "value": "AED 1,200 a month plus AED 300 housing"},
                {"label": "Probation", "value": "12 months"},
                {"label": "Hours", "value": "12 hours a day, 6 days a week"},
                {"label": "Visa fee", "value": "AED 3,500, taken from your salary"},
                {"label": "Penalty for resigning", "value": "AED 10,000"},
            ],
            "findings": [
                {"severity": "high", "kind": "clause", "quote": "keep the Employee's passport for safekeeping",
                 "why": "UAE labour law says an employer must not withhold a worker's official documents.",
                 "ask": "to keep your own passport", "rule_refs": ["AE:employment:no_document_withholding"]},
                {"severity": "high", "kind": "clause", "quote": "AED 3,500 will be deducted from the first three months' salary",
                 "why": "UAE law prohibits the employer from charging the worker recruitment and employment costs, and says the employer pays the entry visa and travel costs.",
                 "ask": "the employer to pay this fee",
                 "rule_refs": ["AE:employment:no_recruitment_fees_from_worker", "AE:employment:employer_pays_visa_travel"]},
                {"severity": "high", "kind": "clause", "quote": "Probation: 12 months",
                 "why": "Official guidance says probation must not be longer than six months.",
                 "ask": "probation of six months at most", "rule_refs": ["AE:employment:probation_six_months"]},
                {"severity": "high", "kind": "clause", "quote": "12 hours a day, 6 days a week. No overtime is payable",
                 "why": "Normal hours are at most 8 a day or 48 a week, and overtime is paid with at least 25 percent extra.",
                 "ask": "normal hours and paid overtime",
                 "rule_refs": ["AE:employment:working_hours", "AE:employment:overtime_pay"]},
                {"severity": "high", "kind": "clause", "quote": "end employment at any time without notice or end-of-service pay",
                 "why": "Official guidance says an employer ending employment during probation must give 14 days of written notice.",
                 "ask": "written notice as the rules require", "rule_refs": ["AE:employment:probation_six_months"]},
                {"severity": "medium", "kind": "clause", "quote": "must pay AED 10,000 to the Company",
                 "why": "Official guidance describes written notice of 30 to 90 days for ending a contract, not a fixed penalty. A large penalty for resigning is a warning sign, so ask the Ministry.",
                 "ask": "the standard notice rules instead of a penalty", "rule_refs": ["AE:employment:notice_period_30_90"]},
            ],
            "next_steps": [
                {"action": "Do not sign or hand over your passport. Ask for the offer to be changed, and ask for the official MoHRE contract.",
                 "deadline": "", "authority_ref": "AE:mohre"},
                {"action": "If you are unsure, call the MoHRE labour advice line before you sign.",
                 "deadline": "", "authority_ref": "AE:mohre"},
            ],
            "checklist": [
                {"task": "Ask for the standard MoHRE contract, in two copies", "due": ""},
                {"task": "Keep your passport with you", "due": ""},
                {"task": "Keep copies of every message and document from the employer", "due": ""},
            ],
            "not_sure": "This is a made-up sample. Dalil has no verified minimum-wage fact, so the salary level is not checked.",
            "closing": "You can ask me about any clause. This is a guide and not legal advice.",
        },
    },
    "fine": {
        "title": "Fine notice",
        "note": "Traffic, Dubai",
        "text": (
            "TRAFFIC VIOLATION NOTICE, Dubai\n\n"
            "Plate: A 12345\n"
            "Violation: exceeding the speed limit by more than 20 km/h but not more than 30 km/h\n"
            "Fine: AED 600    Black points: 3\n"
            "Date: 02/09/2026\n"
            "Pay within 24 hours to avoid your vehicle being impounded and extra charges of AED 2,000.\n"
            "To pay, transfer AED 600 to the officer's personal account or use this link: http://dxb-fines-pay.example/pay"
        ),
        "raw": {
            "country": "AE",
            "doc_type": "Traffic fine notice",
            "summary": "This says you have a speeding fine of AED 600 and 3 black points, and that you must pay within 24 hours. The payment instructions look suspicious.",
            "key_facts": [
                {"label": "Fine", "value": "AED 600"},
                {"label": "Black points", "value": "3"},
                {"label": "Deadline given", "value": "24 hours"},
                {"label": "Extra charge if late", "value": "AED 2,000"},
            ],
            "findings": [
                {"severity": "medium", "kind": "scam_signal", "quote": "transfer AED 600 to the officer's personal account",
                 "why": "This looks suspicious. In Dubai, traffic fines are checked and paid on official websites, not by a transfer to a person's account.",
                 "ask": "to check and pay only on the official RTA, Dubai Police or Ministry of Interior website or app",
                 "rule_refs": ["AE:fines:dubai_fine_channels"]},
                {"severity": "medium", "kind": "scam_signal", "quote": "use this link: http://dxb-fines-pay.example/pay",
                 "why": "This looks suspicious. The link does not look like an official government address and it is not a secure link. Do not open it.",
                 "ask": "the fine to be shown on the official website you type in yourself",
                 "rule_refs": ["AE:fines:dubai_fine_channels"]},
                {"severity": "medium", "kind": "scam_signal", "quote": "Pay within 24 hours to avoid your vehicle being impounded and extra charges of AED 2,000",
                 "why": "This looks suspicious. A very short deadline with a large extra charge is a common way to make people pay in a hurry.",
                 "ask": "time to check the fine on the official channels", "rule_refs": []},
            ],
            "next_steps": [
                {"action": "Check whether you really have a fine on the official RTA, Dubai Police or Ministry of Interior website or app. Type the address yourself.",
                 "deadline": "", "authority_ref": "AE:police"},
                {"action": "If you already paid or shared your details, call your bank at once and report it to the police.",
                 "deadline": "", "authority_ref": "AE:police"},
            ],
            "checklist": [
                {"task": "Do not use the link or transfer any money", "due": ""},
                {"task": "Check the plate number on the official website", "due": ""},
                {"task": "Keep a screenshot of the message", "due": ""},
            ],
            "not_sure": "Dalil cannot tell whether this notice is genuine. Only the official channels can confirm it.",
            "closing": "You can ask me about this notice. This is a guide and not legal advice.",
        },
    },
    "school": {
        "title": "School fee notice",
        "note": "School, Dubai",
        "text": (
            "AL NOOR PRIVATE SCHOOL, Dubai\n\n"
            "Dear Parent,\n"
            "Term 2 fees of AED 4,200 for your child in Grade 5 are due on " + _DUE_TEXT + ".\n"
            "If the fee is not received by that date, a late charge of AED 150 will be added.\n"
            "Please also return the signed trip permission slip within 7 days of this letter.\n"
            "Pay at the school accounts office or by bank transfer using the reference on your invoice."
        ),
        "raw": {
            "doc_type": "School fee notice",
            "summary": "This is a notice from a school. It asks you to pay Term 2 fees of AED 4,200 by a set date, and to return a signed trip permission slip within 7 days.",
            "key_facts": [
                {"label": "Fee", "value": "AED 4,200 (Term 2, Grade 5)"},
                {"label": "Late charge", "value": "AED 150"},
                {"label": "Pay by", "value": _DUE_TEXT},
            ],
            "findings": [],
            "next_steps": [
                {"action": "Pay the fee at the school accounts office or by bank transfer, using the reference on your invoice.", "deadline": _DUE_TEXT, "authority_ref": None},
                {"action": "Sign the trip permission slip and return it to the school.", "deadline": "Within 7 days of the letter", "authority_ref": None},
            ],
            "checklist": [
                {"task": "Find the invoice reference number", "due": ""},
                {"task": "Keep the bank transfer receipt", "due": ""},
            ],
            "deadlines": [
                {"label": "Pay the Term 2 school fee (AED 4,200)", "date": _DUE.isoformat(), "date_text": _DUE_TEXT},
                {"label": "Return the signed trip permission slip", "within_days": 7},
            ],
            "not_sure": "This is a made-up sample. Ask the school if you are unsure about the fee or the trip.",
            "closing": "You can ask me about this notice. This is a guide and not legal advice.",
        },
    },
}


def list_samples() -> list[dict]:
    return [{"id": k, "title": v["title"], "note": v["note"], "text": v["text"]} for k, v in SAMPLES.items()]


def saved_report(sample_id: str | None) -> dict | None:
    s = SAMPLES.get(sample_id or "")
    if not s:
        return None
    report = finalize_report(RawReport.model_validate(s["raw"]), get_language("en"))
    report["saved"] = True
    return report

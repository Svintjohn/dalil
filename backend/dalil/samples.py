"""Made-up sample documents and their saved results."""
from __future__ import annotations

from datetime import date, timedelta

from .agent import finalize_form, finalize_report
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
            "prep": {
                "office": "The landlord or agent",
                "bring": [
                    {"item": "A copy of the contract", "required": False},
                    {"item": "Your ID", "required": False},
                ],
                "questions": [
                    "Will you register this contract in Ejari before I pay anything?",
                    "Can the AED 8,000 deposit be refunded at the end of the contract?",
                    "Can I pay the AED 4,500 agent fee by bank transfer and get a receipt?",
                ],
            },
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
            "scam": {"level": "stop", "reasons": [
                "It asks you to pay into a personal account.",
                "The payment link does not look official and is not secure.",
                "It gives only 24 hours and threatens extra charges.",
            ]},
            "not_sure": "Dalil cannot tell whether this notice is genuine. Only the official channels can confirm it.",
            "closing": "You can ask me about this notice. This is a guide and not legal advice.",
        },
    },
    "bill": {
        "title": "Utility bill",
        "note": "Bills, Dubai",
        "text": (
            "ALFAJR UTILITIES, Dubai. Monthly bill\n\n"
            "Electricity: AED 320.00\n"
            "Water: AED 85.50\n"
            "Cooling charge: AED 210.00\n"
            "Meter fee: AED 14.50\n"
            "Subtotal: AED 630.00\n"
            "VAT 5%: AED 31.50\n"
            "Total to pay: AED 720.00\n"
            "Please pay by bank transfer or at the service counter before the due date."
        ),
        "raw": {
            "doc_type": "Utility bill",
            "summary": "This is a monthly utility bill. It says you must pay AED 720.00, but the amounts on it add up to AED 661.50.",
            "key_facts": [
                {"label": "Total to pay", "value": "AED 720.00"},
                {"label": "VAT", "value": "5%"},
            ],
            "findings": [],
            "due": {"amount": 720.00, "currency": "AED", "label": "Utility bill, total to pay", "date": "", "date_text": ""},
            "amounts": {
                "currency": "AED",
                "lines": [
                    {"label": "Electricity", "amount": 320.00, "role": "item"},
                    {"label": "Water", "amount": 85.50, "role": "item"},
                    {"label": "Cooling charge", "amount": 210.00, "role": "item"},
                    {"label": "Meter fee", "amount": 14.50, "role": "item"},
                    {"label": "Subtotal", "amount": 630.00, "role": "subtotal"},
                    {"label": "VAT 5%", "amount": 31.50, "role": "tax", "rate": 5},
                    {"label": "Total to pay", "amount": 720.00, "role": "total"},
                ],
            },
            "next_steps": [
                {"action": "Ask the utility company to explain why the total is higher than the amounts listed.", "deadline": "", "authority_ref": None},
            ],
            "checklist": [
                {"task": "Compare each figure on the bill with your meter readings", "due": ""},
                {"task": "Keep the payment receipt", "due": ""},
            ],
            "not_sure": "This is a made-up sample. Dalil checks the arithmetic only, not whether the prices are fair.",
            "closing": "You can ask me about this bill. This is a guide and not legal or financial advice.",
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
            "prep": {
                "office": "School accounts office",
                "bring": [
                    {"item": "The invoice with your reference number", "required": True},
                    {"item": "The signed trip permission slip", "required": True},
                    {"item": "Your ID", "required": False},
                    {"item": "A way to keep the payment receipt", "required": False},
                ],
                "questions": [
                    "Can I pay the fee in two parts?",
                    "Is the late charge added automatically, or can it be waived if I pay a few days late?",
                    "Will I get a receipt for the payment?",
                ],
            },
            "if_ignored": [
                {"action": "Pay the Term 2 fee of AED 4,200 by the due date",
                 "consequence": "A late charge of AED 150 will be added.", "source": "document"},
            ],
            "due": {"amount": 4200, "currency": "AED", "label": "Term 2 school fees", "date": _DUE.isoformat(), "date_text": _DUE_TEXT},
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


_MONTHS_AR = ["يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو", "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"]
_DUE_TEXT_AR = f"{_DUE.day} {_MONTHS_AR[_DUE.month - 1]} {_DUE.year}"

# An Arabic version of one sample, written by hand, so the page can be shown right to left even when the AI is not available.
SAMPLES_AR: dict[str, dict] = {
    "school": {
        "doc_type": "إشعار رسوم مدرسية",
        "summary": "هذا إشعار من مدرسة. يطلب منك دفع رسوم الفصل الدراسي الثاني وقدرها 4,200 درهم في موعد محدد، وإعادة إذن الرحلة موقّعًا خلال 7 أيام.",
        "key_facts": [
            {"label": "الرسوم", "value": "4,200 درهم (الفصل الثاني، الصف الخامس)"},
            {"label": "رسوم التأخير", "value": "150 درهمًا"},
            {"label": "آخر موعد للدفع", "value": _DUE_TEXT_AR},
        ],
        "next_steps": [
            {"action": "ادفع الرسوم في مكتب الحسابات بالمدرسة أو بالتحويل المصرفي، مع استخدام الرقم المرجعي الموجود في الفاتورة.", "deadline": _DUE_TEXT_AR},
            {"action": "وقّع إذن الرحلة وأعده إلى المدرسة.", "deadline": "خلال 7 أيام من تاريخ الرسالة"},
        ],
        "checklist": [{"task": "ابحث عن الرقم المرجعي في الفاتورة", "due": ""}, {"task": "احتفظ بإيصال التحويل المصرفي", "due": ""}],
        "prep": {
            "office": "مكتب الحسابات بالمدرسة",
            "bring": [
                {"item": "الفاتورة وعليها الرقم المرجعي", "required": True},
                {"item": "إذن الرحلة موقّعًا", "required": True},
                {"item": "هويتك", "required": False},
                {"item": "وسيلة للاحتفاظ بإيصال الدفع", "required": False},
            ],
            "questions": ["هل يمكنني دفع الرسوم على دفعتين؟", "هل تُضاف رسوم التأخير تلقائيًا، أم يمكن إلغاؤها إذا تأخرت بضعة أيام؟", "هل سأحصل على إيصال بالدفع؟"],
        },
        "if_ignored": [{"action": "دفع رسوم الفصل الثاني (4,200 درهم) في الموعد المحدد", "consequence": "ستُضاف رسوم تأخير قدرها 150 درهمًا."}],
        "due_label": "رسوم الفصل الدراسي الثاني",
        "deadline_labels": ["دفع رسوم الفصل الثاني (4,200 درهم)", "إعادة إذن الرحلة موقّعًا"],
        "not_sure": "هذا مثال من صنعنا. اسأل المدرسة إذا لم تكن متأكدًا من الرسوم أو الرحلة.",
        "closing": "يمكنك أن تسألني عن هذا الإشعار. هذا دليل إرشادي وليس استشارة قانونية.",
        "labels": {
            "plain_words": "بكلمات بسيطة", "terms": "كلمات صعبة مشروحة", "key_facts": "التفاصيل الأساسية", "watch_out": "انتبه", "ask": "اطلب",
            "next_steps": "الخطوات التالية", "checklist": "قائمتك", "deadlines": "المواعيد", "where": "إلى أين تذهب", "not_sure": "غير متأكد من",
            "no_flags": "لم نجد علامات خطر", "numbers_flag": "المبالغ لا تتطابق", "due_amount": "المبلغ المستحق", "due_by": "الدفع قبل",
            "due_check": "راجع هذا الرقم: المبالغ في الورقة لا تتطابق.", "high": "خطر مرتفع", "medium": "تحقق من هذا", "low": "نقطة صغيرة",
            "suspicious": "يبدو مشبوهًا", "sources": "مصادر رسمية", "if_ignored": "إذا لم تفعل شيئًا", "from_document": "المستند يقول", "from_rule": "قاعدة رسمية",
            "prep": "قبل أن تذهب", "prep_bring": "أحضر", "prep_ask": "اسأل", "prep_required": "المستند يطلب هذا", "prep_suggested": "مقترح",
            "numbers": "فحص الأرقام", "numbers_ok": "المبالغ الظاهرة تساوي الإجمالي في المستند.",
        },
    },
}


def saved_report(sample_id: str | None, language: str = "en") -> dict | None:
    s = SAMPLES.get(sample_id or "")
    if not s:
        return None
    raw = dict(s["raw"])
    lang = get_language("en")
    ar = SAMPLES_AR.get(sample_id or "")
    if ar and language == "ar":
        lang = get_language("ar")
        raw.update({k: ar[k] for k in ("doc_type", "summary", "key_facts", "checklist", "prep", "not_sure", "closing", "labels")})
        raw["next_steps"] = [{**e, **a} for e, a in zip(raw["next_steps"], ar["next_steps"])]
        raw["if_ignored"] = [{**e, **a} for e, a in zip(raw["if_ignored"], ar["if_ignored"])]
        raw["due"] = {**raw["due"], "label": ar["due_label"], "date_text": _DUE_TEXT_AR}
        raw["deadlines"] = [{**d, "label": lab} for d, lab in zip(raw["deadlines"], ar["deadline_labels"])]
        raw["deadlines"][0]["date_text"] = _DUE_TEXT_AR
    report = finalize_report(RawReport.model_validate(raw), lang)
    report["saved"] = True
    report["sample_id"] = sample_id
    return report


# Saved reply letters for the sample documents, so "Draft a letter" can be shown even when the AI is not available.
SAMPLE_LETTERS: dict[str, dict] = {
    "school": {
        "to": "School accounts office",
        "subject": "Question about Term 2 fees and the trip permission slip",
        "letter_en": (
            "Dear Accounts Office,\n\n"
            "Thank you for your notice about the Term 2 fees of AED 4,200 for my child in Grade 5.\n\n"
            "I would like to ask two things:\n"
            "1. Can I pay the fee in two parts? If yes, please tell me the dates and amounts.\n"
            "2. Is the late charge of AED 150 added automatically, or can it be waived if a payment is a few days late?\n\n"
            "I will also return the signed trip permission slip within 7 days. Please confirm in writing that you received it.\n\n"
            "I would be grateful for a written reply.\n\n"
            "Kind regards,\n[Your full name]\n[Child's name and class]\n[Date]"
        ),
        "letter_ar": (
            "السادة مكتب الحسابات المحترمين،\n\n"
            "شكرًا لكم على الإشعار بخصوص رسوم الفصل الدراسي الثاني وقدرها 4,200 درهم لابني/ابنتي في الصف الخامس.\n\n"
            "أودّ أن أسأل عن أمرين:\n"
            "1. هل يمكنني دفع الرسوم على دفعتين؟ إن كان ذلك ممكنًا، أرجو إبلاغي بالمواعيد والمبالغ.\n"
            "2. هل تُضاف رسوم التأخير البالغة 150 درهمًا تلقائيًا، أم يمكن إلغاؤها إذا تأخرت دفعة بضعة أيام؟\n\n"
            "وسأعيد إذن الرحلة موقّعًا خلال 7 أيام. أرجو تأكيد استلامه كتابيًا.\n\n"
            "أكون شاكرًا لو وصلني ردّكم كتابيًا.\n\n"
            "مع خالص التحية،\n[اسمك الكامل]\n[اسم الطفل وصفه]\n[التاريخ]"
        ),
    },
    "job": {
        "to": "Employer or HR",
        "subject": "Request to review terms in my job offer",
        "letter_en": (
            "Dear [Hiring manager's name],\n\n"
            "Thank you for the offer for the Warehouse Assistant position. Before I sign, I would like to ask you to review a few terms and confirm them in writing.\n\n"
            "1. The offer says the company will keep my passport for safekeeping. I would like to keep my own passport and give you a copy.\n"
            "2. The offer says the visa and recruitment fee will be deducted from my salary. Please confirm who should pay this fee and where it is allowed.\n"
            "3. Please confirm my working hours and my notice period in writing.\n\n"
            "I would be grateful for a written reply.\n\n"
            "Kind regards,\n[Your full name]\n[Date]"
        ),
        "letter_ar": "",
    },
    "rent": {
        "to": "Landlord or property manager",
        "subject": "Request to register the tenancy contract in Ejari and review some clauses",
        "letter_en": (
            "Dear [Landlord's name],\n\n"
            "Thank you for the tenancy contract. Before I sign or pay, I would like to ask you to register the contract in Ejari and to review a few clauses.\n\n"
            "1. The contract says it does not need to be registered in Ejari. Please register it through the Ejari system.\n"
            "2. The rent can rise at any time with 14 days' notice. Please change this to the written notice that Dubai Land Department guidance describes.\n"
            "3. The AED 8,000 deposit is called non-refundable. Please confirm it will be refunded at the end, less any proven damage.\n"
            "4. Please give me a written receipt for any payment, including the agent fee.\n\n"
            "I would be grateful for a written reply.\n\n"
            "Kind regards,\n[Your full name]\n[Date]"
        ),
        "letter_ar": "",
    },
}


def saved_letter(sample_id: str | None, language: str = "en") -> dict | None:
    s = SAMPLE_LETTERS.get(sample_id or "")
    if not s:
        return None
    lang = get_language(language)
    local = s["letter_ar"] if language == "ar" else ""
    return {
        "to": s["to"], "subject": s["subject"], "letter_en": s["letter_en"], "letter_local": local,
        "language": lang.code, "rtl": lang.rtl, "sources": [],
        "note": "This is a saved letter for a sample document. It was not produced live. It is a draft to check, not legal advice.",
        "saved": True,
    }


# Made-up blank forms for "Fill in a form". Their results are saved, so trying one costs nothing and always works.
FORM_SAMPLES: dict[str, dict] = {
    "form_card": {
        "title": "Library card form",
        "note": "A simple form",
        "text": (
            "CITY LIBRARY - MEMBERSHIP APPLICATION\n\n"
            "Full name: ____________\nDate of birth: ____________\nHome address: ____________\n"
            "Phone number: ____________\nID number: ____________\n"
            "Membership type (tick one): Adult / Student / Senior\n"
            "Do you agree to the library rules? Yes / No\nSignature: ____________  Date: ____________"
        ),
        "raw": {
            "is_form": True,
            "form_name": "Library membership application",
            "purpose": "You fill this in to get a library card so you can borrow books.",
            "fields": [
                {"label": "Full name", "meaning": "Your name as it appears on your ID.", "how_to_fill": "", "kind": "private", "required": "yes"},
                {"label": "Date of birth", "meaning": "The day you were born.", "how_to_fill": "", "kind": "private", "required": "yes"},
                {"label": "Home address", "meaning": "Where you live now. The library may send letters here.", "how_to_fill": "", "kind": "private", "required": "yes"},
                {"label": "Phone number", "meaning": "A number where the library can reach you.", "how_to_fill": "", "kind": "private", "required": "unclear"},
                {"label": "ID number", "meaning": "The number on your identity document.", "how_to_fill": "", "kind": "private", "required": "yes"},
                {"label": "Membership type", "meaning": "The kind of card you want. The price or loan limits can differ.", "how_to_fill": "Tick the one that fits you. If you are not sure, ask the desk which one is right.", "kind": "choice", "required": "yes"},
                {"label": "Do you agree to the library rules?", "meaning": "You confirm you accept the rules for borrowing, returns and fines.", "how_to_fill": "Ask to read the rules first if you have not seen them.", "kind": "choice", "required": "yes"},
                {"label": "Signature and date", "meaning": "Your own signature and today's date. It shows you agree.", "how_to_fill": "", "kind": "signature", "required": "yes"},
            ],
            "warnings": [],
            "before_submit": ["Check that your name matches your ID.", "Read the library rules before you sign."],
            "not_sure": "",
        },
    },
    "form_bank": {
        "title": "Bank form asking for PIN",
        "note": "Has a warning sign",
        "text": (
            "ACCOUNT VERIFICATION FORM\n\n"
            "To keep your account active, complete this form today.\n"
            "Full name: ____________\nAccount number: ____________\n"
            "Card number: ____________  Expiry: ____/____  CVV: ______\n"
            "ATM PIN: ______\nOne-time password (OTP) sent to your phone: ______\n"
            "Accounts not verified within 24 hours will be closed."
        ),
        "raw": {
            "is_form": True,
            "form_name": "Account verification form",
            "purpose": "A form that says it verifies your bank account.",
            "fields": [
                {"label": "Full name", "meaning": "Your name.", "how_to_fill": "", "kind": "private", "required": "yes"},
                {"label": "Account number", "meaning": "The number of your bank account.", "how_to_fill": "", "kind": "private", "required": "yes"},
                {"label": "Card number, expiry and CVV", "meaning": "The details printed on your bank card. With these, someone can spend your money.", "how_to_fill": "", "kind": "private", "required": "yes"},
                {"label": "ATM PIN", "meaning": "The secret code you use at the machine. A real bank never asks for it on a form.", "how_to_fill": "", "kind": "private", "required": "yes"},
                {"label": "One-time password (OTP)", "meaning": "A code sent to your phone to approve one action. Giving it away lets someone approve payments as you.", "how_to_fill": "", "kind": "private", "required": "yes"},
            ],
            "warnings": [
                "Banks do not ask for your PIN, CVV or OTP on a form. Do not fill this in.",
                "The 24-hour deadline is a pressure tactic. Contact your bank using the number on your card.",
            ],
            "before_submit": ["Do not send this form. Call your bank using the number on the back of your card."],
            "not_sure": "",
        },
    },
}


def list_form_samples() -> list[dict]:
    return [{"id": k, "title": v["title"], "note": v["note"], "text": v["text"]} for k, v in FORM_SAMPLES.items()]


def saved_form(sample_id: str | None) -> dict | None:
    s = FORM_SAMPLES.get(sample_id or "")
    if not s:
        return None
    out = finalize_form(s["raw"], get_language("en"))
    out["saved"] = True
    out["saved_note"] = "This is a saved result for a sample form. It was not produced live."
    out["privacy"] = {"hidden": {}, "hidden_total": 0}
    return out

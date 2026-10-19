"""Labeled test documents for Dalil. Every text here is made up (no real person, number or account).

Three groups:
- SCAM: messages and notices that show real scam warning signs. Dalil should warn (level "caution" or "stop").
- LEGIT: ordinary documents. Dalil should show no warning at all. A false "stop" is the worst mistake.
- NUMBERS: bills and schedules with amounts. `lines` is what a careful reader would copy off the paper (the offline
  check uses it); `expect` is "ok" (the amounts add up), "mismatch" (they do not) or "none" (nothing to check).

These cases were written by the developers. They are a regression check and a way to measure the live model, not proof
of accuracy on real documents from real people. Add real (anonymised, with permission) examples as they come in.
"""
from __future__ import annotations

SCAM: list[dict] = [
    {"id": "scam-fine-sms", "min": "stop", "text": "TRAFFIC FINE: AED 600. Pay within 24 hours or your car will be impounded. Transfer to the officer's personal account or use http://dxb-fines-pay.example/pay"},
    {"id": "scam-bank-otp", "min": "stop", "text": "Your bank account will be suspended today. Verify now by sending your OTP and card number at http://secure-bank-verify.top/login"},
    {"id": "scam-lottery", "min": "caution", "text": "Congratulations! You won AED 50,000 in our lottery. To claim your prize, pay AED 500 processing fee by Western Union today."},
    {"id": "scam-parcel-customs", "min": "caution", "text": "Your parcel is held at customs. Pay the AED 15 customs fee at bit.ly/dxb-post-pay or the parcel will be returned."},
    {"id": "scam-job-crypto-fee", "min": "caution", "text": "Job offer: work from home, AED 8,000 per month. To start, pay a AED 1,200 visa processing fee in USDT crypto to our agent."},
    {"id": "scam-tech-support", "min": "stop", "text": "ALERT: a virus was found on your phone. Install AnyDesk now and give the technician your banking password immediately."},
    {"id": "scam-visa-giftcards", "min": "stop", "text": "Immigration notice: your visa will be cancelled and you will be deported unless you pay AED 3,000 in iTunes gift cards within 24 hours."},
    {"id": "scam-rental-deposit", "min": "caution", "text": "Apartment for rent, great price. Do not visit. Send your passport copy by WhatsApp and transfer the deposit to my personal account immediately to hold it."},
    {"id": "scam-utility-disconnect", "min": "caution", "text": "FINAL NOTICE: your electricity will be disconnected today. Pay now at http://dewa-pay-now.com/bill to avoid arrest and fines."},
    {"id": "scam-tax-refund", "min": "caution", "text": "A tax refund of AED 2,300 is waiting for you. Claim your refund by sharing your card number and CVV on the link."},
    {"id": "scam-loan-pin", "min": "caution", "text": "Instant loan approved. Send your Emirates ID photo and your bank PIN to receive the money today."},
    {"id": "scam-redelivery-fee", "min": "caution", "text": "Your package could not be delivered. Pay the small redelivery fee at http://pinoy-parcel.xyz/pay now."},
    {"id": "scam-subsidy-login", "min": "caution", "text": "You qualify for a government subsidy. Reply with your online banking login details and password to receive it."},
    {"id": "scam-personal-account", "min": "caution", "text": "Please pay the AED 600 fine to the personal account of the officer on duty, IBAN given by phone."},
    {"id": "scam-inheritance", "min": "caution", "text": "I am a lawyer. You are the heir of a large inheritance. Keep this secret and send AED 2,000 through MoneyGram to release the funds."},
    {"id": "scam-account-frozen", "min": "caution", "text": "Your account is frozen. Confirm your identity by giving your verification code and PIN to our agent on this call."},
    {"id": "scam-courier-gift", "min": "caution", "text": "You won a free phone. Pay the delivery fee with a Google Play card and send us the code."},
    {"id": "scam-police-warrant", "min": "stop", "text": "Police case opened against you. A warrant will be issued unless you pay AED 5,000 now to the personal account below. Tell no one."},
]

# Set B: written after the rules were tuned on set A, with different wording and some deliberately hard cases
# (scams that need understanding, and ordinary messages that use scary words). Ids start with "b-".
SCAM += [
    {"id": "b-scam-streaming", "min": "caution", "text": "Dear customer, your Netflix payment failed. Update your billing details here: tinyurl.com/nf-update"},
    {"id": "b-scam-family", "min": "caution", "text": "Hi mum, I lost my phone. This is my new number. Can you transfer AED 900 to this account urgently? I will explain later."},
    {"id": "b-scam-rta-lookalike", "min": "caution", "text": "RTA: you have an unpaid fine. Settle now to avoid licence suspension: https://rta-gov-fines.co/pay"},
    {"id": "b-scam-task-deposit", "min": "caution", "text": "Earn AED 500 daily by liking videos. Join our Telegram group. Deposit AED 300 first to unlock your tasks."},
    {"id": "b-scam-id-password", "min": "caution", "text": "Your Emirates ID has expired. Update it now by providing your ID number and password at http://uae-id-update.top"},
    {"id": "b-scam-army-officer", "min": "caution", "text": "I am an army officer with 5 million dollars. Send your bank details and I will share 30 percent with you."},
    {"id": "b-scam-read-code", "min": "caution", "text": "We noticed a login from a new device. If this was not you, call us immediately and read out the code we text you."},
    {"id": "b-scam-invest-usdt", "min": "caution", "text": "Investment opportunity: double your money in 7 days, guaranteed. Send USDT to the wallet address below."},
    {"id": "b-scam-dewa-wu", "min": "caution", "text": "Your DEWA account will be blocked. Pay AED 450 now to this number via Western Union."},
    {"id": "b-scam-cabin-crew", "min": "caution", "text": "Congratulations, you are shortlisted for a cabin crew job. Pay AED 800 for the medical and uniform with a gift card."},
    {"id": "b-scam-new-account", "min": "caution", "text": "Landlord notice: pay the rent to the new account number below. Our old account is closed. Do not call the office, WhatsApp only."},
    {"id": "b-scam-delivery-address", "min": "caution", "text": "Click here to confirm your delivery address or the parcel will be returned: bit.ly/3xYzAbC"},
]

LEGIT: list[dict] = [
    {"id": "ok-bank-security-note", "text": "Monthly statement, March. Closing balance AED 4,210.55. Security reminder: never share your OTP or PIN with anyone. Our staff will never ask for it."},
    {"id": "ok-bank-payment-due", "text": "Your credit card payment of AED 380 is due in 3 days. You can pay in the official mobile app or at any branch."},
    {"id": "ok-school-fees", "text": "Dear Parent, Term 2 fees of AED 4,200 are due on 15 December. A late charge of AED 150 applies after that date. Pay at the accounts office or by bank transfer using the reference on your invoice."},
    {"id": "ok-tenancy-wire", "text": "TENANCY CONTRACT. Annual rent AED 78,000 payable in 4 cheques. Security deposit AED 5,000 refundable at the end. Payments by wire transfer to the landlord's company account are accepted."},
    {"id": "ok-dewa-bill", "text": "Electricity and water bill for April: AED 312.40. Pay online at https://www.dewa.gov.ae or in the app. Due date 28 April."},
    {"id": "ok-clinic-reminder", "text": "Reminder: your appointment is on 12 November at 10:30. Please arrive 15 minutes early and bring your Emirates ID and insurance card. Reply YES to confirm."},
    {"id": "ok-job-offer", "text": "Offer letter. Position: Accountant. Salary AED 9,000 per month. Start date 1 November. Contract 2 years. Please sign and return this letter within 7 days."},
    {"id": "ok-visa-renewal", "text": "Your residence permit expires on 30 November 2026. Please renew it before that date through the official ICP app or https://icp.gov.ae."},
    {"id": "ok-rta-fine", "text": "Traffic violation: speeding, fine AED 400, 4 black points. Check and pay on https://www.rta.ae or in the RTA app within 60 days to keep the discount."},
    {"id": "ok-phone-overdue", "text": "Your phone bill of AED 250 is overdue. Please pay immediately in the operator's app to avoid service suspension."},
    {"id": "ok-court-hearing", "text": "Notice of hearing: you are asked to attend the Labour Court on 12 November at 9:00. Failure to attend may result in a warrant being issued."},
    {"id": "ok-insurance-renewal", "text": "Your motor insurance renews on 3 January. Premium AED 1,850. Pay by card at https://www.axa.ae or call your agent for other options."},
    {"id": "ok-gym", "text": "Your gym membership renews automatically on 1 December at AED 199 per month. This is the final notice before renewal. You can cancel in the app at any time."},
    {"id": "ok-scholarship", "text": "We are pleased to offer you a scholarship of AED 20,000 for the 2027 academic year. Please sign the acceptance letter and return it by 15 January."},
    {"id": "ok-hr-confidential", "text": "Employment contract. Salary AED 7,500. Notice period 30 days. The employee must keep company information confidential during and after employment."},
    {"id": "ok-bank-beware", "text": "Beware of calls or messages asking for your OTP, PIN or password. We will never ask for them. Report suspicious messages to us on the official number on your card."},
    {"id": "ok-courier-track", "text": "Your parcel will arrive today between 2pm and 6pm. Track it at https://www.aramex.com/track. No payment is needed."},
    {"id": "ok-utility-reminder", "text": "Water bill reminder: AED 96.20 is due on 20 October. If you have already paid, please ignore this message."},
    {"id": "ok-loan-statement", "text": "Personal loan statement. Instalment AED 1,150 is due on the 5th of each month by direct debit. Early settlement fee 1%. Contact the branch for questions."},
    {"id": "ok-urgent-school", "text": "URGENT: school will close early tomorrow at 12:00 because of the weather. Please collect your child on time. Buses will leave at 12:15."},
]

LEGIT += [
    {"id": "b-ok-otp-delivered", "text": "Your OTP is 482913. Do not share this code with anyone. It is valid for 5 minutes."},
    {"id": "b-ok-otp-enter", "text": "To complete your online payment of AED 120, enter the OTP sent to your registered mobile number."},
    {"id": "b-ok-crypto-statement", "text": "Exchange statement: your Bitcoin holdings are worth AED 12,400. Crypto investments carry risk and prices can change quickly."},
    {"id": "b-ok-giftcard-receipt", "text": "Receipt: gift card purchase AED 100 at City Mall store. Thank you for shopping with us."},
    {"id": "b-ok-water-works", "text": "Dear tenant, water will be off on Tuesday from 9am to 1pm for maintenance. Urgent: please store water in advance."},
    {"id": "b-ok-parking", "text": "Final warning: your parking permit expires tomorrow. Renew it in the Parkin app."},
    {"id": "b-ok-science-fair", "text": "The prize giving for the school science fair will be held on 5 December. The winners will be announced then."},
    {"id": "b-ok-new-iban", "text": "Our bank account details have changed. New IBAN for rent payments: AE07 0331 2345 6789 0123 456. Please update your standing order."},
    {"id": "b-ok-moi-fines", "text": "Check your traffic fines at https://www.moi.gov.ae. Pay immediately in the official app to avoid extra charges."},
    {"id": "b-ok-customs-paid", "text": "Parcel update: your package was delivered to the front desk at 3pm. The customs duty of AED 20 was already paid online."},
    {"id": "b-ok-passport-copy", "text": "Salary certificate request: please send a copy of your passport and Emirates ID to HR by 10 November."},
    {"id": "b-ok-phone-banking", "text": "Telephone banking: for your security we may ask you to confirm your date of birth. We will never ask for your PIN or password."},
    {"id": "b-ok-lease-pin", "text": "Send the signed lease to the landlord by email and keep a copy. Do not share your bank PIN with anyone."},
    {"id": "b-ok-appointment-reply", "text": "Reply YES to confirm your appointment on 12 November at 10:30. Reply NO to cancel."},
]

# Amounts: `lines` copy what is printed. role is item | subtotal | tax | discount | total. `rate` is a stated tax percentage.
NUMBERS: list[dict] = [
    {"id": "num-bill-ok", "expect": "ok", "text": "Water 85.50, Electricity 320.00, Cooling 210.00, Meter 14.50, Subtotal 630.00, VAT 5% 31.50, Total 661.50",
     "lines": [("Water", 85.5, "item"), ("Electricity", 320, "item"), ("Cooling", 210, "item"), ("Meter", 14.5, "item"), ("Subtotal", 630, "subtotal"), ("VAT 5%", 31.5, "tax", 5), ("Total", 661.5, "total")]},
    {"id": "num-bill-wrong-total", "expect": "mismatch", "text": "Water 85.50, Electricity 320.00, Cooling 210.00, Meter 14.50, Subtotal 630.00, VAT 5% 31.50, Total 720.00",
     "lines": [("Water", 85.5, "item"), ("Electricity", 320, "item"), ("Cooling", 210, "item"), ("Meter", 14.5, "item"), ("Subtotal", 630, "subtotal"), ("VAT 5%", 31.5, "tax", 5), ("Total", 720, "total")]},
    {"id": "num-wrong-vat", "expect": "mismatch", "text": "Service 400.00, VAT 5% 25.00, Total 425.00",
     "lines": [("Service", 400, "item"), ("VAT 5%", 25, "tax", 5), ("Total", 425, "total")]},
    {"id": "num-cheques-ok", "expect": "ok", "text": "Annual rent AED 78,000 in 4 cheques of AED 19,500",
     "lines": [("Cheque 1", 19500, "item"), ("Cheque 2", 19500, "item"), ("Cheque 3", 19500, "item"), ("Cheque 4", 19500, "item"), ("Annual rent", 78000, "total")]},
    {"id": "num-cheques-wrong", "expect": "mismatch", "text": "Annual rent AED 80,000 in 4 cheques of AED 19,500",
     "lines": [("Cheque 1", 19500, "item"), ("Cheque 2", 19500, "item"), ("Cheque 3", 19500, "item"), ("Cheque 4", 19500, "item"), ("Annual rent", 80000, "total")]},
    {"id": "num-discount-ok", "expect": "ok", "text": "Tuition 5,000.00, Sibling discount 500.00, VAT 5% on 4,500.00 is 225.00, Total 4,725.00",
     "lines": [("Tuition", 5000, "item"), ("Sibling discount", 500, "discount"), ("VAT 5%", 225, "tax", 5), ("Total", 4725, "total")]},
    {"id": "num-subtotal-wrong", "expect": "mismatch", "text": "Item A 100, Item B 50, Subtotal 160, Total 160",
     "lines": [("Item A", 100, "item"), ("Item B", 50, "item"), ("Subtotal", 160, "subtotal"), ("Total", 160, "total")]},
    {"id": "num-no-total", "expect": "none", "text": "Item A 100, Item B 50",
     "lines": [("Item A", 100, "item"), ("Item B", 50, "item")]},
    {"id": "num-single-amount", "expect": "none", "text": "Fee AED 4,200 due on 15 December",
     "lines": [("Fee", 4200, "total")]},
    {"id": "num-rounding-ok", "expect": "ok", "text": "Three equal parts of 33.33 and a total of 100.00",
     "lines": [("Part 1", 33.33, "item"), ("Part 2", 33.33, "item"), ("Part 3", 33.33, "item"), ("Total", 100, "total")]},
]

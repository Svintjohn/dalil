# Research brief: official sources per country

Dalil explains contracts, job offers, fine notices and official letters to migrant workers, tenants and
families, in their own language. To do that safely it needs rules and links that come from **official
sources**, not from memory. Your job is to build registry files from official pages.

Read `rules/SCHEMA.md` first. It defines the YAML format. Check your file with:
`cd /home/claude/dalil && python3 scripts/validate_rules.py rules/countries/XX.yaml`

## Hard rules

1. **Nothing from memory.** Every fact, authority and phone number must come from an official page you
   opened with WebFetch during this task. If you cannot confirm it, leave it out. An empty topic is
   better than a wrong fact. Never invent a URL: only use URLs you opened or that WebSearch returned and
   you then opened.
2. **Official means** a government, ministry, regulator, court or statutory body domain. No law-firm
   blogs, news sites, expat guides, banks, Wikipedia. List every official domain you used in
   `official_domains`. The validator rejects any URL outside those domains.
3. **WebFetch returns a short summary written by a small model, not the raw page**, so it can paraphrase
   or err. Ask it for the exact sentence. Use `confidence: quoted` and fill `quote` only when the answer
   gives an exact sentence clearly taken from the page (25 words or fewer, copied exactly). Otherwise set
   `quote: ""` and `confidence: summary`. Never write a quote you are not sure is verbatim: a later script
   checks every quote against the live page and flags mismatches.
4. **What to cover** (only what you can confirm): rules an ordinary person needs when reading
   - a rental contract (`tenancy`): deposit, notice for rent increase or ending the tenancy, contract
     registration, who handles disputes
   - a job offer or work contract (`employment`): written contract, probation, working hours and overtime,
     wage payment, passport or document retention, recruitment fees charged to workers, notice and
     end-of-service pay, who handles complaints
   - a fine or penalty notice (`fines`): how real fines are issued and paid (official channels)
   - a consumer contract (`consumer`): cancellation or cooling-off rights, complaint office
   - `scams`: the official channel to report fraud and official warnings about fake payment links
   - `immigration`: only document-related rules (visa and permit documents, who may hold them)
   - `privacy`: the data-protection law or regulator, in one or two facts
   One plain English sentence per fact, no article or section numbers. Say "usually" or "normally" only if
   the source does. If rules differ by state, province or emirate, say which one the fact covers.
5. **Federal countries** (US, Canada, Australia and similar): record national-level facts, and put
   pointers to the state or province tenant and labour resources in `notes`. Do not try to cover every state.
6. **Authorities**: add the offices people could contact (`name`, `url`, `covers`). Add a phone number only
   if an official page you opened shows it, and set `phone_source` to that page.
7. **Dates**: `last_verified` and every `verified_on` are `2026-10-10`.
8. **Size**: 6 to 12 facts per country (more if the country is marked deep). Cover the topics reasonably
   and stop. If key pages cannot be read, write what you verified and say so in `notes`.
9. Pages in the local language are fine (`language: ar`, `ja` and so on). Write the `statement` in English.
10. The shell cannot reach government websites. Use WebSearch and WebFetch only. Write each file with the
    Write tool to `rules/countries/XX.yaml` (XX = ISO code), run the validator, fix errors.

## Final reply

Short, under 200 words. Per country: file written or not, number of facts per topic, gaps, pages that
could not be read. Do not paste the YAML.

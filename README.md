# Dalil (دليل)

**Understand before you act.**

Dalil explains confusing documents in plain language. Take a photo of a letter, bill, school notice, medical paper,
contract or fine, and Dalil tells you what it says, in your own language, what to watch out for, and what to do next.

*Dalil* means "guide" in Arabic. It was built for the Dubai Chamber Digital AI Agents Championship (GovTech / Civic Tech).

> Dalil is a guide, not a lawyer, doctor or accountant. It does not give legal, medical or financial advice.

## The problem

Many people are handed documents they cannot fully read: a new language, legal wording, small print. Misunderstandings
cost money, jobs and time. Dalil is meant to close that gap for migrant workers, expats, parents and anyone else who
has been handed something confusing.

## What it does

- **Reads photos or pasted text.** Up to 6 pages per document.
- **Explains it in your language.** 71 languages, shown next to the original wording, line by line.
- **Flags the risky parts.** Unusual or one-sided terms, deadlines, and messages that look like scams.
- **Shows its sources.** Rules come from a registry of official pages, each with a link and the date it was last checked.
- **Tells you the next step.** The right office to contact and a checklist you can tick off.
- **Keeps cases.** A document can be saved to a case, and later papers and your own notes are added to it, so each matter has one timeline. Only a short summary is kept, on your own device.
- **Tracks deadlines.** Dates and time limits found in the document can be saved on your own device, sorted by urgency, ticked off, and exported to your calendar with reminders. Nothing is stored on a server.
- **Helps you act.** Listen to the explanation read aloud, copy it, ask follow-up questions (typed or spoken), or draft a reply letter.

## How it works

1. You add a photo or paste text and pick a language.
2. **Photo check.** Blurry, dark, cut-off or tiny photos are sent back with a clear "retake" message.
3. **Privacy first.** ID, card, IBAN, phone and email numbers are hidden before anything goes to the AI. Photos lose their location data. Nothing is saved and request bodies are never logged.
4. **The agent reads it.** The AI model looks up rules in the registry using tools. It can only cite rules, links and offices that exist in the registry, and unsourced "high risk" claims are downgraded.
5. **You get the result.** A plain explanation, key details, findings, hard words explained, and what to do first.

Messages that look like scams are labelled "looks suspicious, check on the official app". Dalil never states that something is fraud as a fact.

## Tech

| Part | What |
|---|---|
| Backend | Python, FastAPI |
| AI | Google Gemini (free tier) or Anthropic Claude, with optional free backups (Groq, Mistral, OpenRouter) |
| App | Flutter web |
| Hosting | Vercel (Python function plus the built site) |
| Rules | YAML files per country in `rules/countries/` |

## Project layout

| Path | Contents |
|---|---|
| `backend/dalil/` | API, agent loop, tools, photo checks, personal-data masking, languages |
| `api/index.py` | Entry point used by Vercel |
| `rules/` | Country rules, the schema (`SCHEMA.md`) and the research brief |
| `app/` | The Flutter web app |
| `scripts/` | Rule validation, link checking, AI connection test, Vercel build |

## Run it locally

You need Python 3.11 or newer and Flutter.

**1. Backend**

```bash
pip install -r requirements.txt pytest
python scripts/validate_rules.py
pytest -q backend/tests
```

Set your own API key in the terminal. Never put it in a file or commit it.

```bash
# macOS / Linux
export GEMINI_API_KEY=your-key

# Windows PowerShell
$env:GEMINI_API_KEY="your-key"
```

A free Gemini key is available at https://aistudio.google.com. To use Anthropic instead, set `ANTHROPIC_API_KEY`.

```bash
python -m uvicorn dalil.app:app --app-dir backend --reload
```

To check that the AI connection works, run `python scripts/check_ai.py`.

**2. App**, in a second terminal:

```bash
cd app
flutter pub get
flutter run -d chrome --dart-define=API_BASE=http://localhost:8000
```

Without a key, the three built-in sample documents return saved results, so the demo still works. Saved results are
labelled as such in the app.

## Settings

| Variable | Purpose |
|---|---|
| `GEMINI_API_KEY` | Use Google Gemini |
| `ANTHROPIC_API_KEY` | Use Anthropic Claude |
| `DALIL_PROVIDER` | Force `gemini` or `anthropic` |
| `GROQ_API_KEY`, `MISTRAL_API_KEY`, `OPENROUTER_API_KEY` | Optional free backup services, used when the main one is busy |
| `GROQ_MODEL`, `MISTRAL_MODEL`, `OPENROUTER_MODEL` | Override a backup service's model (it must accept images and tools) |
| `DALIL_FALLBACKS` | Order of backups, e.g. `groq,mistral` (default: all that have a key) |
| `DALIL_MODEL`, `DALIL_FAST_MODEL` | Override the model names |
| `DALIL_APP_TOKEN` | Optional shared token so only your own app can call the API |
| `DALIL_USE_SAVED=1` | Always return the saved sample results |
| `DALIL_AI_MAX_CONCURRENT` | How many AI jobs may run at once (default 3) |
| `DALIL_AI_PER_IP_INFLIGHT` | How many AI jobs one visitor may run at once (default 2) |
| `DALIL_AI_PER_IP_PER_MIN` | AI requests per visitor per minute (default 8) |
| `DALIL_AI_GLOBAL_PER_MIN` | AI requests per minute for everyone together (default 12) |

## Deploy to Vercel

1. Build the site once: `cd app && flutter build web --release`. Commit `app/build/web`.
2. Push the repo to GitHub and import it in Vercel.
3. Set **Application Preset** to **Other**. The rest comes from `vercel.json`.
4. Add `GEMINI_API_KEY` (or `ANTHROPIC_API_KEY`) under Environment Variables.
5. Deploy. Visit `/api/health` on your site to check the backend.

Vercel limits a request to about 4.5 MB, so the app shrinks photos before upload.

Gemini's free tier has rate limits, and Google may use free-tier prompts to improve its products. Use only made-up
sample documents while testing with it.

## Protecting the free AI quota

The free Gemini tier allows only a few calls per minute, and one review makes several calls. So Dalil protects it:

- **Limits on AI requests.** At most a few jobs run at once, and each visitor and the whole site have a per-minute budget. When a limit is hit, the API answers `429` with a friendly message and a `Retry-After` time instead of failing halfway.
- **Backup AI services.** If Gemini is busy, Dalil tries Groq, Mistral or OpenRouter (whichever have a key) and skips the busy one for a minute.
- **Samples still work.** If the site is busy and the visitor is using a built-in sample, the saved result is returned.
- **Cooldown in the app.** The buttons pause for a few seconds after each request, so a double click cannot send two.
- **Timeouts and retries.** Calls to the AI time out before Vercel's limit, and short overloads are retried once or twice with another model as a fallback.
- **Cached lightweight data.** The language and country lists are cached for five minutes. Documents and results are never cached, because Dalil does not store them.
- **Basic checks.** Upload size limits, a per-IP limit on every endpoint, and an optional app token.

These counters live in memory on each server instance, so on Vercel they slow down abuse but do not stop a determined attacker.
For real protection, add a spending limit on the AI account and turn on Vercel's firewall or bot protection.

## Loading screen

`app/web/index.html` shows a 3-second animated loading screen (the Dalil intro). It waits for the app's first frame, so
if the app is slow it stays until the app is ready (with a 20-second safety limit), and it stops all its animation when it
closes. With "reduce motion" turned on in the system it shows for about 1 second.

## Install as an app (PWA)

The site can be installed on a phone or computer. In Chrome or Edge use the install icon in the address bar. On an iPhone
use Share, then Add to Home Screen. Reading a document still needs an internet connection, because the AI runs on the server.

## Cases and deadlines

A case keeps a short summary of each document (what it is, key details, next steps, how many things to watch) and the notes you add. Photos and full text are never saved. Everything lives in the browser's local storage, so clearing browser data removes it.

### Deadlines

Dalil only lists a deadline when the document states it. A full calendar date is checked by the server before it is shown. A period such as "within 14 days" asks you for the day you received the paper, because Dalil cannot know it. Saved deadlines live in the browser's local storage, so clearing browser data removes them. The calendar file (.ics) adds all-day events with reminders at 9:00 three days before and the day before.

## Share

The "Share" button opens WhatsApp with a short version of the result (the start of the full text, about 1,500
characters) so you can send it to someone you trust. You choose who gets it. Nothing is sent to Dalil's server.

## What changed?

When you add a new reading to an existing case, Dalil compares the key facts (amounts, dates, names) with the latest
document already in that case and shows what is new, what changed and what is no longer shown. It happens on your
device, with no extra AI call and nothing sent anywhere. Facts are matched by their label, ignoring capitals, spacing and
thousands commas, and Dalil never guesses what a change means.

## Scam shield

Dalil checks every document for warning signs of a scam and shows a calm card at the top when it finds them: **Be careful** (one clear sign) or **Stop, do not pay or reply yet** (several signs together).

- Rule checks (`backend/dalil/scam.py`) look for a request for a code, PIN or password, payment by gift card or crypto, a remote-control app, a personal account, links that are not official or secure, very short deadlines, threats, prizes and secrecy. Protective text such as "never share your OTP" is not flagged.
- The model's own view is combined with the rules. The model alone cannot raise the level to "stop", and one weak sign alone shows nothing.
- Dalil never says a document is a scam and never says it is safe. It only says what warning signs it sees and tells the person to check with the real office, typing the address themselves.
- When the level is "stop", deadlines are not offered for tracking, so a scam's payment date never lands in the person's calendar.

## If you do nothing

For each thing the person must do or pay, Dalil shows what happens if they do not, in a short card under "What to do".

- A consequence is shown only when the document states it (for example a late charge) or a verified official fact from the rules registry states it. It is marked "The document says" or "Official rule" with the source link.
- A rule claim without a verified source is dropped. Dalil never guesses a consequence or predicts a court result.
- When a document has a deadline but states no consequence, Dalil says so and tells the person to ask the office that sent it.
- For a likely scam the section is hidden, because doing nothing is the safe choice.

## Before you go

When the person will probably have to visit, call or write to an office, school, bank or landlord, Dalil adds a "Before you go" card: who to meet, what to bring and what to ask.

- Bring items the document itself asks for are marked "The document asks for this". Everything else is marked "Suggested". Dalil does not name a law, form or fee that the document or the rules registry did not give.
- Questions are short and practical (the exact amount, the last day, how to pay, what proof is accepted).
- The person can tick items off as they pack. The card is included in Copy.
- It is hidden for a likely scam.

## Voice

- Tap the microphone and speak a follow-up question in the chosen language. When the microphone stops (or the person taps stop), the question is sent by itself and the answer is read aloud.
- A typed question gets a silent answer. Every answer has its own **Listen** button, and **Listen** at the top reads the whole result.
- Voices come from the browser. If the browser has no voice for a language, Dalil says so instead of reading in the wrong one.

## Number check

When a bill, invoice, fee notice, payment schedule or contract shows several amounts and a total, Dalil adds a "Number check" card.

- The model only reads the figures off the paper. The adding up is done in code (`backend/dalil/numbers.py`), so it is exact.
- It checks the items against a stated subtotal, the tax against a stated tax rate, and the items, tax and discount against the total. A gap of more than 5 cents is reported with both figures and the difference. Instalment schedules (for example four cheques against a yearly rent) are checked the same way.
- If any line cannot be read or placed, Dalil does not guess and shows no check.
- Every line the model read is shown, so the person can compare it with the paper (a mismatch can also be a reading mistake).
- Dalil checks the arithmetic only, not whether prices are fair. For a message with scam warning signs, "the numbers add up" is never shown.

## Save as PDF

The page opens in a new tab laid out for A4 (numbered steps, a checklist with boxes, page numbers) and starts the print
dialog. Choose "Save as PDF". If the browser still prints a web address in the corner, untick "Headers and footers" in the
dialog. The "Print / Save as PDF" button on that page prints again.

## Your saved data

- "Save as PDF" opens a clean print page in a new tab and starts the browser print dialog.
- In the Privacy window, "Delete all my saved data" removes every saved case and deadline from the browser after a confirmation. Documents themselves are never saved.

## Accuracy check

`backend/evaluation/` holds made-up, labeled documents: scam-like messages, ordinary documents that use scary words
("urgent", "OTP", "gift card"), and bills with right and wrong totals.

```powershell
cd backend
python -m evaluation.run              # offline: rules and arithmetic, no keys needed
$env:GEMINI_API_KEY = "<your key>"    # type it in your own terminal, never in chat or a file
python -m evaluation.run --live       # also asks the real model to read every case (slow on the free tier)
```

It writes only case ids and results, never document text. `tests/test_eval.py` runs the offline part with the tests.

Honest caveat: the cases were written by the developers, and the rules were tuned on them (set "b-" was written after
set A and also used for tuning). The numbers are a regression check, not proof of real-world accuracy. Dalil only
ever says "warning signs", never "this is a scam" or "this is safe".

## Rules registry

Countries covered so far: AE, GB, SG, MY, SA, AU, US, QA, KW, BH, OM, PH, IN, PK, CA, JP, KR and BD.
BD is thin, with only 3 facts.

- Only official domains are used, and only verbatim text is quoted.
- Every fact has a link and the date it was checked.
- `python scripts/validate_rules.py` checks the files against the schema.
- `python scripts/check_sources.py` re-opens every link. It also runs weekly on GitHub.

To add a country, follow `rules/RESEARCH_BRIEF.md` and `rules/SCHEMA.md`.

## Privacy

Documents are processed in memory and are not stored. Personal numbers are masked before analysis. The text is sent
to the AI service you configure (Gemini, Anthropic, or a backup such as Groq, Mistral or OpenRouter) for analysis only. Dalil was designed with the UAE Personal Data
Protection Law (Federal Decree-Law No. 45 of 2021) in mind. Get legal review before a real launch.

## Limitations

- The AI can misread a document. Always confirm with the official office linked in the result.
- UAE facts come from official pages but have not yet been re-checked by a person. There are no Abu Dhabi rent or fine rules yet.
- Language quality outside the main languages has not been reviewed by native speakers.
- Spoken questions use the browser's speech recognition, which works in Chrome, Edge and Safari.
- WhatsApp is planned but not built.

## Money due

When a document asks for a payment, the report shows **Amount due** (amount, currency, pay-by date). It is never shown for a scam warning or an unrecognized document. If the amounts on the paper do not add up, the card carries a "check this figure" warning.

The **Money due** card above the cases adds up what is still unpaid, **per currency** (different currencies are never added together). Only the latest amount in each open case counts, so a reminder does not double a bill. Tick **Paid** to remove an item from the total; closed cases are ignored. Everything stays in the browser, like the rest of My cases.

## Friendly "busy" messages

When the AI is busy or rate-limited, people see a calm message ("Many people are using Dalil right now, please try again in about a minute") instead of a technical error. The backend answers `503` with `code: model_busy` and `retry_after: 60`, in the reader's language (`BUSY_MESSAGES` in `backend/dalil/app.py`; unknown languages fall back to English). The app shows it as an amber notice, not a red error.

The translations are machine-written: have a native speaker review them before launch.

## Design

Warm paper background, deep green ink, saffron highlighter. Headlines are set in Fraunces, body text in DM Sans, quoted documents in Source Serif, the wordmark in Reem Kufi. Cards use a thin ink border with a flat offset shadow instead of soft blurry shadows. The header is a floating bar; on narrow screens its links fold into a menu. Under the hero a slow strip shows every reply language. Sections are tighter than before, and cards rise on hover. All colors live in `app/lib/theme.dart` (`Palette`), all fonts in `app/lib/fonts.dart`.

Endless background motion (the language strip) is switched off in tests with `Motion.ambient = false`, and for people who ask their device to reduce motion it does not move.

## Sound studio

A floating **Sound** button (and the header menu) opens the studio. Sound is **off until the person turns it on**, so a quiet office or a late-night bill never gets a surprise click.

- **Sounds:** 15 click sounds in five groups (Linear, Tactile, Clicky, Silent, Special), including an oud pluck. Each one is built from tiny oscillator and noise layers.
- **Matrix:** every sound is a dot on a map (pitch left to right, weight top to bottom). Tap a dot to pick it, or drag the puck to mix your own.
- **Ambient:** rain, brown noise, white noise, wind, café, night hum. They can be mixed and keep playing while you read.
- **Tuning:** pitch, decay, brightness, room, humanize, stereo spread, volume, and switches for click sounds, typing sounds (only inside text boxes) and result sounds (a chime when a result is ready, a low tone for a scam warning).
- **Spectrum:** live bars that follow what is playing.

Everything is made in the browser with the Web Audio API (`app/web/dalil_sfx.js`). There are no audio files, no music API, no account and no network call, so it costs nothing, works offline and sends nothing anywhere. Settings are saved in the browser only. The Flutter side is `sfx.dart` (settings), `sound_studio.dart` (screens) and `sfx_engine*.dart` (the bridge; it does nothing in tests).

To add a sound, add its layers to `P` in `dalil_sfx.js` and an entry to `sfxPresets` in `sfx.dart`. A test checks that the two lists match.

## Speed

What keeps the page quick, and what was left out on purpose.

- **Photos are shrunk by the browser.** `app/web/dalil_img.js` resizes and re-encodes a photo in a few hundred milliseconds (a 12 MP photo of 10 MB becomes about 0.8 MB). The Dart image code was the slowest thing on the page; it is now only a fallback and is a separate download (`photo.dart` is a deferred import), so most people never load it.
- **Code splitting.** The sound studio (`sound_studio.dart`) and the Dart image code are deferred libraries: they download only when first used.
- **Scripts.** `dalil_sfx.js` and `dalil_img.js` load with `defer`. Fonts connect early (`preconnect`).
- **Saved page setup.** `/api/meta` (languages, samples, tips) is kept in the browser and refreshed in the background, so a returning visit shows the page without waiting for the server. The server builds that answer once (`lru_cache`) and sends it with `Cache-Control`.
- **Compression.** The API gzips answers over 800 bytes (`GZipMiddleware`); the static site is compressed by Vercel.
- **CDN.** Vercel serves the site from its edge network and Flutter loads CanvasKit from Google's CDN. `vercel.json` adds long cache headers for the icons.
- **Fewer repaints.** The header is a solid bar (a live blur over scrolling content is slow), the hero, the language strip, the spectrum and the lower sections sit in `RepaintBoundary`, and typing in the paste box rebuilds the page only when the "Explain this" button changes state.
- **Loading skeleton.** A placeholder shaped like the home page shows while the first answer is on its way.

Left out on purpose:

- **Caching review results.** It would mean keeping text from people's documents on the server, which breaks the promise that nothing is saved. Only public data (languages, samples) is cached.
- **A load balancer.** Vercel already runs the API as functions that scale by themselves, and a separate balancer would add cost and a point of failure.
- **Lazily built page sections.** The "How it works" and "Languages" links scroll to sections by key, and a section that is not built yet cannot be scrolled to. The sections are cheap now that they are repaint boundaries.
- **Pagination.** The language picker is already a lazy list, and My cases stays short.
- **Minifying.** `flutter build web --release` already minifies and tree-shakes the app; the two small scripts are left readable (Vercel compresses them).
- **Unused packages.** Every dependency in `pubspec.yaml` and `requirements.txt` is used.

## Seasonal decorations

A few quiet decorations on holidays, drawn faintly over the page. They never take a tap, sit under the header and any dialog, use a handful of shapes, stop when the device asks for less motion, and can be switched off in the footer ("Christmas decorations: on/off"). The setting is remembered on the device.

| Season | When | What |
|---|---|---|
| Halloween | 24 Oct to 1 Nov | three small bats crossing the top, a few rising embers |
| Christmas | 1 to 26 Dec | sparse falling snow |
| New Year | 30 Dec to 2 Jan | slow fireworks in the upper part of the page |
| UAE National Day | 2 and 3 Dec, only when the device clock is on Gulf time | slow confetti in red, green and black |
| Ramadan | the Islamic month 9 | a crescent and a few twinkling stars |
| Eid | 1 to 3 Shawwal and 10 to 13 Dhu al-Hijjah | the crescent and soft gold bursts |

The date comes from the device clock. No location is requested. The Islamic date comes from the browser (`web/dalil_date.js`), so Ramadan and Eid can be a day off from the moon sighting. To preview one, add `?season=christmas` (or `halloween`, `newyear`, `uae`, `ramadan`, `eid`, `off`) to the address. Code: `season.dart` (dates and the setting), `season_layer.dart` (the drawing).

## Clear saved data

The footer has "Clear saved data on this device", the same confirmation as in Privacy. It removes the cases, the deadlines, the sound settings, the decoration setting and the saved page data. Documents were never saved, so there is nothing else to remove.

## Card tilt

Cards lean a few degrees toward the mouse (`tilt.dart`). Touch screens have no hover, so nothing happens there, and nothing moves when the device asks for less motion.

## Make it yours

Everything here is kept in the browser on this device (`dalil.profile.v1`) and is removed by "Clear saved data".

- **Name and greeting.** The page asks "What should we call you?" once, in the hero, with "Not now" to skip for good. After that it greets by name in the chosen language and time of day ("Magandang gabi, John"). Greetings exist for English, Tagalog, Arabic, Hindi, Urdu, Bangla, Nepali, French, Spanish and German; other languages use English. A native speaker should check them.
- **Colour.** Teal (default), terracotta, indigo or rose, in light and dark. Every accent is tested for contrast (at least 4.5 to 1) against buttons, tints, cards and the page.
- **Easy-read font.** One switch changes the whole app to Lexend, with no tight letter spacing. It is an option, not a medical claim.
- **Where.** Header icon (palette) or the phone menu, "Make it yours".

## Due this week

The header shows "2 due this week" when open deadlines or unpaid amounts fall within 7 days, or are already late (red). A bill that has both a deadline and an amount in the same case counts once. Tapping it scrolls to the deadlines. No notification is ever sent; it only shows when the app is open.

## My mixes (sound)

In Sound studio, "Save this sound" stores the preset, the puck position and all six tuning sliders under a name (up to 6, 16 characters each). Tap a chip to bring it back, the x to delete it. "Reset defaults" keeps them; "Clear saved data" removes them.

## Share as a picture

On a result, "Picture" makes a 1080 by 1350 card: document type, the plain-language summary, the first three steps, a count of things to watch out for, and "Explained by Dalil". It is drawn in the browser and never uploaded. On a phone it opens the share sheet; if the browser cannot share files it downloads the PNG instead.

What keeps it private:
- The person's name, the quoted text of the document and the numbers of the document are never on it.
- Emails, phone numbers and long reference or account numbers are always covered with dots.
- "Hide amounts" (on by default) also covers money amounts. Dates, times, percentages and small counts such as "30 days" stay.
- This is a pattern check, not a promise. The card is shown first so the person can look before sending.

## Support link

The footer has a small coffee button that opens https://ko-fi.com/dalilapp in a new tab. It is a plain link: no widget, no script and no tracking from Ko-fi on the page.

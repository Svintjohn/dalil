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

## Install as an app (PWA)

The site can be installed on a phone or computer. In Chrome or Edge use the install icon in the address bar. On an iPhone
use Share, then Add to Home Screen. Reading a document still needs an internet connection, because the AI runs on the server.

## Cases and deadlines

A case keeps a short summary of each document (what it is, key details, next steps, how many things to watch) and the notes you add. Photos and full text are never saved. Everything lives in the browser's local storage, so clearing browser data removes it.

### Deadlines

Dalil only lists a deadline when the document states it. A full calendar date is checked by the server before it is shown. A period such as "within 14 days" asks you for the day you received the paper, because Dalil cannot know it. Saved deadlines live in the browser's local storage, so clearing browser data removes them. The calendar file (.ics) adds all-day events with reminders at 9:00 three days before and the day before.

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

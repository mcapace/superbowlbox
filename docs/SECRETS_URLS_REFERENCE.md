# Secrets.plist URLs reference (from previous builds / docs)

**Secrets.plist is gitignored**, so your real API keys and Lambda URLs are never in the repo. If you're on a new machine or lost your plist, use this to restore the **scan** and **payout** endpoints.

---

## All Lambda URLs (from this repo)

These are the **only concrete API Gateway / Lambda URLs** that appear in the repo. Use the set that matches your AWS API.

### API ID: `0lgqfeaqxh` (from **AI_GRID_LAMBDA_REPLACE.md** – main reference)

| Secrets.plist key        | Full URL |
|--------------------------|----------|
| **AIGridBackendURL**     | `https://0lgqfeaqxh.execute-api.us-east-1.amazonaws.com/ai-grid` |
| **TextractBackendURL**   | `https://0lgqfeaqxh.execute-api.us-east-1.amazonaws.com/ocr` |
| **PayoutParseBackendURL** | `https://0lgqfeaqxh.execute-api.us-east-1.amazonaws.com/parse-payout` |

**Base (for reference):** `https://0lgqfeaqxh.execute-api.us-east-1.amazonaws.com`

### API ID: `kcmpxvlwa8` (from **PAYOUT_ANTHROPIC_LAMBDA.md** – alternate example)

| Use | Full URL |
|-----|----------|
| Payout parse (if you use this API) | `https://kcmpxvlwa8.execute-api.us-east-1.amazonaws.com/parse-payout` |
| Same API with `/ai-grid` | `https://kcmpxvlwa8.execute-api.us-east-1.amazonaws.com/ai-grid` |

**Base:** `https://kcmpxvlwa8.execute-api.us-east-1.amazonaws.com`

**Secrets.example.plist** in the app is set to the **0lgqfeaqxh** URLs above. If your deployed API uses **kcmpxvlwa8**, replace the host in Secrets.plist with that base.

---

## Quick copy (0lgqfeaqxh – one API for all three)

```
AIGridBackendURL     = https://0lgqfeaqxh.execute-api.us-east-1.amazonaws.com/ai-grid
TextractBackendURL   = https://0lgqfeaqxh.execute-api.us-east-1.amazonaws.com/ocr
PayoutParseBackendURL = https://0lgqfeaqxh.execute-api.us-east-1.amazonaws.com/parse-payout
```

---

## URLs that appear in this repo (summary)

These base URLs are referenced in the setup docs. If this is your API Gateway, use them in **Secrets.plist**. If you use a different API ID, replace the host with your Invoke URL.

| Secrets.plist key        | Full URL (example from docs) |
|--------------------------|------------------------------|
| **AIGridBackendURL**     | `https://0lgqfeaqxh.execute-api.us-east-1.amazonaws.com/ai-grid` |
| **TextractBackendURL**   | `https://0lgqfeaqxh.execute-api.us-east-1.amazonaws.com/ocr` (same API, `/ocr` route) |
| **PayoutParseBackendURL** | `https://0lgqfeaqxh.execute-api.us-east-1.amazonaws.com/parse-payout` (same API, `/parse-payout` route) |

- **AI grid (scan):** When **AIGridBackendURL** is set to a valid URL, the app sends the pool sheet image to that endpoint and uses the AI response. When it’s missing or a placeholder, the app uses **on-device Vision** (no server).
- **OCR (scan fallback):** When **TextractBackendURL** is set, the app can use that for OCR instead of on-device Vision. Same API can expose both `/ai-grid` and `/ocr`.
- **Payout parse:** **PayoutParseBackendURL** is used when the user saves or parses payout rules; the app POSTs the rules text to that URL.

## What happened to “previous build” URLs?

- The **repo** only has **Secrets.example.plist** with placeholders (`your-api.example.com`, `your-api-id...`). The app was updated to treat those as “not set” so scanning works on-device when no backend is configured.
- Your **real** Secrets.plist (with real Lambda URLs) was only on the machine where you set it; it is not in version control. To get scan/payout back:
  1. Copy **Secrets.example.plist** to **Secrets.plist** (if needed).
  2. Set **AIGridBackendURL** (and optionally **TextractBackendURL**, **PayoutParseBackendURL**) to the URLs above, or to your own API Gateway Invoke URL + path (e.g. `https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/ai-grid`).

## Where the Lambda code lives (in this repo)

- **AI grid (scan):** `docs/lambda-ai-grid-index.js`
- **Payout parse:** `docs/lambda-payout-parse-index.js`
- **OCR (Textract):** see **docs/TEXTRACT_BACKEND_SETUP.md** and the Lambda code it references.

Deploy those to your API Gateway / Lambda and point Secrets.plist at your Invoke URL + path.

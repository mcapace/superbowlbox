# Lambdas overview – make sure all are working

The app uses **AI** for grid/name matching, rules, and payout logic when configured. **AI overrides OCR**: when `AIGridBackendURL` is set, the scan uses only the AI grid Lambda; OCR (Textract) and on-device Vision are not used. Payout rules are parsed by the **payout-parse** Lambda (also AI).

Use this to verify and redeploy: **AI grid (scan)**, **payout parse**, and optionally **OCR (Textract)** only if you do not use the AI grid.

---

## 1. AI grid (scan pool sheet)

| Item | Value |
|------|--------|
| **App key** | `AIGridBackendURL` in Secrets.plist |
| **Lambda code** | **`docs/lambda-ai-grid-index.js`** |
| **Route** | `POST /ai-grid` |
| **Env** | `ANTHROPIC_API_KEY` (required), `MODEL` (optional, default `claude-sonnet-4-20250514`) |
| **Request** | `POST application/json` body: `{ "image": "<base64 JPEG>" }` (recommended). Legacy: raw image bytes with `Content-Type: image/jpeg`. |
| **Response** | `200` + JSON: `homeTeamAbbreviation`, `awayTeamAbbreviation`, `homeNumbers`, `awayNumbers`, `names` (10×10). |

**Check:** When this URL is set, **all** pool-sheet scanning uses AI only (grid, names, structure). OCR is not used. If you get missing/incomplete data, redeploy this Lambda (use the latest `lambda-ai-grid-index.js`, which accepts JSON body so the image is not corrupted by API Gateway).

---

## 2. Payout parse (parse rules text)

| Item | Value |
|------|--------|
| **App key** | `PayoutParseBackendURL` in Secrets.plist |
| **Lambda code** | **`docs/lambda-payout-parse-index.js`** |
| **Route** | `POST /parse-payout` (or `/payout-parse`) |
| **Env** | `ANTHROPIC_API_KEY` (required), `MODEL` (optional, default `claude-sonnet-4-20250514`) |
| **Request** | `POST application/json` body: `{ "payoutDescription": "<user's rules text>" }` |
| **Response** | `200` + JSON: `poolType`, `quarterNumbers`, `payoutStyle`, `amountsPerPeriod`, `readableRules`, `amountPerChange`, `maxScoreChanges`, etc. (see PayoutParseService.Response in the app). |

**Check:** When this URL is set, “Parse with AI” / Save payout rules sends the text here; the app uses the returned structure for grid header and payouts.

---

## 3. OCR (Textract) – optional, not used when AI is configured

| Item | Value |
|------|--------|
| **App key** | `TextractBackendURL` in Secrets.plist |
| **Lambda code** | Inline in **`docs/TEXTRACT_BACKEND_SETUP.md`** (no separate .js file in repo). Copy the code block into your Lambda. |
| **Route** | `POST /ocr` |
| **Env** | Uses Lambda **IAM role** (no API key in env). Role must allow `textract:DetectDocumentText`. |
| **Request** | `POST` body: raw JPEG bytes, `Content-Type: image/jpeg`. |
| **Response** | `200` + JSON: `{ "blocks": [ ... ] }` (normalized 0–1, bottom-left origin). |

**Check:** **AI overrides OCR.** When `AIGridBackendURL` is set, the app uses only the AI grid Lambda for scan; it does not call Textract or on-device Vision. Use OCR only if you explicitly do not use the AI grid (e.g. leave `AIGridBackendURL` unset). For grid/names/rules/payout we use AI.

---

## Deploy checklist (all Lambdas working as built)

- [ ] **AI grid**
  - AWS Lambda: create or open the function (e.g. `superbowlbox-ai-grid`).
  - Paste/copy the full contents of **`docs/lambda-ai-grid-index.js`** into the Lambda code. Deploy.
  - Env: `ANTHROPIC_API_KEY` set. Optional: `MODEL` if you use a different model.
  - API Gateway: route **POST /ai-grid** → this Lambda.
  - App: **Secrets.plist** → `AIGridBackendURL` = Invoke URL + `/ai-grid` (e.g. `https://0lgqfeaqxh.execute-api.us-east-1.amazonaws.com/ai-grid`).

- [ ] **Payout parse**
  - AWS Lambda: create or open the function (e.g. `superbowlbox-payout-parse`).
  - Paste/copy the full contents of **`docs/lambda-payout-parse-index.js`** into the Lambda code. Deploy.
  - Env: `ANTHROPIC_API_KEY` set. Optional: `MODEL`.
  - API Gateway: route **POST /parse-payout** → this Lambda (can be same API as ai-grid).
  - App: **Secrets.plist** → `PayoutParseBackendURL` = Invoke URL + `/parse-payout`.

- [ ] **OCR (if you use it)**
  - Follow **`docs/TEXTRACT_BACKEND_SETUP.md`**: create Lambda, paste the code from that doc, attach to **POST /ocr**, set IAM role for Textract.
  - App: **Secrets.plist** → `TextractBackendURL` = Invoke URL + `/ocr`.

**URLs from this repo:** See **`docs/SECRETS_URLS_REFERENCE.md`** for the example base URL (e.g. `0lgqfeaqxh.execute-api...`) and paths. Use your own API Gateway Invoke URL if different.

After deploying, run the app: scan a sheet (AI grid), save payout rules (payout parse). If something fails, check CloudWatch logs for the corresponding Lambda.

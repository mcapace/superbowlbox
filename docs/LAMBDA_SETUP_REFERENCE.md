# Lambda setup – rules, info, and how they are set up

This doc consolidates everything about the Square Up Lambdas: runtime, env vars, routes, request/response contracts, and step-by-step setup. Use **Node.js 22.x** for all new/updated Lambdas (Node 20.x EOL in Lambda April 2026).

---

## Runtime and checklist

| Item | Value |
|------|--------|
| **Runtime** | **Node.js 22.x** (Lambda → Configuration → General configuration → Edit → Runtime). |
| **List functions still on 20.x** | `aws lambda list-functions --region us-east-1 --output text --query "Functions[?Runtime=='nodejs20.x'].FunctionArn"` |
| **App behavior** | When **AIGridBackendURL** is set, **all** pool-sheet scanning uses the AI grid Lambda only; OCR and on-device Vision are not used. |

---

## 1. AI Grid (scan pool sheet)

**Purpose:** Reads a pool sheet image and returns teams, row/column numbers, and 10×10 names. Uses Anthropic (Claude) to parse the image.

| Item | Value |
|------|--------|
| **App key (Secrets.plist)** | `AIGridBackendURL` |
| **Lambda code file** | **`docs/lambda-ai-grid-index.js`** (copy full file into Lambda) |
| **API Gateway route** | `POST /ai-grid` |
| **Env vars** | `ANTHROPIC_API_KEY` (required). Optional: `MODEL` (default `claude-sonnet-4-20250514`). |
| **Timeout** | 30 seconds recommended |

**Request**

- **Recommended:** `POST` with `Content-Type: application/json` and body:
  ```json
  { "image": "<base64 JPEG string>" }
  ```
- Legacy: raw image bytes with `Content-Type: image/jpeg` (API Gateway can corrupt binary; JSON base64 is preferred).

**Response (200)**

- JSON:
  - `homeTeamAbbreviation` (column team)
  - `awayTeamAbbreviation` (row team)
  - `homeNumbers` (array of 10 digits, column headers)
  - `awayNumbers` (array of 10 digits, row labels)
  - `names` (10×10 array of strings; empty string for empty cells)

**Deploy steps**

1. Lambda → Create function (or open existing). Name e.g. `superbowlbox-ai-grid`.
2. Runtime: **Node.js 22.x**.
3. Code: Replace handler with full contents of **`docs/lambda-ai-grid-index.js`**.
4. Configuration → Environment variables: add `ANTHROPIC_API_KEY`. Optional: `MODEL`.
5. Configuration → General configuration: Timeout **30** seconds.
6. Add trigger: **API Gateway** → Create HTTP API (or use existing) → route **POST /ai-grid** → this Lambda.
7. **Secrets.plist:** `AIGridBackendURL` = Invoke URL + `/ai-grid`, e.g.  
   `https://0lgqfeaqxh.execute-api.us-east-1.amazonaws.com/ai-grid`.

---

## 2. Payout Parse (parse rules text)

**Purpose:** Parses free-text payout rules (e.g. “$25 per quarter, halftime double”) into structured JSON the app uses for grid header, current winner, and payouts.

| Item | Value |
|------|--------|
| **App key (Secrets.plist)** | `PayoutParseBackendURL` |
| **Lambda code file** | **`docs/lambda-payout-parse-index.js`** (copy full file into Lambda) |
| **API Gateway route** | `POST /parse-payout` or `POST /payout-parse` |
| **Env vars** | `ANTHROPIC_API_KEY` (required). Optional: `MODEL`. |
| **Timeout** | 10–30 seconds |

**Request**

- `POST` with `Content-Type: application/json` and body:
  ```json
  { "payoutDescription": "<user's rules text>" }
  ```

**Response (200)**

- JSON used by `PayoutParseService` in the app, including:
  - `poolType` (e.g. `byQuarter`, `perScoreChange`, `firstScoreChange`, `halftimeOnly`, `finalOnly`)
  - `quarterNumbers`, `payoutStyle`, `amountsPerPeriod`, `amountPerChange`, `maxScoreChanges`
  - `totalPoolAmount`, `currencyCode`, `readableRules`, etc.

**Deploy steps**

1. Lambda → Create function (or open existing). Name e.g. `superbowlbox-payout-parse`.
2. Runtime: **Node.js 22.x**.
3. Code: Replace handler with full contents of **`docs/lambda-payout-parse-index.js`**.
4. Configuration → Environment variables: `ANTHROPIC_API_KEY`. Optional: `MODEL`.
5. Configuration → General configuration: Timeout **10** (or 30) seconds.
6. Add trigger: **API Gateway**. Either:
   - **Same API as ai-grid:** add route **POST /parse-payout** → this Lambda.  
     Then **PayoutParseBackendURL** = same base URL + `/parse-payout`.
   - **New API:** create HTTP API, add route (e.g. **POST /superbowlbox-payout-parse**).  
     Then **PayoutParseBackendURL** = Invoke URL + that path (e.g.  
     `https://zko1kpmg0l.execute-api.us-east-1.amazonaws.com/default/superbowlbox-payout-parse`).
7. **Secrets.plist:** `PayoutParseBackendURL` = full invoke URL for this Lambda.

---

## 3. OCR (Textract) – optional

**Purpose:** Fallback OCR when AI grid is **not** configured. When **AIGridBackendURL** is set, the app never calls this Lambda.

| Item | Value |
|------|--------|
| **App key (Secrets.plist)** | `TextractBackendURL` |
| **Lambda code** | Inline in **`docs/TEXTRACT_BACKEND_SETUP.md`** (no separate .js in repo; copy the code block from that doc) |
| **API Gateway route** | `POST /ocr` |
| **Env vars** | None required if using Lambda **IAM role**. Role must allow `textract:DetectDocumentText`. Optional: `AWS_REGION` (e.g. `us-east-1`). |
| **Timeout** | 30 seconds |

**Request**

- `POST` body: raw JPEG bytes, `Content-Type: image/jpeg` (or base64; see TEXTRACT_BACKEND_SETUP.md).

**Response (200)**

- JSON: `{ "blocks": [ { "text", "x", "y", "width", "height", "confidence" }, ... ] }` (normalized 0–1, bottom-left origin).

**Deploy steps**

1. Follow **`docs/TEXTRACT_BACKEND_SETUP.md`**: create Lambda (Node.js 22.x), paste the handler code from that doc.
2. IAM: Attach **AmazonTextractFullAccess** (or custom policy with `textract:DetectDocumentText`) to the Lambda execution role.
3. API Gateway: **POST /ocr** → this Lambda.
4. **Secrets.plist:** `TextractBackendURL` = Invoke URL + `/ocr`.  
   Only used when **AIGridBackendURL** is not set.

---

## Secrets.plist keys (summary)

| Key | Purpose | Example URL (your IDs may differ) |
|-----|---------|-----------------------------------|
| **AIGridBackendURL** | AI scan (pool sheet → grid + names) | `https://0lgqfeaqxh.execute-api.us-east-1.amazonaws.com/ai-grid` |
| **PayoutParseBackendURL** | Parse payout rules text | `https://zko1kpmg0l.execute-api.us-east-1.amazonaws.com/default/superbowlbox-payout-parse` |
| **TextractBackendURL** | OCR fallback (only if AI grid not used) | `https://0lgqfeaqxh.execute-api.us-east-1.amazonaws.com/ocr` |

See **`docs/SECRETS_URLS_REFERENCE.md`** for the exact URLs that appear in this repo (API IDs `0lgqfeaqxh`, `zko1kpmg0l`, etc.). Use your own API Gateway Invoke URL if different.

---

## API Gateway (one API vs several)

- You can use **one** HTTP API and attach all routes to it:
  - **POST /ai-grid** → AI grid Lambda  
  - **POST /parse-payout** → Payout parse Lambda  
  - **POST /ocr** → Textract Lambda (optional)  
  Then base URL is the same; only the path differs (e.g. `https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/ai-grid`).
- Or use **separate** APIs per Lambda; then each has its own Invoke URL. Set the full URL (including path) in Secrets.plist for each key.

---

## Where the code lives in this repo

| Lambda | File / location |
|--------|------------------|
| AI grid | **`docs/lambda-ai-grid-index.js`** |
| Payout parse | **`docs/lambda-payout-parse-index.js`** |
| OCR (Textract) | **`docs/TEXTRACT_BACKEND_SETUP.md`** (code block in doc) |

---

## Other docs (cross-reference)

- **LAMBDAS_OVERVIEW.md** – High-level overview, AI vs OCR, deploy checklist.
- **AWS_LAMBDA_STEP_BY_STEP.md** – Console walkthrough for creating the payout-parse Lambda (same pattern for others).
- **SECRETS_URLS_REFERENCE.md** – Concrete URLs and Secrets.plist keys.
- **TEXTRACT_BACKEND_SETUP.md** – Full Textract Lambda + IAM + API Gateway.
- **AI_GRID_BACKEND_SETUP.md** / **PAYOUT_ANTHROPIC_LAMBDA.md** – Extra setup notes for AI grid and payout parse.

After deploying, run the app: scan a sheet (AI grid), save/parse payout rules (payout parse). If something fails, check **CloudWatch** logs for the corresponding Lambda.

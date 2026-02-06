# Payout Parse Backend (AI) Setup

The app can send free-text payout rules to a backend that uses Claude (or similar) to **parse** them into structured data (which periods pay, amounts per period). That structure drives **current leader**, **period winners**, **in the hunt**, and **current winnings** in the app.

## App configuration

- In **Secrets.plist** add **PayoutParseBackendURL** with your backend URL (e.g. `https://your-api.example.com/parse-payout`).
- When set, a **"Parse with AI"** button appears next to the payout rules field (e.g. on scan review). The user enters text like "$25 per quarter, halftime pays double", taps the button, and the app updates the pool’s structure from the API response.

## Backend API contract

- **Method:** POST  
- **Content-Type:** application/json  
- **Body:** `{ "payoutDescription": "<free-text payout rules>" }`

**Response:** JSON (UTF-8) with this shape (all fields optional; app uses defaults for missing values):

```json
{
  "poolType": "byQuarter",
  "quarterNumbers": [1, 2, 3, 4],
  "customPeriodLabels": null,
  "payoutStyle": "fixedAmount",
  "amountsPerPeriod": [25, 25, 50, 25],
  "percentagesPerPeriod": null,
  "totalPoolAmount": 125,
  "currencyCode": "USD"
}
```

**poolType** (string): one of  
`byQuarter` | `halftimeOnly` | `finalOnly` | `halftimeAndFinal` | `firstScoreChange` | `custom`

- **byQuarter:** use **quarterNumbers** (array of 1–4), e.g. [1,2,3,4].
- **custom:** use **customPeriodLabels** (array of strings), e.g. ["Q1", "Q2", "Halftime", "Final"].

**payoutStyle** (string): one of  
`equalSplit` | `fixedAmount` | `percentage`

- **fixedAmount:** use **amountsPerPeriod** (array of numbers, dollars per period in order).
- **percentage:** use **percentagesPerPeriod** (array of 0–100, one per period).
- **equalSplit:** split evenly; **totalPoolAmount** optional.

**totalPoolAmount** (number, optional): total pool size in dollars.  
**currencyCode** (string, optional): e.g. "USD".

Return **200** with this JSON. On error return 4xx/5xx.

## Example: Claude prompt for parsing

Your backend can call Anthropic with a system/user message and no image. Example prompt:

```
You parse football pool payout rules into structured JSON.

Input: free-text description of how the pool pays (e.g. "$25 per quarter, halftime pays double", "Q1 Q2 Q3 Q4 $25 each, final $100").

Output ONLY valid JSON (no markdown) with this exact structure. Use null for omitted optional fields.
{
  "poolType": "byQuarter" | "halftimeOnly" | "finalOnly" | "halftimeAndFinal" | "firstScoreChange" | "custom",
  "quarterNumbers": [1,2,3,4],
  "customPeriodLabels": ["Label1", "Label2"],
  "payoutStyle": "equalSplit" | "fixedAmount" | "percentage",
  "amountsPerPeriod": [25, 25, 50, 100],
  "percentagesPerPeriod": [25, 25, 25, 25],
  "totalPoolAmount": 200,
  "currencyCode": "USD"
}

Rules:
- byQuarter = pay at end of Q1, Q2, Q3, Q4; use quarterNumbers [1,2,3,4].
- halftimeOnly = one payout at halftime. finalOnly = one payout at game end. halftimeAndFinal = two payouts. firstScoreChange = first score wins.
- custom = use customPeriodLabels for any other set of periods.
- fixedAmount = list dollar amount per period in order. percentage = list 0-100 per period. equalSplit = split evenly.
- Infer totalPoolAmount if the text implies a total (e.g. $100 pool).
```

Parse Claude’s reply (strip markdown if needed), validate, and return the JSON to the app.

## Security

- Keep your API key only on the backend. Use HTTPS for PayoutParseBackendURL.

## Optional: env override

For local testing you can set **PAYOUT_PARSE_BACKEND_URL** in the run environment; it overrides Secrets if present.

# Verify payout parse (Lambda + app)

## App side (Xcode)

1. **Secrets.plist**
   - File: `SuperBowlBox/Resources/Secrets.plist` (your real plist, not the example).
   - Must contain key **`PayoutParseBackendURL`** (exact spelling).
   - Value: your Lambda invoke URL, e.g. `https://xxxx.execute-api.us-east-1.amazonaws.com/default/superbowlbox-payout-parse`
   - No trailing slash. Must be a valid URL so `URL(string:)` does not return nil.

2. **How the app uses it**
   - `PayoutParseConfig.backendURL` reads from Secrets.plist key `PayoutParseBackendURL`, or from env `PAYOUT_PARSE_BACKEND_URL`.
   - `PayoutParseConfig.usePayoutParse` is true only when `backendURL != nil`.
   - When saving payout rules or tapping "Parse with AI", the app POSTs to this URL only if `usePayoutParse` is true.

## AWS Lambda

1. **Environment variables**
   - **ANTHROPIC_API_KEY** must be set (same value as your grid Lambda is fine).

2. **Configuration**
   - **Timeout:** 10 seconds (recommended).

3. **API Gateway**
   - Lambda must be triggered by an HTTP API (POST).
   - The URL you put in Secrets.plist must be the full invoke URL (including stage/path if any).

## Quick test in the app

1. Build and run.
2. Open any pool → ⋯ menu → **Edit payout rules**.
3. Enter e.g. **$25 per quarter, halftime pays double**.
4. Tap **Save**.

- If the URL is set and the Lambda is correct: no error, sheet dismisses, grid header and "View payout rules" reflect the parsed structure.
- If you see "Payout parse error" or similar: check Secrets.plist value, Lambda env, and timeout.

## Code reference

- URL is read in: `SuperBowlBox/Services/PayoutParseConfig.swift` (key `PayoutParseBackendURL`).
- Used when saving rules: `SuperBowlBox/Views/GridView.swift` (`saveRulesAndDismiss`), `SuperBowlBox/Views/ScannerView.swift` (Confirm & Save, Parse with AI).
- Request: POST body `{ "payoutDescription": "<user text>" }`. Response: JSON with poolType, amountsPerPeriod or amountPerChange/maxScoreChanges, readableRules, etc.

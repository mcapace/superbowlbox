# Payout rules: do I need to do anything in Lambda / AWS?

You only need to touch Lambda/AWS if you want **the AI** to parse rules and talk to the app. Here’s what matters.

## What you want

- AI understands the rules (basic or complex).
- AI communicates with the app (structured JSON).
- Pools update (grid header, current winner, winnings) based on those rules.

## 1. App side: AI powers logic when backend is set

When **PayoutParseBackendURL** is set:

- **Save / Confirm** always calls the Lambda. The app uses **only the API response** for pool structure (no local inference). Grid header, current winner, modal, and payouts all come from what the AI returned.
- The **“View payout rules”** modal shows the stored structure and `readableRules` from the Lambda.
- If the API fails, the app saves the rules text but keeps the previous structure (or equal split) and shows an error so the user can retry.

So: **when the backend is configured, the AI powers the logic**; grid, rules, modals, and payouts are updated from the Lambda response only.

## 2. When you *don’t* need Lambda/AWS

If **Secrets.plist** does **not** have `PayoutParseBackendURL`:

- The app still parses rules **locally** (e.g. “$25 per quarter”, “first score wins $100”, “$400 per score change” with simple patterns).
- Grid header and winner logic still follow the parsed structure.
- You **do not** need to do anything in Lambda or AWS for that to work.

Limitations without Lambda:

- No AI-written **readable summary** in “View payout rules” (you get a formatted summary from the structure only).
- Complex wording might not be parsed as well as with the AI.

## 3. When you *do* need Lambda/AWS (AI understands + communicates)

If you want **the AI** to understand the rules and send structured data to the app (including readable summaries and complex cases like “per score change, cap 25, remainder to final”):

### One-time setup (if you haven’t already)

1. **AWS Lambda**
   - Create a function (e.g. `superbowlbox-payout-parse`), Node.js 20.x.
   - Paste the code from **`docs/lambda-payout-parse-index.js`** (this repo).
   - Environment variable: **ANTHROPIC_API_KEY** (same key as your grid Lambda is fine).
   - Timeout: **10 seconds**.

2. **API Gateway**
   - Add an HTTP API trigger to the Lambda.
   - Route: **POST** (e.g. `/default` or `/parse-payout`).
   - Copy the **Invoke URL** (e.g. `https://xxxx.execute-api.us-east-1.amazonaws.com/default/...`).

3. **App**
   - In **Secrets.plist** add:
     - **Key:** `PayoutParseBackendURL`
     - **Value:** the full URL (e.g. `https://xxxx.execute-api.us-east-1.amazonaws.com/default/superbowlbox-payout-parse`).

After that, the app will POST the user’s rules text to that URL; the Lambda calls the AI and returns JSON; the app updates the pool from that response.

### If the Lambda already exists

- **Update the Lambda code** so it uses the latest **`docs/lambda-payout-parse-index.js`** (prompt with “not all pools same rules”, `perScoreChange`, `readableRules`, etc.).
- No need to change API Gateway or env vars unless you’re moving the URL.
- Ensure **Secrets.plist** still has **PayoutParseBackendURL** pointing at that Lambda’s URL.

## 4. Quick verification

- **Without Lambda:** Edit a pool’s payout rules, enter e.g. “$25 per quarter, halftime double”, Save. Grid header and “View payout rules” should reflect that (from local parsing).
- **With Lambda:** Same flow; “View payout rules” should also show an AI-written **readableRules** summary. For “$400 per score change, stop at 25, remainder to final”, header should show “Score change” and logic should match.

## Summary

| Goal | Need Lambda/AWS? |
|------|-------------------|
| Pools update from rules (header, winner, winnings) | **No** – app does it with or without Lambda (local or API). |
| AI understands and communicates rules to the app | **Yes** – set up (or update) the payout-parse Lambda and set **PayoutParseBackendURL** in Secrets.plist. |

So: you only need to do something in Lambda/AWS if you want the **AI** in the loop. The app and pools are already set up to use whatever structure is parsed (by the AI or by local inference).

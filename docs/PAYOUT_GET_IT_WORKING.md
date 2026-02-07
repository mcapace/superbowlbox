# Get payout rules (AI) working — checklist

Do these in order. Once done, the app will use the Lambda to parse rules and update the grid, modal, and payouts.

---

## 1. Deploy the Lambda code (AWS)

1. Open **AWS Console** → **Lambda** → your payout-parse function (e.g. `superbowlbox-payout-parse`).
2. In **Code** → open `index.mjs` (or the main handler file).
3. Replace its contents with the full contents of **`docs/lambda-payout-parse-index.js`** from this repo (copy/paste).
4. Click **Deploy**.

---

## 2. Lambda configuration (AWS)

In the same Lambda:

- **Configuration** → **Environment variables**  
  - Ensure **ANTHROPIC_API_KEY** is set (same value as your grid Lambda is fine).
- **Configuration** → **General configuration**  
  - **Timeout:** 10 seconds.

Save if you changed anything.

---

## 3. Get the invoke URL (AWS)

- In the Lambda, open **Add trigger** / the existing **API Gateway** trigger.
- Copy the **Invoke URL**. It might look like:
  - `https://xxxx.execute-api.us-east-1.amazonaws.com/default/superbowlbox-payout-parse`  
  or
  - `https://xxxx.execute-api.us-east-1.amazonaws.com` (if you use a path like `/parse-payout`, the full URL is Invoke URL + path).

You need the **full URL** the app will POST to (e.g. `https://xxxx.execute-api.us-east-1.amazonaws.com/default/superbowlbox-payout-parse`).

---

## 4. Point the app at the Lambda (Xcode)

1. In the app project, open **Secrets.plist** (not the example — the real one you use for runs).
2. Set:
   - **Key:** `PayoutParseBackendURL`
   - **Value:** the full invoke URL from step 3 (no trailing slash).

If the key is missing, add it. The app only calls the AI when this value is set.

---

## 5. Build and run the app

1. Build and run from Xcode (Simulator or device).
2. Open a pool (or create one).
3. Open **Edit payout rules** (⋯ menu → “Edit payout rules”).
4. Enter rules, e.g. **$25 per quarter, halftime pays double**.
5. Tap **Save**.

You should see no error, and the grid header should change from “Quarters” (or default) to reflect the parsed structure, and “View payout rules” should show the AI summary. If you get an error, check step 1–4 (code deployed, env var, timeout, URL in Secrets.plist).

---

## Quick reference

| Step | Where | What |
|------|--------|------|
| 1 | AWS Lambda | Paste `docs/lambda-payout-parse-index.js` → Deploy |
| 2 | Lambda → Configuration | ANTHROPIC_API_KEY, Timeout 10 s |
| 3 | Lambda → API Gateway trigger | Copy full Invoke URL |
| 4 | Xcode → Secrets.plist | `PayoutParseBackendURL` = that URL |
| 5 | Xcode | Build & run, edit payout rules, Save |

That’s it. The app uses only the Lambda for parsing when `PayoutParseBackendURL` is set; grid, rules, modals, and payouts update from the AI response.

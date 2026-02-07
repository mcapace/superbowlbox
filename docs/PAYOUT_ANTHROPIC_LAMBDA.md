# Payout Parse: Anthropic Lambda (same as grid)

You can use **the same Anthropic API** (and same pattern as the grid-analyze Lambda) to parse payout rules. The app then uses that structure for **who's winning**, **period winners**, and **what you've earned**.

## 1. Reuse your grid Lambda setup

- Same **ANTHROPIC_API_KEY** (you already have it for the grid Lambda).
- Create a **second Lambda** for payout parse, or add a second route on the same API Gateway.

## 2. Create the payout-parse Lambda

1. **AWS Console** → **Lambda** → **Create function**.
2. **Name:** e.g. `superbowlbox-payout-parse`
3. **Runtime:** Node.js 20.x
4. **Create function.**

In the function:

- **Code:** Replace the default handler with the contents of **`docs/lambda-payout-parse-index.js`** in this repo.
- **Configuration** → **Environment variables:** add **ANTHROPIC_API_KEY** (same value as your grid Lambda).
- **Configuration** → **General configuration:** set **Timeout** to 10 seconds.

## 3. Expose an HTTP endpoint

**Option A – New API Gateway (simplest)**  
1. **Add trigger** → **API Gateway** → Create HTTP API.  
2. Create a route **POST /parse-payout** (or **POST /payout-parse**) that invokes this Lambda.  
3. Copy the **Invoke URL** (e.g. `https://abc123.execute-api.us-east-1.amazonaws.com`).

**Option B – Same API as grid**  
If your grid is at `https://kcmpxvlwa8.execute-api.us-east-1.amazonaws.com` with a route like **POST /ai-grid**, add a **second resource**: e.g. **POST /parse-payout** that invokes this new Lambda.

Your payout URL will be: **Invoke URL** + **/parse-payout**  
Example: `https://kcmpxvlwa8.execute-api.us-east-1.amazonaws.com/parse-payout`

## 4. Point the app at it

In **Secrets.plist** add:

- **Key:** `PayoutParseBackendURL`
- **Value:** your payout-parse URL (e.g. `https://your-api-id.execute-api.us-east-1.amazonaws.com/parse-payout`)

No code changes in the app: it already POSTs `{ "payoutDescription": "<user's text>" }` and expects the JSON contract described in **PAYOUT_PARSE_BACKEND.md**.

## 5. How it ties together

1. User enters payout rules (e.g. "$25 per quarter, halftime pays double") in the app.
2. On **Save** (or **Parse with AI**), the app sends that text to **PayoutParseBackendURL**.
3. This Lambda calls **Anthropic** with the same style of prompt as the grid (text-only here).
4. Claude returns structured JSON (poolType, amountsPerPeriod, etc.).
5. The Lambda returns that JSON to the app.
6. The app stores it in the pool’s **PoolStructure** and uses it for:
   - **Current leader**
   - **Period winners**
   - **Finalized winnings / what I’ve earned so far**

So payout understanding is hooked to the same Anthropic setup as the grid; only the Lambda code and route differ.

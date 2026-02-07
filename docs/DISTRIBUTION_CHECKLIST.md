# Distribution checklist – APIs, Lambdas, AI, Supabase

Use this **before you Archive** (TestFlight, App Store, or ad‑hoc) so the live app has working APIs, scan/payout Lambdas, AI integration, and Supabase.

---

## 1. Secrets.plist is what ships

- The app reads **all** API keys and backend URLs from **`SuperBowlBox/Resources/Secrets.plist`**.
- That file is in **Copy Bundle Resources**, so **whatever Secrets.plist exists in your project when you build/Archive is embedded in the app** and used in production.
- **Secrets.plist is gitignored** – it never goes in the repo. The **machine that runs Product → Archive** must have the real `Secrets.plist` with production values.

**Before every distribution build:**

1. Open **SuperBowlBox/Resources/Secrets.plist** in Xcode.
2. Confirm every key you care about has a **production** value (no `YOUR_*`, no `your-api.example.com`, no `localhost`).

---

## 2. Keys and what they do

| Key | Purpose | Required for |
|-----|--------|---------------|
| **SportsDataIOApiKey** | Live NFL scores (primary) | Live scores from Sports Data IO; if missing, app uses ESPN |
| **LoginDatabaseURL** | Supabase REST base (logins + optional shared pools) | Recording sign‑ins; share/join codes if you use Supabase for pools |
| **LoginDatabaseApiKey** | Supabase anon key | Required if LoginDatabaseURL is set (auth for Supabase) |
| **AIGridBackendURL** | Lambda that reads pool sheet image (AI/Claude) | **Scan** – when set, app sends image here instead of on‑device Vision |
| **TextractBackendURL** | Lambda that runs OCR (e.g. Textract) | Optional scan path; if unset, app uses on‑device Vision or AIGrid |
| **PayoutParseBackendURL** | Lambda that parses payout rules text (AI) | **Parse with AI** for payout rules; when set, app uses only this for grid + payouts |
| **SharedPoolsURL** | Optional separate backend for share/join | Only if you don’t use LoginDatabaseURL for shared pools |
| **SharedPoolsApiKey** | Optional API key for SharedPoolsURL | If your share backend requires a key |

- **Placeholder URLs** (host contains `example.com` or `your-api`) are **ignored** by the app – they are treated as “not set.” So scan works on‑device if you leave placeholders; for **live** scan/payout you must set **real** Invoke URLs.
- **URL reference:** See **docs/SECRETS_URLS_REFERENCE.md** for the Lambda base URL used in this repo (e.g. `https://0lgqfeaqxh.execute-api.us-east-1.amazonaws.com/...`). Use that or your own API Gateway Invoke URL.

---

## 3. Backend and Lambda checklist

### Lambdas (scan + payout)

- [ ] **AI grid (scan)**  
  - Lambda code: **`docs/lambda-ai-grid-index.js`**  
  - Deploy to API Gateway; add route **POST /ai-grid**.  
  - Set **AIGridBackendURL** in Secrets.plist = Invoke URL + `/ai-grid` (e.g. `https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/ai-grid`).

- [ ] **Payout parse (AI)**  
  - Lambda code: **`docs/lambda-payout-parse-index.js`**  
  - Deploy to same or another API; add route **POST /parse-payout**.  
  - Set **PayoutParseBackendURL** = Invoke URL + `/parse-payout`.  
  - Ensure Lambda has **Anthropic API key** in env and sufficient timeout.

- [ ] **OCR (optional)**  
  - If you use Textract backend: deploy per **docs/TEXTRACT_BACKEND_SETUP.md**; set **TextractBackendURL** = Invoke URL + `/ocr`.

All URLs must be **HTTPS** and **reachable from the internet** (no `localhost`). The app does not use different URLs for Debug vs Release – it uses whatever is in the bundled Secrets.plist.

### Supabase

- [ ] **Project** is the one you want for **production** (not a dev-only project if you care about data).
- [ ] **LoginDatabaseURL** = `https://YOUR_PROJECT_REF.supabase.co/rest/v1` (replace with your project ref).
- [ ] **LoginDatabaseApiKey** = your Supabase **anon** key (same as in dashboard).
- [ ] **Tables** (e.g. `logins`, `shared_pools`) and **RLS** are in place – see **docs/SUPABASE_AND_SHARED_POOLS.md** and **docs/LOGIN_DATABASE.md**.

### Sports Data IO

- [ ] **SportsDataIOApiKey** in Secrets.plist = your API key from [sportsdata.io](https://sportsdata.io).  
- If you leave it empty, the app still works and uses **ESPN** for live scores.

---

## 4. Sign‑in (Apple + Google)

- [ ] **Sign in with Apple:** Team set in Xcode; “Sign in with Apple” capability added; App ID has it enabled for production.
- [ ] **Sign in with Google:** **GIDClientID** and URL scheme in Info.plist (and GoogleSignIn package). These are in the repo; ensure they’re your **production** client ID if you use a different one for prod.

No secrets for sign‑in are in Secrets.plist; they’re in Info.plist / capabilities and are included in the app when you Archive.

---

## 5. Quick pre‑Archive check

1. **Secrets.plist** exists at `SuperBowlBox/Resources/Secrets.plist` (copy from Secrets.example.plist if needed).
2. **No placeholders** in Secrets.plist for features you want live:  
   - Scan → **AIGridBackendURL** (or **TextractBackendURL**) = real Lambda URL.  
   - Payout AI → **PayoutParseBackendURL** = real Lambda URL.  
   - Share/join → **LoginDatabaseURL** + **LoginDatabaseApiKey** (or **SharedPoolsURL**) = real Supabase/backend URL.
3. **SportsDataIOApiKey** set if you want Sports Data IO live scores (otherwise ESPN is used).
4. **Product → Archive** – the built app will use this same Secrets.plist.

---

## 6. Where to get help in the repo

| Topic | Doc |
|-------|-----|
| Lambda URLs from previous builds | **docs/SECRETS_URLS_REFERENCE.md** |
| AI grid Lambda setup | **docs/AI_GRID_BACKEND_SETUP.md**, **docs/AI_GRID_LAMBDA_REPLACE.md** |
| Payout parse Lambda | **docs/PAYOUT_GET_IT_WORKING.md**, **docs/PAYOUT_ANTHROPIC_LAMBDA.md**, **docs/AWS_LAMBDA_STEP_BY_STEP.md** |
| Textract/OCR backend | **docs/TEXTRACT_BACKEND_SETUP.md** |
| Supabase + shared pools | **docs/SUPABASE_AND_SHARED_POOLS.md**, **docs/LOGIN_DATABASE.md** |
| Sports Data IO | **docs/SPORTSDATAIO_SETUP.md** |
| General setup | **SETUP.md** |

When everything above is done, APIs, Lambdas, AI integration, and Supabase will work in the distributed app.

# Full Secrets Setup – One plist for local, TestFlight, and live

Use **one** `Secrets.plist` for every environment: local (simulator/device), production builds, TestFlight, and App Store. There are no placeholders in production; fill in real values for every feature you want.

---

## 1. Where the file lives

- **Path:** `SuperBowlBox/Resources/Secrets.plist`
- **Template:** Copy from `Secrets.example.plist` if needed. The app reads this at runtime; whatever is in the project when you build (or Archive) is embedded in the app.
- **Git:** `Secrets.plist` is gitignored. Only `Secrets.example.plist` is in the repo.

---

## 2. All keys (no placeholders in production)

| Key | Purpose | What to put | If empty / unset |
|-----|--------|-------------|-------------------|
| **AIGridBackendURL** | Scan pool sheet with AI (Claude) | Your Lambda Invoke URL + `/ai-grid` | App uses on-device OCR (less accurate) |
| **PayoutParseBackendURL** | Parse payout rules with AI | Your Lambda Invoke URL (e.g. `/default/superbowlbox-payout-parse`) | Payout rules not parsed by AI |
| **TextractBackendURL** | Optional OCR backend | Lambda URL + `/ocr` | Only used when AIGridBackendURL is not set |
| **SportsDataIOApiKey** | Live NFL scores (primary) | API key from [sportsdata.io](https://sportsdata.io) | App uses ESPN for scores |
| **LoginDatabaseURL** | Sign-in + optional shared pools | `https://YOUR_PROJECT_REF.supabase.co/rest/v1` (your Supabase project) | No login recording; no share/join via Supabase |
| **LoginDatabaseApiKey** | Supabase auth | Supabase **anon** key from project dashboard; app sends as `Apikey` + `Authorization: Bearer` so recordLogin (Apple/Google/Email) succeeds | Required if LoginDatabaseURL is set |
| **SharedPoolsURL** | Optional separate share/join backend | Full base URL of your share API | Falls back to LoginDatabaseURL (one Supabase for logins + pools) |
| **SharedPoolsApiKey** | Optional API key for SharedPoolsURL | Your share backend key | Falls back to LoginDatabaseApiKey |
| **AWSRegion** | For Textract (if used) | e.g. `us-east-1` | Only needed if using Textract backend |
| **AWSAccessKeyId** | For Textract (if used) | AWS access key | Only if using Textract backend |
| **AWSSecretAccessKey** | For Textract (if used) | AWS secret key | Only if using Textract backend |

---

## 3. Current URLs (from this repo)

These are already set in `Secrets.example.plist` and in the project’s `Secrets.plist` where created:

```
AIGridBackendURL     = https://0lgqfeaqxh.execute-api.us-east-1.amazonaws.com/ai-grid
TextractBackendURL   = https://0lgqfeaqxh.execute-api.us-east-1.amazonaws.com/ocr
PayoutParseBackendURL = https://zko1kpmg0l.execute-api.us-east-1.amazonaws.com/default/superbowlbox-payout-parse
```

Fill in the rest for full functionality.

---

## 4. What to set for “everything works”

- **Scan (AI):** `AIGridBackendURL` = your ai-grid Lambda URL ✅ (already set above)
- **Payout parse (AI):** `PayoutParseBackendURL` = your payout-parse Lambda URL ✅ (already set above)
- **Live scores:** `SportsDataIOApiKey` = your [sportsdata.io](https://sportsdata.io) API key (or leave empty to use ESPN)
- **Sign-in + share/join:** `LoginDatabaseURL` = your Supabase REST URL, `LoginDatabaseApiKey` = Supabase anon key
- **Share/join only:** If you use the same Supabase for pools, leave `SharedPoolsURL` and `SharedPoolsApiKey` empty; the app uses `LoginDatabaseURL` / `LoginDatabaseApiKey` for share/join.

No placeholders: use real URLs and keys. The app **only** ignores values that exactly match doc/example strings: URL hosts `your-api.example.com` or containing `your-api-id`; Supabase URL containing `your_project_ref` or `your-project-ref`; API keys that **start with** `YOUR_`. Any other value (real project refs, real keys, staging URLs) is used. One plist works for local, TestFlight, and live.

---

## 5. One plist for all environments

- **Local (simulator):** Same Secrets.plist. Use production URLs, or for local backend use `http://localhost:PORT/...` (Info.plist allows localhost).
- **Local (device):** Same plist; for a server on your Mac use the Mac’s LAN IP or HTTPS.
- **TestFlight / App Store:** Before **Product → Archive**, ensure Secrets.plist has your **production** URLs and keys. That plist is embedded in the app; there is no separate “prod” plist.

The app does not switch config by build type (Debug/Release). One plist for local, TestFlight, and live.

---

## 6. Checklist before Archive (TestFlight / live)

- [ ] **AIGridBackendURL** – real Lambda URL (scan)
- [ ] **PayoutParseBackendURL** – real Lambda URL (payout rules)
- [ ] **SportsDataIOApiKey** – real key, or leave empty to use ESPN
- [ ] **LoginDatabaseURL** – real Supabase URL (e.g. `https://xxxx.supabase.co/rest/v1`)
- [ ] **LoginDatabaseApiKey** – real Supabase anon key (if LoginDatabaseURL is set)
- [ ] **SharedPoolsURL** / **SharedPoolsApiKey** – only if you use a separate share backend; otherwise leave empty

See **docs/LOCAL_AND_LIVE_APIS.md** for local vs live behavior and **docs/SECRETS_URLS_REFERENCE.md** for Lambda URL details.

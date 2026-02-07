# Local and live APIs – make everything work in both environments

The app uses **one** config source for APIs: **Secrets.plist** (and optional env vars). There is no separate “dev” vs “prod” plist in the project. To have APIs work in **local** (simulator, dev server) and **live** (TestFlight/App Store), use the following.

---

## 1. What “local” vs “live” means

- **Local:** You run the app in the simulator or on a device, and you want it to call:
  - A server on your Mac (e.g. `http://localhost:3000` or `http://127.0.0.1:3000`), or
  - Your real Lambda/API Gateway URLs (same as live), or
  - A staging backend (e.g. `https://staging-api.yourapp.com`).
- **Live:** The distributed app (TestFlight/App Store) calls your production APIs (Lambda, Supabase, Sports Data IO).

The app does **not** switch URLs by build type (Debug/Release). It uses whatever is in **Secrets.plist** (and env, if set) at runtime. So:

- **Same URLs for both:** Put your **live** URLs in Secrets.plist. Local and live both use them. No extra setup.
- **Different URL for local:** For local-only, you can point to localhost or a staging URL in Secrets.plist and use that when developing; for Archive/distribution, put the **live** URLs in Secrets.plist on the machine that runs **Product → Archive** (that plist is what ships).

---

## 2. Placeholder detection (why something might have stopped working)

The app **ignores** a URL or key only when it looks like the **exact doc/example placeholder**:

- **Lambda-style URLs:** Ignored only if the host is **exactly** `your-api.example.com` or contains **`your-api-id`** (the literal placeholder from the docs). So:
  - Real URLs like `https://0lgqfeaqxh.execute-api.us-east-1.amazonaws.com/ai-grid` are **used**.
  - Staging URLs like `https://staging.example.com/ai-grid` or `https://api.mycompany.example.com/...` are **used** (no longer treated as placeholders).
- **Supabase:** Ignored only if the URL contains `your_project_ref` or `your-project-ref`. Real project refs are used.
- **API keys:** Ignored only if the key **starts with** `YOUR_` (e.g. `YOUR_SPORTSDATA_IO_KEY`, `YOUR_SUPABASE_ANON_KEY`). Keys that contain `YOUR_` elsewhere are **used**.

So if you had a real staging or live URL that was wrongly ignored before, it should be used now.

---

## 3. Local: HTTP (localhost) and simulator

- **Simulator:** The app can call **http://localhost** and **http://127.0.0.1** because **Info.plist** has an **App Transport Security** exception for `localhost` and `127.0.0.1` (`NSExceptionAllowsInsecureHTTPLoads`).
- In **Secrets.plist** you can set, for example:
  - `AIGridBackendURL` = `http://localhost:3000/ai-grid`
  - `PayoutParseBackendURL` = `http://localhost:3000/parse-payout`
- Run your Node (or other) server on the same Mac and the simulator will reach it.

---

## 4. Local: device talking to your Mac

- On a **physical device**, “localhost” is the device itself, not your Mac. To hit a server on your Mac use the Mac’s **LAN IP** (e.g. `http://192.168.1.5:3000`).
- By default, iOS blocks plain HTTP to arbitrary IPs. Options:
  - Use **HTTPS** on your Mac (e.g. self-signed cert or ngrok), or
  - Add an ATS exception for your Mac’s IP in Info.plist (e.g. under `NSExceptionDomains` add an entry for that IP with `NSExceptionAllowsInsecureHTTPLoads` = true). Prefer HTTPS for anything beyond quick testing.

---

## 5. Live: what gets shipped

- When you **Archive**, the app bundle includes the **Secrets.plist** that is in the project on the machine that ran the archive.
- So for **live** to use the right APIs, that Secrets.plist must contain your **production** values (Lambda URLs, Supabase URL, Sports Data IO key, etc.) before you Archive. No separate “prod” plist is required; just ensure the plist you have when archiving is the one you want for production.

---

## 6. Checklist: APIs working in both environments

- [ ] **Secrets.plist** exists (copy from Secrets.example.plist if needed) and is **not** using the doc placeholders (e.g. `your-api.example.com`, `your-api-id`, `YOUR_PROJECT_REF`, `YOUR_...` keys).
- [ ] For **local (simulator):** Optional – set Lambda/backend URLs to `http://localhost:PORT/...` if you run a local server; or leave them as your live URLs so local and live use the same APIs.
- [ ] For **local (device):** Use HTTPS or add an ATS exception for your Mac’s IP if you use HTTP.
- [ ] For **live:** Before **Product → Archive**, put your **production** URLs and keys in Secrets.plist. That same file is embedded in the app and used at runtime.
- [ ] **Lambdas** are deployed and reachable (see **docs/LAMBDAS_OVERVIEW.md**). App sends JSON `{ "image": "<base64>" }` to the AI grid; payout parse sends `{ "payoutDescription": "..." }`.
- [ ] **Supabase / Sports Data IO:** Use real project URL and keys (not placeholders). Placeholders are only skipped when they exactly match the example text above.

If something “was working and now isn’t,” check: (1) placeholder logic (section 2), (2) that you’re using the intended Secrets.plist when building/running, and (3) that Lambdas and backends are deployed and returning the expected JSON.

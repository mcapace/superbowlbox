# Use Supabase for Share Codes (CLI)

SquareUp uses **Supabase** so you can generate invite codes and let others join a pool without scanning. This repo is set up to use the **Supabase CLI** only (no dashboard SQL). One project gives you **shared_pools** (invite codes) and **logins** (optional Apple, Google, and Email sign-in events).

---

## One-time: create the database (run from repo root)

If you already have a Supabase project and have set **LoginDatabaseURL** and **LoginDatabaseApiKey** in `SuperBowlBox/Resources/Secrets.plist`, run this to create the tables:

```bash
# Project ref = the ID in your URL (e.g. from https://abcdefgh.supabase.co/rest/v1 the ref is abcdefgh)
./scripts/supabase-setup.sh YOUR_PROJECT_REF
```

You’ll be prompted for your database password once (or set `SUPABASE_DB_PASSWORD` to avoid the prompt). The script runs `supabase link` then `supabase db push` to apply the migration (creates `shared_pools` and `logins` with RLS). No other code changes are required; the app already uses your URL and key from Secrets.plist.

---

## Prerequisites (if you haven’t set up Supabase yet)

- [Supabase CLI](https://supabase.com/docs/guides/cli/getting-started) installed (e.g. `brew install supabase/tap/supabase`).
- A Supabase account (for `supabase login`).

---

## 1. Log in and create a project (CLI)

```bash
cd /path/to/superbowlbox

# Log in (browser or token)
supabase login

# Create a new hosted project (set a DB password when prompted)
supabase projects create superbowlbox --db-password YOUR_DB_PASSWORD
```

If you prefer an **existing** project, skip `projects create` and use its **project ref** (from the dashboard URL: `https://supabase.com/dashboard/project/<project-ref>`).

---

## 2. Link and push migrations

```bash
# Link this repo to your hosted project (use the project ref from create or dashboard)
supabase link --project-ref YOUR_PROJECT_REF

# Apply migrations: creates shared_pools and logins with RLS
supabase db push
```

When prompted for the database password, use the one you set for the project.

This applies all migrations in `supabase/migrations/`:

- **20250204120000** — **shared_pools** (`code`, `pool_json`), RLS: anon INSERT + SELECT; **logins** (anon INSERT).
- **20250204130000** — **shared_pools**: anon DELETE (so the app can remove a shared pool when the owner deletes it).

---

## 3. Get API URL and anon key

**Option A – CLI**

```bash
supabase projects api-keys --project-ref YOUR_PROJECT_REF
```

Use the **anon public** key from the output.

**Option B – Dashboard**

Project Settings → API → **Project URL** and **anon public** key.

Your REST base URL is: `https://YOUR_PROJECT_REF.supabase.co/rest/v1`.

---

## 4. Configure the app

1. Ensure **SuperBowlBox/Resources/Secrets.plist** exists (copy from `Secrets.example.plist` if needed).
2. Set:
   - **LoginDatabaseURL** = `https://YOUR_PROJECT_REF.supabase.co/rest/v1`
   - **LoginDatabaseApiKey** = your **anon public** key

The app uses these for both shared pools and (if configured) logins. No extra keys needed for invite codes.

**If you get "Upload failed (HTTP 404)" when generating a code:** (1) Use the exact REST URL: `https://YOUR_PROJECT_REF.supabase.co/rest/v1` (with `/rest/v1`). (2) Run the migration so the `shared_pools` table exists (`supabase db push` or run the SQL in `supabase/migrations/` in the Supabase SQL Editor). (3) Confirm **LoginDatabaseApiKey** is your project’s **anon public** key.

---

## 5. Pre-flight: before sharing codes with testers

| Check | What to do |
|-------|------------|
| **Secrets.plist** | Has **LoginDatabaseURL** = `https://YOUR_PROJECT_REF.supabase.co/rest/v1` and **LoginDatabaseApiKey** = your anon key. (Shared pools use these if **SharedPoolsURL** is not set.) |
| **Migrations applied** | Run `supabase db push` from repo root so `shared_pools` (and optional `logins`) exist and RLS policies are in place. |
| **Generate a code** | In the app: Settings → Share My Pools → tap a pool. You should see "Generating code…" then an 8-character code. If you see "Configure SharedPoolsURL or LoginDatabaseURL" or "Upload failed", fix Secrets and/or run migrations. |
| **Join with code** | On another device (or simulator): Settings → Join Pool with Code → enter the 8-char code → Join Pool. You should get "Claim your boxes" and then the pool in your list. |

**Where to share:** Settings → Share My Pools → tap pool → Copy Code or Message/Email/More. Testers: Settings → Join Pool with Code (or Pools tab → Join with code).

---

## 6. Use it in the app

- **Generate a code:** Settings → Share My Pools → tap a pool. The app uploads to Supabase and shows an 8-character code. Copy or share via Message/Email/More.
- **Join with a code:** Settings → Join Pool with Code (or Pools → Join with code) → enter the 8-character code → Join Pool. The joiner then claims their name/boxes (no scan).

---

## Summary

| What you want        | Tables (from migration)   | Secrets.plist                          |
|----------------------|---------------------------|----------------------------------------|
| Share codes only     | `shared_pools`            | `LoginDatabaseURL` + `LoginDatabaseApiKey` |
| Share codes + logins | `shared_pools` + `logins` | Same                                   |

To use a **different** backend only for shared pools, set **SharedPoolsURL** (and optionally **SharedPoolsApiKey**) in Secrets.plist; the app will use that for share/join instead of the LoginDatabase URL.

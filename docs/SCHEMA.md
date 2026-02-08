# Square Up — Database schema

Canonical schema is defined in **`supabase/migrations/20250204120000_create_logins_and_shared_pools.sql`**. This doc summarizes the tables and how the app uses them.

---

## 1. `public.logins`

Stores sign-in events (Apple, Google, or Email) when **LoginDatabaseURL** and **LoginDatabaseApiKey** are set in Secrets.plist.

| Column             | Type         | Notes                    |
|--------------------|--------------|--------------------------|
| `id`               | `uuid`       | PK, default `gen_random_uuid()` |
| `provider`         | `text`       | NOT NULL — `"apple"`, `"google"`, or `"email"` |
| `provider_uid`     | `text`       | NOT NULL — opaque ID from provider |
| `email`            | `text`       | nullable                 |
| `display_name`     | `text`       | nullable                 |
| `client_timestamp` | `timestamptz`| nullable                 |
| `created_at`       | `timestamptz`| NOT NULL, default `now()` |

**RLS:** anon can `INSERT` only. App sends `Apikey` and `Authorization: Bearer <key>` when **LoginDatabaseApiKey** is set so Supabase accepts the request. App POSTs to `{LoginDatabaseURL}/logins` on sign-in (Apple, Google, or Email) and optionally to `/logins/signout` on sign-out.

See **docs/LOGIN_DATABASE.md** for payload and setup.

---

## 2. `public.shared_pools`

Stores invite codes for sharing pools. Used when **SharedPoolsURL** or **LoginDatabaseURL** (fallback) is set.

| Column      | Type         | Notes                    |
|-------------|--------------|--------------------------|
| `id`        | `uuid`       | PK, default `gen_random_uuid()` |
| `code`      | `text`       | NOT NULL — 8-char invite code, unique |
| `pool_json` | `jsonb`      | NOT NULL — full pool (BoxGrid) JSON |
| `created_at`| `timestamptz`| NOT NULL, default `now()` |

**Index:** `idx_shared_pools_code` UNIQUE on `(code)`.

**RLS:** anon can `INSERT` (upload pool → get code) and `SELECT` (fetch pool by code when joining). No UPDATE/DELETE for anon in migration; host delete can be implemented via service role or custom endpoint.

**App usage:**
- **Upload (generate code):** `POST /rest/v1/shared_pools` with body `{ "code": "...", "pool_json": { ... } }` → returns code.
- **Fetch (join):** `GET /rest/v1/shared_pools?code=eq.XXXXXXXX&select=pool_json` → returns `[{ "pool_json": { ... } }]`.
- **Delete (optional):** `DELETE /rest/v1/shared_pools?code=eq.XXXXXXXX` (requires policy or service role).

See **docs/SUPABASE_AND_SHARED_POOLS.md** for setup and **docs/APP_FLOW.md** for user flows (sections 5, 9a).

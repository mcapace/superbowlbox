# Supabase: Login Data & Shared Pool Codes

The app supports **storing user (login) data** and **generating invite codes** to share pools. Both use the same Supabase project when configured.

---

## 1. Login data (store user sign-ins)

To collect Apple/Google login events:

1. Create a Supabase project at [supabase.com](https://supabase.com).
2. **Table**: Table Editor → New table → name: `logins`.
   - Columns: `id` (uuid, primary key, default `gen_random_uuid()`), `provider` (text), `provider_uid` (text), `email` (text, nullable), `display_name` (text, nullable), `client_timestamp` (timestamptz, nullable), `created_at` (timestamptz, default `now()`).
   - Enable RLS; add a policy that allows **INSERT** for anon (or your role) so the app can POST sign-in events.
3. In **Secrets.plist** (copy from `Resources/Secrets.example.plist` if needed):
   - **LoginDatabaseURL** = `https://YOUR_PROJECT_REF.supabase.co/rest/v1`
   - **LoginDatabaseApiKey** = your Supabase anon key (Project Settings → API)

Full payload and sign-out details: [LOGIN_DATABASE.md](LOGIN_DATABASE.md).

---

## 2. Shared pools (generate codes, join with code)

The app **uploads a pool** when you share it (or when you first open the share sheet for that pool), gets an **8-character code**, and saves that code on the pool. Others can **join with that code** to download the pool.

### Supabase setup for shared pools

1. **Table**: Table Editor → New table → name: `shared_pools`.

   | Column       | Type          | Default / Notes                    |
   |--------------|---------------|-------------------------------------|
   | `id`         | `uuid`        | `gen_random_uuid()` (primary key)  |
   | `code`       | `text`        | NOT NULL                            |
   | `pool_json`  | `jsonb`       | NOT NULL                            |
   | `created_at` | `timestamptz` | `now()`                             |

   - Add a **unique index** on `code`: SQL Editor → `CREATE UNIQUE INDEX idx_shared_pools_code ON shared_pools (code);`
   - **RLS**: Enable Row Level Security. Add policies:
     - **Insert**: allow anon (or your role) to INSERT.
     - **Select**: allow anon to SELECT (so anyone with the code can fetch that row). Optionally restrict with `code = current_setting('request.code')` if you use a different pattern.

2. **App config** (same Supabase project as logins):
   - **LoginDatabaseURL** = `https://YOUR_PROJECT_REF.supabase.co/rest/v1`
   - **LoginDatabaseApiKey** = your anon key  

   The app uses this URL and key for shared pools when **SharedPoolsURL** / **SharedPoolsApiKey** are not set. To use a different backend for shared pools only, set **SharedPoolsURL** and optionally **SharedPoolsApiKey** in Secrets.plist.

### App behavior

- **Share (Settings → Share My Pools → tap a pool)**  
  Opens the share sheet. If the pool has no saved code, the app uploads it to `shared_pools` and shows the new 8-character code; the code is then saved on the pool so reopening the sheet shows the same code without re-uploading.

- **Join (Settings → Join Pool with Code)**  
  User enters an 8-character code. The app fetches the row from `shared_pools` with that `code`, decodes `pool_json` into the pool, and adds it to their list.

---

## Summary

| Feature              | Need Supabase? | Config |
|----------------------|----------------|--------|
| Store login data     | Optional       | `LoginDatabaseURL` + `LoginDatabaseApiKey` |
| Generate share codes | Yes (or other backend) | Same as above, or `SharedPoolsURL` + `SharedPoolsApiKey` |

One Supabase project can serve both: create the `logins` and `shared_pools` tables, set `LoginDatabaseURL` and `LoginDatabaseApiKey` in Secrets.plist, and the app will store logins and use the same project for share/join.

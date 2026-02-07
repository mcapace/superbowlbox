# Login Database (Apple & Google logins)

The app can send login (and optional sign-out) events to **your backend** so you can store them in a database. If you don’t set a URL, nothing is sent and behavior is unchanged.

## 1. Configure the app

In **Secrets.plist** (copy from `Secrets.example.plist` if needed), set:

- **`LoginDatabaseURL`** — base URL of your API (no trailing path).
- **`LoginDatabaseApiKey`** — (optional) e.g. Supabase anon key. If set, sent as `Apikey` and `Authorization: Bearer` so you can POST directly to Supabase REST.

Examples:

- Supabase: `LoginDatabaseURL` = `https://YOUR_PROJECT_REF.supabase.co/rest/v1`, `LoginDatabaseApiKey` = your anon key (use RLS to allow insert-only).
- Custom API: `LoginDatabaseURL` = `https://api.yourapp.com` (no key needed if your API is open or uses another auth).

The app will POST to:

- **`{LoginDatabaseURL}/logins`** — when a user signs in with Apple or Google.
- **`{LoginDatabaseURL}/logins/signout`** — when a user signs out (optional; your backend may ignore this).

## 2. Payload (POST /logins)

JSON body:

| Field             | Type   | Description                          |
|-------------------|--------|--------------------------------------|
| `provider`        | string | `"apple"` or `"google"`             |
| `provider_uid`    | string | Opaque user ID from the provider    |
| `email`           | string \| null | Email (if provided by provider) |
| `display_name`    | string \| null | Name (if provided)              |
| `client_timestamp`| string | ISO 8601 time when the app sent it  |

Example:

```json
{
  "provider": "apple",
  "provider_uid": "001234.abc...",
  "email": "user@example.com",
  "display_name": "Jane Doe",
  "client_timestamp": "2025-02-04T18:30:00Z"
}
```

## 3. Suggested database schema

**Canonical schema (Supabase):** See **`supabase/migrations/20250204120000_create_logins_and_shared_pools.sql`** and **docs/SCHEMA.md** for the exact `logins` (and `shared_pools`) tables and RLS used by the app.

### Option A: Supabase (Postgres)

1. In Supabase: **Table Editor** → **New table** → name it `logins`.
2. Columns:

| Column           | Type        | Default / Notes                    |
|------------------|-------------|------------------------------------|
| `id`             | `uuid`      | `gen_random_uuid()` (primary key)  |
| `provider`       | `text`      | NOT NULL                           |
| `provider_uid`   | `text`      | NOT NULL                           |
| `email`          | `text`      | nullable                           |
| `display_name`   | `text`      | nullable                           |
| `client_timestamp` | `timestamptz` | nullable (or use `now()`)       |
| `created_at`     | `timestamptz` | `now()`                          |

3. **RLS**: enable Row Level Security; add a policy that allows `INSERT` (and optionally `SELECT` for your admin) from your app. For a simple “log only” table you can allow inserts from anon or a service role.
4. **API**: Supabase REST uses `POST /rest/v1/logins` with `Content-Type: application/json` and your project’s anon (or service) key in `Apikey` and `Authorization: Bearer <key>`.

Set **LoginDatabaseURL** to:

`https://YOUR_PROJECT_REF.supabase.co/rest/v1`

Then in the app you can set the path to `logins` (default). If you need to send the Supabase key, you’d add a small server or Supabase Edge Function that accepts the app’s POST and inserts into `logins` with the key on the server.

### Option B: Custom API (Node, Python, etc.)

- Accept `POST /logins` with the JSON above.
- Insert into your database (e.g. `users` or `logins` table with the same fields).
- Return 2xx on success. The app does not retry on failure.

### Option C: Firebase Firestore

- Use an HTTPS Callable or a Cloud Function that accepts the same JSON and writes to a Firestore collection (e.g. `logins`).
- Set **LoginDatabaseURL** to your Cloud Function URL (e.g. `https://us-central1-PROJECT.cloudfunctions.net` and path `logins` in the app).

## 4. Sign-out (optional)

The app sends `POST .../logins/signout` with:

```json
{
  "provider": "apple",
  "provider_uid": "001234.abc...",
  "client_timestamp": "2025-02-04T19:00:00Z"
}
```

You can ignore this endpoint or use it to update a “last_seen” / “signed_out_at” column.

## 5. Security notes

- **Secrets.plist** is gitignored; never commit real keys or URLs.
- Prefer HTTPS only.
- If you use Supabase, use RLS and restrict who can read `logins`; the app only needs to be able to POST (e.g. via anon key with an insert-only policy, or via a backend that holds the key).

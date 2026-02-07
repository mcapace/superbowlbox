# Apple App Store Review – Test Account

For **App Review**, provide a test account so reviewers can sign in without Apple or Google.

## Quick checklist (what you need to do)

1. **Create one test user** in your Supabase project (Authentication → Users → Add user). Use a simple email and password you’ll give to Apple (e.g. `apple.review@yourdomain.com` / `SquareUpReview2025!`). Check **Auto Confirm User**.
2. **In App Store Connect**: Your app → **App Review Information** → turn on **Sign-in required** and enter that **Username** (email) and **Password**.
3. **Optional**: In **Notes for reviewer**, add: “Use **Sign in with Email** and the credentials above. You can also sign in with Apple or Google, or skip sign-in.”

## Option 1: Email / password (recommended)

1. **Create a test user in Supabase**
   - Open your project: [Supabase Dashboard](https://supabase.com/dashboard) → your project.
   - Go to **Authentication** → **Users** → **Add user** → **Create new user**.
   - Email: e.g. `apple.review@yourdomain.com` (or any email you control).
   - Password: choose a simple password you’ll share only in App Review (e.g. `SquareUpReview2025!`).
   - Leave **Auto Confirm User** checked so the account works immediately.

2. **Add credentials in App Store Connect**
   - In App Store Connect: your app → **App Review Information**.
   - Under **Sign-in required**, enable it and enter:
     - **Username:** the email above (e.g. `apple.review@yourdomain.com`).
     - **Password:** the password you set.

3. **Optional: add a note for reviewers**
   - In **Notes for reviewer** you can add:
     - “Sign in with Email → use the credentials above. You can also use Sign in with Apple or Google with your own accounts, or skip sign-in.”

## Option 2: Pre-filled test credentials (for internal use)

If you want a fixed test account referenced only in this repo (do **not** put real passwords in git):

- Create a user in Supabase as above.
- Store the email and password in 1Password / Secrets Manager / team doc.
- In **App Store Connect → App Review Information → Notes**, tell reviewers: “Use Sign in with Email. Test account: [email]. Password: [see 1Password / link].”

## After review

- You can disable or delete the reviewer account in Supabase (Authentication → Users) if desired.
- Email sign-in uses the same Supabase project as your **LoginDatabaseURL** / **LoginDatabaseApiKey** (Secrets.plist). Logins are recorded in the `logins` table with `provider = 'email'` and `provider_uid` = Supabase Auth user id.

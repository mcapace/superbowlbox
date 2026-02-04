# Google OAuth setup – Sign in with Google (SquareUp)

Follow these steps to get **Sign in with Google** working in the app.

---

## Step 1: Google Cloud project

1. Go to **[Google Cloud Console](https://console.cloud.google.com/)** and sign in with your Google account.
2. Create or select a project:
   - **New project:** Top bar → **Select a project** → **New Project** → name it (e.g. “SquareUp”) → **Create**.
   - **Existing project:** Select it from the project dropdown.
3. Note the **Project name**; you’ll use this project for the OAuth client.

---

## Step 2: OAuth consent screen

1. In the left menu go to **APIs & Services** → **OAuth consent screen**.
2. Choose **External** (unless you use a Google Workspace org and want **Internal** only) → **Create**.
3. Fill the required fields:
   - **App name:** e.g. `SquareUp`
   - **User support email:** your email
   - **Developer contact:** your email
4. Click **Save and Continue**.
5. **Scopes:** Click **Add or Remove Scopes**. For basic sign-in you can leave the default (email, profile, openid) or add:
   - `.../auth/userinfo.email`
   - `.../auth/userinfo.profile`
   - `openid`
   Then **Update** → **Save and Continue**.
6. **Test users (if app is in “Testing”):** Add your Google account so you can sign in before publishing. Later you can submit for verification or leave as testing.
7. **Save and Continue** through the summary.

---

## Step 3: Create iOS OAuth client ID

1. Go to **APIs & Services** → **Credentials**.
2. Click **+ Create Credentials** → **OAuth client ID**.
3. **Application type:** **iOS**.
4. **Name:** e.g. `SquareUp iOS`.
5. **Bundle ID:** must match your app exactly.
   - In Xcode: select the **SuperBowlBox** target → **General** → **Bundle Identifier**.
   - Example: `com.superbowlbox.app` (use yours; no typos).
6. Click **Create**.
7. A dialog shows your **Client ID**. It looks like:
   ```text
   123456789012-abcdefghijklmnop.apps.googleusercontent.com
   ```
   Copy and save it; you’ll need it in the next steps.
8. You do **not** need an iOS client secret for the Google Sign-In SDK.

---

## Step 4: Add the Google Sign-In package in Xcode

1. Open **SquareUp** in Xcode.
2. **File** → **Add Package Dependencies...**.
3. In the search field (top right) paste:
   ```text
   https://github.com/google/GoogleSignIn-iOS
   ```
4. When the package appears, select it and click **Add Package**.
5. Ensure **GoogleSignIn** is checked for the **SuperBowlBox** target → **Add Package**.
6. Wait for the package to resolve and finish indexing.

---

## Step 5: Add Client ID and URL scheme in the app

The app reads the **iOS Client ID** from `Info.plist` and needs a **URL scheme** so Google can return to the app after sign-in.

### 5a. GIDClientID in Info.plist

1. In Xcode, open **SuperBowlBox/Info.plist** (or the target’s **Info** tab).
2. Add a new row:
   - **Key:** `GIDClientID`  
     (type: String; if using the visual editor, add “Key” and type the name).
   - **Value:** your **full iOS Client ID** from Step 3, e.g.  
     `123456789012-abcdefghijklmnop.apps.googleusercontent.com`

### 5b. URL scheme (reversed client ID)

Google opens your app after sign-in using a URL. The scheme must be your **reversed client ID**.

1. In the same **Info.plist** (or **Info** tab), find **URL Types** (or **CFBundleURLTypes**).
2. If **URL Types** doesn’t exist, add it:
   - **Key:** `URL types` (or `CFBundleURLTypes`)
   - **Type:** Array
3. Expand **URL types** and add **Item 0** (Dictionary).
4. Inside **Item 0** add:
   - **Key:** `URL Schemes` (or `CFBundleURLSchemes`)  
     **Type:** Array  
     **Item 0:** (String) your **reversed client ID**
   - **Key:** `URL Identifier` (or `CFBundleURLName`)  
     **Type:** String  
     **Value:** e.g. `com.superbowlbox.app` (your bundle ID is fine)

**Reversed client ID:**

- Your Client ID looks like:  
  `123456789012-abcdefghijklmnop.apps.googleusercontent.com`
- Take the part **before** `.apps.googleusercontent.com`:  
  `123456789012-abcdefghijklmnop`
- Prepend `com.googleusercontent.apps.`  
  Result: **URL scheme** = `com.googleusercontent.apps.123456789012-abcdefghijklmnop`

So **URL Schemes** → **Item 0** = that one string (no `https://`, no slashes).

**Example plist snippet (for reference):**

```xml
<key>GIDClientID</key>
<string>123456789012-abcdefghijklmnop.apps.googleusercontent.com</string>
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.123456789012-abcdefghijklmnop</string>
        </array>
        <key>CFBundleURLName</key>
        <string>com.superbowlbox.app</string>
    </dict>
</array>
```

---

## Step 6: Build and test

1. **Product** → **Clean Build Folder**, then **Build**.
2. Run on a **device** or **simulator**.
3. Open **Settings** → **Account** → tap **Sign in with Google**.
4. You should see the Google account picker; after choosing an account, you should return to the app and see yourself signed in.

---

## Troubleshooting

| Issue | What to check |
|--------|----------------|
| “Google Sign-In is not configured” | GoogleSignIn package is added to the target and **GIDClientID** is in Info.plist with the full iOS Client ID. |
| “Add GIDClientID to Info.plist” | Key name is exactly `GIDClientID` (no typo) and the value is the full Client ID string. |
| App doesn’t open after choosing account | **URL scheme** in **CFBundleURLSchemes** must be exactly the reversed client ID (e.g. `com.googleusercontent.apps.123456789012-xxxx`). Bundle ID in Google Cloud must match the app’s Bundle ID. |
| “Redirect URI mismatch” or similar | You’re using the **iOS** OAuth client (not Web). No custom redirect URI needed for the iOS SDK. |
| Simulator: sign-in opens but doesn’t return | Try on a real device; ensure the URL scheme is set and the bundle ID matches. |

---

## Summary checklist

- [ ] Google Cloud project created/selected  
- [ ] OAuth consent screen configured (External, app name, emails)  
- [ ] **iOS** OAuth client created with correct **Bundle ID**  
- [ ] Client ID copied  
- [ ] **GoogleSignIn-iOS** package added in Xcode  
- [ ] **GIDClientID** in Info.plist = full iOS Client ID  
- [ ] **CFBundleURLTypes** with **CFBundleURLSchemes** = reversed client ID  
- [ ] Clean build, run, test **Sign in with Google** in Settings → Account  

Once these are done, Google OAuth for SquareUp is set up.

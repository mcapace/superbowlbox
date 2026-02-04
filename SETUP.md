# SquareUp – Setup Checklist

Use this to make sure **Sign in**, **Camera**, **OCR**, **live scores**, and **notifications** all work.

## Get all features working (at a glance)

| Feature | What you need |
|--------|----------------|
| **Scan / create pools, “my name on sheet”, multiple boxes** | Nothing extra. Works out of the box. |
| **Live scores** | Optional: add **SportsDataIOApiKey** in Info.plist (see §4). Otherwise ESPN is used. |
| **In-app “review & push” (You’re leading!, Halftime winner, One score away)** | Allow **notifications** when the app asks. No capability required. Runs when the app is open and scores refresh. |
| **Sign in with Apple** | Set **Team** in Xcode; add **Sign in with Apple** capability (§1). |
| **Sign in with Google** | Add **GoogleSignIn-iOS** package; set **GIDClientID** and URL scheme in Info.plist (§2). |
| **Camera / photo library** | Allow when prompted. Usage strings are already in Info.plist (§3). |
| **Remote push (e.g. from your server)** | Add **Push Notifications** capability; send APNs payloads using the device token (§6). |

---

## 1. Sign in with Apple

**Already in the project:** entitlement file `SuperBowlBox.entitlements` and `CODE_SIGN_ENTITLEMENTS` are set.

**You need to do:**

1. **Set your development team**  
   - In Xcode: select the **SuperBowlBox** project → **SuperBowlBox** target → **Signing & Capabilities**.  
   - Set **Team** to your Apple Developer account (required for signing and capabilities).

2. **Add the Sign in with Apple capability**  
   - In that same **Signing & Capabilities** tab, click **+ Capability**.  
   - Add **Sign in with Apple** (the entitlement file is already in the project; adding the capability wires it to your App ID).

3. **Apple Developer (for distribution)**  
   - In [developer.apple.com](https://developer.apple.com) → **Certificates, Identifiers & Profiles** → **Identifiers** → your App ID.  
   - Ensure **Sign in with Apple** is enabled for that App ID.

**Testing:** Run on a device or simulator with an Apple ID. In the app go to **Settings → Account** and tap **Sign in with Apple**.

---

## 2. Sign in with Google

**Already in the project:** UI and `AuthService` logic; implementation is used only when the Google SDK is added.

**You need to do:**

1. **Add the Google Sign-In package**  
   - Xcode: **File → Add Package Dependencies**.  
   - URL: `https://github.com/google/GoogleSignIn-iOS`  
   - Add the **GoogleSignIn** product to the SuperBowlBox target.

2. **Create an OAuth client (iOS)**  
   - Go to [Google Cloud Console](https://console.cloud.google.com/) → your project (or create one) → **APIs & Services → Credentials**.  
   - **Create Credentials → OAuth client ID** → Application type: **iOS**.  
   - Enter your app’s **Bundle ID** (e.g. `com.superbowlbox.app`).  
   - Copy the **Client ID** (looks like `123456789-xxxx.apps.googleusercontent.com`).

3. **Configure the app**  
   - **Info.plist**  
     - Add a key **GIDClientID** (String) and set the value to your **iOS Client ID** from step 2.  
   - **URL scheme (required for Google sign-in)**  
     - In the target’s **Info** tab (or in Info.plist), under **URL Types** add an entry:  
       - **Identifier**: e.g. `com.google.signin`  
       - **URL Schemes**: your *reversed* client ID, e.g. `com.googleusercontent.apps.123456789-xxxxxxxxxx`  
     - The “reversed” form is the Client ID with the *prefix* `com.googleusercontent.apps.` (the rest is the numeric part from your client ID).

4. **Rebuild**  
   - After adding the package and the two config steps above, **Sign in with Google** in **Settings → Account** will use the SDK.

---

## 3. Camera

**Already in the project:**  
- **NSCameraUsageDescription** and **NSPhotoLibraryUsageDescription** are set in Info.plist (and in the target’s build settings).  
- No extra capability is required for camera or photo library.

**You need to do:**

1. **Run on a device or simulator**  
   - On a **real device**: the first time you open the camera or pick a photo, iOS will show the permission dialog using the strings above. Tap **Allow**.  
   - On **simulator**:  
     - Camera: use **Features → Camera** (e.g. “Mac” or “Simulated”) if you use the in-app camera.  
     - Photo library: use **Features → Photo Library** to add test images; the app can use those for scanning.

2. **If the app doesn’t ask for permission**  
   - On device: **Settings → SquareUp → Camera** (and **Photos**) and ensure access is allowed.  
   - Delete the app and reinstall if you had previously denied and want the prompt again.

No code or entitlement changes are required for camera/photo library beyond what’s already there.

---

## 4. Sports Data IO (live scores)

**Already in the project:**  
- **SportsDataIOConfig** reads your API key from **Secrets.plist** first (gitignored), then Info.plist.  
- **NFLScoreService** uses Sports Data IO for NFL scores when a key is set; otherwise it falls back to ESPN (no key).

**You need to do:**

1. **Get an API key**  
   - Sign up at [sportsdata.io](https://sportsdata.io) and create an account.  
   - In your account / dashboard, copy your **API key** (or create one for the NFL/Scores API).

2. **Add the key securely (never committed)**  
   - Copy **SuperBowlBox/Resources/Secrets.example.plist** to **Secrets.plist** (same folder).  
   - Open **Secrets.plist** and set **SportsDataIOApiKey** to your API key.  
   - **Secrets.plist** is in **.gitignore**, so it will not be committed. The app reads from it at runtime (it’s copied into the app bundle by Xcode).

3. **Rebuild and run**  
   - The dashboard will fetch NFL scores from Sports Data IO. If no key is found, the app uses ESPN instead.

See **docs/SPORTSDATAIO_SETUP.md** for endpoint details and optional NBA/NHL/MLB usage.

---

## 5. OCR (Vision)

**Already in the project:**  
- **Vision** framework is used in `VisionService` for text recognition.  
- Vision is part of iOS; there is **no** separate capability or entitlement for it.  
- The app targets **iOS 17+**, which fully supports the APIs used.

**You need to do:**

- **Nothing.** OCR will work whenever:
  - The app runs on iOS 17+ (device or simulator), and  
  - The user has granted **Camera** and/or **Photo Library** access so the app can get an image to process (camera capture or photo picker).

If OCR fails, it’s usually due to image quality (blur, lighting, or a sheet that doesn’t look like a grid). The app will show an error and offer manual entry.

---

## 6. Notifications (local “review & push” and optional remote push)

**Already in the project:**  
- The app requests notification permission on launch and registers for remote notifications.  
- **GameContextService** reviews the score and pool state and schedules **local** notifications when you’re leading, when a quarter/halftime/final winner is decided, or when your square is one score away.

**For local “review & push” (no extra setup):**

- When iOS prompts for notification permission, tap **Allow**.  
- Score updates run every 30 seconds while the app is **in the foreground**. When a score update triggers a moment (e.g. you take the lead), the app schedules a local notification.  
- **Note:** Those moments are only evaluated when the app has recently refreshed scores. If the app is fully closed, you won’t get those alerts until you open the app again. For alerts while the app is closed, you’d use a backend + remote push (§6 below).

**For remote push (optional, from your own server):**

1. In Xcode: **Signing & Capabilities** → **+ Capability** → **Push Notifications**.  
2. The device token is saved when registration succeeds (see `NotificationService.didRegisterForRemoteNotifications(deviceToken:)`). Send that token to your backend (e.g. on login or app launch).  
3. Your backend fetches scores (or uses webhooks), decides when to notify (e.g. “halftime winner”), and sends an APNs payload to that token.

---

## Quick reference

| Feature              | Capability / entitlement      | Info.plist / config                    | Extra step                          |
|----------------------|-------------------------------|----------------------------------------|-------------------------------------|
| Sign in with Apple   | Add “Sign in with Apple”      | (none)                                 | Set Team; enable in App ID for prod |
| Sign in with Google  | (none)                        | GIDClientID + URL scheme ✓             | Add GoogleSignIn-iOS package        |
| Camera               | (none)                        | NSCameraUsageDescription ✓             | Allow when prompted                 |
| Photo library        | (none)                        | NSPhotoLibraryUsageDescription ✓       | Allow when prompted                 |
| Sports Data IO       | (none)                        | Resources/Secrets.plist (SportsDataIOApiKey); template: Secrets.example.plist | Copy example to Secrets.plist in Resources/; add key (file is gitignored) |
| OCR (Vision)         | (none)                        | (none)                                  | None                                |
| Local notifications  | (none)                        | (none)                                  | Allow when prompted                 |
| Remote push          | Add “Push Notifications”       | (none)                                  | Backend sends APNs to device token  |

---

## Optional: Add camera to required capabilities

If you want the App Store to list “Camera” as a requirement (so the app is only offered on devices with a camera), you can add it to **UIRequiredDeviceCapabilities** in Info.plist (e.g. add `camera`). The project currently does *not* require camera so the app can run on devices without one (e.g. iPad without camera); scanning would then rely on photo library only.

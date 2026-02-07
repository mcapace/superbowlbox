# SquareUp

**Pools, boxes & brackets. Any event.**

A modern iOS app for running and tracking any score-based pool—box pools (squares), brackets, or custom payouts. Create pools, scan sheets, and follow live scores in one place. The app **reviews what’s happening** (live score, quarter, who’s winning, who’s in the hunt) and **uses that to push information to you**—leader changes, your square getting hot, quarter/halftime/final winners—so the experience stays alive during the game.

## Features

### Core Features
- **Smart Scanning**: Use your camera to scan physical pool sheets with OCR (Vision framework)
- **Live Scores**: Real-time score updates via Sports Data IO (with your API key) or ESPN API (no key)
- **Multiple Pools**: Manage many pools at once—box, bracket, or custom
- **Flexible Payouts**: By quarter, halftime, final, first score, or your own rules
- **Winner Tracking**: Highlights current and past winners based on your pool structure
- **My Squares**: Find all your squares across pools

### Pool Management
- **Create Pools**: Set up box pools or brackets with teams, numbers, and payout rules
- **Scan Sheets**: Import existing pool sheets from camera or photo library
- **Share Pools**: Generate invite codes to share with friends
- **Join Pools**: Enter invite codes to join shared pools

### User Experience
- **Elevated UI**: SwiftUI with refined typography (serif display, rounded UI), premium palette, and card-based layout
- **Dark Mode**: Full support for light and dark modes
- **Responsive Grid**: Zoomable grid view with player details
- **Quick Stats**: At-a-glance stats for your squares and wins

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

1. Clone the repository
2. Open `SuperBowlBox.xcodeproj` in Xcode
3. Copy **SuperBowlBox/Resources/Secrets.example.plist** to **Secrets.plist** in the same folder and add your API keys / URLs (see SETUP.md). **Secrets.plist** is gitignored.
4. Select a simulator or device and run (⌘R). The app supports **iOS 17+**; for testing we use **iOS 26.3** (e.g. iPhone 17 simulator). Do not use iPhone 16.
5. Command-line build: `./scripts/build.sh` (uses iPhone 17 or first available simulator)

**Distribution (TestFlight / App Store):** Before archiving, follow **docs/DISTRIBUTION_CHECKLIST.md** so APIs, Lambdas, AI integration, and Supabase work in the distributed app.

## Project Structure

```
SuperBowlBox/
├── SuperBowlBoxApp.swift      # App entry point
├── ContentView.swift          # Main tab view and dashboard
├── Info.plist                 # App configuration
├── Models/
│   ├── BoxGrid.swift          # Pool grid and structure
│   ├── BoxSquare.swift        # Individual square
│   ├── GameScore.swift       # Score tracking
│   ├── PoolStructure.swift   # Payout rules (quarter, halftime, final, etc.)
│   └── Team.swift            # Team model
├── Views/
│   ├── GridView.swift         # Full grid detail view
│   ├── PoolsListView.swift   # Pool list and create flow
│   ├── MySquaresView.swift   # User's squares
│   ├── ScannerView.swift     # OCR scanning
│   ├── ManualEntryView.swift # Manual pool creation
│   ├── SettingsView.swift    # Settings and sharing
│   ├── CameraViewController.swift
│   ├── ScoreOverlayView.swift
│   └── SquareDetailView.swift
├── ViewModels/
│   └── GridViewModel.swift
├── Services/
│   ├── VisionService.swift   # OCR
│   └── NFLScoreService.swift # Live scores
└── Resources/
    └── Assets.xcassets/
```

## How It Works

### Box pools (squares)
1. A 10×10 grid has 100 squares.
2. Columns and rows get numbers 0–9 (one set per team).
3. Winners are determined by the last digit of each team’s score at set times (e.g. end of each quarter, halftime, or final).
4. SquareUp supports payouts by quarter, halftime only, final only, first score, or custom.

### Using the app
1. **Create or scan a pool** — New pool with payout rules, or scan an existing sheet. Say how your name appears on the sheet so the app can find your squares (and add multiple names if you have more than one box).
2. **Set your name** — In Settings, so your squares are highlighted across pools.
3. **Follow the game** — Scores update automatically; the app reviews the score and pool state and can notify you when you’re leading, when a quarter/halftime/final pays out, or when your square is one score away.
4. **Track winners** — Current leader and past period winners are shown.

## Typography & design

- **Display (app name, hero titles):** System serif (New York) for an elevated, editorial look. Optional: bundle **DM Serif Display** (Google Fonts) and use `Font.custom("DMSerifDisplay-Regular", size:)` in `Font.squareUpDisplay` in `SuperBowlBoxApp.swift` for a custom display font.
- **UI (labels, buttons, cards):** System rounded for clarity and consistency.
- **Tracking:** Slight letter-spacing on “SquareUp” and live labels via `AppTracking.display` for a logo-like feel.

## Sign in with Apple & Google

- **Sign in with Apple** works as soon as the capability is enabled: in Xcode, select the target → **Signing & Capabilities** → **+ Capability** → **Sign in with Apple**. The app uses the default entitlement and shows the native Apple button in **Settings → Account**.
- **Sign in with Google** is wired in the UI and in `AuthService`; the implementation is compiled in only when the [GoogleSignIn-iOS](https://github.com/google/GoogleSignIn-iOS) package is added:
  1. **File → Add Package Dependencies** → `https://github.com/google/GoogleSignIn-iOS`
  2. In [Google Cloud Console](https://console.cloud.google.com/) create an OAuth 2.0 Client ID (iOS app), then add to the app:
     - **Info.plist**: add `GIDClientID` (string) = your iOS client ID.
     - **URL scheme**: add a URL type with the *reversed* client ID (e.g. `com.googleusercontent.apps.123456789-xxxx`).
  3. Rebuild; **Sign in with Google** in Settings will then use the SDK.

## Push notifications & polish

- **Push notifications**: The app requests notification permission on launch and registers for remote notifications. It also **reviews what’s happening** (score, quarter, current winner, your squares) and can send **local** notifications for moments like “You’re leading [Pool]!”, “Halftime winner in [Pool]”, or “Your square is one score away.” For remote push:
  1. In Xcode: target → **Signing & Capabilities** → **+ Capability** → **Push Notifications**.
  2. Use the device token (stored after registration) in your backend to send APNs payloads (e.g. score or winner alerts).
- **Haptics**: Key actions use system haptics—selection (tabs, pool picker), light/medium (buttons, grid tap), success/error (scan result, pool saved).
- **Glass / materials**: Dashboard and overlay cards use `.ultraThinMaterial` and subtle borders for a refined, native look.

## Live score integration

The app uses **live NFL scores** from either **Sports Data IO** (when you add your API key) or **ESPN** (no key).

### Sports Data IO (recommended if you have an account)

1. Add your API key in **Info.plist** as **SportsDataIOApiKey** (get it at [sportsdata.io](https://sportsdata.io)).
2. **NFLScoreService** will then fetch from `https://api.sportsdata.io/v3/nfl/scores/json/ScoresByDate/{date}` using your key (sent in the `Ocp-Apim-Subscription-Key` header).
3. If the key is missing or a request fails, the app falls back to ESPN. See **SETUP.md** (§4) and **docs/SPORTSDATAIO_SETUP.md** for details.

### ESPN fallback (no key)

1. **`NFLScoreService`** fetches the NFL scoreboard from:
   - `https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard`
2. **When it starts**: `ContentView` calls `appState.scoreService.startLiveUpdates()` in `onAppear`, so as soon as you open the app it fetches once and then every **30 seconds**.
3. **What it uses**: The service prefers the **Super Bowl** or **playoff** game when present; otherwise it uses the first game on the scoreboard. It parses home/away teams, scores, quarter, clock, and quarter-by-quarter linescores.
4. **Where scores appear**: Dashboard (Live Score card), Winner Spotlight, grid winning square (last digit of each team’s score), pool list rows, My Squares, and the manual refresh button in the nav bar.

### Optional configuration

- **Polling interval**: In `startLiveUpdates(interval: 30)` you can change `30` to another number of seconds (e.g. `15` for more frequent updates during the game).
- **Picking a specific game**: The logic in `parseESPNResponse` prefers events whose name contains “super bowl” or are playoff type; you can change that logic to match a specific event ID or team abbreviations if you add multiple-game support.
- **Offline / no game**: If the request fails or no game is found, the service keeps showing the last `GameScore` (or `GameScore.mock` at launch). The UI still works; you can also use **Settings** or a debug hook to call `setManualScore(homeScore:awayScore:quarter:)` for testing.

### Summary

| Item              | Status |
|-------------------|--------|
| API               | Sports Data IO (with key) or ESPN (no key) |
| Start             | Automatic on app launch |
| Refresh            | Every 30 s + manual refresh button |
| Game selection     | Sports Data IO: first in-progress/scheduled/final for today; ESPN: Super Bowl / playoff preferred, else first game |

## Getting everything into main (Xcode + Git)

- **Xcode**: The project file (`SuperBowlBox.xcodeproj/project.pbxproj`) already includes all Swift sources (e.g. `AuthService`, `HapticService`, `NotificationService`, `InstructionsView`, `PoolStructure`, `SignInWithAppleButton`). Open the project in Xcode and build (⌘B); everything should compile.
- **Git**: To put all current work on `main` and push:

```bash
cd /Volumes/Data5TB/superbowlbox
git add .gitignore README.md SETUP.md docs/
git add SuperBowlBox.xcodeproj/project.pbxproj
git add SuperBowlBox/
git status   # optional: review
git commit -m "Add auth, haptics, notifications, onboarding sign-in, live score docs"
git push origin main
```

If you prefer not to commit workspace/user-specific files, keep `SuperBowlBox.xcodeproj/xcuserdata/` and `SuperBowlBox.xcodeproj/project.xcworkspace/` out of the add (they are in `.gitignore` now). The `.gitignore` above avoids `.DS_Store` and `xcuserdata` so they won’t be added by `git add SuperBowlBox/` or `git add .`.

## Technologies

- **SwiftUI** – UI
- **Vision** – OCR for scanning
- **AVFoundation** – Camera
- **AuthenticationServices** – Sign in with Apple
- **Sports Data IO** – Live NFL scores (optional; add API key in Info.plist)
- **ESPN API** – Live scores fallback (no key)

## License

MIT — use and modify for your own pools and events.

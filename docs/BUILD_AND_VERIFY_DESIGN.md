# Verifying the sportsbook design in Xcode

The design changes **are** implemented in the same Swift files Xcode builds:

- **SuperBowlBox/ContentView.swift** – Dashboard, live score card, winner card, grid card, On the Hunt, Quick Stats (all use `SportsbookBackgroundView` and `sportsbookCard`)
- **SuperBowlBox/DesignSystem.swift** – `SportsbookBackgroundView`, `sportsbookCard()`, colors, typography
- **SuperBowlBox/Views/PoolsListView.swift** – Pools list background
- **SuperBowlBox/Views/MySquaresView.swift** – My Squares background and cards
- **SuperBowlBox/Views/SettingsView.swift** – Settings background, profile (no orbital ring)
- **SuperBowlBox/Views/InstructionsView.swift** – Onboarding background
- **SuperBowlBox/Views/ScannerView.swift** – Scanner background

There are no separate “design” layers; in SwiftUI these files **are** the UI.

## If the app looks unchanged

1. **Open the correct project**  
   Open `SuperBowlBox.xcodeproj` from this repo (e.g. `/Volumes/Data5TB/superbowlbox`).

2. **Force a clean build and run**
   - **Product → Clean Build Folder** (⇧⌘K)
   - **Product → Run** (⌘R)

   This rebuilds the app and reinstalls it on the simulator or device. An old build can otherwise keep running.

3. **Confirm the new build**
   - On the **Live** tab you should see a small green **“Sportsbook”** label in the top-left (temporary). If you see it, the new code is running.
   - Backgrounds should be **flat dark** (no animated gradient orbs, no grid lines).
   - Cards should have **subtle borders** and **no glow/shadow**.

4. **Remove the label**
   After you’ve confirmed the new build, the temporary “Sportsbook” overlay in `ContentView.swift` can be removed (search for `Text("Sportsbook")` and delete the `.overlay(alignment: .topLeading) { ... }` block).

## What changed visually

| Before | After |
|--------|--------|
| Mesh background (floating gradient orbs) | Solid dark background |
| Tech grid overlay (lines) | None |
| Cards with neon glow / shadow | Cards with thin border, no glow |
| Orbital ring on Settings profile | Simple circle |
| Live score card had glow | Live score card has optional green border when game is live |

If your previous build already had a dark theme, the difference is mostly: no mesh/grid, no glow, and flatter cards.

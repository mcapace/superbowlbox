# See the new design — run the latest build

If the app **still looks the same**, the device or simulator is almost certainly running an **old build**. Do this in order:

## 1. Open the correct project
- In Finder, go to: **`/Volumes/Data5TB/superbowlbox`**
- Double‑click **`SuperBowlBox.xcodeproj`** (open this, not a copy elsewhere)

## 2. Remove the old app from the simulator
- In the simulator: **long‑press the SquareUp app icon** → **Remove App** → **Delete App**
- (Or: Simulator menu → **Device** → **Erase All Content and Settings** to start clean)

## 3. Clean and build
- In Xcode: **Product** → **Clean Build Folder** (⇧⌘K)
- Then: **Product** → **Run** (⌘R)

## 4. What you should see (new build)
- **Bright green header bar** at the top on the Live tab (solid bright green #2DD068), not dark gray/green
- **“NEW” white pill** next to the SquareUp logo in the center of the nav bar
- **Blue-tinted dark background** (dark blue #0C1322) when you scroll, not neutral gray/black
- **“Today”** pill on the right (white pill on the green bar)

If you see the **bright green bar**, **“NEW” badge**, and **blue-ish dark background**, you’re on the new build. If you still see a **gray/dark gray** screen and **no “NEW”**, you’re running an old install — delete the app (step 2), then Clean Build + Run again. Make sure you open the project from **`/Volumes/Data5TB/superbowlbox`**.

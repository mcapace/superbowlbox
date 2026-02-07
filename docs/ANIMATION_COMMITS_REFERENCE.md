# Animation & layout commits (reference)

Reference for the premium animations and layout branch. These commits are **not** on `main`; they live on a separate branch. Use this when merging that branch or reverting specific changes.

---

## Premium Animations commit (revert if needed)

**Commit:** `9846af7` — *feat: Add state-of-the-art premium animations and UI enhancements*

**Files changed:**
- `DesignSystem.swift` — 12 new animation components
- `ContentView.swift` — Score display (flip digits, skeletons)
- `GridView.swift` — Winning cell glow animations
- `MySquaresView.swift` — Larger stats, hunt indicators

**Revert just this commit:**
```bash
git revert 9846af7
```

**See what changed:**
```bash
git diff d19373f 9846af7
```

---

## Recent commits on the animations/layout branch (for reference)

| Commit   | Description                    |
|----------|--------------------------------|
| 9846af7  | Premium animations (flip digits, pulse, glow, skeletons) |
| d19373f  | Settings futuristic design     |
| 7dd9042  | Futuristic UI transformation   |
| c3e7bcd  | Premium SF Symbols             |
| 70b40ae  | Dark glassmorphic design       |

---

*Current `main` does not include these commits. Merge the branch when you want the animations; use `git revert 9846af7` to undo only the premium-animations commit.*

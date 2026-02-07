# Payout rules – where we left off

Quick recap after a session crash. This doc summarizes what’s implemented and what to do next.

## Implemented

### 1. **Per-pool rules (basic vs complex)**
- **Lambda** (`docs/lambda-payout-parse-index.js`): Prompt says “Not all pools have the same rules” and to parse exactly what the user entered (basic or complex).
- **Docs** (`PAYOUT_ANTHROPIC_LAMBDA.md`): Section “Pool rules vary (basic vs complex)” explains that each pool has its own structure.
- **App**: `PoolStructure` and `PayoutParseService` comments state that rules are per-pool.

### 2. **Grid header and “View payout rules”**
- Header shows **pool type** (e.g. “Quarters”, “Score change”, “First score”) and a tappable **“View payout rules”** that opens a modal.
- Modal shows **AI-readable summary** (`readableRulesSummary` from the Lambda when available) or a formatted `professionalPayoutSummary`, plus “As you entered” with the raw text.

### 3. **Score change / first score**
- **firstScoreChange**: One payout when the score first changes from 0–0. Header label: “Score change”. Lambda and local inference both support it.
- **perScoreChange**: Pay per score change (each point), optional cap (e.g. 25), remainder to final. Example: “$400 per score change, payouts stop at 25, remainder to final.”
  - **PoolType**: `perScoreChange(amountPerChange: Double, maxScoreChanges: Int?)`
  - **PoolPeriod**: `scoreChange(Int)` for “Change 1” … “Change 25”, plus `.final` for remainder.
  - **BoxGrid**: `scoreChangeInfo(for: score)` returns (count, paid, remainder). `currentPeriod(for:)` now includes `.perScoreChange` and returns `.scoreChange(totalPoints)` or `.final`.
  - **Lambda**: Returns `poolType: "perScoreChange"`, `amountPerChange`, `maxScoreChanges`, `totalPoolAmount`, `readableRules`.
  - **PayoutParseService**: Maps `amountPerChange` / `maxScoreChanges` into `PoolType.perScoreChange`.

### 4. **Lambda response**
- **readableRules**: Required in the prompt; AI returns a short, clear summary for the modal.
- **firstScoreChange** and **perScoreChange** are called out in the prompt; fallbacks detect “first score” / “score change” and set the right `poolType`.

### 5. **Fix applied just now**
- **BoxGrid.currentPeriod(for:)** was missing a `case .perScoreChange`. That case is now added so the “current” period for per-score-change pools is `.scoreChange(totalPoints)` or `.final` when past the cap / game over.

## What you might want to do next

1. **Build and run**  
   - Open the app in Xcode and build. If you see any Codable/encoding errors for `PoolType` (e.g. existing saved pools), we may need backward-compatible decoding for the new `perScoreChange` case.

2. **Redeploy the Lambda**  
   - Deploy the current `docs/lambda-payout-parse-index.js` so the API returns `perScoreChange`, `readableRules`, and the “not all pools have the same rules” behavior.

3. **UI for per-score-change**  
   - Optionally add a small line in the grid or pool card for perScoreChange pools: “Score changes: 12 · Paid: $4,800 · Remainder: $5,200” using `pool.scoreChangeInfo(for: score)`.

4. **Test flows**  
   - Basic: “$25 per quarter” → byQuarter, fixedAmount.  
   - First score: “First score wins $100” → firstScoreChange.  
   - Complex: Your example (e.g. “$400 per score change, stop at 25, remainder to final”) → perScoreChange(400, 25) and correct header/modal.

## Key files

| What | Where |
|------|--------|
| Lambda (parse + readableRules) | `docs/lambda-payout-parse-index.js` |
| Pool rules vary (basic vs complex) | `docs/PAYOUT_ANTHROPIC_LAMBDA.md` |
| Pool type & periods (incl. perScoreChange) | `SuperBowlBox/Models/PoolStructure.swift` |
| Winner/period logic (incl. scoreChangeInfo) | `SuperBowlBox/Models/BoxGrid.swift` |
| Parse API response → PoolStructure | `SuperBowlBox/Services/PayoutParseService.swift` |
| Grid header + “View payout rules” modal | `SuperBowlBox/Views/GridView.swift` |

If something doesn’t match this (e.g. a file was reverted), say what you’re seeing and we can realign.

import Foundation

/// Reviews what’s happening (score, quarter, who’s winning, your squares) and pushes information
/// to the user via local notifications—so the experience stays alive during the game.
enum GameContextService {
    private static let oneScoreAwayCooldown: TimeInterval = 5 * 60 // 5 minutes between "one score away" per pool

    /// Call when the score updates. Compares with previous state and may schedule local notifications.
    static func review(
        currentScore: GameScore?,
        previousScore: GameScore?,
        pools: [BoxGrid],
        globalMyName: String
    ) {
        guard let score = currentScore else { return }
        for pool in pools {
            reviewPool(
                pool: pool,
                score: score,
                previousScore: previousScore,
                globalMyName: globalMyName
            )
        }
    }

    private static func reviewPool(
        pool: BoxGrid,
        score: GameScore,
        previousScore: GameScore?,
        globalMyName: String
    ) {
        let ownerLabels = pool.effectiveOwnerLabels(globalName: globalMyName)
        guard let winningSquare = pool.winningSquare(for: score) else { return }

        // 1) You’re leading the pool
        let iAmLeading = !ownerLabels.isEmpty && pool.isOwnerSquare(winningSquare, ownerLabels: ownerLabels)
        if iAmLeading {
            let key = "gc_lead_\(pool.id.uuidString)"
            let lastNotified = UserDefaults.standard.string(forKey: key)
            if lastNotified != winningSquare.id.uuidString {
                NotificationService.scheduleLocal(
                    title: "You’re leading!",
                    body: "Your square is on top in \(pool.name).",
                    identifier: "lead-\(pool.id.uuidString)"
                )
                UserDefaults.standard.set(winningSquare.id.uuidString, forKey: key)
            }
        } else {
            // Reset so we can notify again if they take the lead later
            let key = "gc_lead_\(pool.id.uuidString)"
            UserDefaults.standard.removeObject(forKey: key)
        }

        // 2) Period just ended (quarter, halftime, final) → notify winner (only if this pool pays that period)
        if let prev = previousScore {
            let periodKey: String? = periodJustEnded(previous: prev, current: score, pool: pool)
            if let periodId = periodKey,
               pool.resolvedPoolStructure.periods.contains(where: { $0.id == periodId }) {
                let key = "gc_period_\(pool.id.uuidString)_\(periodId)"
                guard !UserDefaults.standard.bool(forKey: key) else { return }
                // Winner: at end of period. For Final use current score; for quarter/halftime use previous (end of that period).
                let periodWinner = periodId == "Final" ? pool.winningSquare(for: score) : pool.winningSquare(for: prev)
                let winnerName = (periodWinner?.playerName.isEmpty ?? true) ? "Someone" : (periodWinner?.playerName ?? "Someone")
                let periodLabel = periodId.replacingOccurrences(of: "_", with: " ")
                NotificationService.scheduleLocal(
                    title: "\(periodLabel) winner",
                    body: "\(winnerName) won \(periodLabel) in \(pool.name).",
                    identifier: "period-\(pool.id.uuidString)-\(periodId)"
                )
                UserDefaults.standard.set(true, forKey: key)
            }
        }

        // 3) Your square is one score away (throttled): would win if home or away last digit changed by ±1
        if !ownerLabels.isEmpty {
            let mySquares = pool.squaresForOwner(ownerLabels: ownerLabels)
            let currentH = score.homeLastDigit
            let currentA = score.awayLastDigit
            func digitAdjacent(_ a: Int, _ b: Int) -> Bool {
                let d = abs(a - b)
                return d == 1 || d == 9 // 9 and 0 are adjacent mod 10
            }
            let oneDigitAway = mySquares.contains { mySq in
                let myHomeDigit = pool.homeNumbers[mySq.column]
                let myAwayDigit = pool.awayNumbers[mySq.row]
                let homeOneAway = digitAdjacent(myHomeDigit, currentH) && myAwayDigit == currentA
                let awayOneAway = digitAdjacent(myAwayDigit, currentA) && myHomeDigit == currentH
                return homeOneAway || awayOneAway
            }
            if oneDigitAway {
                let key = "gc_oneAway_\(pool.id.uuidString)"
                let last = UserDefaults.standard.double(forKey: key)
                let now = Date().timeIntervalSince1970
                if last == 0 || (now - last) >= oneScoreAwayCooldown {
                    NotificationService.scheduleLocal(
                        title: "So close!",
                        body: "A square of yours in \(pool.name) is one score away from winning.",
                        identifier: "oneAway-\(pool.id.uuidString)"
                    )
                    UserDefaults.standard.set(now, forKey: key)
                }
            }
        }
    }

    /// Returns period id if that period just ended (e.g. "Halftime", "Q1", "Final").
    private static func periodJustEnded(previous: GameScore, current: GameScore, pool: BoxGrid) -> String? {
        if current.isGameOver && !previous.isGameOver {
            return "Final"
        }
        // Halftime: we were in Q2, now in Q3 (or game over)
        if previous.quarter == 2 && current.quarter >= 3 {
            return "Halftime"
        }
        // Quarter end: Q1→Q2, Q2→Q3, Q3→Q4
        if current.quarter == previous.quarter + 1 && previous.quarter >= 1 && previous.quarter <= 4 {
            return "Q\(previous.quarter)"
        }
        return nil
    }
}

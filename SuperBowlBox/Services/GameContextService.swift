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
                let scoreText = periodId == "Final" ? " Final: \(score.awayScore)-\(score.homeScore)." : ""
                NotificationService.scheduleLocal(
                    title: "\(periodLabel) winner",
                    body: "\(winnerName) won \(periodLabel) in \(pool.name).\(scoreText)",
                    identifier: "period-\(pool.id.uuidString)-\(periodId)"
                )
                UserDefaults.standard.set(true, forKey: key)
            }
        }

        // 3) Your square is one score away (throttled): tell them who and what needs to happen (e.g. "Mike just needs one more score from Seattle to take the quarter")
        if !ownerLabels.isEmpty {
            let mySquares = pool.squaresForOwner(ownerLabels: ownerLabels)
            let currentH = score.homeLastDigit
            let currentA = score.awayLastDigit
            func digitAdjacent(_ a: Int, _ b: Int) -> Bool {
                let d = abs(a - b)
                return d == 1 || d == 9 // 9 and 0 are adjacent mod 10
            }
            typealias OneAway = (square: BoxSquare, teamNeedsToScore: Team)
            var oneAwayList: [OneAway] = []
            for mySq in mySquares {
                let myHomeDigit = pool.homeNumbers[mySq.column]
                let myAwayDigit = pool.awayNumbers[mySq.row]
                let homeOneAway = digitAdjacent(myHomeDigit, currentH) && myAwayDigit == currentA
                let awayOneAway = digitAdjacent(myAwayDigit, currentA) && myHomeDigit == currentH
                if homeOneAway { oneAwayList.append((mySq, pool.homeTeam)) }
                else if awayOneAway { oneAwayList.append((mySq, pool.awayTeam)) }
            }
            if !oneAwayList.isEmpty {
                let key = "gc_oneAway_\(pool.id.uuidString)"
                let last = UserDefaults.standard.double(forKey: key)
                let now = Date().timeIntervalSince1970
                if last == 0 || (now - last) >= oneScoreAwayCooldown {
                    let (title, body) = oneScoreAwayMessage(
                        oneAwayList: oneAwayList,
                        pool: pool,
                        score: score
                    )
                    NotificationService.scheduleLocal(
                        title: title,
                        body: body,
                        identifier: "oneAway-\(pool.id.uuidString)"
                    )
                    UserDefaults.standard.set(now, forKey: key)
                }
            }
        }
    }

    /// Builds contextual title/body for "one score away" (e.g. "Mike just needs one more score from Seattle to take Q3").
    private static func oneScoreAwayMessage(
        oneAwayList: [(square: BoxSquare, teamNeedsToScore: Team)],
        pool: BoxGrid,
        score: GameScore
    ) -> (title: String, body: String) {
        let periodText = currentPeriodText(for: score)
        let teamShortName: (Team) -> String = { team in
            team.name.split(separator: " ").first.map(String.init) ?? team.name
        }
        if let first = oneAwayList.first {
            let name = first.square.displayName
            let team = teamShortName(first.teamNeedsToScore)
            if oneAwayList.count == 1 {
                return (
                    "So close!",
                    "\(name) just needs one more score from \(team) to take \(periodText) in \(pool.name)."
                )
            }
            let teams = Set(oneAwayList.map { teamShortName($0.teamNeedsToScore) })
            if teams.count == 1 {
                return (
                    "So close!",
                    "\(name) is one score away in \(pool.name) — \(teams.first!) could do it for \(periodText)."
                )
            }
            return (
                "So close!",
                "\(name) could take \(periodText) in \(pool.name) with one more score from \(Array(teams).sorted().joined(separator: " or "))."
            )
        }
        return ("So close!", "A square of yours in \(pool.name) is one score away from winning.")
    }

    private static func currentPeriodText(for score: GameScore) -> String {
        if score.quarter == 2 { return "halftime" }
        if score.quarter >= 1 && score.quarter <= 4 { return "Q\(score.quarter)" }
        if score.isGameOver { return "the game" }
        return "the quarter"
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

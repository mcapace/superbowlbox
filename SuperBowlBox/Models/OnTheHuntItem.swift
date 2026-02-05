import Foundation
import SwiftUI

/// A square that is "on the hunt" — one score away from winning. Points needed = minimum points that team could score to make this square win.
struct OnTheHuntItem: Identifiable {
    let square: BoxSquare
    let pool: BoxGrid
    let poolName: String
    let teamNeedsToScore: Team
    /// Minimum points that team could score to flip last digit (1–9). Used for urgency band.
    let pointsNeeded: Int

    var id: String { "\(pool.id.uuidString)-\(square.id.uuidString)" }

    /// Urgency: 1–3 one FG/safety, 4–6 one TD, 7–9 close
    enum Urgency {
        case oneFG   // 1–3 pts, red
        case oneTD   // 4–6 pts, gold
        case close   // 7–9 pts, blue
    }

    var urgency: Urgency {
        switch pointsNeeded {
        case 1...3: return .oneFG
        case 4...6: return .oneTD
        default: return .close
        }
    }

    var urgencyLabel: String {
        switch urgency {
        case .oneFG: return "1–3 pts"
        case .oneTD: return "4–6 pts"
        case .close: return "7 pts"
        }
    }

    var teamShortName: String {
        teamNeedsToScore.name.split(separator: " ").first.map(String.init) ?? teamNeedsToScore.name
    }
}

// MARK: - Compute on-the-hunt squares for a pool
extension BoxGrid {
    /// My squares that are one digit away from winning. Returns items with which team needs to score and points band.
    func onTheHuntItems(score: GameScore, ownerLabels: [String]) -> [OnTheHuntItem] {
        let mySquares = squaresForOwner(ownerLabels: ownerLabels)
        let ch = score.homeLastDigit
        let ca = score.awayLastDigit
        func digitDelta(_ current: Int, _ target: Int) -> Int {
            let d = (target - current + 10) % 10
            return d == 0 ? 10 : d // 10 = already there
        }
        var result: [OnTheHuntItem] = []
        for sq in mySquares {
            let myHome = homeNumbers[sq.column]
            let myAway = awayNumbers[sq.row]
            let homeDelta = digitDelta(ch, myHome)
            let awayDelta = digitDelta(ca, myAway)
            if homeDelta == 10 && awayDelta == 10 { continue } // already winning
            if homeDelta < 10 && ca == myAway {
                result.append(OnTheHuntItem(
                    square: sq,
                    pool: self,
                    poolName: name,
                    teamNeedsToScore: homeTeam,
                    pointsNeeded: homeDelta
                ))
            }
            if awayDelta < 10 && ch == myHome {
                result.append(OnTheHuntItem(
                    square: sq,
                    pool: self,
                    poolName: name,
                    teamNeedsToScore: awayTeam,
                    pointsNeeded: awayDelta
                ))
            }
        }
        return result
    }
}

import Foundation
import UserNotifications
import UIKit

class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var isAuthorized = false
    @Published var pendingNotifications: [String] = []

    private init() {
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.isAuthorized = granted
            }
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Score Change Notifications

    func notifyScoreChange(
        oldScore: GameScore,
        newScore: GameScore,
        pools: [BoxGrid],
        myName: String
    ) {
        // Only notify if score actually changed
        guard oldScore.homeScore != newScore.homeScore ||
              oldScore.awayScore != newScore.awayScore else {
            return
        }

        // Check each pool for winner changes
        for pool in pools {
            let oldWinner = pool.winningSquare(for: oldScore)
            let newWinner = pool.winningSquare(for: newScore)

            // New winner notification
            if let winner = newWinner, winner.id != oldWinner?.id {
                scheduleWinnerNotification(
                    winner: winner,
                    pool: pool,
                    score: newScore,
                    isMe: winner.playerName.lowercased().contains(myName.lowercased()) && !myName.isEmpty
                )
            }

            // Check "On the Hunt" status for my squares
            if !myName.isEmpty {
                checkOnTheHunt(
                    pool: pool,
                    score: newScore,
                    myName: myName
                )
            }
        }
    }

    func scheduleWinnerNotification(
        winner: BoxSquare,
        pool: BoxGrid,
        score: GameScore,
        isMe: Bool
    ) {
        let content = UNMutableNotificationContent()

        if isMe {
            content.title = "You're Winning! 🏆"
            content.body = "Score \(score.awayScore)-\(score.homeScore) in \(pool.name)!"
            content.sound = .default
            Haptics.winner()
        } else {
            content.title = "New Leader in \(pool.name)"
            content.body = "\(winner.displayName) takes the lead! (\(score.awayLastDigit)-\(score.homeLastDigit))"
            content.sound = .default
        }

        content.userInfo = [
            "poolId": pool.id.uuidString,
            "type": "winner"
        ]

        let request = UNNotificationRequest(
            identifier: "winner-\(pool.id)-\(score.homeScore)-\(score.awayScore)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - On The Hunt

    func checkOnTheHunt(
        pool: BoxGrid,
        score: GameScore,
        myName: String
    ) {
        let mySquares = pool.squares(for: myName)
        guard !mySquares.isEmpty else { return }

        // Find squares that are "on the hunt" (1-2 points away from winning)
        let huntSquares = findOnTheHuntSquares(
            mySquares: mySquares,
            pool: pool,
            score: score
        )

        for huntSquare in huntSquares {
            scheduleHuntNotification(
                square: huntSquare.square,
                pointsAway: huntSquare.pointsAway,
                team: huntSquare.team,
                pool: pool,
                score: score
            )
        }
    }

    struct HuntSquare {
        let square: BoxSquare
        let pointsAway: Int
        let team: String // Which team needs to score
    }

    func findOnTheHuntSquares(
        mySquares: [BoxSquare],
        pool: BoxGrid,
        score: GameScore
    ) -> [HuntSquare] {
        var huntSquares: [HuntSquare] = []

        let currentAwayDigit = score.awayLastDigit
        let currentHomeDigit = score.homeLastDigit

        for square in mySquares {
            let squareAwayDigit = pool.awayNumbers[square.row]
            let squareHomeDigit = pool.homeNumbers[square.column]

            // Check if away team scoring would help
            let awayPointsNeeded = pointsToReachDigit(from: score.awayScore, targetDigit: squareAwayDigit)
            let homeMatches = squareHomeDigit == currentHomeDigit

            if awayPointsNeeded > 0 && awayPointsNeeded <= 7 && homeMatches {
                huntSquares.append(HuntSquare(
                    square: square,
                    pointsAway: awayPointsNeeded,
                    team: score.awayTeam.abbreviation
                ))
            }

            // Check if home team scoring would help
            let homePointsNeeded = pointsToReachDigit(from: score.homeScore, targetDigit: squareHomeDigit)
            let awayMatches = squareAwayDigit == currentAwayDigit

            if homePointsNeeded > 0 && homePointsNeeded <= 7 && awayMatches {
                huntSquares.append(HuntSquare(
                    square: square,
                    pointsAway: homePointsNeeded,
                    team: score.homeTeam.abbreviation
                ))
            }
        }

        // Only return the closest opportunities
        return huntSquares.sorted { $0.pointsAway < $1.pointsAway }.prefix(3).map { $0 }
    }

    private func pointsToReachDigit(from currentScore: Int, targetDigit: Int) -> Int {
        let currentDigit = currentScore % 10
        if currentDigit == targetDigit { return 0 }

        // Calculate minimum points to reach target digit
        var diff = targetDigit - currentDigit
        if diff < 0 { diff += 10 }

        return diff
    }

    func scheduleHuntNotification(
        square: BoxSquare,
        pointsAway: Int,
        team: String,
        pool: BoxGrid,
        score: GameScore
    ) {
        // Only notify for very close opportunities (FG or TD away)
        guard pointsAway <= 7 else { return }

        // Avoid spamming - use a unique identifier based on the square and current score
        let identifier = "hunt-\(square.id)-\(score.homeScore)-\(score.awayScore)"

        // Check if we already sent this notification
        if pendingNotifications.contains(identifier) { return }
        pendingNotifications.append(identifier)

        let content = UNMutableNotificationContent()

        if pointsAway <= 3 {
            content.title = "You're ON THE HUNT! 🎯"
            content.body = "One \(team) FG and your square (\(pool.awayNumbers[square.row])-\(pool.homeNumbers[square.column])) wins!"
        } else {
            content.title = "Close Call! 🏈"
            content.body = "One \(team) TD could give you the lead in \(pool.name)!"
        }

        content.userInfo = [
            "poolId": pool.id.uuidString,
            "squareId": square.id.uuidString,
            "type": "hunt"
        ]

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Quarter End Notifications

    func notifyQuarterEnd(
        quarter: Int,
        score: GameScore,
        pools: [BoxGrid],
        myName: String
    ) {
        for pool in pools {
            guard let winner = pool.winningSquare(for: score) else { continue }

            let isMe = !myName.isEmpty &&
                winner.playerName.lowercased().contains(myName.lowercased())

            let content = UNMutableNotificationContent()

            if isMe {
                content.title = "Q\(quarter) WIN! 🏆🎉"
                content.body = "You won Q\(quarter) in \(pool.name)! Score: \(score.awayScore)-\(score.homeScore)"
                content.sound = UNNotificationSound.default
                Haptics.winner()
            } else {
                content.title = "Q\(quarter) Winner: \(winner.displayName)"
                content.body = "\(pool.name): \(score.awayTeam.abbreviation) \(score.awayScore) - \(score.homeScore) \(score.homeTeam.abbreviation)"
                content.sound = .default
            }

            content.userInfo = [
                "poolId": pool.id.uuidString,
                "quarter": quarter,
                "type": "quarter_end"
            ]

            let request = UNNotificationRequest(
                identifier: "quarter-\(pool.id)-Q\(quarter)",
                content: content,
                trigger: nil
            )

            UNUserNotificationCenter.current().add(request)
        }
    }

    // MARK: - Game Start/End

    func notifyGameStart(score: GameScore) {
        let content = UNMutableNotificationContent()
        content.title = "Game Time! 🏈"
        content.body = "\(score.awayTeam.name) vs \(score.homeTeam.name) is starting!"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "game-start",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func notifyGameEnd(score: GameScore, pools: [BoxGrid], myName: String) {
        // Calculate total winnings
        var myWins = 0
        for pool in pools {
            let mySquares = pool.squares(for: myName)
            myWins += mySquares.filter { $0.isWinner }.count
        }

        let content = UNMutableNotificationContent()
        content.title = "Final Score!"
        content.body = "\(score.awayTeam.abbreviation) \(score.awayScore) - \(score.homeScore) \(score.homeTeam.abbreviation)"

        if myWins > 0 {
            content.body += "\nYou won \(myWins) quarter(s)! 🎉"
        }

        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "game-end",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Clear Notifications

    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        pendingNotifications.removeAll()
    }
}

// MARK: - Live Activity Support (iOS 16.1+)
#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
struct GameActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var awayScore: Int
        var homeScore: Int
        var quarter: Int
        var timeRemaining: String
        var winnerName: String?
        var isMyWinner: Bool
    }

    var gameId: String
    var awayTeam: String
    var homeTeam: String
    var poolName: String
}

@available(iOS 16.1, *)
class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<GameActivityAttributes>?

    func startActivity(
        gameId: String,
        awayTeam: String,
        homeTeam: String,
        poolName: String,
        initialState: GameActivityAttributes.ContentState
    ) {
        let attributes = GameActivityAttributes(
            gameId: gameId,
            awayTeam: awayTeam,
            homeTeam: homeTeam,
            poolName: poolName
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
        } catch {
            print("Error starting live activity: \(error)")
        }
    }

    func updateActivity(state: GameActivityAttributes.ContentState) {
        Task {
            await currentActivity?.update(
                ActivityContent(state: state, staleDate: nil)
            )
        }
    }

    func endActivity(state: GameActivityAttributes.ContentState) {
        Task {
            await currentActivity?.end(
                ActivityContent(state: state, staleDate: nil),
                dismissalPolicy: .default
            )
        }
    }
}
#endif

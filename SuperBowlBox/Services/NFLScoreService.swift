import Foundation
import Combine

class NFLScoreService: ObservableObject {
    @Published var currentScore: GameScore?
    @Published var isLoading = false
    @Published var error: ScoreError?
    @Published var lastUpdated: Date?
    @Published var onTheHuntSquares: [OnTheHuntInfo] = []

    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var previousScore: GameScore?
    private var previousQuarter: Int = 0

    // API Configuration - Add your SportsData.io key here
    private let sportsDataApiKey: String? = nil // Set via environment or config

    enum ScoreError: Error, LocalizedError {
        case networkError(Error)
        case decodingError
        case noGameFound
        case apiError(String)

        var errorDescription: String? {
            switch self {
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .decodingError:
                return "Failed to decode score data"
            case .noGameFound:
                return "No game found"
            case .apiError(let message):
                return "API error: \(message)"
            }
        }
    }

    struct OnTheHuntInfo: Identifiable {
        let id = UUID()
        let playerName: String
        let squareNumbers: String
        let pointsAway: Int
        let scoringTeam: String
        let poolName: String
    }

    init() {
        currentScore = GameScore.mock
    }

    func startLiveUpdates(interval: TimeInterval = 30) {
        stopLiveUpdates()

        Task {
            await fetchCurrentScore()
        }

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task {
                await self?.fetchCurrentScore()
            }
        }
    }

    func stopLiveUpdates() {
        timer?.invalidate()
        timer = nil
    }

    @MainActor
    func fetchCurrentScore() async {
        isLoading = true
        error = nil

        do {
            let oldScore = currentScore
            let score = try await fetchScoreFromAPI()

            // Check for score changes and send notifications
            if let old = oldScore, let pools = getPools() {
                handleScoreChange(oldScore: old, newScore: score, pools: pools)
            }

            // Check for quarter changes
            if score.quarter != previousQuarter && previousQuarter > 0 {
                handleQuarterEnd(quarter: previousQuarter, score: score)
            }

            previousScore = oldScore
            previousQuarter = score.quarter
            currentScore = score
            lastUpdated = Date()
        } catch let err as ScoreError {
            error = err
        } catch {
            self.error = .networkError(error)
        }

        isLoading = false
    }

    // MARK: - API Fetching

    private func fetchScoreFromAPI() async throws -> GameScore {
        // Try SportsData.io first if API key is available
        if let apiKey = sportsDataApiKey {
            do {
                return try await fetchFromSportsDataIO(apiKey: apiKey)
            } catch {
                print("SportsData.io failed, falling back to ESPN: \(error)")
            }
        }

        // Fallback to ESPN (free, no auth required)
        return try await fetchFromESPN()
    }

    // MARK: - SportsData.io API

    private func fetchFromSportsDataIO(apiKey: String) async throws -> GameScore {
        // Get current season and week
        let urlString = "https://api.sportsdata.io/v3/nfl/scores/json/ScoresByWeek/2024REG/1?key=\(apiKey)"

        guard let url = URL(string: urlString) else {
            throw ScoreError.apiError("Invalid URL")
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ScoreError.apiError("Invalid response")
        }

        return try parseSportsDataIOResponse(data)
    }

    private func parseSportsDataIOResponse(_ data: Data) throws -> GameScore {
        guard let games = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let game = games.first(where: { ($0["IsInProgress"] as? Bool) == true }) ?? games.first else {
            throw ScoreError.noGameFound
        }

        let homeTeam = Team(
            name: game["HomeTeam"] as? String ?? "Home",
            abbreviation: game["HomeTeam"] as? String ?? "HM",
            primaryColor: "#003366"
        )

        let awayTeam = Team(
            name: game["AwayTeam"] as? String ?? "Away",
            abbreviation: game["AwayTeam"] as? String ?? "AW",
            primaryColor: "#990000"
        )

        let homeScore = game["HomeScore"] as? Int ?? 0
        let awayScore = game["AwayScore"] as? Int ?? 0
        let quarter = game["Quarter"] as? Int ?? 0
        let timeRemaining = game["TimeRemaining"] as? String ?? "15:00"
        let isActive = game["IsInProgress"] as? Bool ?? false
        let isOver = game["IsOver"] as? Bool ?? false

        var quarterScores = QuarterScores()
        quarterScores.q1Home = game["HomeScoreQuarter1"] as? Int ?? 0
        quarterScores.q1Away = game["AwayScoreQuarter1"] as? Int ?? 0
        quarterScores.q2Home = game["HomeScoreQuarter2"] as? Int ?? 0
        quarterScores.q2Away = game["AwayScoreQuarter2"] as? Int ?? 0
        quarterScores.q3Home = game["HomeScoreQuarter3"] as? Int ?? 0
        quarterScores.q3Away = game["AwayScoreQuarter3"] as? Int ?? 0
        quarterScores.q4Home = game["HomeScoreQuarter4"] as? Int ?? 0
        quarterScores.q4Away = game["AwayScoreQuarter4"] as? Int ?? 0

        return GameScore(
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            homeScore: homeScore,
            awayScore: awayScore,
            quarter: quarter,
            timeRemaining: timeRemaining,
            isGameActive: isActive,
            isGameOver: isOver,
            quarterScores: quarterScores
        )
    }

    // MARK: - ESPN API (Fallback)

    private func fetchFromESPN() async throws -> GameScore {
        let urlString = "https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard"

        guard let url = URL(string: urlString) else {
            throw ScoreError.apiError("Invalid URL")
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ScoreError.apiError("Invalid response")
        }

        return try parseESPNResponse(data)
    }

    private func parseESPNResponse(_ data: Data) throws -> GameScore {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let events = json["events"] as? [[String: Any]] else {
            throw ScoreError.decodingError
        }

        for event in events {
            guard let competitions = event["competitions"] as? [[String: Any]],
                  let competition = competitions.first,
                  let competitors = competition["competitors"] as? [[String: Any]] else {
                continue
            }

            let name = event["name"] as? String ?? ""
            let isSuperBowl = name.lowercased().contains("super bowl")
            let isPlayoff = (event["season"] as? [String: Any])?["type"] as? Int == 3

            if isSuperBowl || isPlayoff || events.count == 1 {
                return try parseESPNCompetition(competition, competitors: competitors)
            }
        }

        if let event = events.first,
           let competitions = event["competitions"] as? [[String: Any]],
           let competition = competitions.first,
           let competitors = competition["competitors"] as? [[String: Any]] {
            return try parseESPNCompetition(competition, competitors: competitors)
        }

        throw ScoreError.noGameFound
    }

    private func parseESPNCompetition(_ competition: [String: Any], competitors: [[String: Any]]) throws -> GameScore {
        var homeTeam: Team = .chiefs
        var awayTeam: Team = .eagles
        var homeScore = 0
        var awayScore = 0

        for competitor in competitors {
            let isHome = competitor["homeAway"] as? String == "home"
            let score = Int(competitor["score"] as? String ?? "0") ?? 0

            if let team = competitor["team"] as? [String: Any] {
                let name = team["displayName"] as? String ?? "Team"
                let abbrev = team["abbreviation"] as? String ?? "TM"
                let color = team["color"] as? String ?? "000000"

                let teamObj = Team(
                    name: name,
                    abbreviation: abbrev,
                    primaryColor: "#\(color)"
                )

                if isHome {
                    homeTeam = teamObj
                    homeScore = score
                } else {
                    awayTeam = teamObj
                    awayScore = score
                }
            }
        }

        let status = competition["status"] as? [String: Any]
        let statusType = status?["type"] as? [String: Any]
        let statusName = statusType?["name"] as? String ?? "STATUS_SCHEDULED"
        let period = status?["period"] as? Int ?? 0
        let clock = status?["displayClock"] as? String ?? "15:00"

        let isActive = statusName == "STATUS_IN_PROGRESS"
        let isOver = statusName == "STATUS_FINAL"

        var quarterScores = QuarterScores()
        for competitor in competitors {
            let isHome = competitor["homeAway"] as? String == "home"
            if let linescores = competitor["linescores"] as? [[String: Any]] {
                for (index, linescore) in linescores.enumerated() {
                    let value = linescore["value"] as? Int ?? 0
                    switch index {
                    case 0: isHome ? (quarterScores.q1Home = value) : (quarterScores.q1Away = value)
                    case 1: isHome ? (quarterScores.q2Home = value) : (quarterScores.q2Away = value)
                    case 2: isHome ? (quarterScores.q3Home = value) : (quarterScores.q3Away = value)
                    case 3: isHome ? (quarterScores.q4Home = value) : (quarterScores.q4Away = value)
                    default: break
                    }
                }
            }
        }

        return GameScore(
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            homeScore: homeScore,
            awayScore: awayScore,
            quarter: period,
            timeRemaining: clock,
            isGameActive: isActive,
            isGameOver: isOver,
            quarterScores: quarterScores
        )
    }

    // MARK: - Notification Handling

    private func handleScoreChange(oldScore: GameScore, newScore: GameScore, pools: [BoxGrid]) {
        guard oldScore.homeScore != newScore.homeScore ||
              oldScore.awayScore != newScore.awayScore else {
            return
        }

        // Get myName from UserDefaults
        let myName = UserDefaults.standard.string(forKey: "myName") ?? ""

        // Notify via NotificationService
        NotificationService.shared.notifyScoreChange(
            oldScore: oldScore,
            newScore: newScore,
            pools: pools,
            myName: myName
        )

        // Update on-the-hunt squares
        updateOnTheHuntSquares(score: newScore, pools: pools, myName: myName)
    }

    private func handleQuarterEnd(quarter: Int, score: GameScore) {
        guard let pools = getPools() else { return }
        let myName = UserDefaults.standard.string(forKey: "myName") ?? ""

        NotificationService.shared.notifyQuarterEnd(
            quarter: quarter,
            score: score,
            pools: pools,
            myName: myName
        )
    }

    private func getPools() -> [BoxGrid]? {
        let decoder = JSONDecoder()
        guard let data = UserDefaults.standard.data(forKey: "savedPools"),
              let pools = try? decoder.decode([BoxGrid].self, from: data) else {
            return nil
        }
        return pools
    }

    // MARK: - On The Hunt Tracking

    func updateOnTheHuntSquares(score: GameScore, pools: [BoxGrid], myName: String) {
        guard !myName.isEmpty else {
            onTheHuntSquares = []
            return
        }

        var huntSquares: [OnTheHuntInfo] = []

        for pool in pools {
            let mySquares = pool.squares(for: myName)

            for square in mySquares {
                let rowDigit = pool.awayNumbers[square.row]
                let colDigit = pool.homeNumbers[square.column]

                // Check how far away this square is from winning
                let awayDiff = pointsToDigit(from: score.awayScore, to: rowDigit)
                let homeDiff = pointsToDigit(from: score.homeScore, to: colDigit)

                // If one digit matches and the other is close (1-7 points)
                if score.awayLastDigit == rowDigit && homeDiff > 0 && homeDiff <= 7 {
                    huntSquares.append(OnTheHuntInfo(
                        playerName: square.playerName,
                        squareNumbers: "\(rowDigit)-\(colDigit)",
                        pointsAway: homeDiff,
                        scoringTeam: score.homeTeam.abbreviation,
                        poolName: pool.name
                    ))
                } else if score.homeLastDigit == colDigit && awayDiff > 0 && awayDiff <= 7 {
                    huntSquares.append(OnTheHuntInfo(
                        playerName: square.playerName,
                        squareNumbers: "\(rowDigit)-\(colDigit)",
                        pointsAway: awayDiff,
                        scoringTeam: score.awayTeam.abbreviation,
                        poolName: pool.name
                    ))
                }
            }
        }

        // Sort by closest to winning
        onTheHuntSquares = huntSquares.sorted { $0.pointsAway < $1.pointsAway }
    }

    private func pointsToDigit(from currentScore: Int, to targetDigit: Int) -> Int {
        let currentDigit = currentScore % 10
        if currentDigit == targetDigit { return 0 }

        var diff = targetDigit - currentDigit
        if diff < 0 { diff += 10 }
        return diff
    }

    // MARK: - Manual Controls

    func setManualScore(homeScore: Int, awayScore: Int, quarter: Int = 1) {
        let oldScore = currentScore
        var score = currentScore ?? GameScore.mock
        score.homeScore = homeScore
        score.awayScore = awayScore
        score.quarter = quarter
        score.isGameActive = true
        currentScore = score
        lastUpdated = Date()

        // Trigger notifications
        if let old = oldScore, let pools = getPools() {
            handleScoreChange(oldScore: old, newScore: score, pools: pools)
        }
    }

    func setTeams(home: Team, away: Team) {
        var score = currentScore ?? GameScore.mock
        score.homeTeam = home
        score.awayTeam = away
        currentScore = score
    }

    func simulateScoreChange() {
        guard var score = currentScore else { return }

        let oldScore = score
        let points = [3, 6, 7].randomElement() ?? 3
        if Bool.random() {
            score.homeScore += points
        } else {
            score.awayScore += points
        }

        currentScore = score
        lastUpdated = Date()

        // Trigger notifications
        if let pools = getPools() {
            handleScoreChange(oldScore: oldScore, newScore: score, pools: pools)
        }
    }

    deinit {
        stopLiveUpdates()
    }
}

// MARK: - Demo Support
extension NFLScoreService {
    static let demo: NFLScoreService = {
        let service = NFLScoreService()
        service.currentScore = GameScore.mock
        return service
    }()
}

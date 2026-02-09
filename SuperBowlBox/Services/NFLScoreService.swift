import Foundation
import Combine

class NFLScoreService: ObservableObject {
    @Published var currentScore: GameScore?
    @Published var isLoading = false
    @Published var error: ScoreError?
    @Published var lastUpdated: Date?

    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

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

    init() {
        // No mock: show loading/up-next until real API data loads
        currentScore = nil
    }

    func startLiveUpdates(interval: TimeInterval = 30) {
        stopLiveUpdates()

        // Fetch immediately so live scores appear as soon as the app is ready
        Task {
            await fetchCurrentScore()
        }

        // Poll every interval (e.g. 30s); use .common run loop mode so timer fires even while user scrolls
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task {
                await self?.fetchCurrentScore()
            }
        }
        if let t = timer {
            RunLoop.main.add(t, forMode: .common)
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
            let score = try await fetchScoreFromAPI()
            currentScore = score
            lastUpdated = Date()
        } catch let err as ScoreError {
            error = err
        } catch {
            self.error = .networkError(error)
        }

        isLoading = false
    }

    private func fetchScoreFromAPI() async throws -> GameScore {
        // Primary: ESPN scoreboard (no key, same structure we parse; correct game/quarter/scores for playoff/Super Bowl)
        let urlString = "https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard"
        if let url = URL(string: urlString) {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    return try parseESPNResponse(data)
                }
            } catch {
                // Fall through to Sports Data IO if ESPN fails
            }
        }

        // Fallback: Sports Data IO when API key is set (if ESPN failed or returned no game)
        if SportsDataIOConfig.isConfigured {
            return try await SportsDataIOService.fetchNFLScore()
        }

        throw ScoreError.noGameFound
    }

    /// Featured game is always from API (Sports Data IO if configured, else ESPN scoreboard). Prefer Super Bowl when present.
    private func parseESPNResponse(_ data: Data) throws -> GameScore {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let events = json["events"] as? [[String: Any]] else {
            throw ScoreError.decodingError
        }

        // 1) Prefer Super Bowl by event name or competition notes (e.g. "Super Bowl LX")
        for event in events {
            let name = event["name"] as? String ?? ""
            let competitions = event["competitions"] as? [[String: Any]] ?? []
            guard let competition = competitions.first,
                  let competitors = competition["competitors"] as? [[String: Any]] else { continue }
            let notes = competition["notes"] as? [[String: Any]] ?? []
            let notesHeadline = notes.first?["headline"] as? String ?? ""
            if name.lowercased().contains("super bowl") || notesHeadline.lowercased().contains("super bowl") {
                return try parseCompetition(competition, competitors: competitors, scheduledStart: parseEventDate(event))
            }
        }

        // 2) Else prefer any playoff game
        let playoffType = 3
        for event in events {
            guard (event["season"] as? [String: Any])?["type"] as? Int == playoffType,
                  let competitions = event["competitions"] as? [[String: Any]],
                  let competition = competitions.first,
                  let competitors = competition["competitors"] as? [[String: Any]] else {
                continue
            }
            return try parseCompetition(competition, competitors: competitors, scheduledStart: parseEventDate(event))
        }

        // 3) Else single game or first game in list
        if events.count == 1, let event = events.first,
           let competitions = event["competitions"] as? [[String: Any]],
           let competition = competitions.first,
           let competitors = competition["competitors"] as? [[String: Any]] {
            return try parseCompetition(competition, competitors: competitors, scheduledStart: parseEventDate(event))
        }
        if let event = events.first,
           let competitions = event["competitions"] as? [[String: Any]],
           let competition = competitions.first,
           let competitors = competition["competitors"] as? [[String: Any]] {
            return try parseCompetition(competition, competitors: competitors, scheduledStart: parseEventDate(event))
        }

        throw ScoreError.noGameFound
    }

    /// ESPN may return numbers as Int or Double in JSON; normalize to Int for score/period/linescore.
    private func intFromJSON(_ value: Any?) -> Int {
        guard let v = value else { return 0 }
        if let n = v as? Int { return n }
        if let n = v as? NSNumber { return n.intValue }
        if let n = v as? Double { return Int(n) }
        return 0
    }

    private func parseEventDate(_ event: [String: Any]) -> Date? {
        guard let dateString = event["date"] as? String else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }

    private func parseCompetition(_ competition: [String: Any], competitors: [[String: Any]], scheduledStart: Date? = nil) throws -> GameScore {
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
                var logoURL = team["logo"] as? String
                if logoURL?.isEmpty == true { logoURL = nil }
                // When API gives no logo, leave logoURL nil so Team.displayLogoURL uses espnLogoURL(abbreviation:) with slug mapping (e.g. SE -> sea)

                let teamObj = Team(
                    name: name,
                    abbreviation: abbrev,
                    primaryColor: "#\(color)",
                    logoURL: logoURL
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

        // Parse game status (ESPN puts it under situation.status when game is in progress, else competition.status)
        let situation = competition["situation"] as? [String: Any]
        let status = (situation?["status"] as? [String: Any]) ?? (competition["status"] as? [String: Any])
        let statusType = status?["type"] as? [String: Any]
        let statusName = statusType?["name"] as? String ?? "STATUS_SCHEDULED"
        let period = (status?["period"] as? Int) ?? (status?["period"] as? NSNumber)?.intValue ?? 0
        let clock = status?["displayClock"] as? String ?? "15:00"

        let isActive = statusName == "STATUS_IN_PROGRESS"
        let isOver = statusName == "STATUS_FINAL"

        // Parse quarter scores: each competitor has linescores (value can be Int or Double in JSON)
        var quarterScores = QuarterScores()
        for competitor in competitors {
            let isHome = competitor["homeAway"] as? String == "home"
            guard let linescores = competitor["linescores"] as? [[String: Any]] else { continue }
            for (index, linescore) in linescores.enumerated() {
                let value = intFromJSON(linescore["value"])
                switch index {
                case 0: if isHome { quarterScores.q1Home = value } else { quarterScores.q1Away = value }
                case 1: if isHome { quarterScores.q2Home = value } else { quarterScores.q2Away = value }
                case 2: if isHome { quarterScores.q3Home = value } else { quarterScores.q3Away = value }
                case 3: if isHome { quarterScores.q4Home = value } else { quarterScores.q4Away = value }
                default: break
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
            quarterScores: quarterScores,
            scheduledStart: scheduledStart
        )
    }

    // Manual score entry for testing or when API isn't available
    func setManualScore(homeScore: Int, awayScore: Int, quarter: Int = 1) {
        var score = currentScore ?? GameScore.mock
        score.homeScore = homeScore
        score.awayScore = awayScore
        score.quarter = quarter
        score.isGameActive = true
        currentScore = score
        lastUpdated = Date()
    }

    func setTeams(home: Team, away: Team) {
        var score = currentScore ?? GameScore.mock
        score.homeTeam = home
        score.awayTeam = away
        currentScore = score
    }

    deinit {
        stopLiveUpdates()
    }
}

// MARK: - Demo/Testing Support
extension NFLScoreService {
    static let demo: NFLScoreService = {
        let service = NFLScoreService()
        service.currentScore = GameScore.mock
        return service
    }()

    func simulateScoreChange() {
        guard var score = currentScore else { return }

        // Randomly add points
        let points = [3, 6, 7].randomElement() ?? 3
        if Bool.random() {
            score.homeScore += points
        } else {
            score.awayScore += points
        }

        currentScore = score
        lastUpdated = Date()
    }
}

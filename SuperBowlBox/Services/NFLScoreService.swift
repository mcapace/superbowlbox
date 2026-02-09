import Foundation
import Combine

class NFLScoreService: ObservableObject {
    @Published var currentScore: GameScore?
    @Published var isLoading = false
    @Published var error: ScoreError?
    @Published var lastUpdated: Date?

    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    /// Guard against overlapping fetches (e.g. timer + manual refresh at the same time)
    private var isFetching = false

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

        // Create timer directly in .common run loop mode so it fires even while user scrolls.
        // IMPORTANT: Do NOT use Timer.scheduledTimer (which registers in .default) followed by
        // RunLoop.add(_, forMode: .common) — that double-registers the timer and can cause
        // the callback to fire twice per interval, leading to duplicate score fetches.
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task {
                await self?.fetchCurrentScore()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stopLiveUpdates() {
        timer?.invalidate()
        timer = nil
    }

    @MainActor
    func fetchCurrentScore() async {
        // Prevent overlapping fetches — each fetch just sets the score, but redundant
        // network calls waste resources and can confuse the update pipeline.
        guard !isFetching else {
            print("[ScoreDebug] fetchCurrentScore: skipping, already fetching")
            return
        }
        isFetching = true
        isLoading = true
        error = nil

        do {
            let score = try await fetchScoreFromAPI()
            print("[ScoreDebug] fetchCurrentScore: API returned home=\(score.homeScore) away=\(score.awayScore) (\(score.homeTeam.abbreviation) vs \(score.awayTeam.abbreviation))")
            currentScore = score
            lastUpdated = Date()
        } catch let err as ScoreError {
            error = err
            print("[ScoreDebug] fetchCurrentScore error: \(err.localizedDescription)")
        } catch {
            self.error = .networkError(error)
            print("[ScoreDebug] fetchCurrentScore network error: \(error.localizedDescription)")
        }

        isLoading = false
        isFetching = false
    }

    private func fetchScoreFromAPI() async throws -> GameScore {
        // Primary: Sports Data IO (when API key is set in Secrets.plist or Info.plist)
        if SportsDataIOConfig.isConfigured {
            print("[ScoreDebug] fetchScoreFromAPI: trying SportsDataIO (primary)")
            do {
                let score = try await SportsDataIOService.fetchNFLScore()
                print("[ScoreDebug] SportsDataIO returned: home=\(score.homeScore) away=\(score.awayScore)")
                return score
            } catch {
                print("[ScoreDebug] SportsDataIO failed: \(error.localizedDescription), falling back to ESPN")
                // Backup: if Sports Data IO is down, rate-limited, or returns no game, use ESPN
            }
        }

        // Backup / default: ESPN scoreboard (no key required; always available)
        print("[ScoreDebug] fetchScoreFromAPI: using ESPN scoreboard")
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

    /// Featured game is always from API (Sports Data IO if configured, else ESPN scoreboard). Prefer Super Bowl when present.
    private func parseESPNResponse(_ data: Data) throws -> GameScore {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let events = json["events"] as? [[String: Any]] else {
            throw ScoreError.decodingError
        }

        // 1) Prefer Super Bowl by name (neutral site in CA etc.) so we show the right "next game"
        for event in events {
            guard let name = event["name"] as? String, name.lowercased().contains("super bowl"),
                  let competitions = event["competitions"] as? [[String: Any]],
                  let competition = competitions.first,
                  let competitors = competition["competitors"] as? [[String: Any]] else {
                continue
            }
            return try parseCompetition(competition, competitors: competitors, scheduledStart: parseEventDate(event))
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

            // Parse score: ESPN returns "score" as a String (e.g. "30"), but handle
            // numeric types as a safety net in case the API format changes.
            let score: Int = {
                if let s = competitor["score"] as? String {
                    return Int(s) ?? 0
                }
                if let n = competitor["score"] as? NSNumber {
                    return n.intValue
                }
                return 0
            }()

            let abbrev: String = {
                if let team = competitor["team"] as? [String: Any] {
                    return team["abbreviation"] as? String ?? "?"
                }
                return "?"
            }()
            print("[ScoreDebug] ESPN competitor: \(abbrev) homeAway=\(competitor["homeAway"] as? String ?? "?") rawScore=\(competitor["score"] ?? "nil") parsedScore=\(score)")

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

        print("[ScoreDebug] ESPN parsed totals: home(\(homeTeam.abbreviation))=\(homeScore) away(\(awayTeam.abbreviation))=\(awayScore)")

        // Parse game status
        let status = competition["status"] as? [String: Any]
        let statusType = status?["type"] as? [String: Any]
        let statusName = statusType?["name"] as? String ?? "STATUS_SCHEDULED"
        let period = status?["period"] as? Int ?? 0
        let clock = status?["displayClock"] as? String ?? "15:00"

        let isActive = statusName == "STATUS_IN_PROGRESS"
        let isOver = statusName == "STATUS_FINAL"

        // Parse quarter scores from BOTH competitors.
        // ESPN linescore values are Doubles (e.g. 3.0), not Ints, so we must
        // handle both types. Also correctly assign to Home vs Away based on
        // each competitor's "homeAway" field (not blindly using competitors.first).
        var quarterScores = QuarterScores()
        for competitor in competitors {
            let isHome = competitor["homeAway"] as? String == "home"
            if let linescores = competitor["linescores"] as? [[String: Any]] {
                for (index, linescore) in linescores.enumerated() {
                    // ESPN returns linescore values as Double (e.g. 3.0); handle both Double and Int
                    let value: Int = {
                        if let d = linescore["value"] as? Double { return Int(d) }
                        if let i = linescore["value"] as? Int { return i }
                        if let n = linescore["value"] as? NSNumber { return n.intValue }
                        return 0
                    }()
                    if isHome {
                        switch index {
                        case 0: quarterScores.q1Home = value
                        case 1: quarterScores.q2Home = value
                        case 2: quarterScores.q3Home = value
                        case 3: quarterScores.q4Home = value
                        default: break
                        }
                    } else {
                        switch index {
                        case 0: quarterScores.q1Away = value
                        case 1: quarterScores.q2Away = value
                        case 2: quarterScores.q3Away = value
                        case 3: quarterScores.q4Away = value
                        default: break
                        }
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
            quarterScores: quarterScores,
            scheduledStart: scheduledStart
        )
    }

    // Manual score entry for testing or when API isn't available
    func setManualScore(homeScore: Int, awayScore: Int, quarter: Int = 1) {
        print("[ScoreDebug] setManualScore: home=\(homeScore) away=\(awayScore) quarter=\(quarter)")
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

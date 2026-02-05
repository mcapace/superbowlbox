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
        // Start with a mock score for demo purposes
        currentScore = GameScore.mock
    }

    func startLiveUpdates(interval: TimeInterval = 30) {
        stopLiveUpdates()

        // Fetch immediately
        Task {
            await fetchCurrentScore()
        }

        // Then fetch periodically
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
        // Prefer Sports Data IO when API key is set (Info.plist: SportsDataIOApiKey)
        if SportsDataIOConfig.isConfigured {
            do {
                return try await SportsDataIOService.fetchNFLScore()
            } catch {
                // Fall through to ESPN if Sports Data IO fails (e.g. no games today, key invalid)
            }
        }

        // ESPN API fallback (no key required)
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

        // Look for the featured game (e.g. Super Bowl) or current NFL game
        for event in events {
            guard let name = event["name"] as? String,
                  let competitions = event["competitions"] as? [[String: Any]],
                  let competition = competitions.first,
                  let competitors = competition["competitors"] as? [[String: Any]] else {
                continue
            }

            // Prefer championship/featured game when available
            let isSuperBowl = name.lowercased().contains("super bowl")
            let isPlayoff = (event["season"] as? [String: Any])?["type"] as? Int == 3

            if isSuperBowl || isPlayoff || events.count == 1 {
                return try parseCompetition(competition, competitors: competitors)
            }
        }

        // If no featured game found, return the first game or mock
        if let event = events.first,
           let competitions = event["competitions"] as? [[String: Any]],
           let competition = competitions.first,
           let competitors = competition["competitors"] as? [[String: Any]] {
            return try parseCompetition(competition, competitors: competitors)
        }

        throw ScoreError.noGameFound
    }

    private func parseCompetition(_ competition: [String: Any], competitors: [[String: Any]]) throws -> GameScore {
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
                let logoURL = team["logo"] as? String

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

        // Parse game status
        let status = competition["status"] as? [String: Any]
        let statusType = status?["type"] as? [String: Any]
        let statusName = statusType?["name"] as? String ?? "STATUS_SCHEDULED"
        let period = status?["period"] as? Int ?? 0
        let clock = status?["displayClock"] as? String ?? "15:00"

        let isActive = statusName == "STATUS_IN_PROGRESS"
        let isOver = statusName == "STATUS_FINAL"

        // Parse quarter scores if available
        var quarterScores = QuarterScores()
        if let linescores = competitors.first?["linescores"] as? [[String: Any]] {
            for (index, linescore) in linescores.enumerated() {
                let value = linescore["value"] as? Int ?? 0
                switch index {
                case 0: quarterScores.q1Home = value
                case 1: quarterScores.q2Home = value
                case 2: quarterScores.q3Home = value
                case 3: quarterScores.q4Home = value
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
            quarterScores: quarterScores
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

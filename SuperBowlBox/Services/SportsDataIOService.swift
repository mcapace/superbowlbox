import Foundation

/// Fetches NFL (and optionally other sports) scores from Sports Data IO when API key is configured.
/// See SportsDataIOConfig and Info.plist key `SportsDataIOApiKey`.
enum SportsDataIOService {
    /// Fetches NFL score: today first, then next 6 days so "next upcoming game" always shows when you refresh.
    static func fetchNFLScore() async throws -> GameScore {
        guard SportsDataIOConfig.isConfigured else {
            throw NFLScoreService.ScoreError.apiError("Sports Data IO not configured")
        }
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else { continue }
            let dateStr = formatter.string(from: date).prefix(10)
            guard let url = SportsDataIOConfig.nflScoresURL(pathComponent: "ScoresByDate/\(dateStr)"),
                  var request = SportsDataIOConfig.authenticatedRequest(url: url) else {
                continue
            }
            request.httpMethod = "GET"

            let (data, response): (Data, URLResponse)
            do {
                (data, response) = try await URLSession.shared.data(for: request)
            } catch {
                if dayOffset == 0 { throw NFLScoreService.ScoreError.networkError(error) }
                continue
            }
            guard let http = response as? HTTPURLResponse else {
                continue
            }
            if http.statusCode == 401 {
                throw NFLScoreService.ScoreError.apiError("Invalid API key")
            }
            if http.statusCode != 200 {
                if dayOffset == 0 { throw NFLScoreService.ScoreError.apiError("HTTP \(http.statusCode)") }
                continue
            }

            do {
                return try parseNFLScoresResponse(data)
            } catch NFLScoreService.ScoreError.noGameFound {
                continue
            }
        }

        throw NFLScoreService.ScoreError.noGameFound
    }

    /// Parses Sports Data IO NFL scores JSON. Handles common field names (PascalCase).
    private static func parseNFLScoresResponse(_ data: Data) throws -> GameScore {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              !json.isEmpty else {
            throw NFLScoreService.ScoreError.noGameFound
        }

        // Prefer: in progress > scheduled > final
        let sorted = json.sorted { g1, g2 in
            let s1 = statusOrder(g1)
            let s2 = statusOrder(g2)
            if s1 != s2 { return s1 < s2 }
            let d1 = g1["Date"] as? String ?? ""
            let d2 = g2["Date"] as? String ?? ""
            return d1 >= d2
        }

        guard let game = sorted.first else {
            throw NFLScoreService.ScoreError.noGameFound
        }

        let homeTeam = parseTeam(from: game, home: true)
        let awayTeam = parseTeam(from: game, home: false)
        let homeScore = int(from: game, keys: ["HomeScore", "homeScore"]) ?? 0
        let awayScore = int(from: game, keys: ["AwayScore", "awayScore"]) ?? 0
        let quarter = int(from: game, keys: ["Quarter", "quarter"]) ?? 0
        let timeRemaining = string(from: game, keys: ["TimeRemaining", "timeRemaining"]) ?? "15:00"
        let status = string(from: game, keys: ["Status", "status"]) ?? ""
        let isActive = status.lowercased().contains("inprogress") || status.lowercased().contains("in progress")
        let isOver = status.lowercased().contains("final") || status.lowercased().contains("closed")

        let scheduledStart = parseScheduledStart(from: game)

        var quarterScores = QuarterScores()
        quarterScores.q1Home = int(from: game, keys: ["HomeScoreQuarter1", "homeScoreQuarter1"])
        quarterScores.q1Away = int(from: game, keys: ["AwayScoreQuarter1", "awayScoreQuarter1"])
        quarterScores.q2Home = int(from: game, keys: ["HomeScoreQuarter2", "homeScoreQuarter2"])
        quarterScores.q2Away = int(from: game, keys: ["AwayScoreQuarter2", "awayScoreQuarter2"])
        quarterScores.q3Home = int(from: game, keys: ["HomeScoreQuarter3", "homeScoreQuarter3"])
        quarterScores.q3Away = int(from: game, keys: ["AwayScoreQuarter3", "awayScoreQuarter3"])
        quarterScores.q4Home = int(from: game, keys: ["HomeScoreQuarter4", "homeScoreQuarter4"])
        quarterScores.q4Away = int(from: game, keys: ["AwayScoreQuarter4", "awayScoreQuarter4"])

        return GameScore(
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            homeScore: homeScore,
            awayScore: awayScore,
            quarter: quarter,
            timeRemaining: timeRemaining,
            isGameActive: isActive,
            isGameOver: isOver,
            quarterScores: quarterScores,
            scheduledStart: scheduledStart
        )
    }

    private static func parseScheduledStart(from game: [String: Any]) -> Date? {
        if let dateTime = string(from: game, keys: ["DateTime", "dateTime"]), !dateTime.isEmpty {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = formatter.date(from: dateTime) { return d }
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: dateTime)
        }
        if let dateStr = string(from: game, keys: ["Date", "date"]), !dateStr.isEmpty {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            return formatter.date(from: String(dateStr.prefix(10)))
        }
        return nil
    }

    private static func int(from dict: [String: Any], keys: [String]) -> Int? {
        for k in keys {
            if let n = dict[k] as? Int { return n }
            if let n = dict[k] as? NSNumber { return n.intValue }
        }
        return nil
    }

    private static func string(from dict: [String: Any], keys: [String]) -> String? {
        for k in keys {
            if let s = dict[k] as? String, !s.isEmpty { return s }
        }
        return nil
    }

    private static func statusOrder(_ game: [String: Any]) -> Int {
        let s = (string(from: game, keys: ["Status", "status"]) ?? "").lowercased()
        if s.contains("inprogress") || s.contains("in progress") { return 0 }
        if s.contains("scheduled") || s.contains("pregame") { return 1 }
        return 2 // final/closed
    }

    private static func parseTeam(from game: [String: Any], home: Bool) -> Team {
        let nameKeys = home ? ["HomeTeam", "homeTeam"] : ["AwayTeam", "awayTeam"]
        let name = string(from: game, keys: nameKeys) ?? (home ? "Home" : "Away")
        let abbrevKeys = home ? ["HomeTeamAbbreviation", "homeTeamAbbreviation"] : ["AwayTeamAbbreviation", "awayTeamAbbreviation"]
        let abbrev = string(from: game, keys: abbrevKeys) ?? String(name.prefix(2)).uppercased()
        let colorKeys = home ? ["HomeTeamColor", "homeTeamColor"] : ["AwayTeamColor", "awayTeamColor"]
        var color = string(from: game, keys: colorKeys) ?? "000000"
        if !color.hasPrefix("#") { color = "#\(color)" }
        // ESPN hosts NFL scoreboard logos; use same URL pattern when Sports Data IO doesn't provide logos
        let logoURL = "https://a.espncdn.com/i/teamlogos/nfl/500/scoreboard/\(abbrev.lowercased()).png"
        return Team(name: name, abbreviation: abbrev, primaryColor: color, logoURL: logoURL)
    }
}

import Foundation

/// Fetches list of games from ESPN scoreboard for a given sport. Used by "Create pool from game".
class GamesService: ObservableObject {
    @Published var games: [ListableGame] = []
    @Published var isLoading = false
    @Published var error: String?

    private let baseURL = "https://site.api.espn.com/apis/site/v2/sports"

    func fetchGames(sport: Sport) async {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        defer {
            Task { @MainActor in isLoading = false }
        }

        let urlString = "\(baseURL)/\(sport.espnPath)/scoreboard"
        guard let url = URL(string: urlString) else {
            await MainActor.run { error = "Invalid URL" }
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                await MainActor.run { error = "Could not load games" }
                return
            }
            let list = try parseScoreboard(data, sport: sport)
            await MainActor.run {
                games = list
                if list.isEmpty { error = "No games scheduled" }
            }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    private func parseScoreboard(_ data: Data, sport: Sport) throws -> [ListableGame] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let events = json["events"] as? [[String: Any]] else {
            return []
        }

        var result: [ListableGame] = []
        for event in events {
            guard let eventId = event["id"] as? String,
                  let name = event["name"] as? String,
                  let competitions = event["competitions"] as? [[String: Any]],
                  let competition = competitions.first,
                  let competitors = competition["competitors"] as? [[String: Any]] else {
                continue
            }
            var homeTeam: Team?
            var awayTeam: Team?
            for comp in competitors {
                guard let teamInfo = comp["team"] as? [String: Any] else { continue }
                let displayName = teamInfo["displayName"] as? String ?? "Team"
                let abbrev = teamInfo["abbreviation"] as? String ?? "??"
                let color = (teamInfo["color"] as? String) ?? "000000"
                let team = Team(
                    name: displayName,
                    abbreviation: abbrev,
                    primaryColor: "#\(color)"
                )
                if (comp["homeAway"] as? String) == "home" {
                    homeTeam = team
                } else {
                    awayTeam = team
                }
            }
            guard let home = homeTeam, let away = awayTeam else { continue }
            let status = (competition["status"] as? [String: Any])?["type"] as? [String: Any]
            let statusName = status?["shortDetail"] as? String ?? status?["name"] as? String ?? "Scheduled"
            result.append(ListableGame(
                id: eventId,
                name: name,
                homeTeam: home,
                awayTeam: away,
                status: statusName,
                sport: sport
            ))
        }
        return result
    }
}

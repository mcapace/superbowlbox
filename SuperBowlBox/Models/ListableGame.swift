import Foundation

// MARK: - Sport (for "create pool from game", ESPN & Sports Data IO)

enum Sport: String, CaseIterable, Identifiable {
    case nfl
    case nba
    case nhl
    case mlb
    case ncaaf   // College Football
    case ncaab   // Men's College Basketball
    case wnba
    case cfl     // Canadian Football
    case mls     // MLS Soccer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .nfl: return "NFL"
        case .nba: return "NBA"
        case .nhl: return "NHL"
        case .mlb: return "MLB"
        case .ncaaf: return "NCAAF"
        case .ncaab: return "NCAAB"
        case .wnba: return "WNBA"
        case .cfl: return "CFL"
        case .mls: return "MLS"
        }
    }

    var fullName: String {
        switch self {
        case .nfl: return "Football"
        case .nba: return "Basketball"
        case .nhl: return "Hockey"
        case .mlb: return "Baseball"
        case .ncaaf: return "College Football"
        case .ncaab: return "College Basketball"
        case .wnba: return "WNBA"
        case .cfl: return "CFL"
        case .mls: return "Soccer"
        }
    }

    /// ESPN API path segment for scoreboard: e.g. "football/nfl", "basketball/nba"
    var espnPath: String {
        switch self {
        case .nfl: return "football/nfl"
        case .nba: return "basketball/nba"
        case .nhl: return "hockey/nhl"
        case .mlb: return "baseball/mlb"
        case .ncaaf: return "football/college-football"
        case .ncaab: return "basketball/mens-college-basketball"
        case .wnba: return "basketball/wnba"
        case .cfl: return "football/cfl"
        case .mls: return "soccer/usa.1"
        }
    }

    /// Sports Data IO league path (v3): e.g. "nfl", "nba", "ncaaf"
    var sportsDataIOLeague: String {
        switch self {
        case .nfl: return "nfl"
        case .nba: return "nba"
        case .nhl: return "nhl"
        case .mlb: return "mlb"
        case .ncaaf: return "ncaaf"
        case .ncaab: return "ncaab"
        case .wnba: return "wnba"
        case .cfl: return "cfl"
        case .mls: return "mls"
        }
    }
}

// MARK: - ListableGame (one game from scoreboard, for picker)

struct ListableGame: Identifiable {
    let id: String
    let name: String
    let homeTeam: Team
    let awayTeam: Team
    let status: String
    let sport: Sport
    /// Optional short status: "Scheduled", "Live", "Final"
    var statusShort: String {
        if status.lowercased().contains("final") { return "Final" }
        if status.lowercased().contains("in progress") || status.lowercased().contains("halftime") { return "Live" }
        return "Scheduled"
    }
}

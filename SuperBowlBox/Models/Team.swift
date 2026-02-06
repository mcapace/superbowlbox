import Foundation

struct Team: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var abbreviation: String
    var primaryColor: String
    var secondaryColor: String
    var logoURL: String?

    init(
        id: UUID = UUID(),
        name: String,
        abbreviation: String,
        primaryColor: String = "#000000",
        secondaryColor: String = "#FFFFFF",
        logoURL: String? = nil
    ) {
        self.id = id
        self.name = name
        self.abbreviation = abbreviation
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.logoURL = logoURL
    }

    static let placeholder = Team(
        name: "Team",
        abbreviation: "TM"
    )

    private static func espnLogoURL(abbreviation: String) -> String {
        "https://a.espncdn.com/i/teamlogos/nfl/500/scoreboard/\(abbreviation.lowercased()).png"
    }

    // Super Bowl LIX Teams (2025) — include logoURL so logos show even when using static teams
    static let chiefs = Team(
        name: "Kansas City Chiefs",
        abbreviation: "KC",
        primaryColor: "#E31837",
        secondaryColor: "#FFB81C",
        logoURL: espnLogoURL(abbreviation: "kc")
    )

    static let eagles = Team(
        name: "Philadelphia Eagles",
        abbreviation: "PHI",
        primaryColor: "#004C54",
        secondaryColor: "#A5ACAF",
        logoURL: espnLogoURL(abbreviation: "phi")
    )

    static let fortyNiners = Team(
        name: "San Francisco 49ers",
        abbreviation: "SF",
        primaryColor: "#AA0000",
        secondaryColor: "#B3995D",
        logoURL: espnLogoURL(abbreviation: "sf")
    )

    static let ravens = Team(
        name: "Baltimore Ravens",
        abbreviation: "BAL",
        primaryColor: "#241773",
        secondaryColor: "#9E7C0C",
        logoURL: espnLogoURL(abbreviation: "bal")
    )

    static let bills = Team(
        name: "Buffalo Bills",
        abbreviation: "BUF",
        primaryColor: "#00338D",
        secondaryColor: "#C60C30",
        logoURL: espnLogoURL(abbreviation: "buf")
    )

    static let lions = Team(
        name: "Detroit Lions",
        abbreviation: "DET",
        primaryColor: "#0076B6",
        secondaryColor: "#B0B7BC",
        logoURL: espnLogoURL(abbreviation: "det")
    )

    static let cowboys = Team(
        name: "Dallas Cowboys",
        abbreviation: "DAL",
        primaryColor: "#003594",
        secondaryColor: "#869397",
        logoURL: espnLogoURL(abbreviation: "dal")
    )

    static let packers = Team(
        name: "Green Bay Packers",
        abbreviation: "GB",
        primaryColor: "#203731",
        secondaryColor: "#FFB612",
        logoURL: espnLogoURL(abbreviation: "gb")
    )

    static let patriots = Team(
        name: "New England Patriots",
        abbreviation: "NE",
        primaryColor: "#002244",
        secondaryColor: "#C60C30",
        logoURL: espnLogoURL(abbreviation: "ne")
    )

    static let seahawks = Team(
        name: "Seattle Seahawks",
        abbreviation: "SEA",
        primaryColor: "#002244",
        secondaryColor: "#69BE28",
        logoURL: espnLogoURL(abbreviation: "sea")
    )

    /// Used when scan doesn't detect team names (so we don't show KC/PHI as if we did).
    static let unknown = Team(
        name: "Unknown",
        abbreviation: "—",
        primaryColor: "#6B7280",
        secondaryColor: "#9CA3AF"
    )

    static let allTeams: [Team] = [
        .chiefs, .eagles, .fortyNiners, .ravens,
        .bills, .lions, .cowboys, .packers
    ]

    /// Look up team by abbreviation (e.g. "KC", "SF"). Used when parsing AI/API responses.
    static func from(abbreviation: String) -> Team? {
        let abbr = abbreviation.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !abbr.isEmpty else { return nil }
        let matchable: [Team] = allTeams + [.patriots, .seahawks]
        return matchable.first { $0.abbreviation.lowercased() == abbr }
    }

    /// Match sheet text to a team (abbreviation or distinctive name part). Used by OCR to set grid teams.
    /// Requires abbreviation as whole word or keyword in longer text so "K"/"C" or initials don't match KC.
    static func firstMatching(in text: String) -> Team? {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let t = raw.lowercased()
        guard !t.isEmpty else { return nil }
        // Single letter or very short noise: don't match (avoids "K" or "C" matching KC)
        if t.count == 1 { return nil }
        let matchableTeams: [Team] = allTeams + [.patriots, .seahawks]
        for team in matchableTeams {
            let abbr = team.abbreviation.lowercased()
            if t == abbr { return team }
            if t.count >= 2 && (t.hasPrefix(abbr + " ") || t.hasSuffix(" " + abbr) || t.contains(" " + abbr + " ")) { return team }
            let nameLower = team.name.lowercased()
            if nameLower.contains(t) || t.contains(nameLower) { return team }
        }
        let keywords: [(String, Team)] = [
            ("chiefs", .chiefs), ("chief", .chiefs), ("eagles", .eagles), ("eagle", .eagles),
            ("49er", .fortyNiners), ("niner", .fortyNiners), ("ravens", .ravens), ("raven", .ravens),
            ("bills", .bills), ("lion", .lions), ("cowboys", .cowboys), ("cowboy", .cowboys),
            ("packers", .packers), ("packer", .packers),
            ("patriots", .patriots), ("patriot", .patriots), ("seahawks", .seahawks), ("seahawk", .seahawks)
        ]
        for (keyword, team) in keywords {
            guard t.contains(keyword) else { continue }
            return team
        }
        return nil
    }
}

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

    // Super Bowl LIX Teams (2025)
    static let chiefs = Team(
        name: "Kansas City Chiefs",
        abbreviation: "KC",
        primaryColor: "#E31837",
        secondaryColor: "#FFB81C"
    )

    static let eagles = Team(
        name: "Philadelphia Eagles",
        abbreviation: "PHI",
        primaryColor: "#004C54",
        secondaryColor: "#A5ACAF"
    )

    static let fortyNiners = Team(
        name: "San Francisco 49ers",
        abbreviation: "SF",
        primaryColor: "#AA0000",
        secondaryColor: "#B3995D"
    )

    static let ravens = Team(
        name: "Baltimore Ravens",
        abbreviation: "BAL",
        primaryColor: "#241773",
        secondaryColor: "#9E7C0C"
    )

    static let bills = Team(
        name: "Buffalo Bills",
        abbreviation: "BUF",
        primaryColor: "#00338D",
        secondaryColor: "#C60C30"
    )

    static let lions = Team(
        name: "Detroit Lions",
        abbreviation: "DET",
        primaryColor: "#0076B6",
        secondaryColor: "#B0B7BC"
    )

    static let cowboys = Team(
        name: "Dallas Cowboys",
        abbreviation: "DAL",
        primaryColor: "#003594",
        secondaryColor: "#869397"
    )

    static let packers = Team(
        name: "Green Bay Packers",
        abbreviation: "GB",
        primaryColor: "#203731",
        secondaryColor: "#FFB612"
    )

    static let allTeams: [Team] = [
        .chiefs, .eagles, .fortyNiners, .ravens,
        .bills, .lions, .cowboys, .packers
    ]
}

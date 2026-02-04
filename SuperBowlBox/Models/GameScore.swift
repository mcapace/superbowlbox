import Foundation

struct GameScore: Codable, Equatable {
    var homeTeam: Team
    var awayTeam: Team
    var homeScore: Int
    var awayScore: Int
    var quarter: Int
    var timeRemaining: String
    var isGameActive: Bool
    var isGameOver: Bool
    var quarterScores: QuarterScores

    init(
        homeTeam: Team = .chiefs,
        awayTeam: Team = .eagles,
        homeScore: Int = 0,
        awayScore: Int = 0,
        quarter: Int = 0,
        timeRemaining: String = "15:00",
        isGameActive: Bool = false,
        isGameOver: Bool = false,
        quarterScores: QuarterScores = QuarterScores()
    ) {
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.quarter = quarter
        self.timeRemaining = timeRemaining
        self.isGameActive = isGameActive
        self.isGameOver = isGameOver
        self.quarterScores = quarterScores
    }

    var homeLastDigit: Int {
        homeScore % 10
    }

    var awayLastDigit: Int {
        awayScore % 10
    }

    var gameStatusText: String {
        if isGameOver {
            return "Final"
        } else if !isGameActive {
            return "Pre-Game"
        } else if quarter <= 4 {
            return "Q\(quarter) - \(timeRemaining)"
        } else {
            return "OT - \(timeRemaining)"
        }
    }

    var scoreDisplay: String {
        "\(awayTeam.abbreviation) \(awayScore) - \(homeScore) \(homeTeam.abbreviation)"
    }

    static let mock = GameScore(
        homeTeam: .chiefs,
        awayTeam: .eagles,
        homeScore: 21,
        awayScore: 17,
        quarter: 3,
        timeRemaining: "8:42",
        isGameActive: true,
        isGameOver: false
    )
}

struct QuarterScores: Codable, Equatable {
    var q1Home: Int?
    var q1Away: Int?
    var q2Home: Int?
    var q2Away: Int?
    var q3Home: Int?
    var q3Away: Int?
    var q4Home: Int?
    var q4Away: Int?

    init(
        q1Home: Int? = nil,
        q1Away: Int? = nil,
        q2Home: Int? = nil,
        q2Away: Int? = nil,
        q3Home: Int? = nil,
        q3Away: Int? = nil,
        q4Home: Int? = nil,
        q4Away: Int? = nil
    ) {
        self.q1Home = q1Home
        self.q1Away = q1Away
        self.q2Home = q2Home
        self.q2Away = q2Away
        self.q3Home = q3Home
        self.q3Away = q3Away
        self.q4Home = q4Home
        self.q4Away = q4Away
    }

    func scoreForQuarter(_ quarter: Int) -> (home: Int, away: Int)? {
        switch quarter {
        case 1:
            guard let home = q1Home, let away = q1Away else { return nil }
            return (home, away)
        case 2:
            guard let home = q2Home, let away = q2Away else { return nil }
            return (home, away)
        case 3:
            guard let home = q3Home, let away = q3Away else { return nil }
            return (home, away)
        case 4:
            guard let home = q4Home, let away = q4Away else { return nil }
            return (home, away)
        default:
            return nil
        }
    }
}

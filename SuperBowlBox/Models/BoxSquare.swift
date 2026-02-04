import Foundation

struct BoxSquare: Codable, Identifiable, Equatable {
    let id: UUID
    var playerName: String
    var row: Int
    var column: Int
    var isWinner: Bool
    var quarterWins: [Int]  // Which quarters this square won (1, 2, 3, 4)
    /// Period IDs this square has won (e.g. "Q1", "Halftime", "Final", "FirstScore")
    var winningPeriodIds: [String]

    init(
        id: UUID = UUID(),
        playerName: String = "",
        row: Int,
        column: Int,
        isWinner: Bool = false,
        quarterWins: [Int] = [],
        winningPeriodIds: [String] = []
    ) {
        self.id = id
        self.playerName = playerName
        self.row = row
        self.column = column
        self.isWinner = isWinner
        self.quarterWins = quarterWins
        self.winningPeriodIds = winningPeriodIds
    }

    /// All period labels this square has won (Q1, Q2, Halftime, etc.)
    var allWonPeriodLabels: [String] {
        let fromQuarters = quarterWins.sorted().map { "Q\($0)" }
        let otherIds = winningPeriodIds.filter { ["Q1","Q2","Q3","Q4"].contains($0) == false }
        var seen = Set<String>()
        return (fromQuarters + otherIds).filter { seen.insert($0).inserted }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        playerName = try c.decode(String.self, forKey: .playerName)
        row = try c.decode(Int.self, forKey: .row)
        column = try c.decode(Int.self, forKey: .column)
        isWinner = try c.decode(Bool.self, forKey: .isWinner)
        quarterWins = try c.decodeIfPresent([Int].self, forKey: .quarterWins) ?? []
        winningPeriodIds = try c.decodeIfPresent([String].self, forKey: .winningPeriodIds) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case id, playerName, row, column, isWinner, quarterWins, winningPeriodIds
    }

    var isEmpty: Bool {
        playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var displayName: String {
        isEmpty ? "Empty" : playerName
    }

    var initials: String {
        let words = playerName.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else if let first = words.first {
            return String(first.prefix(2)).uppercased()
        }
        return ""
    }
}

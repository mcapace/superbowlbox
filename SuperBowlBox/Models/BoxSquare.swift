import Foundation

struct BoxSquare: Codable, Identifiable, Equatable {
    let id: UUID
    var playerName: String
    var row: Int
    var column: Int
    var isWinner: Bool
    var quarterWins: [Int]  // Which quarters this square won (1, 2, 3, 4)

    init(
        id: UUID = UUID(),
        playerName: String = "",
        row: Int,
        column: Int,
        isWinner: Bool = false,
        quarterWins: [Int] = []
    ) {
        self.id = id
        self.playerName = playerName
        self.row = row
        self.column = column
        self.isWinner = isWinner
        self.quarterWins = quarterWins
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

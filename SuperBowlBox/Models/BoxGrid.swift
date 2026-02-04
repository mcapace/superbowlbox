import Foundation

struct BoxGrid: Codable, Identifiable {
    let id: UUID
    var name: String
    var homeTeam: Team
    var awayTeam: Team
    var homeNumbers: [Int]  // 0-9 in randomized order for columns
    var awayNumbers: [Int]  // 0-9 in randomized order for rows
    var squares: [[BoxSquare]]  // 10x10 grid
    var createdAt: Date
    var lastModified: Date
    var currentScore: GameScore?

    init(
        id: UUID = UUID(),
        name: String = "Super Bowl Box",
        homeTeam: Team = .chiefs,
        awayTeam: Team = .eagles,
        homeNumbers: [Int]? = nil,
        awayNumbers: [Int]? = nil,
        squares: [[BoxSquare]]? = nil,
        createdAt: Date = Date(),
        lastModified: Date = Date(),
        currentScore: GameScore? = nil
    ) {
        self.id = id
        self.name = name
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.homeNumbers = homeNumbers ?? Array(0...9).shuffled()
        self.awayNumbers = awayNumbers ?? Array(0...9).shuffled()
        self.createdAt = createdAt
        self.lastModified = lastModified
        self.currentScore = currentScore

        if let existingSquares = squares {
            self.squares = existingSquares
        } else {
            var newSquares: [[BoxSquare]] = []
            for row in 0..<10 {
                var rowSquares: [BoxSquare] = []
                for col in 0..<10 {
                    rowSquares.append(BoxSquare(row: row, column: col))
                }
                newSquares.append(rowSquares)
            }
            self.squares = newSquares
        }
    }

    // Get the square at a specific position
    func square(at row: Int, column: Int) -> BoxSquare? {
        guard row >= 0, row < 10, column >= 0, column < 10 else { return nil }
        return squares[row][column]
    }

    // Get the winning square for the current score
    func winningSquare(for score: GameScore) -> BoxSquare? {
        let homeDigit = score.homeLastDigit
        let awayDigit = score.awayLastDigit

        guard let columnIndex = homeNumbers.firstIndex(of: homeDigit),
              let rowIndex = awayNumbers.firstIndex(of: awayDigit) else {
            return nil
        }

        return squares[rowIndex][columnIndex]
    }

    // Get the winning square coordinates for given digits
    func winningPosition(homeDigit: Int, awayDigit: Int) -> (row: Int, column: Int)? {
        guard let columnIndex = homeNumbers.firstIndex(of: homeDigit),
              let rowIndex = awayNumbers.firstIndex(of: awayDigit) else {
            return nil
        }
        return (rowIndex, columnIndex)
    }

    // Update a square's player name
    mutating func updateSquare(row: Int, column: Int, playerName: String) {
        guard row >= 0, row < 10, column >= 0, column < 10 else { return }
        squares[row][column].playerName = playerName
        lastModified = Date()
    }

    // Mark winners based on quarter scores
    mutating func updateWinners(quarterScores: QuarterScores) {
        // Reset all winners
        for row in 0..<10 {
            for col in 0..<10 {
                squares[row][col].isWinner = false
                squares[row][col].quarterWins = []
            }
        }

        // Check each quarter
        for quarter in 1...4 {
            if let score = quarterScores.scoreForQuarter(quarter) {
                let homeDigit = score.home % 10
                let awayDigit = score.away % 10

                if let pos = winningPosition(homeDigit: homeDigit, awayDigit: awayDigit) {
                    squares[pos.row][pos.column].isWinner = true
                    squares[pos.row][pos.column].quarterWins.append(quarter)
                }
            }
        }
    }

    // Get all unique player names
    var allPlayers: [String] {
        var names = Set<String>()
        for row in squares {
            for square in row {
                if !square.isEmpty {
                    names.insert(square.playerName)
                }
            }
        }
        return Array(names).sorted()
    }

    // Get all squares for a specific player
    func squares(for playerName: String) -> [BoxSquare] {
        var result: [BoxSquare] = []
        for row in squares {
            for square in row {
                if square.playerName.lowercased() == playerName.lowercased() {
                    result.append(square)
                }
            }
        }
        return result
    }

    // Randomize the numbers (typically done after all names are entered)
    mutating func randomizeNumbers() {
        homeNumbers = Array(0...9).shuffled()
        awayNumbers = Array(0...9).shuffled()
        lastModified = Date()
    }

    // Check if grid is fully filled
    var isComplete: Bool {
        for row in squares {
            for square in row {
                if square.isEmpty {
                    return false
                }
            }
        }
        return true
    }

    // Count filled squares
    var filledCount: Int {
        var count = 0
        for row in squares {
            for square in row {
                if !square.isEmpty {
                    count += 1
                }
            }
        }
        return count
    }

    static let empty = BoxGrid()
}

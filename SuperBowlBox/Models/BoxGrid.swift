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
    /// How this pool pays out (by quarter, halftime, final, first score, etc.). Nil = legacy, treated as .standardQuarterly.
    var poolStructure: PoolStructure?
    /// Names as they appear on this sheet that identify the current user's boxes (e.g. "Mike" or "Mike", "Mike 2" for multiple boxes).
    var ownerLabels: [String]?
    /// After sharing via SharedPoolsService, the generated invite code is stored so we can show it again without re-uploading.
    var sharedCode: String?

    init(
        id: UUID = UUID(),
        name: String = "Pool",
        homeTeam: Team = .chiefs,
        awayTeam: Team = .eagles,
        homeNumbers: [Int]? = nil,
        awayNumbers: [Int]? = nil,
        squares: [[BoxSquare]]? = nil,
        createdAt: Date = Date(),
        lastModified: Date = Date(),
        currentScore: GameScore? = nil,
        poolStructure: PoolStructure = .standardQuarterly,
        ownerLabels: [String]? = nil,
        sharedCode: String? = nil
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
        self.poolStructure = poolStructure
        self.ownerLabels = ownerLabels
        self.sharedCode = sharedCode

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

    /// Resolved pool structure (defaults to standard quarterly for legacy pools).
    var resolvedPoolStructure: PoolStructure {
        poolStructure ?? .standardQuarterly
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, homeTeam, awayTeam, homeNumbers, awayNumbers, squares
        case createdAt, lastModified, currentScore, poolStructure, ownerLabels, sharedCode
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        homeTeam = try c.decode(Team.self, forKey: .homeTeam)
        awayTeam = try c.decode(Team.self, forKey: .awayTeam)
        homeNumbers = try c.decode([Int].self, forKey: .homeNumbers)
        awayNumbers = try c.decode([Int].self, forKey: .awayNumbers)
        squares = try c.decode([[BoxSquare]].self, forKey: .squares)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        lastModified = try c.decode(Date.self, forKey: .lastModified)
        currentScore = try c.decodeIfPresent(GameScore.self, forKey: .currentScore)
        poolStructure = try c.decodeIfPresent(PoolStructure.self, forKey: .poolStructure)
        ownerLabels = try c.decodeIfPresent([String].self, forKey: .ownerLabels)
        sharedCode = try c.decodeIfPresent(String.self, forKey: .sharedCode)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(homeTeam, forKey: .homeTeam)
        try c.encode(awayTeam, forKey: .awayTeam)
        try c.encode(homeNumbers, forKey: .homeNumbers)
        try c.encode(awayNumbers, forKey: .awayNumbers)
        try c.encode(squares, forKey: .squares)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(lastModified, forKey: .lastModified)
        try c.encodeIfPresent(currentScore, forKey: .currentScore)
        try c.encodeIfPresent(poolStructure, forKey: .poolStructure)
        try c.encodeIfPresent(ownerLabels, forKey: .ownerLabels)
        try c.encodeIfPresent(sharedCode, forKey: .sharedCode)
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

    // Mark winners based on pool structure and quarter/cumulative scores
    mutating func updateWinners(quarterScores: QuarterScores, totalScore: (home: Int, away: Int)? = nil) {
        for row in 0..<10 {
            for col in 0..<10 {
                squares[row][col].isWinner = false
                squares[row][col].quarterWins = []
                squares[row][col].winningPeriodIds = []
            }
        }

        for period in resolvedPoolStructure.periods {
            guard let digits = scoreDigits(for: period, quarterScores: quarterScores, totalScore: totalScore),
                  let pos = winningPosition(homeDigit: digits.0, awayDigit: digits.1) else { continue }
            squares[pos.row][pos.column].isWinner = true
            switch period {
            case .quarter(let q):
                squares[pos.row][pos.column].quarterWins.append(q)
            default:
                squares[pos.row][pos.column].winningPeriodIds.append(period.id)
            }
        }
    }

    /// Score digits used for a given period (for determining winner)
    func scoreDigits(for period: PoolPeriod, quarterScores: QuarterScores, totalScore: (home: Int, away: Int)?) -> (Int, Int)? {
        switch period {
        case .quarter(let q):
            return quarterScores.scoreForQuarter(q).map { ($0.home % 10, $0.away % 10) }
        case .halftime:
            return quarterScores.scoreForQuarter(2).map { ($0.home % 10, $0.away % 10) }
        case .final:
            return totalScore.map { ($0.home % 10, $0.away % 10) }
        case .firstScoreChange, .custom:
            return totalScore.map { ($0.home % 10, $0.away % 10) }
        }
    }

    /// Which period is "current" for live display (e.g. we're in Q2 so current is Q2)
    func currentPeriod(for score: GameScore) -> PoolPeriod? {
        switch resolvedPoolStructure.poolType {
        case .byQuarter(let quarters):
            guard score.quarter >= 1, score.quarter <= 4, quarters.contains(score.quarter) else { return nil }
            return .quarter(score.quarter)
        case .halftimeOnly:
            return score.quarter == 2 ? .halftime : nil
        case .finalOnly:
            return score.isGameOver ? .final : nil
        case .firstScoreChange:
            return (score.homeScore + score.awayScore) > 0 ? .firstScoreChange : nil
        case .halftimeAndFinal:
            if score.quarter == 2 { return .halftime }
            if score.isGameOver { return .final }
            return nil
        case .custom:
            return nil
        }
    }

    /// True if this period has already ended (winner is final).
    func isPeriodFinalized(_ period: PoolPeriod, score: GameScore) -> Bool {
        if score.isGameOver { return true }
        switch period {
        case .quarter(let q):
            return score.quarter > q
        case .halftime:
            return score.quarter >= 3
        case .final:
            return score.isGameOver
        case .firstScoreChange:
            return (score.homeScore + score.awayScore) > 0
        case .custom:
            return score.isGameOver
        }
    }

    /// Square that won the given period (from current winner state).
    func squareThatWon(period: PoolPeriod) -> BoxSquare? {
        for row in squares {
            for sq in row {
                switch period {
                case .quarter(let q):
                    if sq.quarterWins.contains(q) { return sq }
                default:
                    if sq.winningPeriodIds.contains(period.id) { return sq }
                }
            }
        }
        return nil
    }

    /// Finalized periods with winner name and payout amount (for "Current winnings" UI).
    func finalizedWinnings(score: GameScore) -> [(period: PoolPeriod, winnerName: String, amount: Double?)] {
        let periods = resolvedPoolStructure.periods
        return periods.enumerated().compactMap { index, period in
            guard isPeriodFinalized(period, score: score) else { return nil }
            let sq = squareThatWon(period: period)
            let name = sq?.displayName ?? "—"
            let amount = resolvedPoolStructure.amountPerPeriod(at: index)
            return (period, name, amount)
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

    // Get all squares for a specific player (name match, case-insensitive, whitespace-tolerant)
    func squares(for playerName: String) -> [BoxSquare] {
        squaresForOwner(ownerLabels: [playerName])
    }

    /// Labels that identify "my" boxes on this sheet (set when scanning/creating). Used with effectiveOwnerLabels(globalName:).
    /// Names as they appear on the sheet so we can find your boxes; supports multiple entries for multiple boxes.
    func effectiveOwnerLabels(globalName: String) -> [String] {
        let global = globalName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let labels = ownerLabels, !labels.isEmpty {
            return labels.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        if !global.isEmpty { return [global] }
        return []
    }

    /// Normalize for name matching: trim, lowercase, collapse whitespace, and apply common OCR substitutions (0/O, 1/l, 5/S) so "M1ke" and "M i k e" match "Mike".
    private static func normalizeForNameMatch(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .joined()
        return t
            .replacingOccurrences(of: "0", with: "o")
            .replacingOccurrences(of: "1", with: "l")
            .replacingOccurrences(of: "5", with: "s")
    }

    /// Edit distance between two strings (Levenshtein). Used for fuzzy name match so OCR variants like "Mike o Copec" match "Mike Capace".
    private static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a)
        let b = Array(b)
        let m = a.count
        let n = b.count
        if m == 0 { return n }
        if n == 0 { return m }
        var row = Array(0...n)
        for i in 1...m {
            var prev = row[0]
            row[0] = i
            for j in 1...n {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                let next = min(row[j] + 1, row[j - 1] + 1, prev + cost)
                prev = row[j]
                row[j] = next
            }
        }
        return row[n]
    }

    /// True if normalized cell name matches an owner label: exact match, or fuzzy (similarity >= 0.75) so handwriting/OCR variants still match.
    private static func normalizedNamesMatch(cellName: String, ownerKey: String) -> Bool {
        if cellName.isEmpty || ownerKey.isEmpty { return false }
        if cellName == ownerKey { return true }
        let dist = editDistance(cellName, ownerKey)
        let maxLen = max(cellName.count, ownerKey.count)
        let similarity = maxLen > 0 ? 1.0 - (Double(dist) / Double(maxLen)) : 1.0
        return similarity >= 0.75
    }

    /// All boxes that belong to the owner. Match is exact normalized first; if none, fuzzy match (OCR/handwriting variants like "Mike o Copec" → "Mike Capace"). One box = one cell.
    func squaresForOwner(ownerLabels: [String]) -> [BoxSquare] {
        let keys = ownerLabels.map { Self.normalizeForNameMatch($0) }.filter { !$0.isEmpty }
        guard !keys.isEmpty else { return [] }
        var result: [BoxSquare] = []
        for row in squares {
            for square in row {
                let name = Self.normalizeForNameMatch(square.playerName)
                guard !name.isEmpty else { continue }
                let exactMatch = keys.contains(name)
                let fuzzyMatch = !exactMatch && keys.contains { Self.normalizedNamesMatch(cellName: name, ownerKey: $0) }
                if exactMatch || fuzzyMatch {
                    result.append(square)
                }
            }
        }
        return result
    }

    /// Whether a square is one of the owner's (exact or fuzzy normalized match).
    func isOwnerSquare(_ square: BoxSquare, ownerLabels: [String]) -> Bool {
        let name = Self.normalizeForNameMatch(square.playerName)
        guard !name.isEmpty else { return false }
        let keys = ownerLabels.map { Self.normalizeForNameMatch($0) }.filter { !$0.isEmpty }
        guard !keys.isEmpty else { return false }
        if keys.contains(name) { return true }
        return keys.contains { Self.normalizedNamesMatch(cellName: name, ownerKey: $0) }
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

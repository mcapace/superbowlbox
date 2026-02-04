import Foundation

// MARK: - Pool Structure (how winners are determined and paid)

/// Defines when and how pool payouts happen (by quarter, halftime, final, first score, etc.)
struct PoolStructure: Codable, Equatable, Hashable {
    var poolType: PoolType
    var payoutStyle: PayoutStyle
    var totalPoolAmount: Double?
    var currencyCode: String

    init(
        poolType: PoolType = .byQuarter([1, 2, 3, 4]),
        payoutStyle: PayoutStyle = .equalSplit,
        totalPoolAmount: Double? = nil,
        currencyCode: String = "USD"
    ) {
        self.poolType = poolType
        self.payoutStyle = payoutStyle
        self.totalPoolAmount = totalPoolAmount
        self.currencyCode = currencyCode
    }

    /// Periods that can win in this pool (for display and winner logic)
    var periods: [PoolPeriod] {
        switch poolType {
        case .byQuarter(let quarters):
            return quarters.sorted().map { .quarter($0) }
        case .halftimeOnly:
            return [.halftime]
        case .finalOnly:
            return [.final]
        case .firstScoreChange:
            return [.firstScoreChange]
        case .halftimeAndFinal:
            return [.halftime, .final]
        case .custom(let labels):
            return labels.enumerated().map { .custom(id: "\($0.offset)", label: $0.element) }
        }
    }

    /// Human-readable period labels
    var periodLabels: [String] {
        periods.map { $0.displayLabel }
    }

    /// Payout amount or description per period (count must match periods.count when applicable)
    var payoutDescriptions: [String] {
        let count = periods.count
        switch payoutStyle {
        case .fixedAmount(let amounts):
            return amounts.prefix(count).map { formatCurrency($0) } +
                (count > amounts.count ? (0..<(count - amounts.count)).map { _ in formatCurrency(0) } : [])
        case .percentage(let percents):
            return percents.prefix(count).map { "\(Int($0))%" } +
                (count > percents.count ? (0..<(count - percents.count)).map { _ in "0%" } : [])
        case .equalSplit:
            let pct = count > 0 ? 100 / count : 0
            return (0..<count).map { _ in "\(pct)%" }
        case .custom(let descriptions):
            return Array(descriptions.prefix(count))
        }
    }

    /// Amount per period if we have totalPoolAmount and a computable split
    func amountPerPeriod(at index: Int) -> Double? {
        guard let total = totalPoolAmount, total >= 0, index >= 0, index < periods.count else { return nil }
        switch payoutStyle {
        case .fixedAmount(let amounts):
            guard index < amounts.count else { return nil }
            return amounts[index]
        case .percentage(let percents):
            guard index < percents.count, percents[index] > 0 else { return nil }
            return total * (percents[index] / 100.0)
        case .equalSplit:
            let count = Double(periods.count)
            return count > 0 ? total / count : nil
        case .custom:
            return nil
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
    }

    static let standardQuarterly = PoolStructure(
        poolType: .byQuarter([1, 2, 3, 4]),
        payoutStyle: .equalSplit,
        totalPoolAmount: nil,
        currencyCode: "USD"
    )

    /// Suggested pool structure when creating a pool from a live game (by sport).
    static func defaultFor(sport: Sport) -> PoolStructure {
        switch sport {
        case .nfl, .nba, .ncaaf, .ncaab, .wnba, .cfl:
            return PoolStructure(
                poolType: .byQuarter([1, 2, 3, 4]),
                payoutStyle: .equalSplit,
                totalPoolAmount: nil,
                currencyCode: "USD"
            )
        case .nhl:
            return PoolStructure(
                poolType: .custom(periodLabels: ["Period 1", "Period 2", "Period 3", "Final"]),
                payoutStyle: .equalSplit,
                totalPoolAmount: nil,
                currencyCode: "USD"
            )
        case .mlb:
            return PoolStructure(
                poolType: .custom(periodLabels: ["3rd Inning", "6th Inning", "9th Inning", "Final"]),
                payoutStyle: .equalSplit,
                totalPoolAmount: nil,
                currencyCode: "USD"
            )
        case .mls:
            return PoolStructure(
                poolType: .custom(periodLabels: ["Halftime", "Final"]),
                payoutStyle: .equalSplit,
                totalPoolAmount: nil,
                currencyCode: "USD"
            )
        }
    }
}

// MARK: - Pool Type

enum PoolType: Codable, Equatable, Hashable {
    /// End of Q1, Q2, Q3, Q4 (last digit of score at end of each quarter)
    case byQuarter([Int])
    /// Only halftime (end of Q2)
    case halftimeOnly
    /// Only final score
    case finalOnly
    /// First time the score changes from 0–0 (first score wins)
    case firstScoreChange
    /// Halftime + Final (two payouts)
    case halftimeAndFinal
    /// Custom period labels (e.g. "Q1", "Q3", "Final")
    case custom(periodLabels: [String])
}

// MARK: - Pool Period (single winning moment)

enum PoolPeriod: Codable, Equatable, Hashable {
    case quarter(Int)
    case halftime
    case final
    case firstScoreChange
    case custom(id: String, label: String)

    var displayLabel: String {
        switch self {
        case .quarter(let q): return "Q\(q)"
        case .halftime: return "Halftime"
        case .final: return "Final"
        case .firstScoreChange: return "First Score"
        case .custom(_, let label): return label
        }
    }

    var id: String {
        switch self {
        case .quarter(let q): return "Q\(q)"
        case .halftime: return "Halftime"
        case .final: return "Final"
        case .firstScoreChange: return "FirstScore"
        case .custom(let id, _): return id
        }
    }
}

// MARK: - Payout Style

enum PayoutStyle: Codable, Equatable, Hashable {
    /// Fixed dollar amount per period (e.g. $25, $25, $25, $25)
    case fixedAmount([Double])
    /// Percentage of pool per period (e.g. 25, 25, 25, 25)
    case percentage([Double])
    /// Split evenly across all periods
    case equalSplit
    /// Custom text per period
    case custom(descriptions: [String])
}

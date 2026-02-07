import Foundation

// MARK: - Pool Structure (how winners are determined and paid)

/// Defines when and how pool payouts happen for this pool. Each pool has its own structure — basic (quarters, first score, equal split) or complex (e.g. per score change with cap); the AI parses the user’s rules and the app uses this for the grid header and winner logic.
struct PoolStructure: Codable, Equatable, Hashable {
    var poolType: PoolType
    var payoutStyle: PayoutStyle
    var totalPoolAmount: Double?
    var currencyCode: String
    /// Free-text description of how this pool pays (e.g. "$25 per quarter, halftime pays double"). Shown in UI; can be used for AI/LLM to explain winnings.
    var customPayoutDescription: String?
    /// AI-generated short, readable summary of the rules (from payout-parse backend). Shown in "View payout rules" modal.
    var readableRulesSummary: String?

    init(
        poolType: PoolType = .byQuarter([1, 2, 3, 4]),
        payoutStyle: PayoutStyle = .equalSplit,
        totalPoolAmount: Double? = nil,
        currencyCode: String = "USD",
        customPayoutDescription: String? = nil,
        readableRulesSummary: String? = nil
    ) {
        self.poolType = poolType
        self.payoutStyle = payoutStyle
        self.totalPoolAmount = totalPoolAmount
        self.currencyCode = currencyCode
        self.customPayoutDescription = customPayoutDescription
        self.readableRulesSummary = readableRulesSummary
    }

    private enum CodingKeys: String, CodingKey {
        case poolType, payoutStyle, totalPoolAmount, currencyCode, customPayoutDescription, readableRulesSummary
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        poolType = try c.decode(PoolType.self, forKey: .poolType)
        payoutStyle = try c.decode(PayoutStyle.self, forKey: .payoutStyle)
        totalPoolAmount = try c.decodeIfPresent(Double.self, forKey: .totalPoolAmount)
        currencyCode = try c.decode(String.self, forKey: .currencyCode)
        customPayoutDescription = try c.decodeIfPresent(String.self, forKey: .customPayoutDescription)
        readableRulesSummary = try c.decodeIfPresent(String.self, forKey: .readableRulesSummary)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(poolType, forKey: .poolType)
        try c.encode(payoutStyle, forKey: .payoutStyle)
        try c.encodeIfPresent(totalPoolAmount, forKey: .totalPoolAmount)
        try c.encode(currencyCode, forKey: .currencyCode)
        try c.encodeIfPresent(customPayoutDescription, forKey: .customPayoutDescription)
        try c.encodeIfPresent(readableRulesSummary, forKey: .readableRulesSummary)
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
        case .perScoreChange(_, let maxChanges):
            let n = maxChanges ?? 25
            return (1...n).map { .scoreChange($0) } + [.final]
        }
    }

    /// Human-readable period labels
    var periodLabels: [String] {
        periods.map { $0.displayLabel }
    }

    /// Payout amount or description per period (count must match periods.count when applicable)
    var payoutDescriptions: [String] {
        let count = periods.count
        if case .perScoreChange(let amountPerChange, let maxChanges) = poolType {
            let n = maxChanges ?? 25
            let per = (0..<min(n, count)).map { _ in formatCurrency(amountPerChange) }
            let remainder = count > n ? (totalPoolAmount.map { formatCurrency($0 - Double(n) * amountPerChange) } ?? "—") : nil
            return per + (remainder.map { [$0] } ?? [])
        }
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

    /// Short, professional summary for the "View payout rules" modal (parsed structure, not raw input).
    var professionalPayoutSummary: String {
        let periodLine = periodLabels.joined(separator: " · ")
        switch poolType {
        case .firstScoreChange:
            switch payoutStyle {
            case .fixedAmount(let amounts):
                let amount = amounts.first.map { formatCurrency($0) } ?? "the pot"
                return "One payout when the score first changes from 0–0. The winning square takes \(amount)."
            case .equalSplit, .percentage:
                return "One payout when the score first changes from 0–0. The winning square takes the full pot."
            case .custom(let descriptions):
                return descriptions.first ?? "One payout when the score first changes from 0–0."
            }
        case .perScoreChange(let amountPerChange, let maxChanges):
            let amount = formatCurrency(amountPerChange)
            let cap = maxChanges.map { " Payouts stop after \($0) score changes; the remainder goes to the final score winner." } ?? ""
            let total = totalPoolAmount.map { " Total pot: \(formatCurrency($0))." } ?? ""
            return "This pool pays \(amount) per score change (each point scored).\(cap)\(total)"
        default:
            break
        }
        switch payoutStyle {
        case .fixedAmount(let amounts):
            let amountsLine = amounts.prefix(periods.count).map { formatCurrency($0) }.joined(separator: ", ")
            if let total = totalPoolAmount, total > 0 {
                return "This pool pays at the end of each period. Payouts: \(amountsLine). Total pool: \(formatCurrency(total))."
            }
            return "This pool pays at the end of each period. Payouts: \(amountsLine)."
        case .percentage(let percents):
            let pctLine = percents.prefix(periods.count).map { "\(Int($0))%" }.joined(separator: ", ")
            if let total = totalPoolAmount, total > 0 {
                return "This pool pays a percentage of the pot each period. Payouts: \(pctLine). Total pool: \(formatCurrency(total))."
            }
            return "This pool pays a percentage of the pot each period. Payouts: \(pctLine)."
        case .equalSplit:
            let pct = periods.count > 0 ? 100 / periods.count : 0
            return "This pool splits the pot equally across \(periods.count) periods (\(pct)% each): \(periodLine)."
        case .custom(let descriptions):
            let descLine = descriptions.prefix(periods.count).joined(separator: ", ")
            return "This pool pays as follows: \(descLine)."
        }
    }

    /// For perScoreChange: amount per score change and remainder to final (for real-time UI).
    var perScoreChangeParams: (amountPerChange: Double, maxScoreChanges: Int)? {
        if case .perScoreChange(let amount, let max) = poolType { return (amount, max ?? 25) }
        return nil
    }

    /// One-line pool type label for the grid header (e.g. "Quarters" or "Q1 · Q2 · Q3 · Q4").
    var poolTypeLabel: String {
        switch poolType {
        case .byQuarter(let qs) where qs.sorted() == [1, 2, 3, 4]:
            return "Quarters"
        case .byQuarter:
            return periodLabels.joined(separator: " · ")
        case .halftimeOnly:
            return "Halftime"
        case .finalOnly:
            return "Final score"
        case .firstScoreChange:
            return "Score change"
        case .halftimeAndFinal:
            return "Halftime · Final"
        case .perScoreChange(_, let max):
            let cap = max.map { " (first \($0))" } ?? ""
            return "Per score change\(cap)"
        case .custom:
            return periodLabels.joined(separator: " · ")
        }
    }

    /// Amount per period if we have totalPoolAmount and a computable split
    func amountPerPeriod(at index: Int) -> Double? {
        guard index >= 0, index < periods.count else { return nil }
        if case .perScoreChange(let amountPerChange, let maxChanges) = poolType {
            let n = maxChanges ?? 25
            if index < n { return amountPerChange }
            guard let total = totalPoolAmount, total > 0 else { return nil }
            return total - (Double(n) * amountPerChange)
        }
        guard let total = totalPoolAmount, total >= 0 else { return nil }
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
    /// Pay per score change (each point = one change). Optional cap (e.g. 25); remainder goes to final. 0–0 is not a score change.
    case perScoreChange(amountPerChange: Double, maxScoreChanges: Int?)
}

// MARK: - Pool Period (single winning moment)

enum PoolPeriod: Codable, Equatable, Hashable {
    case quarter(Int)
    case halftime
    case final
    case firstScoreChange
    case custom(id: String, label: String)
    /// Nth score change (total points = N). 0–0 is not a score change.
    case scoreChange(Int)

    var displayLabel: String {
        switch self {
        case .quarter(let q): return "Q\(q)"
        case .halftime: return "Halftime"
        case .final: return "Final"
        case .firstScoreChange: return "First Score"
        case .custom(_, let label): return label
        case .scoreChange(let n): return "Change \(n)"
        }
    }

    var id: String {
        switch self {
        case .quarter(let q): return "Q\(q)"
        case .halftime: return "Halftime"
        case .final: return "Final"
        case .firstScoreChange: return "FirstScore"
        case .custom(let id, _): return id
        case .scoreChange(let n): return "ScoreChange\(n)"
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

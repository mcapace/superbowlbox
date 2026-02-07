import Foundation

/// Calls the payout-parse backend (Lambda/AI) to turn free-text payout rules into structured PoolStructure.
/// When PayoutParseBackendURL is set, the app uses only the API response for grid, modal, and payouts (no local inference). The AI powers the logic.
enum PayoutParseService {
    struct Response: Decodable {
        /// byQuarter | halftimeOnly | finalOnly | halftimeAndFinal | firstScoreChange | custom
        let poolType: String?
        /// For byQuarter: e.g. [1,2,3,4]
        let quarterNumbers: [Int]?
        /// For custom: e.g. ["Q1","Q2","Halftime","Final"]
        let customPeriodLabels: [String]?
        /// equalSplit | fixedAmount | percentage
        let payoutStyle: String?
        /// For fixedAmount: dollar amount per period in order
        let amountsPerPeriod: [Double]?
        /// For percentage: 0-100 per period in order
        let percentagesPerPeriod: [Double]?
        let totalPoolAmount: Double?
        let currencyCode: String?
        /// AI-written short, readable summary of the rules for the "View payout rules" modal.
        let readableRules: String?
        /// For perScoreChange: dollars per score change (e.g. 400).
        let amountPerChange: Double?
        /// For perScoreChange: cap on number of payouts (e.g. 25); remainder goes to final.
        let maxScoreChanges: Int?
    }

    /// Infer payout structure from rules text when backend is unavailable or returns equalSplit.
    /// Looks for dollar amounts (e.g. "$25", "25 dollars") and "halftime double" to build fixedAmount.
    static func inferFromDescription(_ text: String) -> PoolStructure? {
        let lower = text.lowercased()

        // Per score change: $X per score change, stop at N, remainder to final
        let isPerScoreChange = (lower.contains("per score change") || (lower.contains("score change") && lower.contains("$"))) && (lower.contains("stop at") || lower.contains("remainder") || lower.contains("25"))
        if isPerScoreChange {
            var amount: Double = 400
            if let regex = try? NSRegularExpression(pattern: #"\$?\s*(\d{2,4})\s*(?:dollars?)?\s*per\s*(?:score\s*change|point)"#, options: .caseInsensitive),
               let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let r = Range(m.range(at: 1), in: text), let n = Double(text[r]), n > 0 { amount = n }
            var maxChanges: Int? = 25
            if let regex = try? NSRegularExpression(pattern: #"stop\s*at\s*(\d+)"#, options: .caseInsensitive),
               let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               m.range(at: 1).location != NSNotFound, let r = Range(m.range(at: 1), in: text), let n = Int(text[r]), n > 0 { maxChanges = n }
            else if lower.contains("25") { maxChanges = 25 }
            var total: Double? = 10000
            if lower.contains("10,000") || lower.contains("10000") || lower.contains("$10,000") { total = 10000 }
            if lower.contains("100 per box") || lower.contains("$100 per box") { total = 10000 }
            return PoolStructure(poolType: .perScoreChange(amountPerChange: amount, maxScoreChanges: maxChanges), payoutStyle: .equalSplit, totalPoolAmount: total, currencyCode: "USD", customPayoutDescription: nil)
        }

        // First score / score change: one payout when score first changes from 0–0
        let isFirstScore = (lower.contains("first score") || lower.contains("first td") || lower.contains("first field goal") || lower.contains("first team to score")) && !isPerScoreChange
        if isFirstScore {
            let pattern = #"\$\s*(\d+(?:\.\d+)?)|\b(\d+(?:\.\d+)?)\s*dollars?"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                return PoolStructure(poolType: .firstScoreChange, payoutStyle: .equalSplit, currencyCode: "USD", customPayoutDescription: nil)
            }
            let range = NSRange(text.startIndex..., in: text)
            var amount: Double?
            regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                guard let m = match else { return }
                for i in 1..<m.numberOfRanges {
                    guard m.range(at: i).location != NSNotFound, let r = Range(m.range(at: i), in: text), let n = Double(text[r]), n > 0 else { continue }
                    amount = n
                    return
                }
            }
            if let amt = amount {
                return PoolStructure(poolType: .firstScoreChange, payoutStyle: .fixedAmount([amt]), totalPoolAmount: amt, currencyCode: "USD", customPayoutDescription: nil)
            }
            return PoolStructure(poolType: .firstScoreChange, payoutStyle: .equalSplit, currencyCode: "USD", customPayoutDescription: nil)
        }

        let hasDollars = lower.contains("$") || lower.contains("dollar")
        guard hasDollars else { return nil }

        // Extract numbers that look like dollar amounts: $25 or 25 dollars
        let pattern = #"\$\s*(\d+(?:\.\d+)?)|\b(\d+(?:\.\d+)?)\s*dollars?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        var amounts: [Double] = []
        regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let m = match else { return }
            for i in 1..<m.numberOfRanges {
                guard m.range(at: i).location != NSNotFound, let r = Range(m.range(at: i), in: text) else { continue }
                if let num = Double(text[r]), num > 0 { amounts.append(num) }
            }
        }
        if amounts.isEmpty { return nil }

        let halftimeDouble = lower.contains("halftime") && (lower.contains("double") || lower.contains("2x") || lower.contains("twice"))
        let byQuarter = lower.contains("quarter") || lower.contains("q1") || lower.contains("q2") || lower.contains("q3") || lower.contains("q4")

        if byQuarter && amounts.count == 1 {
            let base = amounts[0]
            let four: [Double] = halftimeDouble ? [base, base, base * 2, base] : [base, base, base, base]
            return PoolStructure(
                poolType: .byQuarter([1, 2, 3, 4]),
                payoutStyle: .fixedAmount(four),
                totalPoolAmount: four.reduce(0, +),
                currencyCode: "USD",
                customPayoutDescription: nil
            )
        }
        if amounts.count >= 2 {
            let capped = Array(amounts.prefix(8))
            return PoolStructure(
                poolType: capped.count == 4 ? .byQuarter([1, 2, 3, 4]) : .custom(periodLabels: (0..<capped.count).map { "Period \($0 + 1)" }),
                payoutStyle: .fixedAmount(capped),
                totalPoolAmount: capped.reduce(0, +),
                currencyCode: "USD",
                customPayoutDescription: nil
            )
        }
        return nil
    }

    /// POST payoutDescription to backend; returns a PoolStructure from the parsed response, or nil on failure.
    static func parse(payoutDescription: String) async throws -> PoolStructure {
        guard let url = PayoutParseConfig.backendURL else {
            throw PayoutParseError.notConfigured
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["payoutDescription": payoutDescription]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw PayoutParseError.httpError(status: code)
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return mapToPoolStructure(decoded)
    }

    private static func mapToPoolStructure(_ r: Response) -> PoolStructure {
        let poolType: PoolType = {
            let t = (r.poolType ?? "").lowercased()
            if t == "perscorechange" {
                let amount = r.amountPerChange ?? 400
                let max = r.maxScoreChanges
                return .perScoreChange(amountPerChange: amount, maxScoreChanges: max)
            }
            if t == "byquarter", let q = r.quarterNumbers, !q.isEmpty {
                return .byQuarter(Array(Set(q)).filter { (1...4).contains($0) }.sorted())
            }
            if t == "halftimeonly" { return .halftimeOnly }
            if t == "finalonly" { return .finalOnly }
            if t == "halftimeandfinal" { return .halftimeAndFinal }
            if t == "firstscorechange" { return .firstScoreChange }
            if t == "custom", let labels = r.customPeriodLabels, !labels.isEmpty {
                return .custom(periodLabels: labels)
            }
            return .byQuarter([1, 2, 3, 4])
        }()

        let payoutStyle: PayoutStyle = {
            let s = (r.payoutStyle ?? "").lowercased()
            if s == "fixedamount", let amounts = r.amountsPerPeriod, !amounts.isEmpty {
                return .fixedAmount(amounts)
            }
            if s == "percentage", let pcts = r.percentagesPerPeriod, !pcts.isEmpty {
                return .percentage(pcts)
            }
            return .equalSplit
        }()

        return PoolStructure(
            poolType: poolType,
            payoutStyle: payoutStyle,
            totalPoolAmount: r.totalPoolAmount,
            currencyCode: r.currencyCode ?? "USD",
            customPayoutDescription: nil,
            readableRulesSummary: (r.readableRules?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
        )
    }

    enum PayoutParseError: Error, LocalizedError {
        case notConfigured
        case httpError(status: Int)
        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Payout parse backend not configured"
            case .httpError(let s): return "Payout parse error (HTTP \(s))"
            }
        }
    }
}

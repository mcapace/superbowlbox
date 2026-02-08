import Foundation

/// Calls the payout-parse backend (Lambda/AI) to turn free-text payout rules into structured PoolStructure.
/// When PayoutParseBackendURL is set, the app uses only the API response for grid, modal, and payouts (no local inference). The AI powers the logic.
enum PayoutParseService {
    struct Response: Decodable {
        /// byQuarter | halftimeOnly | finalOnly | halftimeAndFinal | firstScoreChange | perScoreChange | custom
        let poolType: String?
        /// True if the AI needs more info to parse the rules correctly
        let needsClarification: Bool?
        /// Question to ask the user if needsClarification is true
        let clarificationQuestion: String?
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
        /// True if 0-0 counts as the first score change payout
        let zeroZeroCounts: Bool?
    }

    /// Result of parsing payout rules - includes clarification info if needed
    struct ParseResult {
        let structure: PoolStructure
        let needsClarification: Bool
        let clarificationQuestion: String?

        var isComplete: Bool { !needsClarification }
    }

    /// Infer payout structure from rules text when backend is unavailable or returns equalSplit.
    /// Looks for dollar amounts (e.g. "$25", "25 dollars") and "halftime double" to build fixedAmount.
    static func inferFromDescription(_ text: String) -> PoolStructure? {
        let lower = text.lowercased()

        // Per score change: $X per score change, stop at N, remainder to final
        let isPerScoreChange = (lower.contains("per score change") || lower.contains("per point") || (lower.contains("score change") && lower.contains("$")))
        if isPerScoreChange {
            var amount: Double?
            // Extract amount - handle comma-formatted numbers
            if let regex = try? NSRegularExpression(pattern: #"\$\s*([\d,]+(?:\.\d+)?)\s*(?:dollars?)?\s*(?:per|each)\s*(?:score\s*change|point|payoff)"#, options: .caseInsensitive),
               let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let r = Range(m.range(at: 1), in: text) {
                let numStr = String(text[r]).replacingOccurrences(of: ",", with: "")
                amount = Double(numStr)
            }

            var maxChanges: Int?
            if let regex = try? NSRegularExpression(pattern: #"stop\s*(?:at|after)\s*(\d+)"#, options: .caseInsensitive),
               let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               m.range(at: 1).location != NSNotFound, let r = Range(m.range(at: 1), in: text), let n = Int(text[r]), n > 0 {
                maxChanges = n
            }

            var total: Double?
            // Look for total pot/pool (not per box)
            if let regex = try? NSRegularExpression(pattern: #"\$\s*([\d,]+)\s*(?:total\s*(?:pot|pool)|pot|pool)"#, options: .caseInsensitive),
               let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let r = Range(m.range(at: 1), in: text) {
                let numStr = String(text[r]).replacingOccurrences(of: ",", with: "")
                total = Double(numStr)
            }

            if let amt = amount {
                return PoolStructure(poolType: .perScoreChange(amountPerChange: amt, maxScoreChanges: maxChanges), payoutStyle: .equalSplit, totalPoolAmount: total, currencyCode: "USD", customPayoutDescription: text)
            }
        }

        // First score / score change: one payout when score first changes from 0–0
        let isFirstScore = (lower.contains("first score") || lower.contains("first td") || lower.contains("first field goal") || lower.contains("first team to score")) && !isPerScoreChange
        if isFirstScore {
            let pattern = #"\$\s*([\d,]+(?:\.\d+)?)"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                return PoolStructure(poolType: .firstScoreChange, payoutStyle: .equalSplit, currencyCode: "USD", customPayoutDescription: text)
            }
            let range = NSRange(text.startIndex..., in: text)
            var amount: Double?
            regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                guard let m = match, let r = Range(m.range(at: 1), in: text) else { return }
                let numStr = String(text[r]).replacingOccurrences(of: ",", with: "")
                if let n = Double(numStr), n > 0 { amount = n; return }
            }
            if let amt = amount {
                return PoolStructure(poolType: .firstScoreChange, payoutStyle: .fixedAmount([amt]), totalPoolAmount: amt, currencyCode: "USD", customPayoutDescription: text)
            }
            return PoolStructure(poolType: .firstScoreChange, payoutStyle: .equalSplit, currencyCode: "USD", customPayoutDescription: text)
        }

        let hasDollars = lower.contains("$") || lower.contains("dollar")
        guard hasDollars else { return nil }

        // Extract dollar amounts - handle comma-formatted numbers
        let pattern = #"\$\s*([\d,]+(?:\.\d+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        var amounts: [Double] = []
        regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let m = match, let r = Range(m.range(at: 1), in: text) else { return }
            let numStr = String(text[r]).replacingOccurrences(of: ",", with: "")
            if let num = Double(numStr), num > 0 { amounts.append(num) }
        }
        if amounts.isEmpty { return nil }

        let halftimeDouble = lower.contains("halftime") && (lower.contains("double") || lower.contains("2x") || lower.contains("twice"))
        let byQuarter = lower.contains("quarter") || lower.contains("q1") || lower.contains("q2") || lower.contains("q3") || lower.contains("q4") || lower.contains("final")

        if byQuarter && amounts.count == 1 {
            let base = amounts[0]
            let four: [Double] = halftimeDouble ? [base, base, base * 2, base] : [base, base, base, base]
            return PoolStructure(
                poolType: .byQuarter([1, 2, 3, 4]),
                payoutStyle: .fixedAmount(four),
                totalPoolAmount: four.reduce(0, +),
                currencyCode: "USD",
                customPayoutDescription: text
            )
        }
        if amounts.count >= 2 {
            let capped = Array(amounts.prefix(8))
            return PoolStructure(
                poolType: capped.count == 4 ? .byQuarter([1, 2, 3, 4]) : .custom(periodLabels: (0..<capped.count).map { "Period \($0 + 1)" }),
                payoutStyle: .fixedAmount(capped),
                totalPoolAmount: capped.reduce(0, +),
                currencyCode: "USD",
                customPayoutDescription: text
            )
        }
        return nil
    }

    /// POST payoutDescription to backend; returns a ParseResult with structure and clarification info.
    static func parse(payoutDescription: String) async throws -> ParseResult {
        guard let url = PayoutParseConfig.backendURL else {
            throw PayoutParseError.notConfigured
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["payoutDescription": payoutDescription]
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError where urlError.code == .cannotFindHost {
            throw PayoutParseError.serverUnreachable
        }

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw PayoutParseError.httpError(status: code)
        }

        var dataToDecode = data
        // Lambda proxy can return { "statusCode": 200, "body": "<json string>" }; unwrap body if present
        if let wrapper = try? JSONDecoder().decode(LambdaProxyWrapper.self, from: data),
           let bodyData = wrapper.body.data(using: .utf8) {
            dataToDecode = bodyData
        }
        let decoded = try JSONDecoder().decode(Response.self, from: dataToDecode)
        return mapToParseResult(decoded, originalDescription: payoutDescription)
    }

    /// Re-parse rules after user provides clarification or updates rules
    static func reparse(originalDescription: String, clarification: String) async throws -> ParseResult {
        let combined = "\(originalDescription)\n\nAdditional info: \(clarification)"
        return try await parse(payoutDescription: combined)
    }

    private static func mapToParseResult(_ r: Response, originalDescription: String) -> ParseResult {
        let structure = mapToPoolStructure(r, originalDescription: originalDescription)
        return ParseResult(
            structure: structure,
            needsClarification: r.needsClarification ?? false,
            clarificationQuestion: r.clarificationQuestion
        )
    }

    private static func mapToPoolStructure(_ r: Response, originalDescription: String) -> PoolStructure {
        let poolType: PoolType = {
            let t = (r.poolType ?? "").lowercased()
            if t == "perscorechange" {
                let amount = r.amountPerChange
                let max = r.maxScoreChanges
                return .perScoreChange(amountPerChange: amount ?? 0, maxScoreChanges: max)
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
            customPayoutDescription: originalDescription,
            readableRulesSummary: (r.readableRules?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
        )
    }

    private struct LambdaProxyWrapper: Decodable {
        let body: String
    }

    enum PayoutParseError: Error, LocalizedError {
        case notConfigured
        case httpError(status: Int)
        case serverUnreachable
        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Payout parse backend not configured"
            case .httpError(let s): return "Payout parse error (HTTP \(s))"
            case .serverUnreachable: return "Payout server not found. Use a valid PayoutParseBackendURL in Secrets.plist."
            }
        }
    }
}

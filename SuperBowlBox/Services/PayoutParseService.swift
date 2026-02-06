import Foundation

/// Calls the payout-parse backend to turn free-text payout rules into structured PoolStructure
/// so the app can correctly determine current leader, period winners, in the hunt, and current winnings.
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
            customPayoutDescription: nil
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

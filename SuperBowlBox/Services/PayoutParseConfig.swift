import Foundation

/// Optional backend that parses free-text payout rules into structured pool type and amounts (e.g. Claude).
/// When set, the app can call "Parse with AI" to understand payout logic for current leader, winners, in the hunt, current winnings.
enum PayoutParseConfig {
    private static let backendURLKey = "PayoutParseBackendURL"

    /// Only doc-placeholder hostnames are treated as unset. Real and local URLs work.
    static var backendURL: URL? {
        if let s = stringFromSecrets(key: backendURLKey), !s.isEmpty, !isPlaceholderURL(s) {
            return URL(string: s.trimmingCharacters(in: .whitespaces))
        }
        if let s = ProcessInfo.processInfo.environment["PAYOUT_PARSE_BACKEND_URL"], !s.isEmpty, !isPlaceholderURL(s) {
            return URL(string: s.trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    private static func isPlaceholderURL(_ s: String) -> Bool {
        let host = (URL(string: s.trimmingCharacters(in: .whitespaces))?.host ?? "").lowercased()
        return host == "your-api.example.com" || host.contains("your-api-id")
    }

    static var usePayoutParse: Bool { backendURL != nil }

    private static func stringFromSecrets(key: String) -> String? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any] else { return nil }
        return dict[key] as? String
    }
}

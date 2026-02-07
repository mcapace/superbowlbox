import Foundation

/// Sports Data IO API key and base URLs. Keys are read from Secrets.plist (gitignored) first,
/// then Info.plist. Use Secrets.example.plist as a template: copy to Secrets.plist and add your key.
/// Get your key at https://sportsdata.io (account / API keys).
enum SportsDataIOConfig {
    private static let apiKeyKey = "SportsDataIOApiKey"

    /// Placeholder values (e.g. YOUR_SPORTSDATA_IO_KEY) are treated as unset so the app uses ESPN when plist is not filled in.
    static var apiKey: String? {
        let raw: String? = {
            if let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
               let dict = NSDictionary(contentsOf: url) as? [String: Any],
               let key = dict[apiKeyKey] as? String { return key }
            return Bundle.main.object(forInfoDictionaryKey: apiKeyKey) as? String
        }()
        guard let key = raw?.trimmingCharacters(in: .whitespaces), !key.isEmpty else { return nil }
        if key.uppercased().hasPrefix("YOUR_") || key == "YOUR_SPORTSDATA_IO_KEY" { return nil }
        return key
    }

    static var isConfigured: Bool {
        guard let key = apiKey else { return false }
        return !key.trimmingCharacters(in: .whitespaces).isEmpty
    }

    static let base = "https://api.sportsdata.io/v3"

    /// Builds a URL for any league scores (e.g. nfl, nba, ncaaf). Path e.g. "ScoresByDate/2024-02-11".
    static func scoresURL(league: String, pathComponent: String) -> URL? {
        let path = "\(base)/\(league)/scores/json/\(pathComponent)"
        return URL(string: path)
    }

    /// Builds a URL for NFL scores (convenience for current live score flow).
    static func nflScoresURL(pathComponent: String) -> URL? {
        scoresURL(league: "nfl", pathComponent: pathComponent)
    }

    /// Request with API key per Sports Data IO docs: "The API key can be passed either as a query parameter
    /// or using the following HTTP request header: Ocp-Apim-Subscription-Key: {key}"
    static func authenticatedRequest(url: URL) -> URLRequest? {
        guard let key = apiKey else { return nil }
        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        return request
    }
}

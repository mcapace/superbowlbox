import Foundation

/// Backend for shared pools (upload pool → get code; fetch pool by code).
/// Uses SharedPoolsURL / SharedPoolsApiKey from Secrets.plist, or falls back to LoginDatabaseURL / LoginDatabaseApiKey
/// so one Supabase project can serve both logins and shared_pools.
enum SharedPoolsConfig {
    private static let urlKey = "SharedPoolsURL"
    private static let apiKeyKey = "SharedPoolsApiKey"

    static var baseURL: URL? {
        let raw: URL? = {
            if let url = urlFromSecrets(key: urlKey) ?? Bundle.main.object(forInfoDictionaryKey: urlKey) as? String,
               !url.trimmingCharacters(in: .whitespaces).isEmpty,
               let u = URL(string: url.trimmingCharacters(in: .whitespaces)) {
                return u
            }
            return LoginDatabaseConfig.baseURL
        }()
        guard let url = raw else { return nil }
        return urlWithRestV1IfSupabase(url)
    }

    /// Supabase REST API is at base/rest/v1. If the configured URL is just the project URL (e.g. https://xxx.supabase.co), append /rest/v1 to avoid 404.
    private static func urlWithRestV1IfSupabase(_ url: URL) -> URL {
        let host = (url.host ?? "").lowercased()
        guard host.contains("supabase.co") else { return url }
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path == "rest/v1" || path.hasSuffix("rest/v1") { return url }
        let baseStr = url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: baseStr + "/rest/v1") ?? url
    }

    static var apiKey: String? {
        if let s = apiKeyFromSecrets(key: apiKeyKey) ?? Bundle.main.object(forInfoDictionaryKey: apiKeyKey) as? String,
           !s.trimmingCharacters(in: .whitespaces).isEmpty {
            return s.trimmingCharacters(in: .whitespaces)
        }
        return LoginDatabaseConfig.apiKey
    }

    static var isConfigured: Bool { baseURL != nil }

    private static func urlFromSecrets(key: String) -> String? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any] else { return nil }
        return dict[key] as? String
    }

    private static func apiKeyFromSecrets(key: String) -> String? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any] else { return nil }
        return dict[key] as? String
    }
}

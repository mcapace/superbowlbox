import Foundation

/// Backend for shared pools (upload pool → get code; fetch pool by code).
/// Uses SharedPoolsURL / SharedPoolsApiKey from Secrets.plist, or falls back to LoginDatabaseURL / LoginDatabaseApiKey
/// so one Supabase project can serve both logins and shared_pools.
enum SharedPoolsConfig {
    private static let urlKey = "SharedPoolsURL"
    private static let apiKeyKey = "SharedPoolsApiKey"

    static var baseURL: URL? {
        if let url = urlFromSecrets(key: urlKey) ?? Bundle.main.object(forInfoDictionaryKey: urlKey) as? String,
           !url.trimmingCharacters(in: .whitespaces).isEmpty,
           let u = URL(string: url.trimmingCharacters(in: .whitespaces)) {
            return u
        }
        return LoginDatabaseConfig.baseURL
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

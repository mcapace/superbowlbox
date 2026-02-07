import Foundation

/// Optional backend for recording Apple/Google logins. Read from Secrets.plist (LoginDatabaseURL, optional LoginDatabaseApiKey).
/// If set, the app POSTs login events so you can store them in your own database (Supabase, Firebase, custom API).
enum LoginDatabaseConfig {
    private static let urlKey = "LoginDatabaseURL"
    private static let apiKeyKey = "LoginDatabaseApiKey"

    /// Base URL for the login API (e.g. https://your-project.supabase.co/rest/v1 or https://api.yourapp.com).
    /// Placeholder URLs (YOUR_PROJECT_REF) are treated as unset so the app doesn't call a fake Supabase.
    static var baseURL: URL? {
        guard let urlString = urlString, !urlString.trimmingCharacters(in: .whitespaces).isEmpty,
              !isPlaceholderURL(urlString),
              let url = URL(string: urlString.trimmingCharacters(in: .whitespaces)) else {
            return nil
        }
        return url
    }

    private static func isPlaceholderURL(_ s: String) -> Bool {
        let lower = s.lowercased()
        return lower.contains("your_project_ref") || lower.contains("your-project-ref")
    }

    /// Optional API key (e.g. Supabase anon key). If set, sent as Apikey + Authorization: Bearer.
    /// Placeholder values (YOUR_SUPABASE_ANON_KEY) are treated as unset.
    static var apiKey: String? {
        guard let s = apiKeyString?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
        if s.uppercased().contains("YOUR_") { return nil }
        return s
    }

    private static var urlString: String? {
        if let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
           let dict = NSDictionary(contentsOf: url) as? [String: Any],
           let s = dict[urlKey] as? String { return s }
        return Bundle.main.object(forInfoDictionaryKey: urlKey) as? String
    }

    private static var apiKeyString: String? {
        if let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
           let dict = NSDictionary(contentsOf: url) as? [String: Any],
           let s = dict[apiKeyKey] as? String { return s }
        return Bundle.main.object(forInfoDictionaryKey: apiKeyKey) as? String
    }

    static var isConfigured: Bool { baseURL != nil }
}

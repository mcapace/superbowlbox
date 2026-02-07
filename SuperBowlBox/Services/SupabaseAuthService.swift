import Foundation

/// Supabase Auth (GoTrue) REST API for email/password sign-in and sign-up.
/// Uses the same project as LoginDatabaseConfig: auth base URL is derived from LoginDatabaseURL.
enum SupabaseAuthService {
    /// Auth base URL, e.g. https://xxx.supabase.co/auth/v1 (derived from LoginDatabaseURL).
    static var authBaseURL: URL? {
        guard let restURL = LoginDatabaseConfig.baseURL else { return nil }
        let str = restURL.absoluteString
        guard str.contains("supabase.co") else { return nil }
        let authStr = str.replacingOccurrences(of: "/rest/v1", with: "/auth/v1")
        return URL(string: authStr)
    }

    static var isConfigured: Bool {
        authBaseURL != nil && LoginDatabaseConfig.apiKey != nil
    }

    /// POST /auth/v1/signup → create email user in Supabase Auth.
    static func signUp(email: String, password: String) async throws -> SupabaseAuthSession {
        let url = (authBaseURL?.appendingPathComponent("signup"))!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(LoginDatabaseConfig.apiKey!, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(LoginDatabaseConfig.apiKey!)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(SupabaseAuthRequest(email: email, password: password))

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response: response, data: data)
        return try JSONDecoder().decode(SupabaseAuthSession.self, from: data)
    }

    /// POST /auth/v1/token?grant_type=password → sign in with email/password.
    static func signIn(email: String, password: String) async throws -> SupabaseAuthSession {
        var comp = URLComponents(url: authBaseURL!.appendingPathComponent("token"), resolvingAgainstBaseURL: false)!
        comp.queryItems = [URLQueryItem(name: "grant_type", value: "password")]
        var request = URLRequest(url: comp.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(LoginDatabaseConfig.apiKey!, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(LoginDatabaseConfig.apiKey!)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(SupabaseAuthRequest(email: email, password: password))

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response: response, data: data)
        return try JSONDecoder().decode(SupabaseAuthSession.self, from: data)
    }

    private static func validateHTTP(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["msg"] as? String
                ?? (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error_description"] as? String
                ?? String(data: data, encoding: .utf8)
                ?? "Unknown error"
            throw SupabaseAuthError.http(statusCode: http.statusCode, message: message)
        }
    }
}

struct SupabaseAuthRequest: Encodable {
    let email: String
    let password: String
}

struct SupabaseAuthSession: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?
    let user: SupabaseAuthUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
    }
}

struct SupabaseAuthUser: Decodable {
    let id: String
    let email: String?
}

enum SupabaseAuthError: LocalizedError {
    case http(statusCode: Int, message: String)
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .http(let code, let msg): return "\(msg) (HTTP \(code))"
        case .notConfigured: return "Supabase auth is not configured. Set LoginDatabaseURL and LoginDatabaseApiKey in Secrets.plist."
        }
    }
}

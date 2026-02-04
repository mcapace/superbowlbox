import Foundation

/// Sends login events to your backend so you can store Apple/Google logins in a database.
/// Configure LoginDatabaseURL in Secrets.plist to enable. No-op if not set.
enum LoginDatabaseService {
    /// Path appended to base URL. Override if your API uses a different path (e.g. auth/login).
    static var loginPath = "logins"

    /// Record a login (or sign-up) after successful Apple or Google sign-in.
    /// Call from main thread optional; runs the request in the background.
    static func recordLogin(user: AuthUser) {
        guard let base = LoginDatabaseConfig.baseURL else { return }
        guard let url = URL(string: loginPath, relativeTo: base) else { return }

        let body = LoginPayload(
            provider: user.provider.rawValue,
            providerUid: user.id,
            email: user.email,
            displayName: user.displayName,
            clientTimestamp: ISO8601DateFormatter().string(from: Date())
        )

        guard let data = try? JSONEncoder().encode(body) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        URLSession.shared.dataTask(with: request) { _, response, _ in
            #if DEBUG
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                print("LoginDatabaseService: POST \(url) returned \(http.statusCode)")
            }
            #endif
        }.resume()
    }

    /// Optional: record sign-out for analytics. Only called if you add sign-out tracking.
    static func recordSignOut(provider: AuthProvider, providerUid: String) {
        guard let base = LoginDatabaseConfig.baseURL else { return }
        guard let url = URL(string: "logins/signout", relativeTo: base) else { return }

        let body: [String: Any] = [
            "provider": provider.rawValue,
            "provider_uid": providerUid,
            "client_timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key = LoginDatabaseConfig.apiKey {
            request.setValue(key, forHTTPHeaderField: "Apikey")
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = data

        URLSession.shared.dataTask(with: request).resume()
    }
}

// MARK: - Payload (matches common backend schema)

private struct LoginPayload: Encodable {
    let provider: String
    let providerUid: String
    let email: String?
    let displayName: String?
    let clientTimestamp: String

    enum CodingKeys: String, CodingKey {
        case provider
        case providerUid = "provider_uid"
        case email
        case displayName = "display_name"
        case clientTimestamp = "client_timestamp"
    }
}

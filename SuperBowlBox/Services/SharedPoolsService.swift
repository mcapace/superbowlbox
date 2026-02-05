import Foundation

/// Uploads a pool to get a share code and fetches a pool by code (Supabase shared_pools table or compatible API).
enum SharedPoolsService {
    static let tablePath = "shared_pools"

    enum SharedPoolsError: LocalizedError {
        case notConfigured
        case invalidURL
        case uploadFailed(Int)
        case fetchFailed(Int)
        case noPoolForCode
        case decodingFailed

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Share is not configured. Add SharedPoolsURL or LoginDatabaseURL in Secrets.plist."
            case .invalidURL: return "Invalid server URL."
            case .uploadFailed(let code): return "Upload failed (HTTP \(code))."
            case .fetchFailed(let code): return "Could not load pool (HTTP \(code))."
            case .noPoolForCode: return "Invalid or expired code."
            case .decodingFailed: return "Invalid pool data."
            }
        }
    }

    /// Generate an 8-character uppercase alphanumeric code.
    private static func generateCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<8).map { _ in chars.randomElement()! })
    }

    /// Upload pool to backend; returns the share code. Uses existing sharedCode if backend supports upsert, otherwise always creates new row.
    static func uploadPool(_ pool: BoxGrid) async throws -> String {
        guard SharedPoolsConfig.isConfigured else { throw SharedPoolsError.notConfigured }
        guard let base = SharedPoolsConfig.baseURL,
              let url = URL(string: tablePath, relativeTo: base) else { throw SharedPoolsError.invalidURL }

        let code = generateCode()
        let body = SharedPoolRowPayload(code: code, pool_json: pool)
        guard let data = try? JSONEncoder().encode(body) else { throw SharedPoolsError.decodingFailed }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = data
        if let key = SharedPoolsConfig.apiKey {
            request.setValue(key, forHTTPHeaderField: "Apikey")
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SharedPoolsError.uploadFailed(0) }
        guard (200...299).contains(http.statusCode) else { throw SharedPoolsError.uploadFailed(http.statusCode) }
        return code
    }

    /// Fetch pool by invite code.
    static func fetchPool(code: String) async throws -> BoxGrid {
        guard SharedPoolsConfig.isConfigured else { throw SharedPoolsError.notConfigured }
        let trimmed = code.trimmingCharacters(in: .whitespaces).uppercased()
        guard trimmed.count == 8 else { throw SharedPoolsError.noPoolForCode }

        guard let base = SharedPoolsConfig.baseURL else { throw SharedPoolsError.invalidURL }
        var comp = URLComponents(url: base.appendingPathComponent(tablePath), resolvingAgainstBaseURL: true)!
        comp.queryItems = [
            URLQueryItem(name: "code", value: "eq.\(trimmed)"),
            URLQueryItem(name: "select", value: "pool_json")
        ]
        guard let url = comp.url else { throw SharedPoolsError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let key = SharedPoolsConfig.apiKey {
            request.setValue(key, forHTTPHeaderField: "Apikey")
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SharedPoolsError.fetchFailed(0) }
        guard http.statusCode == 200 else { throw SharedPoolsError.fetchFailed(http.statusCode) }

        let rows = try JSONDecoder().decode([SharedPoolFetchRow].self, from: data)
        guard let first = rows.first else { throw SharedPoolsError.noPoolForCode }
        return first.pool_json
    }
}

private struct SharedPoolRowPayload: Encodable {
    let code: String
    let pool_json: BoxGrid
}

private struct SharedPoolFetchRow: Decodable {
    let pool_json: BoxGrid
}

import Foundation

/// Uploads a pool to get a share code and fetches a pool by code (Supabase shared_pools table or compatible API).
enum SharedPoolsService {
    static let tablePath = "shared_pools"

    enum SharedPoolsError: LocalizedError {
        case notConfigured
        case invalidURL
        case uploadFailed(Int, String?)
        case fetchFailed(Int)
        case noPoolForCode
        case decodingFailed

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Share is not configured. Add SharedPoolsURL or LoginDatabaseURL in Secrets.plist."
            case .invalidURL: return "Invalid server URL."
            case .uploadFailed(let code, let detail):
                var msg = "Upload failed (HTTP \(code))."
                if code == 404 {
                    msg += " Use Supabase URL ending in /rest/v1, set anon key, and ensure shared_pools table exists (run migration)."
                }
                if let d = detail, !d.isEmpty { msg += " \(d)" }
                return msg
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

    /// Builds the full URL for the shared_pools table (Supabase: base is .../rest/v1, so this becomes .../rest/v1/shared_pools).
    private static func tableURL() throws -> URL {
        guard let base = SharedPoolsConfig.baseURL else { throw SharedPoolsError.invalidURL }
        let baseStr = base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: baseStr + "/" + tablePath) else { throw SharedPoolsError.invalidURL }
        return url
    }

    /// Upload pool to backend; returns the share code. Rules/payout/structure are stored; ownerLabels are stripped so joiners claim with their own name.
    static func uploadPool(_ pool: BoxGrid) async throws -> String {
        guard SharedPoolsConfig.isConfigured else { throw SharedPoolsError.notConfigured }
        let url: URL
        do { url = try tableURL() } catch { throw error }

        var template = pool
        template.ownerLabels = nil
        let code = generateCode()
        let body = SharedPoolRowPayload(code: code, pool_json: template)
        guard let bodyData = try? JSONEncoder().encode(body) else { throw SharedPoolsError.decodingFailed }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.setValue("public", forHTTPHeaderField: "Content-Profile")
        request.setValue("public", forHTTPHeaderField: "Accept-Profile")
        request.httpBody = bodyData
        if let key = SharedPoolsConfig.apiKey {
            request.setValue(key, forHTTPHeaderField: "Apikey")
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SharedPoolsError.uploadFailed(0, nil) }
        guard (200...299).contains(http.statusCode) else {
            let detail = Self.messageFromErrorResponse(responseData)
            throw SharedPoolsError.uploadFailed(http.statusCode, detail)
        }
        return code
    }

    /// Fetch pool by invite code.
    static func fetchPool(code: String) async throws -> BoxGrid {
        guard SharedPoolsConfig.isConfigured else { throw SharedPoolsError.notConfigured }
        let trimmed = code.trimmingCharacters(in: .whitespaces).uppercased()
        guard trimmed.count == 8 else { throw SharedPoolsError.noPoolForCode }

        guard let base = SharedPoolsConfig.baseURL else { throw SharedPoolsError.invalidURL }
        let baseStr = base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var comp = URLComponents(string: baseStr + "/" + tablePath)!
        comp.queryItems = [
            URLQueryItem(name: "code", value: "eq.\(trimmed)"),
            URLQueryItem(name: "select", value: "pool_json")
        ]
        guard let url = comp.url else { throw SharedPoolsError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("public", forHTTPHeaderField: "Accept-Profile")
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

    /// Delete a shared pool by invite code (owner only). Participants will get noPoolForCode when they next check and can be alerted.
    static func deletePool(code: String) async throws {
        guard SharedPoolsConfig.isConfigured else { throw SharedPoolsError.notConfigured }
        let trimmed = code.trimmingCharacters(in: .whitespaces).uppercased()
        guard trimmed.count == 8 else { return }

        guard let base = SharedPoolsConfig.baseURL else { throw SharedPoolsError.invalidURL }
        let baseStr = base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var comp = URLComponents(string: baseStr + "/" + tablePath)!
        comp.queryItems = [URLQueryItem(name: "code", value: "eq.\(trimmed)")]
        guard let url = comp.url else { throw SharedPoolsError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("public", forHTTPHeaderField: "Content-Profile")
        if let key = SharedPoolsConfig.apiKey {
            request.setValue(key, forHTTPHeaderField: "Apikey")
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SharedPoolsError.uploadFailed(0, nil) }
        guard (200...299).contains(http.statusCode) else { throw SharedPoolsError.uploadFailed(http.statusCode, Self.messageFromErrorResponse(data)) }
    }

    /// Parse Supabase/PostgREST error body for a short message to show the user.
    private static func messageFromErrorResponse(_ data: Data?) -> String? {
        guard let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let msg = json["message"] as? String { return msg }
        if let msg = json["error_description"] as? String { return msg }
        if let details = json["details"] as? String { return details }
        if let code = json["code"] as? String { return code }
        return nil
    }
}

private struct SharedPoolRowPayload: Encodable {
    let code: String
    let pool_json: BoxGrid
}

private struct SharedPoolFetchRow: Decodable {
    let pool_json: BoxGrid
}

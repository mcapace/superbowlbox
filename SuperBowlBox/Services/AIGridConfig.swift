import Foundation

/// AI grid parsing: use a backend that calls Claude (or similar) to read the pool sheet from the image.
/// Configure AIGridBackendURL in Secrets.plist to use AI instead of OCR.
enum AIGridConfig {
    private static let backendURLKey = "AIGridBackendURL"

    /// Backend URL that accepts an image and returns structured pool JSON (e.g. Lambda/API that calls Claude).
    /// Only doc-placeholder hostnames are treated as unset (your-api.example.com, your-api-id). Real and local URLs work.
    static var backendURL: URL? {
        if let s = stringFromSecrets(key: backendURLKey), !s.isEmpty, !isPlaceholderURL(s) {
            return URL(string: s.trimmingCharacters(in: .whitespaces))
        }
        if let s = ProcessInfo.processInfo.environment["AI_GRID_BACKEND_URL"], !s.isEmpty, !isPlaceholderURL(s) {
            return URL(string: s.trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    /// Reject only the exact placeholders from docs/example plist so staging and localhost work.
    private static func isPlaceholderURL(_ s: String) -> Bool {
        let host = (URL(string: s.trimmingCharacters(in: .whitespaces))?.host ?? "").lowercased()
        return host == "your-api.example.com" || host.contains("your-api-id")
    }

    static var useAIGrid: Bool { backendURL != nil }

    private static func stringFromSecrets(key: String) -> String? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any] else { return nil }
        return dict[key] as? String
    }
}

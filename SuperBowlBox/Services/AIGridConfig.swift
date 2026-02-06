import Foundation

/// AI grid parsing: use a backend that calls Claude (or similar) to read the pool sheet from the image.
/// Configure AIGridBackendURL in Secrets.plist to use AI instead of OCR.
enum AIGridConfig {
    private static let backendURLKey = "AIGridBackendURL"

    /// Backend URL that accepts an image and returns structured pool JSON (e.g. Lambda/API that calls Claude).
    static var backendURL: URL? {
        if let s = stringFromSecrets(key: backendURLKey), !s.isEmpty {
            return URL(string: s.trimmingCharacters(in: .whitespaces))
        }
        if let s = ProcessInfo.processInfo.environment["AI_GRID_BACKEND_URL"], !s.isEmpty {
            return URL(string: s.trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    static var useAIGrid: Bool { backendURL != nil }

    private static func stringFromSecrets(key: String) -> String? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any] else { return nil }
        return dict[key] as? String
    }
}

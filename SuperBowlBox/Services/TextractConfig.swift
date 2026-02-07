import Foundation

/// Textract configuration: either a backend URL (recommended for distribution) or direct AWS keys (dev only).
enum TextractConfig {
    private static let regionKey = "AWSRegion"
    private static let accessKeyKey = "AWSAccessKeyId"
    private static let secretKeyKey = "AWSSecretAccessKey"
    private static let backendURLKey = "TextractBackendURL"

    /// Backend OCR URL (e.g. Lambda + API Gateway). When set, app sends image here; no AWS keys in app.
    /// Placeholder hostnames (your-api.example.com, your-api-id) are treated as unset so on-device Vision is used.
    static var backendURL: URL? {
        if let s = stringFromSecrets(key: backendURLKey), !s.isEmpty, !isPlaceholderURL(s) {
            return URL(string: s.trimmingCharacters(in: .whitespaces))
        }
        if let s = ProcessInfo.processInfo.environment["TEXTRACT_BACKEND_URL"], !s.isEmpty, !isPlaceholderURL(s) {
            return URL(string: s.trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    private static func isPlaceholderURL(_ s: String) -> Bool {
        let host = (URL(string: s.trimmingCharacters(in: .whitespaces))?.host ?? "").lowercased()
        return host.contains("example.com") || host.contains("your-api")
    }

    /// Use Textract via your backend (no keys in app). Prefer this for distributed builds.
    static var useBackend: Bool { backendURL != nil }

    static var region: String? {
        if let s = stringFromSecrets(key: regionKey), !s.isEmpty { return s.trimmingCharacters(in: .whitespaces) }
        return ProcessInfo.processInfo.environment["AWS_REGION"]
    }

    static var accessKeyId: String? {
        if let s = stringFromSecrets(key: accessKeyKey), !s.isEmpty { return s.trimmingCharacters(in: .whitespaces) }
        return ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"]
    }

    static var secretAccessKey: String? {
        if let s = stringFromSecrets(key: secretKeyKey), !s.isEmpty { return s.trimmingCharacters(in: .whitespaces) }
        return ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"]
    }

    /// Direct AWS credentials (dev only; do not use in distributed app).
    static var isConfigured: Bool {
        region != nil && accessKeyId != nil && secretAccessKey != nil
    }

    /// Use Textract at all: either via backend or via direct AWS (dev).
    static var useTextract: Bool { useBackend || isConfigured }

    private static func stringFromSecrets(key: String) -> String? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any] else { return nil }
        return dict[key] as? String
    }
}

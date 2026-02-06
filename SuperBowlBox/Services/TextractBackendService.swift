import Foundation

/// Calls your backend OCR endpoint (e.g. Lambda + Textract). No AWS keys in the app.
enum TextractBackendService {
    /// POST image to backend; returns text blocks in Vision-style coordinates (normalized 0–1, origin bottom-left).
    static func recognize(imageData: Data, url: URL) async throws -> [VisionService.RecognizedTextBlock] {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw BackendError.httpError(status: http.statusCode)
        }

        let decoded = try JSONDecoder().decode(BackendOCRResponse.self, from: data)
        return decoded.blocks.map { block in
            let rect = CGRect(
                x: CGFloat(block.x),
                y: CGFloat(block.y),
                width: CGFloat(block.width),
                height: CGFloat(block.height)
            )
            return VisionService.RecognizedTextBlock(
                text: block.text,
                boundingBox: rect,
                confidence: Float(block.confidence)
            )
        }
    }

    private struct BackendOCRResponse: Decodable {
        let blocks: [Block]
        struct Block: Decodable {
            let text: String
            let x: Double
            let y: Double
            let width: Double
            let height: Double
            let confidence: Double
        }
    }

    enum BackendError: Error, LocalizedError {
        case invalidResponse
        case httpError(status: Int)
        var errorDescription: String? {
            switch self {
            case .invalidResponse: return "Invalid response from OCR server"
            case .httpError(let s): return "OCR server error (HTTP \(s))"
            }
        }
    }
}

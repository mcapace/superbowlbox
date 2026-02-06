import Foundation

/// Sends the pool sheet image to your AI backend (e.g. Claude). Backend returns structured pool JSON.
enum AIGridBackendService {
    /// POST image to backend; returns a BoxGrid built from the AI response.
    static func parseGrid(imageData: Data, url: URL) async throws -> BoxGrid {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIGridBackendError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw AIGridBackendError.httpError(status: http.statusCode)
        }

        var dataToDecode = data
        // Lambda proxy can return { "statusCode": 200, "body": "<json string>" }; unwrap body if present
        if let wrapper = try? JSONDecoder().decode(LambdaProxyWrapper.self, from: data),
           let bodyData = wrapper.body.data(using: .utf8) {
            dataToDecode = bodyData
        }
        // If response looks like OCR blocks (wrong backend), give a clear message
        if let raw = String(data: dataToDecode, encoding: .utf8), raw.contains("\"blocks\"") {
            throw AIGridBackendError.invalidJSON(
                reason: "Wrong backend: got OCR blocks. Point POST /ai-grid to the AI grid Lambda (superbowlbox-ai-grid), not the OCR Lambda.",
                responsePreview: String(raw.prefix(150))
            )
        }
        do {
            let decoded = try JSONDecoder().decode(AIGridResponse.self, from: dataToDecode)
            return try decoded.toBoxGrid()
        } catch {
            let preview = String(data: dataToDecode.prefix(300), encoding: .utf8) ?? ""
            throw AIGridBackendError.invalidJSON(reason: error.localizedDescription, responsePreview: preview)
        }
    }

    private struct LambdaProxyWrapper: Decodable {
        let body: String
    }

    private struct AIGridResponse: Decodable {
        let homeTeamAbbreviation: String?
        let awayTeamAbbreviation: String?
        let homeNumbers: [Int]?
        let awayNumbers: [Int]?
        /// Row-major: names[row][column], 10 rows × 10 columns. Empty string = empty cell.
        let names: [[String]]?

        func toBoxGrid() throws -> BoxGrid {
            let home = Team.from(abbreviation: homeTeamAbbreviation ?? "") ?? Team.unknown
            let away = Team.from(abbreviation: awayTeamAbbreviation ?? "") ?? Team.unknown
            let homeNums = (homeNumbers?.count == 10) ? homeNumbers! : Array(0...9).shuffled()
            let awayNums = (awayNumbers?.count == 10) ? awayNumbers! : Array(0...9).shuffled()

            var grid = BoxGrid(
                homeTeam: home,
                awayTeam: away,
                homeNumbers: homeNums,
                awayNumbers: awayNums
            )

            let nameGrid = names ?? []
            for row in 0..<10 {
                for col in 0..<10 {
                    let name = (row < nameGrid.count && col < nameGrid[row].count)
                        ? nameGrid[row][col].trimmingCharacters(in: .whitespacesAndNewlines)
                        : ""
                    if !name.isEmpty {
                        grid.updateSquare(row: row, column: col, playerName: name)
                    }
                }
            }
            return grid
        }
    }

    enum AIGridBackendError: Error, LocalizedError {
        case invalidResponse
        case httpError(status: Int)
        case invalidJSON(reason: String, responsePreview: String)
        var errorDescription: String? {
            switch self {
            case .invalidResponse: return "Invalid response from AI grid server"
            case .httpError(let s): return "AI grid server error (HTTP \(s))"
            case .invalidJSON(let reason, let preview):
                let short = preview.count > 120 ? String(preview.prefix(120)) + "…" : preview
                return "AI returned unexpected format: \(reason). Response: \(short)"
            }
        }
    }
}

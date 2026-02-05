import Foundation
import Vision
import UIKit
import CoreImage

class VisionService: ObservableObject {
    @Published var isProcessing = false
    @Published var recognizedText: [RecognizedTextBlock] = []
    @Published var detectedGrid: DetectedGrid?
    @Published var error: VisionError?

    struct RecognizedTextBlock: Identifiable {
        let id = UUID()
        let text: String
        let boundingBox: CGRect
        let confidence: Float
    }

    struct DetectedGrid {
        var homeNumbers: [Int]
        var awayNumbers: [Int]
        var names: [[String]]  // 10x10 grid of names
        var confidence: Float
    }

    enum VisionError: Error, LocalizedError {
        case imageProcessingFailed
        case noTextFound
        case gridDetectionFailed
        case invalidGridStructure

        var errorDescription: String? {
            switch self {
            case .imageProcessingFailed:
                return "Failed to process the image"
            case .noTextFound:
                return "No text was found in the image"
            case .gridDetectionFailed:
                return "Could not detect a valid grid structure"
            case .invalidGridStructure:
                return "The detected grid doesn't match expected format"
            }
        }
    }

    func processImage(_ image: UIImage) async throws -> BoxGrid {
        await MainActor.run {
            isProcessing = true
            error = nil
        }

        defer {
            Task { @MainActor in
                isProcessing = false
            }
        }

        guard let cgImage = image.cgImage else {
            throw VisionError.imageProcessingFailed
        }

        // Perform text recognition on the whole sheet (numbers, names, team labels, titles)
        let textBlocks = try await recognizeText(in: cgImage)

        await MainActor.run {
            recognizedText = textBlocks
        }

        if textBlocks.isEmpty {
            throw VisionError.noTextFound
        }

        // Parse the full sheet into grid structure: numbers, names, and optional team detection
        let grid = try await parseGridFromText(textBlocks, imageSize: CGSize(width: cgImage.width, height: cgImage.height))

        return grid
    }

    private func recognizeText(in image: CGImage) async throws -> [RecognizedTextBlock] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let blocks = observations.compactMap { observation -> RecognizedTextBlock? in
                    guard let topCandidate = observation.topCandidates(1).first else { return nil }
                    return RecognizedTextBlock(
                        text: topCandidate.string,
                        boundingBox: observation.boundingBox,
                        confidence: topCandidate.confidence
                    )
                }

                continuation.resume(returning: blocks)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["en-US"]
            request.minimumTextHeight = 0.008

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func parseGridFromText(_ blocks: [RecognizedTextBlock], imageSize: CGSize) async throws -> BoxGrid {
        // Use the whole sheet: sort all text by position (top to bottom, left to right)
        let sortedBlocks = blocks.sorted { block1, block2 in
            let y1 = 1 - block1.boundingBox.midY
            let y2 = 1 - block2.boundingBox.midY
            if abs(y1 - y2) < 0.06 { return block1.boundingBox.minX < block2.boundingBox.minX }
            return y1 < y2
        }

        // Detect teams from any text on the sheet (titles, labels, headers)
        var detectedTeams: [Team] = []
        for block in sortedBlocks {
            let text = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if let team = Team.firstMatching(in: text), !detectedTeams.contains(where: { $0.id == team.id }) {
                detectedTeams.append(team)
            }
        }
        let (homeTeam, awayTeam): (Team, Team) = {
            if detectedTeams.count >= 2 {
                return (detectedTeams[1], detectedTeams[0])
            }
            if detectedTeams.count == 1 {
                return (detectedTeams[0], Team.eagles)
            }
            return (Team.chiefs, Team.eagles)
        }()

        var homeNumbers: [Int] = []
        var awayNumbers: [Int] = []
        var nameGrid: [[String]] = Array(repeating: Array(repeating: "", count: 10), count: 10)

        // Group blocks by row — use tolerance so two lines in one cell (e.g. "Mike" / "Capace") stay in same row
        var rows: [[RecognizedTextBlock]] = []
        var currentRow: [RecognizedTextBlock] = []
        var lastY: CGFloat = -1
        let rowTolerance: CGFloat = 0.08

        for block in sortedBlocks {
            let y = 1 - block.boundingBox.midY
            if lastY < 0 || abs(y - lastY) < rowTolerance {
                currentRow.append(block)
            } else {
                if !currentRow.isEmpty {
                    rows.append(currentRow.sorted { $0.boundingBox.minX < $1.boundingBox.minX })
                }
                currentRow = [block]
            }
            lastY = y
        }
        if !currentRow.isEmpty {
            rows.append(currentRow.sorted { $0.boundingBox.minX < $1.boundingBox.minX })
        }

        // Header row = row that has exactly 10 single digits (0-9) — the column numbers. Ignore "Patriots" / team row.
        var headerRowIndex: Int?
        var headerBlocksByX: [RecognizedTextBlock] = []
        for (rowIndex, row) in rows.enumerated() {
            let digitBlocks = row.filter { b in
                let t = b.text.trimmingCharacters(in: .whitespaces)
                return t.count == 1 && (Int(t).map { (0...9).contains($0) } ?? false)
            }
            if digitBlocks.count == 10 {
                headerRowIndex = rowIndex
                headerBlocksByX = digitBlocks.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
                homeNumbers = headerBlocksByX.compactMap { b in Int(b.text.trimmingCharacters(in: .whitespaces)) }
                break
            }
        }
        if headerRowIndex == nil {
            for (rowIndex, row) in rows.enumerated() {
                let digitBlocks = row.filter { b in
                    let t = b.text.trimmingCharacters(in: .whitespaces)
                    return t.count == 1 && (Int(t).map { (0...9).contains($0) } ?? false)
                }
                if digitBlocks.count >= 6 && digitBlocks.count <= 12 {
                    headerRowIndex = rowIndex
                    headerBlocksByX = digitBlocks.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
                    if headerBlocksByX.count > 10 { headerBlocksByX = Array(headerBlocksByX.prefix(10)) }
                    homeNumbers = headerBlocksByX.compactMap { b in Int(b.text.trimmingCharacters(in: .whitespaces)) }
                    break
                }
            }
        }

        // Column boundaries: 11 split points so column i is [bounds[i], bounds[i+1])
        let columnBounds: [CGFloat]
        if headerBlocksByX.count == 10 {
            let midX = headerBlocksByX.map { $0.boundingBox.midX }
            var bounds: [CGFloat] = []
            for i in 0...10 {
                if i == 0 {
                    bounds.append(max(0, midX[0] - 0.05))
                } else if i == 10 {
                    bounds.append(min(1, midX[9] + 0.05))
                } else {
                    bounds.append((midX[i - 1] + midX[i]) / 2)
                }
            }
            columnBounds = bounds
        } else {
            columnBounds = (0...10).map { CGFloat($0) / 10.0 }
        }
        let awayColumnMaxX = (headerBlocksByX.first?.boundingBox.minX ?? 0.12) - 0.03

        func columnForBlock(_ block: RecognizedTextBlock) -> Int? {
            let x = block.boundingBox.midX
            if x < awayColumnMaxX { return nil }
            for i in 0..<10 {
                if x >= columnBounds[i] && x < columnBounds[i + 1] { return i }
            }
            return 9
        }

        // Data rows: one row index per grid row; away number = leftmost single digit in that row
        if let headerIdx = headerRowIndex, homeNumbers.count == 10 {
            for dataRowOffset in 0..<10 {
                let rowIndex = headerIdx + 1 + dataRowOffset
                guard rowIndex < rows.count else { break }
                let row = rows[rowIndex]

                let awayDigitBlock = row
                    .filter { b in
                        let t = b.text.trimmingCharacters(in: .whitespaces)
                        return t.count == 1 && (Int(t).map { (0...9).contains($0) } ?? false) && b.boundingBox.midX < awayColumnMaxX
                    }
                    .min(by: { $0.boundingBox.minX < $1.boundingBox.minX })
                if let b = awayDigitBlock, let n = Int(b.text.trimmingCharacters(in: .whitespaces)) {
                    awayNumbers.append(n)
                }

                for block in row {
                    let text = block.text.trimmingCharacters(in: .whitespaces)
                    guard !text.isEmpty else { continue }
                    let isSingleDigit = text.count == 1 && (Int(text).map { (0...9).contains($0) } ?? false)
                    let isCellId = text.count <= 3 && (Int(text).map { (1...100).contains($0) } ?? false)

                    if isSingleDigit && block.boundingBox.midX < awayColumnMaxX { continue }
                    if isCellId { continue }
                    if let col = columnForBlock(block), col >= 0, col < 10 {
                        let existing = nameGrid[dataRowOffset][col]
                        nameGrid[dataRowOffset][col] = existing.isEmpty ? text : (existing + " " + text)
                    }
                }
            }
        }

        // Fallback: if no names captured (e.g. no header blocks), use one-block-per-column order
        if nameGrid.flatMap({ $0 }).filter({ !$0.isEmpty }).isEmpty, let headerIdx = headerRowIndex {
            for dataRowOffset in 0..<10 {
                let rowIndex = headerIdx + 1 + dataRowOffset
                guard rowIndex < rows.count else { break }
                let row = rows[rowIndex]
                var colOffset = 0
                for (colIndex, block) in row.enumerated() {
                    let text = block.text.trimmingCharacters(in: .whitespaces)
                    if colIndex == 0, let num = Int(text), num >= 0 && num <= 9 {
                        if awayNumbers.count < 10 { awayNumbers.append(num) }
                        colOffset = 1
                        continue
                    }
                    let gridColIndex = colIndex - colOffset
                    if gridColIndex >= 0 && gridColIndex < 10, !text.isEmpty {
                        nameGrid[dataRowOffset][gridColIndex] = text
                    }
                }
            }
        }

        if homeNumbers.count != 10 { homeNumbers = Array(0...9).shuffled() }
        if awayNumbers.count != 10 { awayNumbers = Array(0...9).shuffled() }

        var grid = BoxGrid(
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            homeNumbers: homeNumbers,
            awayNumbers: awayNumbers
        )

        for row in 0..<10 {
            for col in 0..<10 {
                let name = nameGrid[row][col]
                if !name.isEmpty {
                    grid.updateSquare(row: row, column: col, playerName: name)
                }
            }
        }

        let h = homeNumbers
        let a = awayNumbers
        let n = nameGrid
        let confidence = Float(sortedBlocks.map { $0.confidence }.reduce(0, +)) / Float(max(sortedBlocks.count, 1))
        await MainActor.run {
            detectedGrid = DetectedGrid(homeNumbers: h, awayNumbers: a, names: n, confidence: confidence)
        }

        return grid
    }

    private func extractNumbers(from blocks: [RecognizedTextBlock]) -> [Int] {
        var numbers: [Int] = []
        for block in blocks {
            let text = block.text.trimmingCharacters(in: .whitespaces)
            if let num = Int(text), num >= 0 && num <= 9 {
                numbers.append(num)
            }
        }

        // Ensure we have 10 unique numbers
        if Set(numbers).count == 10 {
            return numbers
        }

        // If not all numbers found, fill in missing ones
        let found = Set(numbers)
        var missing = Set(0...9).subtracting(found)

        var result = numbers
        while result.count < 10 && !missing.isEmpty {
            if let next = missing.first {
                result.append(next)
                missing.remove(next)
            }
        }

        return Array(result.prefix(10))
    }

    func detectGridLines(in image: UIImage) async throws -> [CGRect] {
        guard let cgImage = image.cgImage else {
            throw VisionError.imageProcessingFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRectangleObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let rects = observations.map { $0.boundingBox }
                continuation.resume(returning: rects)
            }

            request.minimumAspectRatio = 0.8
            request.maximumAspectRatio = 1.2
            request.minimumSize = 0.01
            request.maximumObservations = 120

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    func reset() {
        recognizedText = []
        detectedGrid = nil
        error = nil
    }
}

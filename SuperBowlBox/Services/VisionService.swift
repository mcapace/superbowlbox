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

        // Perform text recognition
        let textBlocks = try await recognizeText(in: cgImage)

        await MainActor.run {
            recognizedText = textBlocks
        }

        if textBlocks.isEmpty {
            throw VisionError.noTextFound
        }

        // Parse the recognized text into a grid structure
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
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func parseGridFromText(_ blocks: [RecognizedTextBlock], imageSize: CGSize) async throws -> BoxGrid {
        // Sort blocks by position (top to bottom, left to right)
        let sortedBlocks = blocks.sorted { block1, block2 in
            // Vision coordinates are normalized with origin at bottom-left
            // Convert to top-left origin for easier processing
            let y1 = 1 - block1.boundingBox.midY
            let y2 = 1 - block2.boundingBox.midY

            if abs(y1 - y2) < 0.05 {  // Same row (within 5% tolerance)
                return block1.boundingBox.minX < block2.boundingBox.minX
            }
            return y1 < y2
        }

        // Try to identify numbers (0-9) for header row and column
        var homeNumbers: [Int] = []
        var awayNumbers: [Int] = []
        var nameGrid: [[String]] = Array(repeating: Array(repeating: "", count: 10), count: 10)

        // Group blocks by approximate row
        var rows: [[RecognizedTextBlock]] = []
        var currentRow: [RecognizedTextBlock] = []
        var lastY: CGFloat = -1

        for block in sortedBlocks {
            let y = 1 - block.boundingBox.midY
            if lastY < 0 || abs(y - lastY) < 0.05 {
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

        // Try to identify the structure
        // First row with 10 numbers is likely the header (home team numbers)
        // First column with 10 numbers is likely the away team numbers

        for (rowIndex, row) in rows.enumerated() {
            // Check if this row could be the header (contains numbers 0-9)
            let numbers = row.compactMap { Int($0.text.trimmingCharacters(in: .whitespaces)) }
                .filter { $0 >= 0 && $0 <= 9 }

            if numbers.count >= 8 && homeNumbers.isEmpty && rowIndex < 3 {
                // This is likely the header row
                homeNumbers = extractNumbers(from: row)
                continue
            }

            // For content rows, first item might be away number, rest are names
            if rowIndex > 0 && homeNumbers.count == 10 {
                let gridRowIndex = rowIndex - 1 - (homeNumbers.isEmpty ? 0 : 1)
                if gridRowIndex >= 0 && gridRowIndex < 10 {
                    var colOffset = 0
                    for (colIndex, block) in row.enumerated() {
                        let text = block.text.trimmingCharacters(in: .whitespaces)

                        // Check if this is an away number
                        if colIndex == 0, let num = Int(text), num >= 0 && num <= 9 {
                            if awayNumbers.count < 10 {
                                awayNumbers.append(num)
                            }
                            colOffset = 1
                            continue
                        }

                        let gridColIndex = colIndex - colOffset
                        if gridColIndex >= 0 && gridColIndex < 10 {
                            nameGrid[gridRowIndex][gridColIndex] = text
                        }
                    }
                }
            }
        }

        // Validate and fill in missing numbers
        if homeNumbers.count != 10 {
            homeNumbers = Array(0...9).shuffled()
        }
        if awayNumbers.count != 10 {
            awayNumbers = Array(0...9).shuffled()
        }

        // Create the BoxGrid
        var grid = BoxGrid(
            homeNumbers: homeNumbers,
            awayNumbers: awayNumbers
        )

        // Populate squares with names
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

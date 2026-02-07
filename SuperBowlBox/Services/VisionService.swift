import Foundation
import Vision
import UIKit
import CoreImage

class VisionService: ObservableObject {
    @Published var isProcessing = false
    @Published var recognizedText: [RecognizedTextBlock] = []
    @Published var detectedGrid: DetectedGrid?
    @Published var error: VisionError?
    /// True if the last successful scan used the AI backend (Lambda/Claude); false if it used on-device OCR. Used so the UI can show "Analyzed with AI" vs "Analyzed on device".
    @Published var lastScanUsedAIBackend = false

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
        /// Scan server URL in Secrets.plist could not be reached (e.g. hostname not found).
        case scanServerUnreachable

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
            case .scanServerUnreachable:
                return "Scan server not found. Use a valid AIGridBackendURL in Secrets.plist (AI handles grid, names, and rules)."
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

        // Work in upright space so crop coordinates match: normalize orientation if needed
        let uprightImage = image.imageOrientation == .up ? cgImage : (renderUprightCGImage(from: image) ?? cgImage)

        // AI overrides OCR: when AIGrid backend is configured, we use AI only for grid/names/rules. OCR and on-device Vision are not used.
        if let aiURL = AIGridConfig.backendURL {
            await MainActor.run { self.lastScanUsedAIBackend = true }
            let imageForAI = UIImage(cgImage: uprightImage)
            guard let jpeg = imageForAI.jpegData(compressionQuality: 0.85) else {
                throw VisionError.imageProcessingFailed
            }
            do {
                return try await AIGridBackendService.parseGrid(imageData: jpeg, url: aiURL)
            } catch let urlError as URLError where urlError.code == .cannotFindHost {
                throw VisionError.scanServerUnreachable
            }
        }

        // No AI backend configured: fallback to OCR (Textract backend or on-device Vision). Not used when AIGridBackendURL is set.
        await MainActor.run { self.lastScanUsedAIBackend = false }
        let croppedImage = cropToLargestPoolLikeRectangle(uprightImage, orientation: .up)

        func runPipeline(image: CGImage) async throws -> (BoxGrid, [RecognizedTextBlock]) {
            let size = CGSize(width: image.width, height: image.height)
            let blocks: [RecognizedTextBlock]
            if let url = TextractConfig.backendURL {
                let imageForBackend = UIImage(cgImage: image)
                guard let jpeg = imageForBackend.jpegData(compressionQuality: 0.85) else {
                    throw VisionError.imageProcessingFailed
                }
                do {
                    blocks = try await TextractBackendService.recognize(imageData: jpeg, url: url)
                } catch let urlError as URLError where urlError.code == .cannotFindHost {
                    throw VisionError.scanServerUnreachable
                }
            } else {
                blocks = try await recognizeText(in: image)
            }
            if blocks.isEmpty { throw VisionError.noTextFound }
            let grid = try await parseGridFromText(blocks, imageSize: size)
            return (grid, blocks)
        }

        var textBlocks: [RecognizedTextBlock]
        var grid: BoxGrid

        if let cropped = croppedImage {
            do {
                (grid, textBlocks) = try await runPipeline(image: cropped)
                // If crop gave almost no text or no names, retry with full image
                if textBlocks.count < 20 || grid.filledCount == 0 {
                    let (fullGrid, fullBlocks) = try await runPipeline(image: uprightImage)
                    if fullGrid.filledCount > grid.filledCount {
                        grid = fullGrid
                        textBlocks = fullBlocks
                    }
                }
            } catch {
                (grid, textBlocks) = try await runPipeline(image: uprightImage)
            }
        } else {
            (grid, textBlocks) = try await runPipeline(image: uprightImage)
        }

        let blocksToPublish = textBlocks
        await MainActor.run {
            recognizedText = blocksToPublish
        }

        return grid
    }

    /// Renders the image so its orientation is .up (correct for Vision and crop math).
    private func renderUprightCGImage(from image: UIImage) -> CGImage? {
        let size = image.size
        let renderer = UIGraphicsImageRenderer(size: size)
        let drawn = renderer.image { _ in
            image.draw(at: .zero)
        }
        return drawn.cgImage
    }

    /// Detects document-like rectangles and crops to the largest one (pool sheet) so we analyze only that region.
    private func cropToLargestPoolLikeRectangle(_ cgImage: CGImage, orientation: CGImagePropertyOrientation = .up) -> CGImage? {
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 8
        request.minimumConfidence = 0.5
        request.minimumAspectRatio = 0.25
        request.maximumAspectRatio = 1.8
        request.minimumSize = 0.10

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let results = request.results, !results.isEmpty else {
            return nil
        }

        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)

        // Pick the largest rectangle by area (likely the pool sheet)
        let best = results
            .filter { obs in
                let ar = obs.boundingBox.width / max(obs.boundingBox.height, 0.01)
                return ar >= 0.4 && ar <= 1.2
            }
            .max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height })

        guard let observation = best else { return nil }

        // Vision: normalized (0–1), origin bottom-left. Crop rect: top-left origin pixels.
        // Expand top by 15% so header/title (team names) above the grid are included
        let n = observation.boundingBox
        let expandTop = n.height * h * 0.15
        let x = n.minX * w
        let y = (1 - n.maxY) * h - expandTop
        let cropW = n.width * w
        let cropH = n.height * h + expandTop

        let xi = max(0, min(Int(x), cgImage.width - 1))
        let yi = max(0, min(Int(y), cgImage.height - 1))
        let wi = max(1, min(Int(cropW), cgImage.width - xi))
        let hi = max(1, min(Int(cropH), cgImage.height - yi))

        let cropRect = CGRect(x: xi, y: yi, width: wi, height: hi)
        return cgImage.cropping(to: cropRect)
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
            request.minimumTextHeight = 0.004

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Recognizes all text in an image and returns it as a single string (e.g. for payout rules from a photo).
    func recognizeTextInImage(_ image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { throw VisionError.imageProcessingFailed }
        let blocks = try await recognizeText(in: cgImage)
        return blocks.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseGridFromText(_ blocks: [RecognizedTextBlock], imageSize: CGSize) async throws -> BoxGrid {
        // Use the whole sheet: sort all text by position (top to bottom, left to right)
        let sortedBlocks = blocks.sorted { block1, block2 in
            let y1 = 1 - block1.boundingBox.midY
            let y2 = 1 - block2.boundingBox.midY
            if abs(y1 - y2) < 0.06 { return block1.boundingBox.minX < block2.boundingBox.minX }
            return y1 < y2
        }

        // Detect teams from text in the top of the sheet (titles/headers), not from player names in the grid
        let topYThreshold: CGFloat = 0.35
        var detectedTeams: [Team] = []
        for block in sortedBlocks {
            let y = 1 - block.boundingBox.midY
            if y > topYThreshold { continue }
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
                return (detectedTeams[0], Team.unknown)
            }
            return (Team.unknown, Team.unknown)
        }()

        var homeNumbers: [Int] = []
        var awayNumbers: [Int] = []
        var nameGrid: [[String]] = Array(repeating: Array(repeating: "", count: 10), count: 10)

        // Group blocks by row — use tolerance so two lines in one cell (e.g. "Mike" / "Capace") stay in same row (need 11 rows: 1 header + 10 data)
        var rows: [[RecognizedTextBlock]] = []
        var currentRow: [RecognizedTextBlock] = []
        var lastY: CGFloat = -1
        let rowTolerance: CGFloat = 0.14

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

        // Header row = row with 10 single digits (0-9) for column numbers. Reject rows that contain cell IDs (1-100).
        var headerRowIndex: Int?
        var headerBlocksByX: [RecognizedTextBlock] = []
        func isCellId(_ t: String) -> Bool {
            let s = t.trimmingCharacters(in: .whitespaces)
            return s.count >= 1 && s.count <= 3 && (Int(s).map { (1...100).contains($0) } ?? false)
        }
        typealias HeaderCandidate = (rowIndex: Int, digitBlocks: [RecognizedTextBlock], totalBlocks: Int)
        var candidates: [HeaderCandidate] = []
        for (rowIndex, row) in rows.enumerated() {
            let hasCellId = row.contains { b in isCellId(b.text) }
            if hasCellId { continue }
            let digitBlocks = row.filter { b in
                let t = b.text.trimmingCharacters(in: .whitespaces)
                return t.count == 1 && (Int(t).map { (0...9).contains($0) } ?? false)
            }
            if digitBlocks.count == 10 {
                candidates.append((rowIndex, digitBlocks, row.count))
            }
        }
        // Prefer header row that is in the top of the sheet (column numbers are usually at top)
        let headerRowTopYThreshold: CGFloat = 0.65
        func rowCenterY(_ candidate: HeaderCandidate) -> CGFloat {
            let blocks = candidate.digitBlocks
            guard !blocks.isEmpty else { return 0 }
            let sum = blocks.reduce(0 as CGFloat) { acc, b in acc + (1 - b.boundingBox.midY) }
            return sum / CGFloat(blocks.count)
        }
        if let best = candidates.min(by: { a, b in
            let aTop = rowCenterY(a) > headerRowTopYThreshold
            let bTop = rowCenterY(b) > headerRowTopYThreshold
            if aTop != bTop { return aTop }
            if a.totalBlocks != b.totalBlocks { return a.totalBlocks < b.totalBlocks }
            return a.rowIndex < b.rowIndex
        }) {
            headerRowIndex = best.rowIndex
            headerBlocksByX = best.digitBlocks.sorted { $0.boundingBox.midX < $1.boundingBox.midX }
            homeNumbers = headerBlocksByX.compactMap { b in Int(b.text.trimmingCharacters(in: .whitespaces)) }
        }
        if headerRowIndex == nil {
            for (rowIndex, row) in rows.enumerated() {
                if row.contains(where: { b in isCellId(b.text) }) { continue }
                let digitBlocks = row.filter { b in
                    let t = b.text.trimmingCharacters(in: .whitespaces)
                    return t.count == 1 && (Int(t).map { (0...9).contains($0) } ?? false)
                }
                if digitBlocks.count >= 6 && digitBlocks.count <= 12 {
                    headerRowIndex = rowIndex
                    headerBlocksByX = digitBlocks.sorted { $0.boundingBox.midX < $1.boundingBox.midX }
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
                    bounds.append(max(0, midX[0] - 0.08))
                } else if i == 10 {
                    bounds.append(min(1, midX[9] + 0.08))
                } else {
                    bounds.append((midX[i - 1] + midX[i]) / 2)
                }
            }
            columnBounds = bounds
        } else {
            columnBounds = (0...10).map { CGFloat($0) / 10.0 }
        }
        // Only treat leftmost strip as "away" (row numbers). Cap at 0.06 so we don't drop name columns.
        let rawAwayMaxX = (headerBlocksByX.first?.boundingBox.minX ?? 0.12) - 0.03
        let awayColumnMaxX = min(0.06, rawAwayMaxX)

        func columnForBlock(_ block: RecognizedTextBlock) -> Int? {
            let x = block.boundingBox.midX
            if x < awayColumnMaxX { return nil }
            for i in 0..<10 {
                if x >= columnBounds[i] && x < columnBounds[i + 1] { return i }
            }
            return 9
        }

        // Data rows: one row index per grid row; away number = leftmost single digit in that row
        if let headerIdx = headerRowIndex {
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

        // Fallback: if no names captured (e.g. wrong column bounds), group each row's blocks by X into 10 columns and merge text per cell
        if nameGrid.flatMap({ $0 }).filter({ !$0.isEmpty }).isEmpty, let headerIdx = headerRowIndex {
            for dataRowOffset in 0..<10 {
                let rowIndex = headerIdx + 1 + dataRowOffset
                guard rowIndex < rows.count else { break }
                let row = rows[rowIndex]
                // Away digit = leftmost single digit
                let awayDigitBlock = row.first { b in
                    let t = b.text.trimmingCharacters(in: .whitespaces)
                    return t.count == 1 && (Int(t).map { (0...9).contains($0) } ?? false)
                }
                if let b = awayDigitBlock, let n = Int(b.text.trimmingCharacters(in: .whitespaces)), awayNumbers.count < 10 {
                    awayNumbers.append(n)
                }
                let nameLike = row.filter { b in
                    let t = b.text.trimmingCharacters(in: .whitespaces)
                    if t.isEmpty { return false }
                    if t.count == 1 && (Int(t).map { (0...9).contains($0) } ?? false) { return false }
                    if t.count <= 3 && (Int(t).map { (1...100).contains($0) } ?? false) { return false }
                    return true
                }
                guard !nameLike.isEmpty else { continue }
                let xs = nameLike.map { $0.boundingBox.midX }
                let xMin = xs.min() ?? 0
                let xSpan = (xs.max() ?? 1) - xMin
                var columns: [[String]] = Array(repeating: [], count: 10)
                for b in nameLike {
                    let x = b.boundingBox.midX
                    let col = xSpan > 0.001 ? min(9, max(0, Int(10 * (x - xMin) / xSpan))) : 0
                    let t = b.text.trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty { columns[col].append(t) }
                }
                for (col, parts) in columns.enumerated() where !parts.isEmpty {
                    nameGrid[dataRowOffset][col] = parts.joined(separator: " ")
                }
            }
        }

        // Second fallback: no header found or still no names — use first 10 data-like rows, group by X into 10 columns
        if nameGrid.flatMap({ $0 }).filter({ !$0.isEmpty }).isEmpty && rows.count >= 10 {
            let startRow: Int
            if let headerIdx = headerRowIndex, headerIdx + 10 < rows.count {
                startRow = headerIdx + 1
            } else {
                startRow = 1
            }
            for dataRowOffset in 0..<10 {
                let rowIndex = startRow + dataRowOffset
                guard rowIndex < rows.count else { break }
                let row = rows[rowIndex]
                let nameLike = row.filter { b in
                    let t = b.text.trimmingCharacters(in: .whitespaces)
                    if t.isEmpty { return false }
                    if t.count == 1 && (Int(t).map { (0...9).contains($0) } ?? false) { return false }
                    if t.count <= 3 && (Int(t).map { (1...100).contains($0) } ?? false) { return false }
                    return true
                }
                guard !nameLike.isEmpty else { continue }
                let xs = nameLike.map { $0.boundingBox.midX }
                let xMin = xs.min() ?? 0
                let xSpan = (xs.max() ?? 1) - xMin
                var columns: [[String]] = Array(repeating: [], count: 10)
                for b in nameLike {
                    let x = b.boundingBox.midX
                    let col = xSpan > 0.001 ? min(9, max(0, Int(10 * (x - xMin) / xSpan))) : 0
                    let t = b.text.trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty { columns[col].append(t) }
                }
                for (col, parts) in columns.enumerated() where !parts.isEmpty {
                    nameGrid[dataRowOffset][col] = parts.joined(separator: " ")
                }
            }
        }

        // Last resort: fill grid from all name-like blocks by position (Y then X), ignoring structure
        if nameGrid.flatMap({ $0 }).filter({ !$0.isEmpty }).isEmpty {
            let nameLike = sortedBlocks.filter { block in
                let t = block.text.trimmingCharacters(in: .whitespaces)
                if t.isEmpty { return false }
                if t.count == 1, let n = Int(t), (0...9).contains(n) { return false }
                if t.count <= 3, let n = Int(t), (1...100).contains(n) { return false }
                return true
            }
            let byPosition = nameLike.sorted { b1, b2 in
                let y1 = 1 - b1.boundingBox.midY
                let y2 = 1 - b2.boundingBox.midY
                if abs(y1 - y2) > 0.06 { return y1 < y2 }
                return b1.boundingBox.minX < b2.boundingBox.minX
            }
            // Merge blocks that are in same cell (close in Y and X)
            var cells: [String] = []
            var i = 0
            while i < byPosition.count {
                let b = byPosition[i]
                var cellText = b.text.trimmingCharacters(in: .whitespaces)
                let midY = 1 - b.boundingBox.midY
                let midX = b.boundingBox.midX
                i += 1
                while i < byPosition.count {
                    let next = byPosition[i]
                    let ny = 1 - next.boundingBox.midY
                    let nx = next.boundingBox.minX
                    if abs(ny - midY) < 0.04 && abs(nx - midX) < 0.12 {
                        cellText += " " + next.text.trimmingCharacters(in: .whitespaces)
                        i += 1
                    } else { break }
                }
                cells.append(cellText)
            }
            for (idx, cell) in cells.prefix(100).enumerated() {
                let r = idx / 10
                let c = idx % 10
                if r < 10, c < 10, !cell.isEmpty {
                    nameGrid[r][c] = cell
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

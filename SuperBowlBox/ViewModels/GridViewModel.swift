import Foundation
import SwiftUI
import Combine

@MainActor
class GridViewModel: ObservableObject {
    @Published var grid: BoxGrid
    @Published var scoreService: NFLScoreService
    @Published var visionService: VisionService
    @Published var selectedSquare: BoxSquare?
    @Published var isShowingScanner = false
    @Published var isShowingManualEntry = false
    @Published var isShowingSettings = false
    @Published var searchText = ""
    @Published var highlightedPlayer: String?

    private var cancellables = Set<AnyCancellable>()

    init(
        grid: BoxGrid = BoxGrid.empty,
        scoreService: NFLScoreService = NFLScoreService(),
        visionService: VisionService = VisionService()
    ) {
        self.grid = grid
        self.scoreService = scoreService
        self.visionService = visionService

        setupBindings()
    }

    private func setupBindings() {
        // Update grid winners when score changes
        scoreService.$currentScore
            .compactMap { $0 }
            .sink { [weak self] score in
                self?.updateWinners(for: score)
            }
            .store(in: &cancellables)
    }

    func updateWinners(for score: GameScore) {
        grid.currentScore = score
        grid.updateWinners(
            quarterScores: score.quarterScores,
            totalScore: (score.homeScore, score.awayScore)
        )
    }

    var currentWinner: BoxSquare? {
        guard let score = scoreService.currentScore else { return nil }
        return grid.winningSquare(for: score)
    }

    var currentWinnerName: String {
        currentWinner?.displayName ?? "No winner yet"
    }

    func selectSquare(_ square: BoxSquare) {
        selectedSquare = square
    }

    func updateSquareName(row: Int, column: Int, playerName: String) {
        grid.updateSquare(row: row, column: column, playerName: playerName)
        objectWillChange.send()
    }

    func processScannedImage(_ image: UIImage) async {
        do {
            let scannedGrid = try await visionService.processImage(image)
            grid = scannedGrid
        } catch {
            print("Error processing image: \(error)")
        }
    }

    func randomizeNumbers() {
        grid.randomizeNumbers()
    }

    func resetGrid() {
        grid = BoxGrid(
            homeTeam: grid.homeTeam,
            awayTeam: grid.awayTeam
        )
    }

    func setTeams(home: Team, away: Team) {
        grid.homeTeam = home
        grid.awayTeam = away
        scoreService.setTeams(home: home, away: away)
    }

    func startLiveScores() {
        scoreService.startLiveUpdates()
    }

    func stopLiveScores() {
        scoreService.stopLiveUpdates()
    }

    // Search/filter functionality
    var filteredSquares: [BoxSquare] {
        guard !searchText.isEmpty else { return [] }
        return grid.squares(for: searchText)
    }

    func highlightPlayer(_ name: String?) {
        highlightedPlayer = name
    }

    // Persistence
    func saveGrid() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(grid) {
            UserDefaults.standard.set(data, forKey: "savedGrid")
        }
    }

    func loadGrid() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: "savedGrid"),
           let savedGrid = try? decoder.decode(BoxGrid.self, from: data) {
            grid = savedGrid
        }
    }

    // Export functionality
    func exportGridAsText() -> String {
        var text = "Pool Grid\n"
        text += "\(grid.awayTeam.name) vs \(grid.homeTeam.name)\n\n"

        // Header row with home team numbers
        text += "    "
        for num in grid.homeNumbers {
            text += String(format: "%3d", num)
        }
        text += "\n"
        text += "    " + String(repeating: "-", count: 30) + "\n"

        // Grid rows
        for (rowIndex, row) in grid.squares.enumerated() {
            text += String(format: "%d | ", grid.awayNumbers[rowIndex])
            for square in row {
                let initial = square.initials.isEmpty ? "--" : square.initials
                text += String(format: "%3s", initial)
            }
            text += "\n"
        }

        return text
    }
}


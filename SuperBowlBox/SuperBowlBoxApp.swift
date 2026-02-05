import SwiftUI

@main
struct SquareUpApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - App State
class AppState: ObservableObject {
    @Published var pools: [BoxGrid] = []
    @Published var selectedPoolIndex: Int = 0
    @Published var scoreService = NFLScoreService()
    @Published var myName: String = ""

    var currentPool: BoxGrid? {
        guard selectedPoolIndex >= 0 && selectedPoolIndex < pools.count else { return nil }
        return pools[selectedPoolIndex]
    }

    init() {
        loadPools()
        if pools.isEmpty {
            // Create a demo pool
            var samplePool = BoxGrid(name: "Super Bowl LIX")
            let sampleNames = ["Mike", "Sarah", "John", "Emma", "Chris", "Lisa", "Dave", "Amy", "Tom", "Kate"]
            for row in 0..<10 {
                for col in 0..<10 {
                    samplePool.updateSquare(row: row, column: col, playerName: sampleNames.randomElement() ?? "")
                }
            }
            pools.append(samplePool)
        }
    }

    func addPool(_ pool: BoxGrid) {
        pools.append(pool)
        savePools()
    }

    func removePool(at index: Int) {
        guard index >= 0 && index < pools.count else { return }
        pools.remove(at: index)
        if selectedPoolIndex >= pools.count {
            selectedPoolIndex = max(0, pools.count - 1)
        }
        savePools()
    }

    func updatePool(_ pool: BoxGrid) {
        if let index = pools.firstIndex(where: { $0.id == pool.id }) {
            pools[index] = pool
            savePools()
        }
    }

    func savePools() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(pools) {
            UserDefaults.standard.set(data, forKey: "savedPools")
        }
        UserDefaults.standard.set(myName, forKey: "myName")
    }

    func loadPools() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: "savedPools"),
           let savedPools = try? decoder.decode([BoxGrid].self, from: data) {
            pools = savedPools
        }
        myName = UserDefaults.standard.string(forKey: "myName") ?? ""
    }
}

// MARK: - Legacy Design System (kept for compatibility)
struct AppColors {
    static let primary = DesignSystem.Colors.accent
    static let fieldGreen = DesignSystem.Colors.live
    static let endZoneRed = DesignSystem.Colors.danger
    static let gold = DesignSystem.Colors.gold

    static let gradientPrimary = DesignSystem.Colors.liveGradient
    static let gradientGold = DesignSystem.Colors.goldGradient

    static let cardBackground = DesignSystem.Colors.surface
    static let cardShadow = Color.black.opacity(0.3)
}

struct AppTypography {
    static let largeTitle = DesignSystem.Typography.title
    static let title = DesignSystem.Typography.headline
    static let headline = DesignSystem.Typography.subheadline
    static let body = DesignSystem.Typography.body
    static let caption = DesignSystem.Typography.caption
    static let scoreDisplay = DesignSystem.Typography.scoreLarge
}

import SwiftUI

@main
struct GridIronApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.none) // Respect system setting
        }
    }
}

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
            // Create a default pool with some sample data
            var samplePool = BoxGrid(name: "Super Bowl LIX Pool")
            // Add some sample names for demo
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

// MARK: - Design System
struct AppColors {
    static let primary = Color("AccentColor")
    static let fieldGreen = Color(red: 0.133, green: 0.545, blue: 0.133)
    static let endZoneRed = Color(red: 0.8, green: 0.1, blue: 0.1)
    static let gold = Color(red: 1.0, green: 0.84, blue: 0.0)

    static let gradientPrimary = LinearGradient(
        colors: [Color(red: 0.1, green: 0.4, blue: 0.1), Color(red: 0.2, green: 0.6, blue: 0.2)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let gradientGold = LinearGradient(
        colors: [Color(red: 1.0, green: 0.84, blue: 0.0), Color(red: 0.85, green: 0.65, blue: 0.0)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let cardBackground = Color(.systemBackground)
    static let cardShadow = Color.black.opacity(0.12)
}

struct AppTypography {
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let title = Font.system(size: 28, weight: .bold, design: .rounded)
    static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 17, weight: .regular, design: .default)
    static let caption = Font.system(size: 12, weight: .medium, design: .rounded)
    static let scoreDisplay = Font.system(size: 56, weight: .bold, design: .rounded)
}

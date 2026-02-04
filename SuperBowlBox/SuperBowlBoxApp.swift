import SwiftUI

@main
struct SquareUpApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.none) // Respect system setting
        }
    }
}

// MARK: - App delegate (push notification token)
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        HapticService.prepare()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationService.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationService.didFailToRegisterForRemoteNotifications(error: error)
    }
}

class AppState: ObservableObject {
    @Published var pools: [BoxGrid] = []
    @Published var selectedPoolIndex: Int = 0
    @Published var scoreService = NFLScoreService()
    @Published var myName: String = ""
    @Published var hasCompletedOnboarding: Bool = false
    @Published var authService = AuthService()
    /// Last score we used when reviewing game context (for notifications). Used to detect period/lead changes.
    private var lastReviewedScore: GameScore?

    var currentPool: BoxGrid? {
        guard selectedPoolIndex >= 0 && selectedPoolIndex < pools.count else { return nil }
        return pools[selectedPoolIndex]
    }

    init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        loadPools()
        if pools.isEmpty {
            // Create a default pool with some sample data
            var samplePool = BoxGrid(name: "My Pool")
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

    /// Updates winner state on all pools from current score and saves. Also reviews what’s happening and may push local notifications.
    func refreshWinnersFromCurrentScore() {
        guard let score = scoreService.currentScore else { return }
        var didChange = false
        for i in pools.indices {
            var pool = pools[i]
            pool.updateWinners(
                quarterScores: score.quarterScores,
                totalScore: (score.homeScore, score.awayScore)
            )
            if pool.squares != pools[i].squares {
                pools[i] = pool
                didChange = true
            }
        }
        if didChange { savePools() }

        // Review what’s happening and push info to the user (leader, period winner, one score away)
        GameContextService.review(
            currentScore: score,
            previousScore: lastReviewedScore,
            pools: pools,
            globalMyName: myName
        )
        lastReviewedScore = score
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    /// Call from Settings to show onboarding again (e.g. "Show onboarding again").
    func resetOnboarding() {
        hasCompletedOnboarding = false
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
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

// MARK: - Design System (SquareUp — elevated, state of the art)
struct AppColors {
    static let primary = Color("AccentColor")
    /// Primary brand — deep teal/emerald (confident, premium)
    static let fieldGreen = Color(red: 0.04, green: 0.32, blue: 0.22)
    /// Lighter teal for highlights and live states
    static let fieldGreenLight = Color(red: 0.12, green: 0.48, blue: 0.36)
    /// Bright accent for CTAs and focus
    static let accent = Color(red: 0.10, green: 0.58, blue: 0.42)
    /// Warm accent for alerts / end zone
    static let endZoneRed = Color(red: 0.75, green: 0.18, blue: 0.22)
    /// Premium gold — wins and premium accents
    static let gold = Color(red: 0.92, green: 0.72, blue: 0.28)
    static let goldMuted = Color(red: 0.82, green: 0.62, blue: 0.24)
    /// Near-black for high-contrast type
    static let ink = Color(red: 0.08, green: 0.08, blue: 0.10)
    /// Elevated surface (cards, sheets)
    static let surface = Color(.secondarySystemBackground)
    /// Rich background for hero areas (adapts to dark/light)
    static let backgroundElevated = Color(red: 0.96, green: 0.96, blue: 0.98)
    static let backgroundElevatedDark = Color(red: 0.08, green: 0.10, blue: 0.12)

    static let gradientPrimary = LinearGradient(
        colors: [fieldGreen, fieldGreenLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    /// Wordmark / hero gradient (teal → gold hint)
    static let gradientWordmark = LinearGradient(
        colors: [fieldGreen, fieldGreenLight, fieldGreenLight.opacity(0.9)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let gradientGold = LinearGradient(
        colors: [gold, goldMuted],
        startPoint: .top,
        endPoint: .bottom
    )

    static let cardBackground = Color(.systemBackground)
    static let cardShadow = Color.black.opacity(0.08)
    static let cardShadowStrong = Color.black.opacity(0.14)
    static let cardTint = Color(.secondarySystemBackground)
}

// MARK: - Typography (SquareUp)
// Display: system serif (New York). To use a custom font (e.g. DM Serif Display from Google Fonts),
// add the .ttf to the target, register in Info.plist "Fonts provided by application", and
// use Font.custom("DMSerifDisplay-Regular", size: size) in squareUpDisplay below.

extension Font {
    /// Display font for app name and hero titles. Uses system serif (New York).
    static func squareUpDisplay(size: CGFloat = 32, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    /// Wordmark / logo — larger, bold serif for "SquareUp" branding
    static func squareUpWordmark(size: CGFloat = 36) -> Font {
        .system(size: size, weight: .bold, design: .serif)
    }
}

struct AppTypography {
    /// App name / wordmark — bold serif for logo
    static let appName = Font.squareUpWordmark(size: 34)
    static let wordmark = Font.squareUpWordmark(size: 36)
    static let largeTitle = Font.squareUpDisplay(size: 34)
    static let title = Font.squareUpDisplay(size: 28)
    static let title2 = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 17, weight: .regular, design: .default)
    static let callout = Font.system(size: 16, weight: .medium, design: .rounded)
    static let caption = Font.system(size: 12, weight: .medium, design: .rounded)
    static let caption2 = Font.system(size: 11, weight: .medium, design: .rounded)
    static let scoreDisplay = Font.system(size: 56, weight: .bold, design: .rounded)
    static let label = Font.system(size: 11, weight: .semibold, design: .rounded)
}

/// Letter spacing for display / wordmark
struct AppTracking {
    static let display: CGFloat = 1.2   // wordmark "SquareUp"
    static let tight: CGFloat = -0.2
}

/// Card and layout — refined radius and shadow for depth without clutter.
struct AppCardStyle {
    static let cornerRadius: CGFloat = 22
    static let cornerRadiusSmall: CGFloat = 14
    static let shadowRadius: CGFloat = 20
    static let shadowY: CGFloat = 8
}

// MARK: - SquareUp logo + wordmark (app screen branding)
struct SquareUpLogoView: View {
    var showIcon: Bool = true
    var wordmarkSize: CGFloat = 28

    var body: some View {
        VStack(spacing: 6) {
            if showIcon {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(AppColors.gradientPrimary)
                    .symbolRenderingMode(.hierarchical)
            }
            Text("SquareUp")
                .font(Font.squareUpWordmark(size: wordmarkSize))
                .foregroundStyle(AppColors.gradientWordmark)
                .tracking(AppTracking.display)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Glass / material cards (iOS 15+)
extension View {
    /// Premium card with material background and subtle border. Use for dashboard cards.
    func glassCard(cornerRadius: CGFloat = AppCardStyle.cornerRadius) -> some View {
        self
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: AppColors.cardShadow, radius: AppCardStyle.shadowRadius, y: AppCardStyle.shadowY)
    }

    /// Solid card with shadow (when material is too light for content).
    func solidCard(cornerRadius: CGFloat = AppCardStyle.cornerRadius) -> some View {
        self
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(AppColors.cardBackground)
                    .shadow(color: AppColors.cardShadow, radius: AppCardStyle.shadowRadius, y: AppCardStyle.shadowY)
            )
    }
}

// MARK: - Animation presets
extension Animation {
    static let appSpring = Animation.spring(response: 0.35, dampingFraction: 0.8)
    static let appSpringBouncy = Animation.spring(response: 0.5, dampingFraction: 0.7)
    static let appQuick = Animation.easeOut(duration: 0.25)
}

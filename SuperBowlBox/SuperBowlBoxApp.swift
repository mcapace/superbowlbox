import SwiftUI

@main
struct SquareUpApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .font(DesignSystem.Typography.body)
                .preferredColorScheme(.dark)
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
        // No sample/fake pool: when empty, user can upload, create, or join with code
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

// MARK: - Design System (squareup — clean, minimal, Jules-inspired)
struct AppColors {
    static let primary = Color("AccentColor")
    /// Navy — Jules-style primary (brand, headers, key UI)
    static let navy = Color(red: 0.11, green: 0.14, blue: 0.22)
    /// Primary green — accent for live, CTAs, success
    static let fieldGreen = Color(red: 0.12, green: 0.45, blue: 0.32)
    static let fieldGreenLight = Color(red: 0.18, green: 0.55, blue: 0.40)
    static let accent = fieldGreen
    static let endZoneRed = Color(red: 0.78, green: 0.22, blue: 0.22)
    static let gold = Color(red: 0.85, green: 0.65, blue: 0.22)
    static let goldMuted = Color(red: 0.75, green: 0.55, blue: 0.20)
    static let ink = Color(red: 0.10, green: 0.10, blue: 0.12)
    static let surface = Color(.systemBackground)
    /// Screen background — warm gray with a hint of green so it’s clearly not default white
    static let screenBackground = Color(red: 0.93, green: 0.95, blue: 0.94)
    static let backgroundElevated = screenBackground
    static let backgroundElevatedDark = Color(red: 0.08, green: 0.10, blue: 0.14)

    /// Legacy aliases for compatibility
    static let techCyan = fieldGreenLight
    static let glowTeal = fieldGreen
    static let glowGold = gold
    static let gradientTechBackground = LinearGradient(colors: [screenBackground, screenBackground], startPoint: .top, endPoint: .bottom)
    static let gradientWordmark = LinearGradient(colors: [fieldGreen, fieldGreenLight], startPoint: .leading, endPoint: .trailing)
    static let gradientPrimary = LinearGradient(colors: [fieldGreen, fieldGreenLight], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let gradientGold = LinearGradient(colors: [gold, goldMuted], startPoint: .top, endPoint: .bottom)
    static let gradientGlow = gradientPrimary
    static let cardBackground = surface
    static let cardShadow = Color.black.opacity(0.10)
    static let cardShadowStrong = Color.black.opacity(0.18)
    static let cardHighlight = Color.white.opacity(0.6)
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
    /// Wordmark — SF Pro Rounded Bold for "SquareUp" (default 48pt)
    static func squareUpWordmark(size: CGFloat = 48) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
}

struct AppTypography {
    static let appName = Font.squareUpWordmark(size: 48)
    static let wordmark = Font.squareUpWordmark(size: 48)
    static let largeTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let title = Font.system(size: 22, weight: .bold, design: .rounded)
    static let title2 = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 17, weight: .regular, design: .rounded)
    static let callout = Font.system(size: 16, weight: .medium, design: .rounded)
    static let caption = Font.system(size: 13, weight: .medium, design: .rounded)
    static let caption2 = Font.system(size: 11, weight: .medium, design: .rounded)
    static let scoreDisplay = Font.system(size: 48, weight: .bold, design: .rounded)
    static let label = Font.system(size: 11, weight: .semibold, design: .rounded)
}

/// Letter spacing for display / wordmark
struct AppTracking {
    static let display: CGFloat = 1.2   // wordmark "SquareUp"
    static let tight: CGFloat = -0.2
}

/// Card and layout — elevated, premium feel.
struct AppCardStyle {
    static let cornerRadius: CGFloat = 20
    static let cornerRadiusSmall: CGFloat = 14
    static let cardPadding: CGFloat = 24
    static let cardPaddingCompact: CGFloat = 16
    /// Spacing between cards/sections on a screen
    static let sectionSpacing: CGFloat = 28
    /// Horizontal inset for card content from screen edge
    static let screenHorizontalInset: CGFloat = 20
    /// Shadow: soft ambient
    static let shadowRadius: CGFloat = 24
    static let shadowY: CGFloat = 8
    /// Shadow: tighter offset for depth
    static let shadowRadiusTight: CGFloat = 8
    static let shadowYTight: CGFloat = 3
}

// MARK: - SquareUp in-app logo: App Store icon graphic (arrow) above wordmark
struct SquareUpLogoView: View {
    var showIcon: Bool = true
    var wordmarkSize: CGFloat = 48
    var iconSize: CGFloat = 44
    /// Inline = one row (icon + text) for nav bar; false = stacked for large layouts
    var inline: Bool = false

    var body: some View {
        if inline {
            HStack(spacing: 5) {
                if showIcon {
                    Image("SquareUpLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                }
                Text("squareup")
                    .font(.system(size: wordmarkSize, weight: .bold, design: .rounded))
                    .tracking(0.2)
            }
            .frame(height: 24)
        } else {
            VStack(spacing: 8) {
                if showIcon {
                    Image("SquareUpLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: iconSize, height: iconSize)
                }
                Text("squareup")
                    .font(.system(size: wordmarkSize, weight: .bold, design: .rounded))
                    .foregroundColor(DesignSystem.Colors.liveGreen)
                    .tracking(0.5)
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Cards (elevated, premium)
extension View {
    /// Primary card style — white, two-layer shadow, subtle top highlight for raised feel.
    func glassCard(cornerRadius: CGFloat = AppCardStyle.cornerRadius) -> some View {
        self
            .padding(AppCardStyle.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(AppColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.35),
                                Color.black.opacity(0.06)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: AppColors.cardShadow, radius: AppCardStyle.shadowRadius, y: AppCardStyle.shadowY)
            .shadow(color: AppColors.cardShadowStrong.opacity(0.5), radius: AppCardStyle.shadowRadiusTight, y: AppCardStyle.shadowYTight)
    }

    func solidCard(cornerRadius: CGFloat = AppCardStyle.cornerRadius) -> some View {
        glassCard(cornerRadius: cornerRadius)
    }

    /// Single card style alias — use for all screen cards.
    func card(cornerRadius: CGFloat = AppCardStyle.cornerRadius) -> some View {
        glassCard(cornerRadius: cornerRadius)
    }
}

// MARK: - Animation presets
extension Animation {
    static let appSpring = Animation.spring(response: 0.35, dampingFraction: 0.8)
    static let appSpringBouncy = Animation.spring(response: 0.5, dampingFraction: 0.7)
    static let appQuick = Animation.easeOut(duration: 0.25)
    /// Staggered entrance (use with delay)
    static let appEntrance = Animation.spring(response: 0.55, dampingFraction: 0.82)
    /// Smooth opacity/scale for transitions
    static let appReveal = Animation.easeOut(duration: 0.4)
    /// Slow, subtle loop for ambient motion
    static let appAmbient = Animation.easeInOut(duration: 2.5).repeatForever(autoreverses: true)
}

// MARK: - Staggered entrance modifier (high-tech reveal)
struct EntranceModifier: ViewModifier {
    let delay: Double
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .scaleEffect(appeared ? 1 : 0.96)
            .onAppear {
                withAnimation(Animation.appEntrance.delay(delay)) {
                    appeared = true
                }
            }
    }
}

// MARK: - Subtle glow overlay for cards (tech border)
struct TechGlowModifier: ViewModifier {
    var color: Color = AppColors.glowTeal
    var lineWidth: CGFloat = 1
    var opacity: Double = 0.5
    var cornerRadius: CGFloat = AppCardStyle.cornerRadius

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [color.opacity(opacity), color.opacity(opacity * 0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: lineWidth
                    )
            )
    }
}

// MARK: - Shimmer / scan-line style (optional for hero cards)
struct ShimmerPhaseKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}
extension EnvironmentValues {
    var shimmerPhase: CGFloat {
        get { self[ShimmerPhaseKey.self] }
        set { self[ShimmerPhaseKey.self] = newValue }
    }
}

extension View {
    /// Staggered entrance: appears with slight delay (e.g. index * 0.08).
    func entrance(delay: Double = 0) -> some View {
        modifier(EntranceModifier(delay: delay))
    }

    /// Thin tech-style gradient border on cards.
    func techGlow(color: Color = AppColors.glowTeal, opacity: Double = 0.5, cornerRadius: CGFloat = AppCardStyle.cornerRadius) -> some View {
        modifier(TechGlowModifier(color: color, opacity: opacity, cornerRadius: cornerRadius))
    }
}

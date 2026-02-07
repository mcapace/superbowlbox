import SwiftUI

// MARK: - Main Content View
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
    @Namespace private var tabAnimation

    var body: some View {
        ZStack(alignment: .bottom) {
            // Animated Background
            AnimatedMeshBackground()
            TechGridBackground()

            // Tab Content
            TabView(selection: $selectedTab) {
                FuturisticDashboard()
                    .tag(0)

                PoolsHubView()
                    .tag(1)

                MySquaresHubView()
                    .tag(2)

                SettingsHubView()
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Futuristic Tab Bar
            FuturisticTabBar(selectedTab: $selectedTab, namespace: tabAnimation)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            appState.scoreService.startLiveUpdates()
        }
    }
}

// MARK: - Futuristic Tab Bar
struct FuturisticTabBar: View {
    @Binding var selectedTab: Int
    var namespace: Namespace.ID

    let tabs = [
        ("waveform.path.ecg", "LIVE"),
        ("cube.transparent", "POOLS"),
        ("person.crop.rectangle.stack", "MINE"),
        ("gearshape.2", "CONFIG")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                FuturisticTabButton(
                    icon: tab.0,
                    label: tab.1,
                    isSelected: selectedTab == index,
                    namespace: namespace
                ) {
                    withAnimation(DesignSystem.Animation.springSnappy) {
                        selectedTab = index
                        Haptics.selection()
                    }
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(DesignSystem.Colors.surface.opacity(0.9))
        )
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [DesignSystem.Colors.accent.opacity(0.3), DesignSystem.Colors.holoPurple.opacity(0.2), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: DesignSystem.Colors.accent.opacity(0.2), radius: 20, y: 5)
    }
}

struct FuturisticTabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    var namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [DesignSystem.Colors.accent, DesignSystem.Colors.holoPurple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 36)
                            .matchedGeometryEffect(id: "tabIndicator", in: namespace)
                            .shadow(color: DesignSystem.Colors.accentGlow, radius: 12)
                    }

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isSelected ? .white : DesignSystem.Colors.textMuted)
                        .frame(width: 48, height: 36)
                }

                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.textMuted)
                    .tracking(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Futuristic Dashboard
struct FuturisticDashboard: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedPoolIndex = 0

    var currentPool: BoxGrid? {
        guard selectedPoolIndex >= 0 && selectedPoolIndex < appState.pools.count else { return nil }
        return appState.pools[selectedPoolIndex]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Header with brand
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SQUAREUP")
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                            .foregroundStyle(DesignSystem.Colors.cyberGradient)

                        Text("LIVE TRACKING SYSTEM")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.textMuted)
                            .tracking(2)
                    }

                    Spacer()

                    // Status indicator
                    HStack(spacing: 6) {
                        Circle()
                            .fill(DesignSystem.Colors.live)
                            .frame(width: 8, height: 8)
                            .glow(DesignSystem.Colors.live, radius: 6)

                        Text("ONLINE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.live)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(DesignSystem.Colors.live.opacity(0.1))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(DesignSystem.Colors.live.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 24)

                // Main Score Display - Orbital Style
                if let score = appState.scoreService.currentScore {
                    OrbitalScoreDisplay(score: score)
                        .padding(.horizontal, 20)
                } else {
                    WaitingForGameView()
                        .padding(.horizontal, 20)
                }

                // Live Waveform
                DataWaveform(color: DesignSystem.Colors.accent)
                    .frame(height: 40)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 20)
                    .opacity(0.6)

                // Pool Selector
                if appState.pools.count > 1 {
                    FuturisticPoolSelector(
                        pools: appState.pools,
                        selectedIndex: $selectedPoolIndex
                    )
                    .padding(.bottom, 20)
                }

                // Winner Command Center
                if let pool = currentPool,
                   let score = appState.scoreService.currentScore {
                    CommandCenterCard(pool: pool, score: score)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                }

                // On The Hunt Radar
                if !appState.scoreService.onTheHuntSquares.isEmpty {
                    HuntRadarCard(huntSquares: appState.scoreService.onTheHuntSquares)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                }

                // Grid Matrix Preview
                if let pool = currentPool {
                    NavigationLink {
                        GridDetailView(pool: binding(for: pool))
                    } label: {
                        MatrixGridPreview(
                            pool: pool,
                            score: appState.scoreService.currentScore,
                            myName: appState.myName
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.horizontal, 20)
                }

                Spacer(minLength: 140)
            }
        }
    }

    func binding(for pool: BoxGrid) -> Binding<BoxGrid> {
        guard let index = appState.pools.firstIndex(where: { $0.id == pool.id }) else {
            return .constant(pool)
        }
        return $appState.pools[index]
    }
}

// MARK: - Premium Score Display
struct OrbitalScoreDisplay: View {
    let score: GameScore
    @State private var pulseScale: CGFloat = 1.0
    @State private var showScoreChange = false

    var body: some View {
        VStack(spacing: 20) {
            // Status Bar - Live indicator + Quarter + Time
            HStack {
                // Live Pulse Indicator
                HStack(spacing: 8) {
                    LivePulseIndicator(isLive: score.isGameActive, size: 10)

                    Text(score.isGameActive ? "LIVE" : "PRE-GAME")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(score.isGameActive ? DesignSystem.Colors.live : DesignSystem.Colors.textMuted)
                        .tracking(2)
                }

                Spacer()

                // Quarter Progress
                if score.isGameActive {
                    HStack(spacing: 12) {
                        QuarterProgressDots(currentQuarter: score.quarter)

                        Text(score.timeRemaining)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                }
            }

            // Main Score Display with Flip Digits
            HStack(spacing: 0) {
                // Away Team
                VStack(spacing: 12) {
                    TeamBadgePremium(team: score.awayTeam, isLeading: score.awayScore > score.homeScore)

                    // Score with flip animation
                    HStack(spacing: 4) {
                        ForEach(scoreDigits(score.awayScore), id: \.self) { digit in
                            FlipDigit(digit: digit, color: DesignSystem.Colors.textPrimary, size: 36)
                        }
                    }

                    // Last digit badge
                    Text("(\(score.awayLastDigit))")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.danger)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(DesignSystem.Colors.danger.opacity(0.15))
                        .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity)

                // VS Divider
                VStack(spacing: 8) {
                    Text("VS")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.textMuted)

                    Rectangle()
                        .fill(DesignSystem.Colors.glassBorder)
                        .frame(width: 1, height: 40)
                }
                .padding(.horizontal, 16)

                // Home Team
                VStack(spacing: 12) {
                    TeamBadgePremium(team: score.homeTeam, isLeading: score.homeScore > score.awayScore)

                    // Score with flip animation
                    HStack(spacing: 4) {
                        ForEach(scoreDigits(score.homeScore), id: \.self) { digit in
                            FlipDigit(digit: digit, color: DesignSystem.Colors.textPrimary, size: 36)
                        }
                    }

                    // Last digit badge
                    Text("(\(score.homeLastDigit))")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(DesignSystem.Colors.accent.opacity(0.15))
                        .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity)
            }

            // Winning Numbers Footer
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "target")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.gold)

                    Text("WINNING NUMBERS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.textMuted)
                        .tracking(1)
                }

                Spacer()

                HStack(spacing: 6) {
                    DigitBadge(digit: score.awayLastDigit, color: DesignSystem.Colors.danger)
                    Text("-")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.textMuted)
                    DigitBadge(digit: score.homeLastDigit, color: DesignSystem.Colors.accent)
                }
            }
            .padding(.top, 8)
        }
        .padding(20)
        .neonCard(score.isGameActive ? DesignSystem.Colors.live : DesignSystem.Colors.accent, intensity: score.isGameActive ? 0.25 : 0.15)
    }

    func scoreDigits(_ score: Int) -> [Int] {
        if score < 10 {
            return [0, score]
        }
        return String(score).compactMap { Int(String($0)) }
    }
}

// MARK: - Team Badge Premium
struct TeamBadgePremium: View {
    let team: Team
    let isLeading: Bool

    var teamColor: Color {
        Color(hex: team.primaryColor) ?? DesignSystem.Colors.accent
    }

    var body: some View {
        ZStack {
            // Glow for leading team
            if isLeading {
                Circle()
                    .fill(teamColor.opacity(0.3))
                    .frame(width: 56, height: 56)
                    .blur(radius: 8)
            }

            Circle()
                .fill(teamColor.gradient)
                .frame(width: 48, height: 48)
                .shadow(color: isLeading ? teamColor.opacity(0.5) : .clear, radius: 8)

            Text(team.abbreviation)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

struct TeamScoreUnit: View {
    let team: Team
    let teamScore: Int
    let lastDigit: Int
    let isLeading: Bool
    let color: Color

    var teamColor: Color {
        Color(hex: team.primaryColor) ?? color
    }

    var body: some View {
        VStack(spacing: 8) {
            // Team badge
            ZStack {
                Circle()
                    .fill(teamColor.opacity(0.2))
                    .frame(width: 50, height: 50)

                Circle()
                    .fill(teamColor.gradient)
                    .frame(width: 40, height: 40)

                Text(team.abbreviation)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            .glow(teamColor, radius: isLeading ? 12 : 0)

            // Score
            AnimatedCounter(
                value: teamScore,
                font: DesignSystem.Typography.scoreMedium,
                color: isLeading ? color : DesignSystem.Colors.textPrimary
            )

            // Last digit
            Text("(\(lastDigit))")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(DesignSystem.Colors.textTertiary)
        }
    }
}

struct DigitBadge: View {
    let digit: Int
    let color: Color

    var body: some View {
        Text("\(digit)")
            .font(.system(size: 20, weight: .black, design: .monospaced))
            .foregroundColor(.white)
            .frame(width: 36, height: 36)
            .background(color.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: color.opacity(0.5), radius: 8, y: 2)
    }
}

// MARK: - Waiting For Game View
struct WaitingForGameView: View {
    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                // Scanning animation
                Circle()
                    .stroke(DesignSystem.Colors.accent.opacity(0.1), lineWidth: 2)
                    .frame(width: 150, height: 150)

                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(DesignSystem.Colors.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(rotation))

                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 40))
                    .foregroundStyle(DesignSystem.Colors.cyberGradient)
            }
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }

            VStack(spacing: 8) {
                Text("SCANNING FOR SIGNAL")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .tracking(2)

                Text("Waiting for game data...")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .neonCard(DesignSystem.Colors.accent, intensity: 0.15)
    }
}

// MARK: - Score Card Skeleton
struct ScoreCardSkeleton: View {
    var body: some View {
        VStack(spacing: 20) {
            // Status bar skeleton
            HStack {
                SkeletonView(width: 80, height: 20, cornerRadius: 10)
                Spacer()
                SkeletonView(width: 100, height: 20, cornerRadius: 10)
            }

            // Score area skeleton
            HStack {
                VStack(spacing: 12) {
                    SkeletonView(width: 48, height: 48, cornerRadius: 24)
                    SkeletonView(width: 70, height: 50, cornerRadius: 8)
                    SkeletonView(width: 40, height: 24, cornerRadius: 12)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 8) {
                    SkeletonView(width: 30, height: 16, cornerRadius: 4)
                    SkeletonView(width: 2, height: 40, cornerRadius: 1)
                }
                .padding(.horizontal, 16)

                VStack(spacing: 12) {
                    SkeletonView(width: 48, height: 48, cornerRadius: 24)
                    SkeletonView(width: 70, height: 50, cornerRadius: 8)
                    SkeletonView(width: 40, height: 24, cornerRadius: 12)
                }
                .frame(maxWidth: .infinity)
            }

            // Footer skeleton
            HStack {
                SkeletonView(width: 120, height: 16, cornerRadius: 4)
                Spacer()
                SkeletonView(width: 80, height: 30, cornerRadius: 8)
            }
        }
        .padding(20)
        .neonCard(DesignSystem.Colors.accent, intensity: 0.1)
    }
}

// MARK: - Pool Card Skeleton
struct PoolCardSkeleton: View {
    var body: some View {
        HStack(spacing: 16) {
            SkeletonView(width: 80, height: 80, cornerRadius: 12)

            VStack(alignment: .leading, spacing: 8) {
                SkeletonView(width: 120, height: 18, cornerRadius: 4)
                HStack(spacing: 8) {
                    SkeletonView(width: 22, height: 22, cornerRadius: 11)
                    SkeletonView(width: 30, height: 12, cornerRadius: 4)
                    SkeletonView(width: 22, height: 22, cornerRadius: 11)
                }
                HStack(spacing: 16) {
                    SkeletonView(width: 70, height: 12, cornerRadius: 4)
                    SkeletonView(width: 60, height: 12, cornerRadius: 4)
                }
            }

            Spacer()

            SkeletonView(width: 14, height: 20, cornerRadius: 4)
        }
        .padding(16)
        .neonCard(DesignSystem.Colors.accent, intensity: 0.1)
    }
}

// MARK: - Futuristic Pool Selector
struct FuturisticPoolSelector: View {
    let pools: [BoxGrid]
    @Binding var selectedIndex: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(pools.enumerated()), id: \.element.id) { index, pool in
                    Button {
                        withAnimation(DesignSystem.Animation.springSnappy) {
                            selectedIndex = index
                            Haptics.selection()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "cube.fill")
                                .font(.system(size: 12))

                            Text(pool.name.uppercased())
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .tracking(1)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            selectedIndex == index ?
                                AnyShapeStyle(DesignSystem.Colors.cyberGradient) :
                                AnyShapeStyle(DesignSystem.Colors.surface)
                        )
                        .foregroundColor(selectedIndex == index ? .white : DesignSystem.Colors.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    selectedIndex == index ?
                                        Color.clear :
                                        DesignSystem.Colors.glassBorder,
                                    lineWidth: 1
                                )
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Command Center Card (Winner)
struct CommandCenterCard: View {
    let pool: BoxGrid
    let score: GameScore
    @State private var glowPulse = false

    var winner: BoxSquare? {
        pool.winningSquare(for: score)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(DesignSystem.Colors.goldGradient)
                        .scaleEffect(glowPulse ? 1.1 : 1.0)

                    Text("COMMAND CENTER")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .tracking(2)
                }

                Spacer()

                if score.isGameActive {
                    Text("Q\(score.quarter)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.gold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(DesignSystem.Colors.gold.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            if let winner = winner {
                HStack(spacing: 16) {
                    // Winner avatar with glow
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.gold.opacity(0.2))
                            .frame(width: 64, height: 64)
                            .scaleEffect(glowPulse ? 1.1 : 1.0)

                        Circle()
                            .fill(DesignSystem.Colors.goldGradient)
                            .frame(width: 52, height: 52)

                        Text(winner.initials)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .glow(DesignSystem.Colors.gold, radius: 15)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(winner.displayName.uppercased())
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .tracking(1)

                        Text("\(pool.awayTeam.abbreviation): \(score.awayLastDigit)  •  \(pool.homeTeam.abbreviation): \(score.homeLastDigit)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }

                    Spacer()

                    // Winning numbers
                    VStack(spacing: 2) {
                        Text("\(score.awayLastDigit)")
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                        Rectangle()
                            .fill(DesignSystem.Colors.gold)
                            .frame(width: 24, height: 2)
                        Text("\(score.homeLastDigit)")
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                    }
                    .foregroundColor(DesignSystem.Colors.gold)
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 24))
                        .foregroundColor(DesignSystem.Colors.textMuted)

                    Text("AWAITING DATA...")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .tracking(2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .padding(20)
        .neonCard(DesignSystem.Colors.gold, intensity: winner != nil ? 0.25 : 0.1)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }
}

// MARK: - Hunt Radar Card
struct HuntRadarCard: View {
    let huntSquares: [NFLScoreService.OnTheHuntInfo]
    @State private var scanRotation: Double = 0

    var body: some View {
        VStack(spacing: 16) {
            // Header with radar
            HStack {
                HStack(spacing: 12) {
                    // Mini radar
                    ZStack {
                        Circle()
                            .stroke(DesignSystem.Colors.danger.opacity(0.2), lineWidth: 1)
                            .frame(width: 36, height: 36)

                        Circle()
                            .trim(from: 0, to: 0.25)
                            .stroke(DesignSystem.Colors.danger, lineWidth: 2)
                            .frame(width: 36, height: 36)
                            .rotationEffect(.degrees(scanRotation))

                        Circle()
                            .fill(DesignSystem.Colors.danger)
                            .frame(width: 6, height: 6)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("TRACKING RADAR")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.danger)
                            .tracking(2)

                        Text("\(huntSquares.count) squares in range")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                }

                Spacer()

                Text("\(huntSquares.count)")
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundStyle(DesignSystem.Colors.dangerGradient)
            }

            // Hunt items
            VStack(spacing: 8) {
                ForEach(huntSquares.prefix(3)) { huntInfo in
                    HuntTargetRow(huntInfo: huntInfo)
                }
            }

            if huntSquares.count > 3 {
                Text("+ \(huntSquares.count - 3) MORE TARGETS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.textMuted)
                    .tracking(1)
            }
        }
        .padding(20)
        .neonCard(DesignSystem.Colors.danger, intensity: 0.2)
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                scanRotation = 360
            }
        }
    }
}

struct HuntTargetRow: View {
    let huntInfo: NFLScoreService.OnTheHuntInfo

    var urgencyColor: Color {
        if huntInfo.pointsAway <= 3 { return DesignSystem.Colors.danger }
        if huntInfo.pointsAway <= 6 { return DesignSystem.Colors.gold }
        return DesignSystem.Colors.accent
    }

    var body: some View {
        HStack(spacing: 12) {
            // Square numbers
            Text(huntInfo.squareNumbers)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .frame(width: 60)
                .padding(.vertical, 8)
                .background(DesignSystem.Colors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(huntInfo.poolName.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .tracking(1)

                Text("\(huntInfo.scoringTeam) needs \(huntInfo.pointsAway) pts")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }

            Spacer()

            // Distance indicator
            HStack(spacing: 4) {
                Text("\(huntInfo.pointsAway)")
                    .font(.system(size: 20, weight: .black, design: .monospaced))

                Text("PTS")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
            }
            .foregroundColor(urgencyColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(urgencyColor.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(12)
        .background(DesignSystem.Colors.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(urgencyColor.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Matrix Grid Preview
struct MatrixGridPreview: View {
    let pool: BoxGrid
    let score: GameScore?
    let myName: String

    var winningPosition: (row: Int, column: Int)? {
        guard let score = score else { return nil }
        return pool.winningPosition(homeDigit: score.homeLastDigit, awayDigit: score.awayLastDigit)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pool.name.uppercased())
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .tracking(1)

                    Text("\(pool.awayTeam.abbreviation) vs \(pool.homeTeam.abbreviation)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("VIEW MATRIX")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(DesignSystem.Colors.accent)
            }

            // Matrix Grid
            GeometryReader { geo in
                let cellSize = (geo.size.width - 11) / 11

                VStack(spacing: 1) {
                    // Header row
                    HStack(spacing: 1) {
                        Rectangle()
                            .fill(DesignSystem.Colors.surface)
                            .frame(width: cellSize, height: cellSize)

                        ForEach(0..<10, id: \.self) { col in
                            Text("\(pool.homeNumbers[col])")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .frame(width: cellSize, height: cellSize)
                                .background(DesignSystem.Colors.accent.opacity(0.3))
                                .foregroundColor(DesignSystem.Colors.accent)
                        }
                    }

                    // Grid rows
                    ForEach(0..<10, id: \.self) { row in
                        HStack(spacing: 1) {
                            Text("\(pool.awayNumbers[row])")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .frame(width: cellSize, height: cellSize)
                                .background(DesignSystem.Colors.danger.opacity(0.3))
                                .foregroundColor(DesignSystem.Colors.danger)

                            ForEach(0..<10, id: \.self) { col in
                                let square = pool.squares[row][col]
                                let isWinning = winningPosition?.row == row && winningPosition?.column == col
                                let isMine = !myName.isEmpty && square.playerName.lowercased().contains(myName.lowercased())

                                MatrixCell(
                                    square: square,
                                    isWinning: isWinning,
                                    isMine: isMine,
                                    size: cellSize
                                )
                            }
                        }
                    }
                }
            }
            .aspectRatio(1.0, contentMode: .fit)

            // Legend
            HStack(spacing: 16) {
                LegendItem(color: DesignSystem.Colors.live, label: "WINNER")
                LegendItem(color: DesignSystem.Colors.accent.opacity(0.5), label: "FILLED")
                if !myName.isEmpty {
                    LegendItem(color: DesignSystem.Colors.gold, label: "MINE")
                }

                Spacer()

                Text("\(pool.filledCount)/100")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
        }
        .padding(20)
        .neonCard(DesignSystem.Colors.accent, intensity: 0.15)
    }
}

struct MatrixCell: View {
    let square: BoxSquare
    let isWinning: Bool
    let isMine: Bool
    let size: CGFloat

    var cellColor: Color {
        if isWinning { return DesignSystem.Colors.live }
        if isMine { return DesignSystem.Colors.gold.opacity(0.7) }
        if !square.isEmpty { return DesignSystem.Colors.accent.opacity(0.3) }
        return DesignSystem.Colors.surface
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(cellColor)
                .frame(width: size, height: size)

            if isWinning {
                Rectangle()
                    .stroke(DesignSystem.Colors.gold, lineWidth: 1)
            }

            if !square.isEmpty {
                Text(square.initials)
                    .font(.system(size: 6, weight: .bold))
                    .foregroundColor(isWinning || isMine ? .white : DesignSystem.Colors.textSecondary)
            }
        }
    }
}

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(DesignSystem.Colors.textMuted)
        }
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(DesignSystem.Animation.springSnappy, value: configuration.isPressed)
    }
}

// MARK: - Placeholder Views
struct PoolsHubView: View {
    var body: some View {
        PoolsListView()
    }
}

struct MySquaresHubView: View {
    var body: some View {
        MySquaresView()
    }
}

struct SettingsHubView: View {
    var body: some View {
        SettingsView()
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .environmentObject(AppState())
}

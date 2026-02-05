import SwiftUI

// MARK: - Main Content View
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
    @Namespace private var tabAnimation

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            DesignSystem.Colors.background
                .ignoresSafeArea()

            // Tab Content
            TabView(selection: $selectedTab) {
                LiveDashboardView()
                    .tag(0)

                PoolsHubView()
                    .tag(1)

                MySquaresHubView()
                    .tag(2)

                SettingsHubView()
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Custom Floating Tab Bar
            FloatingTabBar(selectedTab: $selectedTab, namespace: tabAnimation)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            appState.scoreService.startLiveUpdates()
        }
    }
}

// MARK: - Floating Tab Bar
struct FloatingTabBar: View {
    @Binding var selectedTab: Int
    var namespace: Namespace.ID

    let tabs = [
        ("play.fill", "Live"),
        ("square.grid.3x3.topleft.filled", "Pools"),
        ("star.fill", "Mine"),
        ("gearshape.fill", "Settings")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                TabBarButton(
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
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(DesignSystem.Colors.glassBorder, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }
}

struct TabBarButton: View {
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
                        Circle()
                            .fill(DesignSystem.Colors.accent)
                            .frame(width: 44, height: 44)
                            .matchedGeometryEffect(id: "tabIndicator", in: namespace)
                            .shadow(color: DesignSystem.Colors.accentGlow, radius: 12)
                    }

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isSelected ? .white : DesignSystem.Colors.textTertiary)
                        .frame(width: 44, height: 44)
                }

                Text(label)
                    .font(DesignSystem.Typography.captionSmall)
                    .foregroundColor(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Live Dashboard
struct LiveDashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedPoolIndex = 0
    @State private var showRefresh = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SquareUp")
                            .font(DesignSystem.Typography.title)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        Text("Live Score Tracking")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }

                    Spacer()

                    Button {
                        withAnimation(DesignSystem.Animation.springSnappy) {
                            showRefresh = true
                        }
                        Haptics.impact(.light)
                        Task {
                            await appState.scoreService.fetchCurrentScore()
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            withAnimation { showRefresh = false }
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .rotationEffect(.degrees(showRefresh ? 360 : 0))
                            .frame(width: 44, height: 44)
                            .background(DesignSystem.Colors.surfaceElevated)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)

                // Hero Score Card
                HeroScoreCard(score: appState.scoreService.currentScore ?? GameScore.mock)
                    .padding(.horizontal, 20)

                // Pool Selector (if multiple pools)
                if appState.pools.count > 1 {
                    PoolChipSelector(
                        pools: appState.pools,
                        selectedIndex: $selectedPoolIndex
                    )
                }

                // Current Winner
                if let pool = currentPool,
                   let score = appState.scoreService.currentScore {
                    WinnerCard(pool: pool, score: score)
                        .padding(.horizontal, 20)
                }

                // Grid Preview
                if let pool = currentPool {
                    NavigationLink {
                        GridDetailView(pool: binding(for: pool))
                    } label: {
                        GridPreviewCard(
                            pool: pool,
                            score: appState.scoreService.currentScore,
                            myName: appState.myName
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.horizontal, 20)
                }

                Spacer(minLength: 120)
            }
        }
        .background(DesignSystem.Colors.background)
    }

    var currentPool: BoxGrid? {
        guard selectedPoolIndex >= 0 && selectedPoolIndex < appState.pools.count else { return nil }
        return appState.pools[selectedPoolIndex]
    }

    func binding(for pool: BoxGrid) -> Binding<BoxGrid> {
        guard let index = appState.pools.firstIndex(where: { $0.id == pool.id }) else {
            return .constant(pool)
        }
        return $appState.pools[index]
    }
}

// MARK: - Hero Score Card
struct HeroScoreCard: View {
    let score: GameScore
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 20) {
            // Live Badge
            if score.isGameActive {
                HStack(spacing: 8) {
                    Circle()
                        .fill(DesignSystem.Colors.live)
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulse ? 1.2 : 1.0)
                        .glow(DesignSystem.Colors.live, radius: 8)

                    Text("LIVE")
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundColor(DesignSystem.Colors.live)
                        .tracking(2)

                    if !score.timeRemaining.isEmpty {
                        Text("Q\(score.quarter) \(score.timeRemaining)")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(DesignSystem.Colors.live.opacity(0.15))
                        .overlay(
                            Capsule()
                                .stroke(DesignSystem.Colors.live.opacity(0.3), lineWidth: 1)
                        )
                )
                .onAppear {
                    withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }
            } else {
                Text(score.gameStatusText.uppercased())
                    .font(DesignSystem.Typography.captionSmall)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .tracking(2)
            }

            // Scores
            HStack(spacing: 0) {
                // Away Team
                TeamScoreView(
                    team: score.awayTeam,
                    teamScore: score.awayScore,
                    lastDigit: score.awayLastDigit,
                    isLeading: score.awayScore > score.homeScore
                )

                // Divider
                VStack(spacing: 8) {
                    Text("VS")
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundColor(DesignSystem.Colors.textMuted)

                    Rectangle()
                        .fill(DesignSystem.Colors.glassBorder)
                        .frame(width: 1, height: 40)
                }
                .frame(width: 60)

                // Home Team
                TeamScoreView(
                    team: score.homeTeam,
                    teamScore: score.homeScore,
                    lastDigit: score.homeLastDigit,
                    isLeading: score.homeScore > score.awayScore
                )
            }

            // Winning Numbers
            HStack(spacing: 12) {
                Text("WINNING DIGITS")
                    .font(DesignSystem.Typography.captionSmall)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .tracking(1)

                HStack(spacing: 8) {
                    NumberBadge(number: score.awayLastDigit, color: DesignSystem.Colors.danger)
                    Text("-")
                        .foregroundColor(DesignSystem.Colors.textMuted)
                    NumberBadge(number: score.homeLastDigit, color: DesignSystem.Colors.accent)
                }
            }
            .padding(.top, 8)
        }
        .padding(24)
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                .stroke(
                    score.isGameActive ?
                        DesignSystem.Colors.live.opacity(0.3) :
                        Color.clear,
                    lineWidth: 1
                )
        )
    }
}

struct TeamScoreView: View {
    let team: Team
    let teamScore: Int
    let lastDigit: Int
    let isLeading: Bool

    var teamColor: Color {
        Color(hex: team.primaryColor) ?? DesignSystem.Colors.accent
    }

    var body: some View {
        VStack(spacing: 12) {
            // Team badge
            ZStack {
                Circle()
                    .fill(teamColor.gradient)
                    .frame(width: 56, height: 56)

                Text(team.abbreviation)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            .shadow(color: teamColor.opacity(0.4), radius: 12, y: 4)

            // Score
            Text("\(teamScore)")
                .font(DesignSystem.Typography.scoreLarge)
                .foregroundColor(isLeading ? DesignSystem.Colors.live : DesignSystem.Colors.textPrimary)
                .contentTransition(.numericText())

            // Last digit
            Text("(\(lastDigit))")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textTertiary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(DesignSystem.Colors.surfaceElevated)
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
    }
}

struct NumberBadge: View {
    let number: Int
    let color: Color

    var body: some View {
        Text("\(number)")
            .font(DesignSystem.Typography.monoLarge)
            .foregroundColor(.white)
            .frame(width: 36, height: 36)
            .background(color.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: color.opacity(0.4), radius: 8, y: 2)
    }
}

// MARK: - Pool Chip Selector
struct PoolChipSelector: View {
    let pools: [BoxGrid]
    @Binding var selectedIndex: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(pools.enumerated()), id: \.element.id) { index, pool in
                    Button {
                        withAnimation(DesignSystem.Animation.springSnappy) {
                            selectedIndex = index
                            Haptics.selection()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.grid.3x3.fill")
                                .font(.system(size: 12))

                            Text(pool.name)
                                .font(DesignSystem.Typography.bodyMedium)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(selectedIndex == index ?
                                      DesignSystem.Colors.accent :
                                      DesignSystem.Colors.surfaceElevated)
                        )
                        .foregroundColor(selectedIndex == index ?
                                        .white :
                                        DesignSystem.Colors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Winner Card
struct WinnerCard: View {
    let pool: BoxGrid
    let score: GameScore
    @State private var celebrateAnimation = false

    var winner: BoxSquare? {
        pool.winningSquare(for: score)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.title3)
                    .foregroundColor(DesignSystem.Colors.gold)
                    .scaleEffect(celebrateAnimation ? 1.1 : 1.0)

                Text("Current Leader")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                if score.isGameActive {
                    Text("Q\(score.quarter)")
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundColor(DesignSystem.Colors.gold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(DesignSystem.Colors.gold.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            if let winner = winner {
                HStack(spacing: 16) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.goldGradient)
                            .frame(width: 56, height: 56)

                        Text(winner.initials)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .glow(DesignSystem.Colors.gold, radius: 12)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(winner.displayName)
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        Text("\(pool.awayTeam.abbreviation): \(score.awayLastDigit)  \(pool.homeTeam.abbreviation): \(score.homeLastDigit)")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }

                    Spacer()

                    // Winning combo
                    VStack(spacing: 2) {
                        Text("\(score.awayLastDigit)")
                            .font(DesignSystem.Typography.scoreMedium)
                        Rectangle()
                            .fill(DesignSystem.Colors.textMuted)
                            .frame(width: 24, height: 2)
                        Text("\(score.homeLastDigit)")
                            .font(DesignSystem.Typography.scoreMedium)
                    }
                    .foregroundColor(DesignSystem.Colors.gold)
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "hourglass")
                        .font(.title2)
                        .foregroundColor(DesignSystem.Colors.textMuted)

                    Text("Waiting for game...")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .padding(20)
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                .stroke(
                    LinearGradient(
                        colors: [DesignSystem.Colors.gold.opacity(0.4), DesignSystem.Colors.gold.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                celebrateAnimation = true
            }
        }
    }
}

// MARK: - Grid Preview Card
struct GridPreviewCard: View {
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
                    Text(pool.name)
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text("\(pool.awayTeam.abbreviation) vs \(pool.homeTeam.abbreviation)")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("View Grid")
                        .font(DesignSystem.Typography.caption)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(DesignSystem.Colors.accent)
            }

            // Mini Grid
            GeometryReader { geo in
                let cellSize = (geo.size.width - 10) / 11

                VStack(spacing: 1) {
                    // Header row
                    HStack(spacing: 1) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(DesignSystem.Colors.surfaceElevated)
                            .frame(width: cellSize, height: cellSize)

                        ForEach(0..<10, id: \.self) { col in
                            Text("\(pool.homeNumbers[col])")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .frame(width: cellSize, height: cellSize)
                                .background(DesignSystem.Colors.accent.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(2)
                        }
                    }

                    // Grid rows
                    ForEach(0..<10, id: \.self) { row in
                        HStack(spacing: 1) {
                            Text("\(pool.awayNumbers[row])")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .frame(width: cellSize, height: cellSize)
                                .background(DesignSystem.Colors.danger.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(2)

                            ForEach(0..<10, id: \.self) { col in
                                let square = pool.squares[row][col]
                                let isWinning = winningPosition?.row == row && winningPosition?.column == col
                                let isMine = !myName.isEmpty && square.playerName.lowercased().contains(myName.lowercased())

                                MiniGridCell(
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

            // Footer
            HStack {
                HStack(spacing: 12) {
                    LegendDot(color: DesignSystem.Colors.live, label: "Winner")
                    LegendDot(color: DesignSystem.Colors.accent.opacity(0.6), label: "Filled")
                    if !myName.isEmpty {
                        LegendDot(color: DesignSystem.Colors.gold, label: "Mine")
                    }
                }

                Spacer()

                Text("\(pool.filledCount)/100")
                    .font(DesignSystem.Typography.mono)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
        }
        .padding(20)
        .glassCard()
    }
}

struct MiniGridCell: View {
    let square: BoxSquare
    let isWinning: Bool
    let isMine: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(cellColor)

            if isWinning {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(DesignSystem.Colors.gold, lineWidth: 1.5)
            }

            if !square.isEmpty {
                Text(square.initials)
                    .font(.system(size: 6, weight: .medium))
                    .foregroundColor(isWinning || isMine ? .white : DesignSystem.Colors.textSecondary)
            }
        }
        .frame(width: size, height: size)
    }

    var cellColor: Color {
        if isWinning {
            return DesignSystem.Colors.live
        } else if isMine {
            return DesignSystem.Colors.gold.opacity(0.7)
        } else if !square.isEmpty {
            return DesignSystem.Colors.accent.opacity(0.3)
        }
        return DesignSystem.Colors.surfaceElevated
    }
}

struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(DesignSystem.Typography.captionSmall)
                .foregroundColor(DesignSystem.Colors.textTertiary)
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

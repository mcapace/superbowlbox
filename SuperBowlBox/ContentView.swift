import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Live", systemImage: "play.circle.fill")
                }
                .tag(0)

            PoolsListView()
                .tabItem {
                    Label("Pools", systemImage: "square.grid.3x3.fill")
                }
                .tag(1)

            MySquaresView()
                .tabItem {
                    Label("My Squares", systemImage: "star.fill")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(AppColors.fieldGreen)
        .onAppear {
            appState.scoreService.startLiveUpdates()
            configureTabBarAppearance()
            NotificationService.requestPermissionAndRegister()
        }
        .onChange(of: selectedTab) { _, _ in
            HapticService.selection()
        }
        .onChange(of: appState.scoreService.lastUpdated) { _, _ in
            appState.refreshWinnersFromCurrentScore()
        }
        .fullScreenCover(isPresented: Binding(
            get: { !appState.hasCompletedOnboarding },
            set: { if !$0 { appState.completeOnboarding() } }
        )) {
            InstructionsView(isOnboarding: true) {
                appState.completeOnboarding()
            }
            .environmentObject(appState)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.98)),
                removal: .opacity.combined(with: .scale(scale: 1.02))
            ))
        }
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Dashboard View (high-tech, animated)
struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedPoolIndex = 0
    @State private var showingRefreshAnimation = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Animated tech-style background (subtle gradient shift)
                techBackground

                ScrollView {
                    VStack(spacing: 24) {
                        // Live Score Card — entrance 0
                        LiveScoreCard(
                            score: appState.scoreService.currentScore ?? GameScore.mock,
                            isLoading: appState.scoreService.isLoading
                        )
                        .padding(.horizontal)
                        .entrance(delay: 0)

                        // Pool Selector — entrance 1
                        if appState.pools.count > 1 {
                            PoolSelectorView(
                                selectedIndex: $selectedPoolIndex,
                                pools: appState.pools
                            )
                            .entrance(delay: 0.06)
                        }

                        // Current Winner Spotlight — entrance 2
                        if let pool = currentPool,
                           let score = appState.scoreService.currentScore {
                            WinnerSpotlightCard(pool: pool, score: score)
                                .padding(.horizontal)
                                .entrance(delay: 0.12)
                        }

                        // Interactive Grid — entrance 3
                        if let pool = currentPool {
                            NavigationLink {
                                GridDetailView(pool: binding(for: pool))
                            } label: {
                                InteractiveGridCard(
                                    pool: pool,
                                    score: appState.scoreService.currentScore,
                                    globalMyName: appState.myName
                                )
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .padding(.horizontal)
                            .entrance(delay: 0.18)
                        }

                        // Quick Stats — entrance 4
                        if let pool = currentPool {
                            QuickStatsCard(pool: pool, globalMyName: appState.myName)
                                .padding(.horizontal)
                                .entrance(delay: 0.24)
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.top)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    SquareUpLogoView(showIcon: true, wordmarkSize: 24)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        HapticService.impactLight()
                        withAnimation(.appSpring) {
                            showingRefreshAnimation = true
                        }
                        Task {
                            await appState.scoreService.fetchCurrentScore()
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            withAnimation(.appQuick) {
                                showingRefreshAnimation = false
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 18, weight: .semibold))
                            .rotationEffect(.degrees(showingRefreshAnimation ? 360 : 0))
                            .animation(.easeInOut(duration: 0.5), value: showingRefreshAnimation)
                    }
                }
            }
        }
    }

    private var techBackground: some View {
        ZStack {
            AppColors.gradientTechBackground
                .ignoresSafeArea()
            // Subtle radial glow (ambient)
            RadialGradient(
                colors: [
                    AppColors.techCyan.opacity(0.06),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [
                    AppColors.fieldGreen.opacity(0.05),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 350
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Scale on press (high-tech button feel)
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.appQuick, value: configuration.isPressed)
    }
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

// MARK: - Live Score Card
struct LiveScoreCard: View {
    let score: GameScore
    let isLoading: Bool

    @State private var pulseAnimation = false

    var body: some View {
        VStack(spacing: 16) {
            // Live indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(score.isGameActive ? Color.red : Color.gray)
                    .frame(width: 8, height: 8)
                    .scaleEffect(pulseAnimation && score.isGameActive ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulseAnimation)

                Text(score.isGameActive ? "LIVE" : score.gameStatusText.uppercased())
                    .font(AppTypography.label)
                    .tracking(0.8)
                    .foregroundColor(score.isGameActive ? .red : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(score.isGameActive ? Color.red.opacity(0.15) : Color.secondary.opacity(0.1))
            )

            // Teams and Scores
            HStack(spacing: 0) {
                // Away Team
                TeamScoreColumn(
                    team: score.awayTeam,
                    score: score.awayScore,
                    lastDigit: score.awayLastDigit,
                    isLeading: score.awayScore > score.homeScore
                )

                // VS Divider
                VStack {
                    Text("VS")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
                .frame(width: 50)

                // Home Team
                TeamScoreColumn(
                    team: score.homeTeam,
                    score: score.homeScore,
                    lastDigit: score.homeLastDigit,
                    isLeading: score.homeScore > score.awayScore
                )
            }

            // Winning Numbers Display
            HStack(spacing: 8) {
                Image(systemName: "number.square.fill")
                    .foregroundColor(AppColors.fieldGreen)
                Text("Winning Numbers:")
                    .font(AppTypography.caption)
                    .foregroundColor(.secondary)
                Text("\(score.awayLastDigit) - \(score.homeLastDigit)")
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.fieldGreen)
            }
            .padding(.top, 8)
        }
        .glassCard()
        .techGlow(color: score.isGameActive ? AppColors.techCyan : AppColors.glowTeal, opacity: score.isGameActive ? 0.6 : 0.35)
        .overlay(
            RoundedRectangle(cornerRadius: AppCardStyle.cornerRadius)
                .stroke(score.isGameActive ? AppColors.techCyan.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
        .onAppear {
            pulseAnimation = true
            withAnimation(.appAmbient) {
                liveGlowOpacity = 0.7
            }
        }
    }
}

struct TeamScoreColumn: View {
    let team: Team
    let score: Int
    let lastDigit: Int
    let isLeading: Bool

    var body: some View {
        VStack(spacing: 8) {
            // Team Logo Placeholder
            Circle()
                .fill(Color(hex: team.primaryColor) ?? .gray)
                .frame(width: 50, height: 50)
                .overlay(
                    Text(team.abbreviation)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                )
                .shadow(color: (Color(hex: team.primaryColor) ?? .gray).opacity(0.4), radius: 8, y: 4)

            Text(team.abbreviation)
                .font(.subheadline)
                .fontWeight(.semibold)

            Text("\(score)")
                .font(AppTypography.scoreDisplay)
                .foregroundColor(isLeading ? AppColors.fieldGreen : .primary)
                .contentTransition(.numericText())

            // Last digit indicator
            Text("(\(lastDigit))")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color(.systemGray5))
                )
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Pool Selector (animated pills)
struct PoolSelectorView: View {
    @Binding var selectedIndex: Int
    let pools: [BoxGrid]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(pools.enumerated()), id: \.element.id) { index, pool in
                    Button {
                        HapticService.selection()
                        withAnimation(.appSpring) {
                            selectedIndex = index
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.grid.3x3.fill")
                                .font(.caption)
                            Text(pool.name)
                                .font(AppTypography.callout)
                                .fontWeight(selectedIndex == index ? .semibold : .regular)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(selectedIndex == index ? AppColors.fieldGreen : Color(.systemGray5))
                        )
                        .foregroundColor(selectedIndex == index ? .white : .primary)
                        .overlay(
                            Capsule()
                                .strokeBorder(selectedIndex == index ? AppColors.techCyan.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Winner Spotlight Card
struct WinnerSpotlightCard: View {
    let pool: BoxGrid
    let score: GameScore

    @State private var shimmerOffset: CGFloat = -200

    var winner: BoxSquare? {
        pool.winningSquare(for: score)
    }

    var currentPeriodLabel: String? {
        pool.currentPeriod(for: score).map { period in
            switch period {
            case .quarter(let q): return "Q\(q)"
            case .halftime: return "Halftime"
            case .final: return "Final"
            case .firstScoreChange: return "First score"
            case .custom(_, let label): return label
            }
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.title2)
                    .foregroundColor(AppColors.gold)
                Text("Current Leader")
                    .font(AppTypography.title2)
                Spacer()
                if let periodLabel = currentPeriodLabel {
                    Text(periodLabel)
                        .font(AppTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.fieldGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(AppColors.fieldGreen.opacity(0.15)))
                }
            }

            if let winner = winner {
                HStack(spacing: 16) {
                    // Winner Avatar
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.gold, AppColors.gold.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)

                        Text(winner.initials)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .shadow(color: AppColors.gold.opacity(0.4), radius: 10, y: 4)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(winner.displayName)
                            .font(.title3)
                            .fontWeight(.bold)

                        HStack(spacing: 4) {
                            Text("\(pool.awayTeam.abbreviation):")
                            Text("\(score.awayLastDigit)")
                                .fontWeight(.bold)
                            Text("\(pool.homeTeam.abbreviation):")
                            Text("\(score.homeLastDigit)")
                                .fontWeight(.bold)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Winning combination
                    VStack(spacing: 2) {
                        Text("\(score.awayLastDigit)")
                            .font(.title)
                            .fontWeight(.bold)
                        Rectangle()
                            .fill(Color.secondary)
                            .frame(width: 30, height: 2)
                        Text("\(score.homeLastDigit)")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(AppColors.fieldGreen)
                }
            } else {
                HStack {
                    Image(systemName: "hourglass")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text("Waiting for game to start...")
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
        .glassCard()
        .techGlow(color: AppColors.glowGold, opacity: 0.5)
        .overlay(
            RoundedRectangle(cornerRadius: AppCardStyle.cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [AppColors.gold.opacity(0.5), AppColors.gold.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }
}

// MARK: - Interactive Grid Card
struct InteractiveGridCard: View {
    let pool: BoxGrid
    let score: GameScore?
    /// Global "my name" from Settings; pool may override with ownerLabels (how name appears on this sheet).
    let globalMyName: String

    var winningPosition: (row: Int, column: Int)? {
        guard let score = score else { return nil }
        return pool.winningPosition(homeDigit: score.homeLastDigit, awayDigit: score.awayLastDigit)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pool.name)
                        .font(AppTypography.headline)
                    Text("\(pool.awayTeam.abbreviation) vs \(pool.homeTeam.abbreviation)")
                        .font(AppTypography.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("View Full Grid")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.fieldGreen)
                    Image(systemName: "chevron.right")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.fieldGreen)
                }
            }

            // Grid
            GeometryReader { geometry in
                let cellSize = (geometry.size.width - 22) / 11

                VStack(spacing: 1) {
                    // Header row
                    HStack(spacing: 1) {
                        // Empty corner
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.clear)
                            .frame(width: cellSize, height: cellSize)

                        // Column headers (home team numbers)
                        ForEach(0..<10, id: \.self) { col in
                            Text("\(pool.homeNumbers[col])")
                                .font(.system(size: cellSize * 0.4, weight: .bold))
                                .frame(width: cellSize, height: cellSize)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(hex: pool.homeTeam.primaryColor)?.opacity(0.8) ?? Color.blue.opacity(0.8))
                                )
                                .foregroundColor(.white)
                        }
                    }

                    // Grid rows
                    ForEach(0..<10, id: \.self) { row in
                        HStack(spacing: 1) {
                            // Row header (away team number)
                            Text("\(pool.awayNumbers[row])")
                                .font(.system(size: cellSize * 0.4, weight: .bold))
                                .frame(width: cellSize, height: cellSize)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(hex: pool.awayTeam.primaryColor)?.opacity(0.8) ?? Color.red.opacity(0.8))
                                )
                                .foregroundColor(.white)

                            // Grid cells
                            ForEach(0..<10, id: \.self) { col in
                                let square = pool.squares[row][col]
                                let isWinning = winningPosition?.row == row && winningPosition?.column == col
                                let ownerLabels = pool.effectiveOwnerLabels(globalName: globalMyName)
                                let isHighlighted = !ownerLabels.isEmpty && pool.isOwnerSquare(square, ownerLabels: ownerLabels)

                                GridCellView(
                                    square: square,
                                    isWinning: isWinning,
                                    isHighlighted: isHighlighted,
                                    cellSize: cellSize
                                )
                            }
                        }
                    }
                }
            }
            .aspectRatio(1.0, contentMode: .fit)

            // Legend
            HStack(spacing: 16) {
                LegendItem(color: AppColors.fieldGreen, label: "Winner")
                LegendItem(color: .blue.opacity(0.6), label: "Filled")
                if !pool.effectiveOwnerLabels(globalName: globalMyName).isEmpty {
                    LegendItem(color: .orange, label: "My Squares")
                }
                Spacer()
                Text("\(pool.filledCount)/100")
                    .font(AppTypography.caption)
                    .foregroundColor(.secondary)
            }
        }
        .glassCard()
        .techGlow(opacity: 0.4)
    }
}

struct GridCellView: View {
    let square: BoxSquare
    let isWinning: Bool
    let isHighlighted: Bool
    let cellSize: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(cellColor)

            if !square.isEmpty {
                Text(square.initials)
                    .font(.system(size: cellSize * 0.35, weight: .medium))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }

            if isWinning {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(AppColors.gold, lineWidth: 2)
            }
        }
        .frame(width: cellSize, height: cellSize)
    }

    var cellColor: Color {
        if isWinning {
            return AppColors.fieldGreen
        } else if isHighlighted {
            return .orange.opacity(0.7)
        } else if square.isWinner {
            return AppColors.gold.opacity(0.6)
        } else if !square.isEmpty {
            return .blue.opacity(0.4)
        } else {
            return Color(.systemGray5)
        }
    }

    var textColor: Color {
        if isWinning || isHighlighted {
            return .white
        }
        return .primary
    }
}

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .font(AppTypography.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Quick Stats Card
struct QuickStatsCard: View {
    let pool: BoxGrid
    /// Global "my name" from Settings; pool may override with ownerLabels (how name appears on this sheet).
    let globalMyName: String

    var ownerLabels: [String] {
        pool.effectiveOwnerLabels(globalName: globalMyName)
    }

    var mySquares: [BoxSquare] {
        pool.squaresForOwner(ownerLabels: ownerLabels)
    }

    var body: some View {
        HStack(spacing: 16) {
            StatItem(
                icon: "square.grid.3x3.fill",
                value: "\(pool.filledCount)",
                label: "Filled",
                color: .blue
            )

            if !ownerLabels.isEmpty {
                StatItem(
                    icon: "star.fill",
                    value: "\(mySquares.count)",
                    label: "My Squares",
                    color: .orange
                )

                StatItem(
                    icon: "trophy.fill",
                    value: "\(mySquares.filter { $0.isWinner }.count)",
                    label: "Wins",
                    color: AppColors.gold
                )
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppCardStyle.cornerRadiusSmall)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppCardStyle.cornerRadiusSmall)
                .strokeBorder(.white.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: AppColors.cardShadow, radius: 10, y: 5)
        .techGlow(cornerRadius: AppCardStyle.cornerRadiusSmall)
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(value)
                .font(AppTypography.title2)

            Text(label)
                .font(AppTypography.caption2)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 60)
    }
}

// MARK: - Color Extension
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}

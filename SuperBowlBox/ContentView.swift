import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Live", systemImage: "dot.radiowaves.left.and.right")
                }
                .tag(0)

            PoolsListView()
                .tabItem {
                    Label("Pools", systemImage: "rectangle.split.3x3")
                }
                .tag(1)

            MySquaresView()
                .tabItem {
                    Label("My Squares", systemImage: "person.text.rectangle")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
                .tag(3)
        }
        .tint(DesignSystem.Colors.accentBlue)
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
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Dashboard View
struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedPoolIndex = 0
    @State private var showingRefreshAnimation = false

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackgroundView()
                TechGridOverlay()
                ScrollView {
                    VStack(spacing: AppCardStyle.sectionSpacing) {
                    LiveScoreCard(
                        score: appState.scoreService.currentScore ?? GameScore.mock,
                        isLoading: appState.scoreService.isLoading
                    )
                    .padding(.horizontal, AppCardStyle.screenHorizontalInset)

                    if appState.pools.count > 1 {
                        PoolSelectorView(
                            selectedIndex: $selectedPoolIndex,
                            pools: appState.pools
                        )
                        .padding(.horizontal, AppCardStyle.screenHorizontalInset)
                    }

                    if let pool = currentPool,
                       let score = appState.scoreService.currentScore,
                       !onTheHuntItems(pool: pool, score: score).isEmpty {
                        OnTheHuntCard(
                            items: onTheHuntItems(pool: pool, score: score)
                        )
                        .padding(.horizontal, AppCardStyle.screenHorizontalInset)
                    }

                    if let pool = currentPool,
                       let score = appState.scoreService.currentScore {
                        WinnerSpotlightCard(pool: pool, score: score)
                            .padding(.horizontal, AppCardStyle.screenHorizontalInset)
                    }

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
                        .padding(.horizontal, AppCardStyle.screenHorizontalInset)
                    }

                    if let pool = currentPool {
                        QuickStatsCard(pool: pool, globalMyName: appState.myName)
                            .padding(.horizontal, AppCardStyle.screenHorizontalInset)
                    }

                    Spacer(minLength: 120)
                    }
                    .padding(.top, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DesignSystem.Colors.backgroundSecondary, for: .navigationBar)
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
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 18, weight: .semibold))
                            .rotationEffect(.degrees(showingRefreshAnimation ? 360 : 0))
                            .animation(.easeInOut(duration: 0.5), value: showingRefreshAnimation)
                    }
                }
            }
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

    func onTheHuntItems(pool: BoxGrid, score: GameScore) -> [OnTheHuntItem] {
        let labels = pool.effectiveOwnerLabels(globalName: appState.myName)
        return pool.onTheHuntItems(score: score, ownerLabels: labels)
    }
}

// MARK: - On the Hunt Card (glass, urgency colors)
struct OnTheHuntCard: View {
    let items: [OnTheHuntItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "viewfinder.circle.fill")
                    .font(.title2)
                    .foregroundColor(DesignSystem.Colors.accentBlue)
                    .pulse(isActive: true)
                Text("On the Hunt")
                    .font(DesignSystem.Typography.title)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }

            ForEach(items.prefix(5)) { item in
                HStack(spacing: 12) {
                    urgencyIcon(item.urgency)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.square.displayName)
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        Text("\(item.teamShortName) needs to score • \(item.urgencyLabel)")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    Spacer()
                    Text(item.poolName)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall).fill(DesignSystem.Colors.backgroundTertiary.opacity(0.6)))
            }
        }
        .neonCard(glowColor: DesignSystem.Colors.neonCyanGlow)
    }

    @ViewBuilder
    private func urgencyIcon(_ urgency: OnTheHuntItem.Urgency) -> some View {
        let (icon, color): (String, Color) = {
            switch urgency {
            case .oneFG: return ("bolt.horizontal.fill", DesignSystem.Colors.dangerRed)
            case .oneTD: return ("arrow.up.right.circle.fill", DesignSystem.Colors.winnerGold)
            case .close: return ("viewfinder.circle.fill", DesignSystem.Colors.accentBlue)
            }
        }()
        Image(systemName: icon)
            .font(.title3)
            .foregroundColor(color)
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

// MARK: - Live Score Card (hero, glass)
struct LiveScoreCard: View {
    let score: GameScore
    let isLoading: Bool

    @State private var pulseAnimation = false

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                Circle()
                    .fill(score.isGameActive ? DesignSystem.Colors.liveGreen : DesignSystem.Colors.textMuted)
                    .frame(width: 8, height: 8)
                    .pulse(isActive: score.isGameActive)

                Text(score.isGameActive ? "LIVE" : score.gameStatusText.uppercased())
                    .font(DesignSystem.Typography.caption2)
                    .tracking(0.8)
                    .foregroundColor(score.isGameActive ? DesignSystem.Colors.liveGreen : DesignSystem.Colors.textSecondary)
            }

            HStack(spacing: 0) {
                TeamScoreColumn(
                    team: score.awayTeam,
                    score: score.awayScore,
                    lastDigit: score.awayLastDigit,
                    isLeading: score.awayScore > score.homeScore
                )
                VStack {
                    Text("VS")
                        .font(DesignSystem.Typography.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                .frame(width: 44)
                TeamScoreColumn(
                    team: score.homeTeam,
                    score: score.homeScore,
                    lastDigit: score.homeLastDigit,
                    isLeading: score.homeScore > score.awayScore
                )
            }

            HStack(spacing: 8) {
                Text("Winning Numbers:")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                Text("\(score.awayLastDigit) – \(score.homeLastDigit)")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.accentBlue)
            }
        }
        .padding(DesignSystem.Layout.cardPadding)
        .frame(maxWidth: .infinity)
        .neonCard(glowColor: score.isGameActive ? DesignSystem.Colors.matrixGreenGlow : DesignSystem.Colors.neonCyanGlow)
        .glow(color: score.isGameActive ? DesignSystem.Colors.matrixGreenGlow : DesignSystem.Colors.neonCyanGlow.opacity(0.3), radius: 10)
        .onAppear { pulseAnimation = true }
    }
}

struct TeamScoreColumn: View {
    let team: Team
    let score: Int
    let lastDigit: Int
    let isLeading: Bool

    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(Color(hex: team.primaryColor) ?? DesignSystem.Colors.textTertiary)
                .frame(width: 48, height: 48)
                .overlay(
                    Text(team.abbreviation)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                )

            Text(team.abbreviation)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Text("\(score)")
                .font(DesignSystem.Typography.scoreLarge)
                .foregroundColor(isLeading ? DesignSystem.Colors.liveGreen : DesignSystem.Colors.textPrimary)
                .contentTransition(.numericText())

            Text("(\(lastDigit))")
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(DesignSystem.Colors.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(DesignSystem.Colors.backgroundTertiary))
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
                            Image(systemName: "rectangle.split.3x3")
                                .font(.caption)
                            Text(pool.name)
                                .font(AppTypography.callout)
                                .fontWeight(selectedIndex == index ? .semibold : .regular)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(selectedIndex == index ? DesignSystem.Colors.accentBlue : DesignSystem.Colors.backgroundTertiary)
                        )
                        .foregroundColor(selectedIndex == index ? .white : DesignSystem.Colors.textPrimary)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Winner Spotlight Card (glass)
struct WinnerSpotlightCard: View {
    let pool: BoxGrid
    let score: GameScore

    var winner: BoxSquare? { pool.winningSquare(for: score) }

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
                Image(systemName: "crown.fill")
                    .font(.title2)
                    .foregroundColor(DesignSystem.Colors.winnerGold)
                Text("Current Leader")
                    .font(DesignSystem.Typography.title)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Spacer()
                if let periodLabel = currentPeriodLabel {
                    Text(periodLabel)
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.liveGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(DesignSystem.Colors.liveGreen.opacity(0.2)))
                }
            }

            if let winner = winner {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [DesignSystem.Colors.winnerGold, DesignSystem.Colors.winnerGold.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 56, height: 56)
                        Text(winner.initials)
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(winner.displayName)
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        HStack(spacing: 4) {
                            Text("\(pool.awayTeam.abbreviation): \(score.awayLastDigit)  \(pool.homeTeam.abbreviation): \(score.homeLastDigit)")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("\(score.awayLastDigit)")
                            .font(DesignSystem.Typography.title)
                        Rectangle().fill(DesignSystem.Colors.textTertiary).frame(width: 24, height: 2)
                        Text("\(score.homeLastDigit)")
                            .font(DesignSystem.Typography.title)
                    }
                    .foregroundColor(DesignSystem.Colors.accentBlue)
                }
            } else {
                HStack {
                    Image(systemName: "hourglass")
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                    Text("Waiting for game to start...")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding()
            }
        }
        .neonCard(glowColor: DesignSystem.Colors.winnerGold.opacity(0.6))
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
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text("\(pool.awayTeam.abbreviation) vs \(pool.homeTeam.abbreviation)")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("View Full Grid")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.accentBlue)
                    Image(systemName: "chevron.right")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.accentBlue)
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

            HStack(spacing: 16) {
                LegendItem(color: DesignSystem.Colors.liveGreen, label: "Winner")
                LegendItem(color: DesignSystem.Colors.accentBlue.opacity(0.8), label: "Filled")
                if !pool.effectiveOwnerLabels(globalName: globalMyName).isEmpty {
                    LegendItem(color: DesignSystem.Colors.winnerGold, label: "My Squares")
                }
                Spacer()
                Text("\(pool.filledCount)/100")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .neonCard(glowColor: DesignSystem.Colors.matrixGreenGlow.opacity(0.5))
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
                    .stroke(DesignSystem.Colors.winnerGold, lineWidth: 2)
            }
        }
        .frame(width: cellSize, height: cellSize)
    }

    var cellColor: Color {
        if isWinning {
            return DesignSystem.Colors.liveGreen
        } else if isHighlighted {
            return DesignSystem.Colors.winnerGold.opacity(0.7)
        } else if square.isWinner {
            return DesignSystem.Colors.winnerGold.opacity(0.5)
        } else if !square.isEmpty {
            return DesignSystem.Colors.accentBlue.opacity(0.4)
        } else {
            return DesignSystem.Colors.backgroundTertiary
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
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(DesignSystem.Colors.textSecondary)
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
                icon: "rectangle.split.3x3",
                value: "\(pool.filledCount)",
                label: "Filled",
                color: DesignSystem.Colors.accentBlue
            )

            if !ownerLabels.isEmpty {
                StatItem(
                    icon: "person.text.rectangle",
                    value: "\(mySquares.count)",
                    label: "My Squares",
                    color: DesignSystem.Colors.winnerGold
                )

                StatItem(
                    icon: "crown.fill",
                    value: "\(mySquares.filter { $0.isWinner }.count)",
                    label: "Wins",
                    color: DesignSystem.Colors.winnerGold
                )
            }

            Spacer()
        }
        .neonCard(cornerRadius: DesignSystem.Layout.cornerRadiusSmall, glowColor: DesignSystem.Colors.neonCyanGlow)
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
                .font(DesignSystem.Typography.title)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text(label)
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(DesignSystem.Colors.textSecondary)
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

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(onAddPoolTapped: { selectedTab = 1 })
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
        // Inactive tabs readable (sportsbook-style contrast)
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(white: 0.55, alpha: 1)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(white: 0.55, alpha: 1)]
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(red: 0.04, green: 0.52, blue: 1, alpha: 1)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(red: 0.04, green: 0.52, blue: 1, alpha: 1)]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Dashboard View
struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedPoolIndex = 0
    @State private var showingRefreshAnimation = false
    var onAddPoolTapped: (() -> Void)?

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.backgroundPrimary
                    .ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Layout.sectionSpacing) {
                    SectionHeaderView(title: "Featured Game")
                    LiveScoreCard(
                        score: appState.scoreService.currentScore ?? GameScore.mock,
                        isLoading: appState.scoreService.isLoading
                    )
                    .padding(.horizontal, DesignSystem.Layout.screenInset)

                    SectionHeaderView(title: "Your Pools")
                    if appState.pools.isEmpty {
                        AddPoolChipView(onTap: { onAddPoolTapped?() })
                            .padding(.horizontal, DesignSystem.Layout.screenInset)
                    } else {
                        PoolSelectorView(
                            selectedIndex: $selectedPoolIndex,
                            pools: appState.pools
                        )
                        .padding(.horizontal, DesignSystem.Layout.screenInset)
                    }

                    if let pool = currentPool,
                       let score = appState.scoreService.currentScore,
                       !onTheHuntItems(pool: pool, score: score).isEmpty {
                        SectionHeaderView(title: "On the Hunt")
                        OnTheHuntCard(
                            items: onTheHuntItems(pool: pool, score: score)
                        )
                        .padding(.horizontal, DesignSystem.Layout.screenInset)
                    }

                    if let pool = currentPool,
                       let score = appState.scoreService.currentScore {
                        SectionHeaderView(title: "Current Leader")
                        WinnerSpotlightCard(pool: pool, score: score)
                            .padding(.horizontal, DesignSystem.Layout.screenInset)
                    }

                    if let pool = currentPool {
                        SectionHeaderView(title: "Grid")
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
                        .padding(.horizontal, DesignSystem.Layout.screenInset)
                    }

                    if let pool = currentPool {
                        SectionHeaderView(title: "Stats")
                        QuickStatsCard(pool: pool, globalMyName: appState.myName)
                            .padding(.horizontal, DesignSystem.Layout.screenInset)
                    }

                    Spacer(minLength: 120)
                    }
                    .padding(.top, 12)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DesignSystem.Colors.headerGreen, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    SquareUpLogoView(showIcon: true, wordmarkSize: 20, iconSize: 20, inline: true)
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Text("Today")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
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

// MARK: - On the Hunt Card (urgency list; section title from SectionHeaderView)
struct OnTheHuntCard: View {
    let items: [OnTheHuntItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
        .sportsbookCard()
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

// MARK: - Live Score Card (Apple Sports style: league + status top, team gradient, simple winning strip)
struct LiveScoreCard: View {
    let score: GameScore
    let isLoading: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Top: League + status (like Apple Sports "MLB" "▲ 8th")
            HStack {
                Text("NFL")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                Spacer()
                HStack(spacing: 4) {
                    if score.isGameActive {
                        Circle()
                            .fill(DesignSystem.Colors.liveGreen)
                            .frame(width: 5, height: 5)
                            .pulse(isActive: true)
                    }
                    Text(score.isGameActive ? "LIVE" : score.gameStatusText.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.6)
                        .foregroundColor(score.isGameActive ? DesignSystem.Colors.liveGreen : DesignSystem.Colors.textTertiary)
                }
            }
            .padding(.bottom, 14)

            // Teams + scores
            HStack(spacing: 0) {
                TeamScoreColumn(
                    team: score.awayTeam,
                    score: score.awayScore,
                    lastDigit: score.awayLastDigit,
                    isLeading: score.awayScore > score.homeScore
                )
                Text("–")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .frame(width: 24)
                TeamScoreColumn(
                    team: score.homeTeam,
                    score: score.homeScore,
                    lastDigit: score.homeLastDigit,
                    isLeading: score.homeScore > score.awayScore
                )
            }

            // Winning numbers — informative strip
            VStack(alignment: .leading, spacing: 6) {
                Text("Winning numbers")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                Text("Last digit of each score → row × column")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(DesignSystem.Colors.textMuted)
                HStack {
                    Text("\(score.awayTeam.abbreviation)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                    Text("\(score.awayLastDigit) – \(score.homeLastDigit)")
                        .font(.system(size: 18, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text("\(score.homeTeam.abbreviation)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 14)
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall)
                    .fill(DesignSystem.Colors.backgroundTertiary.opacity(0.6))
            )
        }
        .padding(DesignSystem.Layout.cardPadding)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius)
                    .fill(DesignSystem.Colors.cardSurface)
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                (Color(hex: score.awayTeam.primaryColor) ?? Color.clear).opacity(0.06),
                                Color.clear,
                                (Color(hex: score.homeTeam.primaryColor) ?? Color.clear).opacity(0.06)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius)
                .strokeBorder(DesignSystem.Colors.cardBorder, lineWidth: 0.5)
        )
        .shadow(color: DesignSystem.Colors.cardShadow.opacity(0.5), radius: 6, x: 0, y: 2)
    }
}

struct TeamScoreColumn: View {
    let team: Team
    let score: Int
    let lastDigit: Int
    let isLeading: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color(hex: team.primaryColor) ?? DesignSystem.Colors.textTertiary)
                    .frame(width: 40, height: 40)
                if let urlString = team.logoURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                        case .failure:
                            Text(team.abbreviation)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        case .empty:
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        @unknown default:
                            Text(team.abbreviation)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                } else {
                    Text(team.abbreviation)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 40, height: 40)
            Text(team.abbreviation)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textTertiary)

            Text("\(score)")
                .font(.system(size: 32, weight: .bold))
                .monospacedDigit()
                .foregroundColor(isLeading ? DesignSystem.Colors.liveGreen : DesignSystem.Colors.textPrimary)
                .contentTransition(.numericText())

            Text("\(lastDigit)")
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundColor(DesignSystem.Colors.textTertiary)
                .frame(minWidth: 22)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DesignSystem.Colors.backgroundTertiary)
                )
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Add pool chip (when no pools — sends user to Pools tab)
struct AddPoolChipView: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            HapticService.selection()
            onTap()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                Text("Add your first pool")
                    .font(DesignSystem.Typography.callout)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall)
                    .fill(DesignSystem.Colors.accentBlue.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall)
                            .strokeBorder(DesignSystem.Colors.accentBlue.opacity(0.6), lineWidth: 1)
                    )
            )
            .foregroundColor(DesignSystem.Colors.accentBlue)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Pool Selector (Apple Sports style: one bar, selected segment filled)
struct PoolSelectorView: View {
    @Binding var selectedIndex: Int
    let pools: [BoxGrid]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(pools.enumerated()), id: \.element.id) { index, pool in
                Button {
                    HapticService.selection()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedIndex = index
                    }
                } label: {
                    Text(pool.name)
                        .font(.system(size: 15, weight: selectedIndex == index ? .semibold : .regular))
                        .foregroundColor(selectedIndex == index ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedIndex == index ? DesignSystem.Colors.cardSurface : Color.clear)
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(DesignSystem.Colors.backgroundTertiary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(DesignSystem.Colors.cardBorder, lineWidth: 0.5)
        )
    }
}

// MARK: - Winner Spotlight Card (gold accent, chip badge, data strip)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.winnerGold)
                    Text("Current Leader")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                Spacer()
                if let periodLabel = currentPeriodLabel {
                    Text(periodLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.5)
                        .foregroundColor(DesignSystem.Colors.winnerGold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(DesignSystem.Colors.winnerGold.opacity(0.15)))
                }
            }

            if let winner = winner {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [DesignSystem.Colors.winnerGold, DesignSystem.Colors.winnerGold.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                        Text(winner.initials)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(winner.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        Text("Leads this period")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.liveGreen)
                        Text("\(pool.awayTeam.abbreviation): \(score.awayLastDigit) · \(pool.homeTeam.abbreviation): \(score.homeLastDigit)")
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("\(score.awayLastDigit)")
                            .font(.system(size: 20, weight: .semibold))
                            .monospacedDigit()
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        Rectangle().fill(DesignSystem.Colors.textTertiary).frame(width: 20, height: 1)
                        Text("\(score.homeLastDigit)")
                            .font(.system(size: 20, weight: .semibold))
                            .monospacedDigit()
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall)
                        .fill(DesignSystem.Colors.backgroundTertiary)
                )
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 16))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                    Text("Waiting for game to start...")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
        }
        .padding(DesignSystem.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius)
                .fill(DesignSystem.Colors.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius)
                .strokeBorder(DesignSystem.Colors.cardBorder, lineWidth: 0.5)
        )
        .shadow(color: DesignSystem.Colors.cardShadow.opacity(0.4), radius: 6, x: 0, y: 2)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pool.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text("\(pool.awayTeam.abbreviation) × \(pool.homeTeam.abbreviation)")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("View grid")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.accentBlue)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.accentBlue)
                }
            }

            // Sleek grid: 2pt gap, small radius, clear axes
            GeometryReader { geometry in
                let gap: CGFloat = 2
                let totalGap = gap * 11
                let cellSize = (geometry.size.width - totalGap) / 11

                VStack(spacing: gap) {
                    // Top row: corner + column headers (home)
                    HStack(spacing: gap) {
                        Text("·")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.textMuted)
                            .frame(width: cellSize, height: cellSize)
                        ForEach(0..<10, id: \.self) { col in
                            let isWin = winningPosition?.column == col
                            Text("\(pool.homeNumbers[col])")
                                .font(.system(size: max(9, cellSize * 0.38), weight: .bold))
                                .monospacedDigit()
                                .frame(width: cellSize, height: cellSize)
                                .background(
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(isWin ? DesignSystem.Colors.liveGreen : (Color(hex: pool.homeTeam.primaryColor) ?? .blue).opacity(0.85))
                                )
                                .foregroundColor(.white)
                        }
                    }

                    ForEach(0..<10, id: \.self) { row in
                        HStack(spacing: gap) {
                            Text("\(pool.awayNumbers[row])")
                                .font(.system(size: max(9, cellSize * 0.38), weight: .bold))
                                .monospacedDigit()
                                .frame(width: cellSize, height: cellSize)
                                .background(
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(winningPosition?.row == row ? DesignSystem.Colors.liveGreen : (Color(hex: pool.awayTeam.primaryColor) ?? .red).opacity(0.85))
                                )
                                .foregroundColor(.white)

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

            // Compact legend + count
            HStack(spacing: 12) {
                LegendDot(color: DesignSystem.Colors.liveGreen, label: "Winner")
                LegendDot(color: DesignSystem.Colors.accentBlue.opacity(0.9), label: "Filled")
                if !pool.effectiveOwnerLabels(globalName: globalMyName).isEmpty {
                    LegendDot(color: DesignSystem.Colors.winnerGold, label: "Yours")
                }
                Spacer()
                Text("\(pool.filledCount)/100")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
        }
        .sportsbookCard()
    }
}

struct GridCellView: View {
    let square: BoxSquare
    let isWinning: Bool
    let isHighlighted: Bool
    let cellSize: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(cellColor)

            if !square.isEmpty {
                Text(square.initials)
                    .font(.system(size: cellSize * 0.36, weight: .semibold))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }

            if isWinning {
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(Color.white, lineWidth: 1.5)
            }
        }
        .frame(width: cellSize, height: cellSize)
    }

    var cellColor: Color {
        if isWinning {
            return DesignSystem.Colors.liveGreen
        } else if isHighlighted {
            return DesignSystem.Colors.winnerGold.opacity(0.75)
        } else if square.isWinner {
            return DesignSystem.Colors.winnerGold.opacity(0.45)
        } else if !square.isEmpty {
            return DesignSystem.Colors.accentBlue.opacity(0.35)
        } else {
            return DesignSystem.Colors.backgroundTertiary.opacity(0.8)
        }
    }

    var textColor: Color {
        if isWinning || isHighlighted { return .white }
        return DesignSystem.Colors.textPrimary
    }
}

struct LegendDot: View {
    let color: Color
    let label: String
    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(DesignSystem.Colors.textTertiary)
        }
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

// MARK: - Quick Stats Card (sleek strip with dividers)
struct QuickStatsCard: View {
    let pool: BoxGrid
    let globalMyName: String

    private var ownerLabels: [String] {
        pool.effectiveOwnerLabels(globalName: globalMyName)
    }

    private var mySquares: [BoxSquare] {
        pool.squaresForOwner(ownerLabels: ownerLabels)
    }

    var body: some View {
        HStack(spacing: 0) {
            StatPill(value: "\(pool.filledCount)", label: "Filled", color: DesignSystem.Colors.accentBlue)
            if !ownerLabels.isEmpty {
                Rectangle().fill(DesignSystem.Colors.cardBorder).frame(width: 0.5).padding(.vertical, 8)
                StatPill(value: "\(mySquares.count)", label: "Yours", color: DesignSystem.Colors.winnerGold)
                Rectangle().fill(DesignSystem.Colors.cardBorder).frame(width: 0.5).padding(.vertical, 8)
                StatPill(value: "\(mySquares.filter { $0.isWinner }.count)", label: "Wins", color: DesignSystem.Colors.winnerGold)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, DesignSystem.Layout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius)
                .fill(DesignSystem.Colors.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius)
                        .strokeBorder(DesignSystem.Colors.cardBorder, lineWidth: 0.5)
                )
        )
        .shadow(color: DesignSystem.Colors.cardShadow.opacity(0.4), radius: 6, x: 0, y: 2)
    }
}

struct StatPill: View {
    let value: String
    let label: String
    let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .monospacedDigit()
                .foregroundColor(DesignSystem.Colors.textPrimary)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
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

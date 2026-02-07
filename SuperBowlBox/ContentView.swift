import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
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
                    Label("My Boxes", systemImage: "person.text.rectangle")
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
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await appState.refreshJoinedPoolsIfNeeded()
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
        appearance.backgroundColor = UIColor(red: 0.09, green: 0.10, blue: 0.10, alpha: 1)
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(white: 0.62, alpha: 1)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(white: 0.62, alpha: 1)]
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(red: 0.04, green: 0.52, blue: 1, alpha: 1)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(red: 0.04, green: 0.52, blue: 1, alpha: 1)]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Dashboard View (live score + all pools at a glance)
struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingRefreshAnimation = false
    @State private var showingAddPoolFlow = false
    var onAddPoolTapped: (() -> Void)?

    /// All "on the hunt" items across every pool (for mission control)
    private var allOnTheHuntItems: [OnTheHuntItem] {
        guard let score = appState.scoreService.currentScore else { return [] }
        return appState.pools.flatMap { onTheHuntItems(pool: $0, score: score) }
    }

    /// Score matches this pool's game (same teams)
    private func scoreMatchesPool(_ pool: BoxGrid) -> Bool {
        guard let score = appState.scoreService.currentScore else { return false }
        return (pool.awayTeam.id == score.awayTeam.id && pool.homeTeam.id == score.homeTeam.id)
            || (pool.awayTeam.id == score.homeTeam.id && pool.homeTeam.id == score.awayTeam.id)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.backgroundPrimary
                    .ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Layout.sectionSpacing) {
                        // Live label (NFL only for now; league picker removed to reduce clutter)
                        HStack {
                            Spacer()
                            Text("LIVE")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.2)
                                .foregroundColor(DesignSystem.Colors.liveGreen)
                        }
                        .padding(.horizontal, DesignSystem.Layout.screenInset)
                        .padding(.bottom, 2)

                        SectionHeaderView(title: "Featured games")
                        // Score and matchup come from API (Sports Data IO or ESPN); Super Bowl preferred when in feed
                        Group {
                            if let score = appState.scoreService.currentScore {
                                LiveScoreCard(
                                    score: score,
                                    isLoading: appState.scoreService.isLoading
                                )
                            } else {
                                UpNextPlaceholderCard(
                                    isLoading: appState.scoreService.isLoading,
                                    error: appState.scoreService.error?.localizedDescription,
                                    onRefresh: { Task { await appState.scoreService.fetchCurrentScore() } }
                                )
                            }
                        }
                        .padding(.horizontal, DesignSystem.Layout.screenInset)

                        SectionHeaderView(title: "Your pools")
                        if appState.pools.isEmpty {
                            AddPoolChipView(onTap: { showingAddPoolFlow = true })
                                .padding(.horizontal, DesignSystem.Layout.screenInset)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(Array(appState.pools.enumerated()), id: \.element.id) { index, pool in
                                    NavigationLink {
                                        GridDetailView(pool: binding(for: pool))
                                    } label: {
                                        DashboardPoolCard(
                                            pool: pool,
                                            score: appState.scoreService.currentScore,
                                            scoreMatchesThisPool: scoreMatchesPool(pool),
                                            globalMyName: appState.myName
                                        )
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                                Button {
                                    showingAddPoolFlow = true
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 18))
                                        Text("Add another pool")
                                            .font(DesignSystem.Typography.callout)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(DesignSystem.Colors.accentBlue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        ZStack {
                                            RoundedRectangle(cornerRadius: DesignSystem.Layout.glassCornerRadius)
                                                .fill(.ultraThinMaterial)
                                            RoundedRectangle(cornerRadius: DesignSystem.Layout.glassCornerRadius)
                                                .strokeBorder(DesignSystem.Colors.accentBlue.opacity(0.5), lineWidth: 1)
                                        }
                                    )
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                            .padding(.horizontal, DesignSystem.Layout.screenInset)
                        }

                        if !allOnTheHuntItems.isEmpty {
                            SectionHeaderView(title: "On the hunt")
                            OnTheHuntCard(items: Array(allOnTheHuntItems.prefix(4)))
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
                    VStack(spacing: 0) {
                        Text("Live")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Scores · Your pools")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        HapticService.impactLight()
                        withAnimation(.appSpring) { showingRefreshAnimation = true }
                        Task {
                            await appState.scoreService.fetchCurrentScore()
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            withAnimation(.appQuick) { showingRefreshAnimation = false }
                        }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(showingRefreshAnimation ? 360 : 0))
                            .animation(.easeInOut(duration: 0.5), value: showingRefreshAnimation)
                    }
                }
            }
            .sheet(isPresented: $showingAddPoolFlow) {
                AddPoolFlowView(
                    onAddPool: { _ in
                        showingAddPoolFlow = false
                    },
                    onDismiss: { showingAddPoolFlow = false }
                )
                .environmentObject(appState)
            }
        }
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

// MARK: - Dashboard pool card (one per pool: name, teams, leader, winning numbers)
struct DashboardPoolCard: View {
    let pool: BoxGrid
    let score: GameScore?
    let scoreMatchesThisPool: Bool
    let globalMyName: String

    private var winner: BoxSquare? {
        guard let score = score, scoreMatchesThisPool else { return nil }
        return pool.winningSquare(for: score)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    TeamLogoView(team: pool.awayTeam, size: 40)
                    TeamLogoView(team: pool.homeTeam, size: 40)
                }
                .frame(minWidth: 92, minHeight: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pool.name)
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text("\(pool.awayTeam.abbreviation) vs \(pool.homeTeam.abbreviation)")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            if scoreMatchesThisPool, let score = score {
                HStack(spacing: 12) {
                    Text("\(score.awayLastDigit)–\(score.homeLastDigit)")
                        .font(.system(size: 14, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(DesignSystem.Colors.liveGreen)
                    if let winner = winner {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .font(.caption2)
                                .foregroundColor(DesignSystem.Colors.winnerGold)
                            Text(winner.displayName)
                                .font(DesignSystem.Typography.caption2)
                                .foregroundColor(DesignSystem.Colors.winnerGold)
                        }
                    }
                }
            } else {
                Text("Upcoming")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
        }
        .padding(DesignSystem.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.Layout.glassCornerRadius)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: DesignSystem.Layout.glassCornerRadius)
                    .fill(DesignSystem.Colors.cardSurface.opacity(0.4))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Layout.glassCornerRadius)
                .strokeBorder(DesignSystem.Colors.glassBorder, lineWidth: 0.8)
        )
        .glassBevelHighlight(cornerRadius: DesignSystem.Layout.glassCornerRadius)
        .glassDepthShadowsEnhanced()
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
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall)
                            .fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall)
                            .strokeBorder(DesignSystem.Colors.glassBorder.opacity(0.6), lineWidth: 0.5)
                    }
                )
                .glassDepthShadows()
            }
        }
        .liquidGlassCard(cornerRadius: DesignSystem.Layout.glassCornerRadius)
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

// MARK: - Scale on press + haptic (Control Center–style tap feel)
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { HapticService.impactLight() }
            }
    }
}

// MARK: - Up next / loading placeholder (no fictitious game)
struct UpNextPlaceholderCard: View {
    let isLoading: Bool
    let error: String?
    let onRefresh: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(DesignSystem.Colors.textSecondary)
                Text("Loading game…")
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            } else {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 44))
                    .foregroundColor(DesignSystem.Colors.accentBlue)
                Text("Up next")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                if let error = error {
                    Text(error)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("No game data right now. Pull to refresh.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                Button("Refresh") {
                    onRefresh()
                }
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.accentBlue)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Layout.cardPadding * 2)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.Layout.glassCornerRadius)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: DesignSystem.Layout.glassCornerRadius)
                    .fill(DesignSystem.Colors.cardSurface.opacity(0.35))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Layout.glassCornerRadius)
                .strokeBorder(DesignSystem.Colors.glassBorder, lineWidth: 0.8)
        )
        .glassBevelHighlight(cornerRadius: DesignSystem.Layout.glassCornerRadius)
        .glassDepthShadowsEnhanced()
    }
}

// MARK: - Live Score Card (Apple Sports style: league + status top, team gradient, kickoff when scheduled)
struct LiveScoreCard: View {
    let score: GameScore
    let isLoading: Bool

    private var isUpcoming: Bool { !score.isGameActive && !score.isGameOver }

    var body: some View {
        VStack(spacing: 0) {
            // Top: League + status or kickoff timeline
            HStack {
                Text("NFL")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                Spacer()
                if isUpcoming, let kickoff = score.kickoffDisplayString {
                    Text("Kickoff \(kickoff)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.accentBlue)
                } else {
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
            }
            .padding(.bottom, 14)

            // Teams + scores (larger logos for featured game)
            HStack(spacing: 0) {
                TeamScoreColumn(
                    team: score.awayTeam,
                    score: score.awayScore,
                    lastDigit: score.awayLastDigit,
                    isLeading: score.awayScore > score.homeScore,
                    logoSize: 56
                )
                Text("vs")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .frame(width: 28)
                TeamScoreColumn(
                    team: score.homeTeam,
                    score: score.homeScore,
                    lastDigit: score.homeLastDigit,
                    isLeading: score.homeScore > score.awayScore,
                    logoSize: 56
                )
            }

            // Winning numbers (or "upcoming" message)
            if isUpcoming {
                Text("Scores and winning numbers update at kickoff.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)
                    .padding(.vertical, 12)
            } else {
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
                    ZStack {
                        RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall)
                            .fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall)
                            .strokeBorder(DesignSystem.Colors.glassBorder.opacity(0.5), lineWidth: 0.5)
                    }
                )
                .glassDepthShadows()
            }
        }
        .padding(DesignSystem.Layout.cardPadding)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.Layout.glassCornerRadiusLarge)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: DesignSystem.Layout.glassCornerRadiusLarge)
                    .fill(
                        LinearGradient(
                            colors: [
                                (Color(hex: score.awayTeam.primaryColor) ?? Color.clear).opacity(0.08),
                                Color.clear,
                                (Color(hex: score.homeTeam.primaryColor) ?? Color.clear).opacity(0.08)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                RoundedRectangle(cornerRadius: DesignSystem.Layout.glassCornerRadiusLarge)
                    .fill(DesignSystem.Colors.cardSurface.opacity(0.25))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Layout.glassCornerRadiusLarge)
                .strokeBorder(DesignSystem.Colors.glassBorder, lineWidth: 0.8)
        )
        .glassBevelHighlight(cornerRadius: DesignSystem.Layout.glassCornerRadiusLarge)
        .glassDepthShadowsEnhanced()
    }
}

struct TeamScoreColumn: View {
    let team: Team
    let score: Int
    let lastDigit: Int
    let isLeading: Bool
    /// Logo circle size for featured game (default 40).
    var logoSize: CGFloat = 40

    private var imageSize: CGFloat { logoSize * 0.82 }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color(hex: team.primaryColor) ?? DesignSystem.Colors.textTertiary)
                    .frame(width: logoSize, height: logoSize)
                if let urlString = team.displayLogoURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(width: imageSize, height: imageSize)
                                .clipShape(Circle())
                        case .failure:
                            Text(team.abbreviation)
                                .font(.system(size: logoSize * 0.3, weight: .bold))
                                .foregroundColor(.white)
                        case .empty:
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        @unknown default:
                            Text(team.abbreviation)
                                .font(.system(size: logoSize * 0.3, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                } else {
                    Text(team.abbreviation)
                        .font(.system(size: logoSize * 0.3, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(width: logoSize, height: logoSize)
            Text(team.abbreviation)
                .font(.system(size: logoSize * 0.22, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textTertiary)

            Text("\(score)")
                .font(.system(size: logoSize * 0.58, weight: .bold))
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

// MARK: - Add pool chip (when no pools — sends user to Add Pool flow)
struct AddPoolChipView: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
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
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.Layout.glassCornerRadius)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: DesignSystem.Layout.glassCornerRadius)
                        .fill(DesignSystem.Colors.accentBlue.opacity(0.15))
                    RoundedRectangle(cornerRadius: DesignSystem.Layout.glassCornerRadius)
                        .strokeBorder(DesignSystem.Colors.accentBlue.opacity(0.6), lineWidth: 1)
                }
            )
            .foregroundColor(DesignSystem.Colors.accentBlue)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Unified Add Pool flow: Choose sport → Choose game → Scan | Enter numbers | Join code
struct AddPoolFlowView: View {
    let onAddPool: (BoxGrid) -> Void
    let onDismiss: () -> Void
    @EnvironmentObject var appState: AppState
    @StateObject private var gamesService = GamesService()
    @State private var selectedSport: Sport = .nfl
    @State private var selectedGame: ListableGame?
    @State private var showingScanner = false
    @State private var gameForEnterNumbers: ListableGame?
    @State private var showingJoin = false
    @Environment(\.dismiss) private var flowDismiss

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.backgroundPrimary.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Add a pool")
                            .font(DesignSystem.Typography.title)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        Text("Choose sport, pick the game, then scan a sheet or enter your numbers.")
                            .font(DesignSystem.Typography.callout)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        // 1) Sport
                        Text("Sport")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Sport.allCases) { sport in
                                    Button {
                                        HapticService.selection()
                                        selectedSport = sport
                                        selectedGame = nil
                                    } label: {
                                        Text(sport.displayName)
                                            .font(.callout)
                                            .fontWeight(selectedSport == sport ? .semibold : .regular)
                                            .foregroundColor(selectedSport == sport ? .white : .primary)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(Capsule().fill(selectedSport == sport ? AppColors.fieldGreen : DesignSystem.Colors.surfaceElevated))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // 2) Upcoming game
                        Text("Upcoming game")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                        if gamesService.isLoading {
                            HStack {
                                ProgressView()
                                Text("Loading games…")
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        } else if gamesService.games.isEmpty, let err = gamesService.error {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .padding()
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(gamesService.games) { game in
                                    Button {
                                        HapticService.selection()
                                        selectedGame = game
                                    } label: {
                                        HStack(spacing: 12) {
                                            TeamLogoView(team: game.awayTeam, size: 28)
                                            Text("\(game.awayTeam.abbreviation) vs \(game.homeTeam.abbreviation)")
                                                .font(.subheadline)
                                                .fontWeight(selectedGame?.id == game.id ? .semibold : .regular)
                                            Spacer()
                                            TeamLogoView(team: game.homeTeam, size: 28)
                                            if selectedGame?.id == game.id {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(AppColors.fieldGreen)
                                            }
                                        }
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 12)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(selectedGame?.id == game.id ? AppColors.fieldGreen.opacity(0.2) : DesignSystem.Colors.surfaceElevated))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // 3) How to add
                        Text("How do you want to add this pool?")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                        VStack(spacing: 10) {
                            if selectedGame != nil {
                                Button {
                                    HapticService.impactMedium()
                                    showingScanner = true
                                } label: {
                                    HStack {
                                        Image(systemName: "text.viewfinder")
                                        Text("Scan pool sheet")
                                            .fontWeight(.medium)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(DesignSystem.Colors.textTertiary)
                                    }
                                    .padding()
                                    .background(RoundedRectangle(cornerRadius: 12).fill(DesignSystem.Colors.surfaceElevated))
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                }
                                .buttonStyle(ScaleButtonStyle())

                                Button {
                                    HapticService.impactMedium()
                                    gameForEnterNumbers = selectedGame
                                } label: {
                                    HStack {
                                        Image(systemName: "square.and.pencil")
                                        Text("Enter my numbers")
                                            .fontWeight(.medium)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(DesignSystem.Colors.textTertiary)
                                    }
                                    .padding()
                                    .background(RoundedRectangle(cornerRadius: 12).fill(DesignSystem.Colors.surfaceElevated))
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                            Button {
                                HapticService.impactMedium()
                                showingJoin = true
                            } label: {
                                HStack {
                                    Image(systemName: "link.badge.plus")
                                    Text("Join with code")
                                        .fontWeight(.medium)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(DesignSystem.Colors.textTertiary)
                                }
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 12).fill(DesignSystem.Colors.surfaceElevated))
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .padding(DesignSystem.Layout.screenInset)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                        flowDismiss()
                    }
                }
            }
            .task(id: selectedSport) {
                await gamesService.fetchGames(sport: selectedSport)
            }
            .sheet(isPresented: $showingScanner) {
                Group {
                    if let game = selectedGame {
                        ScannerView(
                            onPoolScanned: { pool in
                                appState.addPool(pool)
                                HapticService.success()
                                showingScanner = false
                                onDismiss()
                                flowDismiss()
                            },
                            initialGame: game
                        )
                        .environmentObject(appState)
                    } else {
                        EmptyView()
                    }
                }
            }
            .sheet(item: $gameForEnterNumbers) { game in
                EnterMyNumbersView(
                    game: game,
                    onSave: { pool in
                        appState.addPool(pool)
                        HapticService.success()
                        gameForEnterNumbers = nil
                        onDismiss()
                        flowDismiss()
                    },
                    onCancel: { gameForEnterNumbers = nil }
                )
                .environmentObject(appState)
            }
            .sheet(isPresented: $showingJoin, onDismiss: {
                onDismiss()
                flowDismiss()
            }) {
                JoinPoolSheet()
                    .environmentObject(appState)
            }
        }
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
            case .scoreChange(let n): return "Score change \(n)"
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

// MARK: - Finalized winnings (period winners + amounts based on pool rules)
struct FinalizedWinningsCard: View {
    let pool: BoxGrid
    let score: GameScore
    let ownerLabels: [String]

    private var items: [(period: PoolPeriod, winnerName: String, amount: Double?)] {
        pool.finalizedWinnings(score: score)
    }

    private func isMyWin(_ winnerName: String) -> Bool {
        let w = winnerName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !w.isEmpty else { return false }
        return ownerLabels.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == w }
    }

    private func formatAmount(_ amount: Double?) -> String {
        guard let amount else { return "—" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = pool.resolvedPoolStructure.currencyCode
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(DesignSystem.Colors.liveGreen)
                Text("Finalized by rules")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack {
                        Text(item.period.displayLabel)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .frame(width: 56, alignment: .leading)
                        Text(item.winnerName)
                            .font(.system(size: 14, weight: isMyWin(item.winnerName) ? .semibold : .regular))
                            .foregroundColor(isMyWin(item.winnerName) ? DesignSystem.Colors.winnerGold : DesignSystem.Colors.textPrimary)
                        Spacer()
                        Text(formatAmount(item.amount))
                            .font(.system(size: 14, weight: .medium))
                            .monospacedDigit()
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall)
                    .fill(DesignSystem.Colors.backgroundTertiary)
            )
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
        .liquidGlassCard(cornerRadius: DesignSystem.Layout.glassCornerRadius)
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
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.Layout.glassCornerRadius)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: DesignSystem.Layout.glassCornerRadius)
                    .fill(DesignSystem.Colors.cardSurface.opacity(0.4))
                RoundedRectangle(cornerRadius: DesignSystem.Layout.glassCornerRadius)
                    .strokeBorder(DesignSystem.Colors.glassBorder, lineWidth: 0.8)
            }
        )
        .glassBevelHighlight(cornerRadius: DesignSystem.Layout.glassCornerRadius)
        .glassDepthShadowsEnhanced()
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

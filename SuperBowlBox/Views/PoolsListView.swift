import SwiftUI

struct PoolsListView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingNewPoolSheet = false
    @State private var showingCreateFromGame = false
    @State private var newPoolPrefill: NewPoolPrefill?
    @State private var gameForMyNumbers: ListableGame?
    @State private var showingScanner = false
    @State private var showingJoinPool = false
    @State private var poolToDelete: BoxGrid?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                SportsbookBackgroundView()
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Layout.sectionSpacing) {
                        if appState.pools.isEmpty {
                            // No fake pool: only options to upload, create, or join
                            NoPoolsEmptyState(
                                onScan: { showingScanner = true },
                                onCreateNew: { newPoolPrefill = nil; showingNewPoolSheet = true },
                                onCreateFromGame: { showingCreateFromGame = true },
                                onJoinWithCode: { showingJoinPool = true }
                            )
                            .padding(.horizontal, DesignSystem.Layout.screenInset)
                        } else {
                            SectionHeaderView(title: "Add Pool")
                            ImportPoolCard(
                                onScan: { showingScanner = true },
                                onCreateNew: { newPoolPrefill = nil; showingNewPoolSheet = true },
                                onCreateFromGame: { showingCreateFromGame = true }
                            )
                            .padding(.horizontal, DesignSystem.Layout.screenInset)

                            SectionHeaderView(title: "My Pools")
                            LazyVStack(spacing: 12) {
                                ForEach(Array(appState.pools.enumerated()), id: \.element.id) { index, pool in
                                    HStack(spacing: 0) {
                                        NavigationLink {
                                            GridDetailView(pool: binding(for: pool))
                                        } label: {
                                            PoolGameCard(pool: pool, score: appState.scoreService.currentScore)
                                        }
                                        .buttonStyle(ScaleButtonStyle())
                                        .frame(maxWidth: .infinity)

                                        Button {
                                            poolToDelete = pool
                                            showingDeleteConfirmation = true
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.system(size: 18, weight: .medium))
                                                .foregroundColor(DesignSystem.Colors.dangerRed)
                                                .frame(width: 44, height: 44)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            poolToDelete = pool
                                            showingDeleteConfirmation = true
                                        } label: {
                                            Label(pool.isOwner ? "Delete pool" : "Remove from my list", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, DesignSystem.Layout.screenInset)
                        }
                        Spacer(minLength: 100)
                    }
                    .padding(.top, 20)
                }
            }
            .sheet(isPresented: $showingJoinPool) {
                JoinPoolSheet()
                    .environmentObject(appState)
            }
            .toolbarBackground(DesignSystem.Colors.backgroundSecondary, for: .navigationBar)
            .navigationTitle("Pools")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            newPoolPrefill = nil
                            showingNewPoolSheet = true
                        } label: {
                            Label("Create New Pool", systemImage: "plus.square")
                        }
                        Button {
                            showingCreateFromGame = true
                        } label: {
                            Label("Create from Game", systemImage: "sportscourt")
                        }
                        Button {
                            showingScanner = true
                        } label: {
                            Label("Scan Pool Sheet", systemImage: "text.viewfinder")
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                }
            }
            .sheet(isPresented: $showingNewPoolSheet) {
                NewPoolSheet(
                    onSave: { pool in
                        HapticService.success()
                        appState.addPool(pool)
                        newPoolPrefill = nil
                        showingNewPoolSheet = false
                    },
                    prefill: newPoolPrefill
                )
            }
            .sheet(isPresented: $showingCreateFromGame) {
                CreateFromGameView(
                    onSelect: { game in
                        showingCreateFromGame = false
                        gameForMyNumbers = game
                    },
                    onCancel: { showingCreateFromGame = false }
                )
            }
            .sheet(item: $gameForMyNumbers) { game in
                EnterMyNumbersView(
                    game: game,
                    onSave: { pool in
                        HapticService.success()
                        appState.addPool(pool)
                        gameForMyNumbers = nil
                    },
                    onCancel: { gameForMyNumbers = nil }
                )
                .environmentObject(appState)
            }
            .sheet(isPresented: $showingScanner) {
                ScannerView { scannedPool in
                    HapticService.success()
                    appState.addPool(scannedPool)
                    showingScanner = false
                }
                .environmentObject(appState)
            }
            .alert("Remove pool?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    if let pool = poolToDelete,
                       let index = appState.pools.firstIndex(where: { $0.id == pool.id }) {
                        HapticService.impactHeavy()
                        appState.removePool(at: index)
                    }
                }
            } message: {
                if let pool = poolToDelete {
                    Text(pool.isOwner
                         ? "'\(pool.name)' will be removed from this device. It does not delete the pool from the system if it was shared."
                         : "'\(pool.name)' will be removed from your list only. The pool stays in the system for the host and others.")
                }
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

// MARK: - Import pool card (Scan / Create / From game — always first)
struct ImportPoolCard: View {
    let onScan: () -> Void
    let onCreateNew: () -> Void
    let onCreateFromGame: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            ImportPoolButton(icon: "camera.viewfinder", label: "Scan", action: onScan)
            Rectangle().fill(DesignSystem.Colors.cardBorder).frame(width: 1).padding(.vertical, 12)
            ImportPoolButton(icon: "plus.square.fill", label: "New", action: onCreateNew)
            Rectangle().fill(DesignSystem.Colors.cardBorder).frame(width: 1).padding(.vertical, 12)
            ImportPoolButton(icon: "sportscourt.fill", label: "From Game", action: onCreateFromGame)
        }
        .padding(.vertical, 4)
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
        .shadow(color: DesignSystem.Colors.cardShadow.opacity(0.35), radius: 2, x: 0, y: 1)
        .shadow(color: DesignSystem.Colors.cardShadow.opacity(0.2), radius: 10, x: 0, y: 3)
    }
}

private struct ImportPoolButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(DesignSystem.Colors.accentBlue)
                Text(label)
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Reusable glass background for no-pools and list cards
private struct NoPoolsGlassBackground: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignSystem.Layout.glassCornerRadius)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: DesignSystem.Layout.glassCornerRadius)
                .fill(DesignSystem.Colors.cardSurface.opacity(0.4))
            RoundedRectangle(cornerRadius: DesignSystem.Layout.glassCornerRadius)
                .strokeBorder(DesignSystem.Colors.glassBorder, lineWidth: 0.8)
        }
        .shadow(color: DesignSystem.Colors.cardShadow.opacity(0.35), radius: 2, x: 0, y: 1)
        .shadow(color: DesignSystem.Colors.cardShadow.opacity(0.2), radius: 10, x: 0, y: 3)
    }
}

// MARK: - No pools: only real options — upload, create, or join with code (no fake pool)
struct NoPoolsEmptyState: View {
    let onScan: () -> Void
    let onCreateNew: () -> Void
    let onCreateFromGame: () -> Void
    let onJoinWithCode: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("No pools yet")
                .font(DesignSystem.Typography.title)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            Text("Upload a sheet, create a pool, or join one with a code.")
                .font(DesignSystem.Typography.callout)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button(action: onScan) {
                    HStack {
                        Image(systemName: "text.viewfinder")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Scan pool sheet")
                                .font(DesignSystem.Typography.headline)
                            Text("Upload a photo of your pool")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding(DesignSystem.Layout.cardPadding)
                    .background(NoPoolsGlassBackground())
                }
                .buttonStyle(ScaleButtonStyle())

                Button(action: onCreateNew) {
                    HStack {
                        Image(systemName: "plus.square.fill")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Create new pool")
                                .font(DesignSystem.Typography.headline)
                            Text("Build a pool from scratch")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding(DesignSystem.Layout.cardPadding)
                    .background(NoPoolsGlassBackground())
                }
                .buttonStyle(ScaleButtonStyle())

                Button(action: onCreateFromGame) {
                    HStack {
                        Image(systemName: "sportscourt.fill")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Manual / from game")
                                .font(DesignSystem.Typography.headline)
                            Text("Pick a game, then enter your numbers")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding(DesignSystem.Layout.cardPadding)
                    .background(NoPoolsGlassBackground())
                }
                .buttonStyle(ScaleButtonStyle())

                Button(action: onJoinWithCode) {
                    HStack {
                        Image(systemName: "link.badge.plus")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Join with code")
                                .font(DesignSystem.Typography.headline)
                            Text("Enter an invite code from a host")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding(DesignSystem.Layout.cardPadding)
                    .background(NoPoolsGlassBackground())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Layout.cardPadding * 2)
    }
}

// MARK: - Pool as game-style card
struct PoolGameCard: View {
    let pool: BoxGrid
    let score: GameScore?

    private var winner: BoxSquare? {
        guard let score = score else { return nil }
        return pool.winningSquare(for: score)
    }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                TeamLogoView(team: pool.awayTeam, size: 40)
                TeamLogoView(team: pool.homeTeam, size: 40)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(pool.name)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Text("\(pool.awayTeam.abbreviation) vs \(pool.homeTeam.abbreviation)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                HStack(spacing: 12) {
                    Text("\(pool.filledCount)/100 filled")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
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
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.textTertiary)
        }
        .padding(DesignSystem.Layout.cardPadding)
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
        .shadow(color: DesignSystem.Colors.cardShadow.opacity(0.35), radius: 2, x: 0, y: 1)
        .shadow(color: DesignSystem.Colors.cardShadow.opacity(0.2), radius: 10, x: 0, y: 3)
    }
}

struct PoolRowView: View {
    let pool: BoxGrid
    let score: GameScore?

    var winner: BoxSquare? {
        guard let score = score else { return nil }
        return pool.winningSquare(for: score)
    }

    var body: some View {
        HStack(spacing: 16) {
            MiniGridPreview(pool: pool, score: score)
                .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(pool.name)
                    .font(.headline)
                    .fontWeight(.semibold)

                Text("\(pool.awayTeam.abbreviation) vs \(pool.homeTeam.abbreviation)")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Text(pool.resolvedPoolStructure.periodLabels.joined(separator: " · "))
                    .font(.caption2)
                    .foregroundColor(AppColors.fieldGreen.opacity(0.9))

                HStack(spacing: 12) {
                    Label("\(pool.filledCount)/100", systemImage: "rectangle.split.3x3")
                        .font(.caption2)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    if let winner = winner {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .foregroundColor(DesignSystem.Colors.winnerGold)
                            Text(winner.displayName)
                        }
                        .font(.caption2)
                        .foregroundColor(AppColors.gold)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct MiniGridPreview: View {
    let pool: BoxGrid
    let score: GameScore?

    var winningPosition: (row: Int, column: Int)? {
        guard let score = score else { return nil }
        return pool.winningPosition(homeDigit: score.homeLastDigit, awayDigit: score.awayLastDigit)
    }

    var body: some View {
        VStack(spacing: 0.5) {
            ForEach(0..<10, id: \.self) { row in
                HStack(spacing: 0.5) {
                    ForEach(0..<10, id: \.self) { col in
                        let square = pool.squares[row][col]
                        let isWinning = winningPosition?.row == row && winningPosition?.column == col

                        Rectangle()
                            .fill(cellColor(square: square, isWinning: isWinning))
                            .frame(width: 5, height: 5)
                    }
                }
            }
        }
        .background(DesignSystem.Colors.surfaceElevated)
        .cornerRadius(4)
    }

    func cellColor(square: BoxSquare, isWinning: Bool) -> Color {
        if isWinning {
            return AppColors.fieldGreen
        } else if square.isWinner {
            return AppColors.gold
        } else if !square.isEmpty {
            return .blue.opacity(0.5)
        }
        return DesignSystem.Colors.surfaceElevated
    }
}

struct EmptyPoolsView: View {
    let onCreateNew: () -> Void
    let onCreateFromGame: () -> Void
    let onScan: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "rectangle.split.3x3")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.accentBlue)

            VStack(spacing: 8) {
                Text("No Pools Yet")
                    .font(DesignSystem.Typography.title)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("Create a pool from a live game, build one from scratch, or scan a sheet")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                Button {
                    onCreateNew()
                } label: {
                    Label("Create New Pool", systemImage: "plus.square.fill")
                        .frame(maxWidth: .infinity)
                        .padding(DesignSystem.Layout.cardPadding)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall)
                                .fill(DesignSystem.Colors.accentBlue)
                        )
                        .foregroundColor(.white)
                }

                Button {
                    onCreateFromGame()
                } label: {
                    Label("Create from Game", systemImage: "sportscourt")
                        .frame(maxWidth: .infinity)
                        .padding(DesignSystem.Layout.cardPadding)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall)
                                .fill(DesignSystem.Colors.glassFill)
                                .overlay(RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall).strokeBorder(DesignSystem.Colors.glassBorder, lineWidth: 1))
                        )
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }

                Button {
                    onScan()
                } label: {
                    Label("Scan Pool Sheet", systemImage: "text.viewfinder")
                        .frame(maxWidth: .infinity)
                        .padding(DesignSystem.Layout.cardPadding)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall)
                                .fill(DesignSystem.Colors.glassFill)
                                .overlay(RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall).strokeBorder(DesignSystem.Colors.glassBorder, lineWidth: 1))
                        )
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
            }
            .padding(.horizontal, DesignSystem.Layout.screenInset + 8)
        }
        .padding(.vertical, 28)
    }
}

// MARK: - Pool type option for picker
private enum PoolTypeOption: String, CaseIterable {
    case byQuarter = "By quarter (Q1–Q4)"
    case halftimeOnly = "Halftime only"
    case finalOnly = "Final score only"
    case firstScore = "First score"
    case halftimeAndFinal = "Halftime + Final"

    var poolType: PoolType {
        switch self {
        case .byQuarter: return .byQuarter([1, 2, 3, 4])
        case .halftimeOnly: return .halftimeOnly
        case .finalOnly: return .finalOnly
        case .firstScore: return .firstScoreChange
        case .halftimeAndFinal: return .halftimeAndFinal
        }
    }
}

// MARK: - Payout style option for picker
private enum PayoutStyleOption: String, CaseIterable {
    case equalSplit = "Equal split"
    case fixed25 = "$25 per period"
    case fixed50 = "$50 per period"
    case percentage = "Custom %"

    var payoutStyle: PayoutStyle {
        switch self {
        case .equalSplit: return .equalSplit
        case .fixed25: return .fixedAmount([25, 25, 25, 25])
        case .fixed50: return .fixedAmount([50, 50, 50, 50])
        case .percentage: return .percentage([25, 25, 25, 25])
        }
    }
}

/// Optional prefill when creating a pool from a game (teams + name + suggested structure).
struct NewPoolPrefill {
    let poolName: String
    let homeTeam: Team
    let awayTeam: Team
    let suggestedPoolStructure: PoolStructure
}

struct NewPoolSheet: View {
    let onSave: (BoxGrid) -> Void
    var prefill: NewPoolPrefill?
    @Environment(\.dismiss) var dismiss

    @State private var poolName = ""
    @State private var selectedHomeTeam = Team.chiefs
    @State private var selectedAwayTeam = Team.eagles
    @State private var poolTypeOption: PoolTypeOption = .byQuarter
    @State private var payoutStyleOption: PayoutStyleOption = .equalSplit
    @State private var totalPoolAmountText = ""
    @State private var customPayoutDescription = ""
    @State private var showPoolStructureInfo = false
    /// When set (from prefill), we use this structure when creating the pool instead of the form-derived one.
    @State private var prefillStructure: PoolStructure?

    private var totalPoolAmount: Double? {
        guard !totalPoolAmountText.isEmpty,
              let value = Double(totalPoolAmountText.trimmingCharacters(in: .whitespaces)),
              value >= 0 else { return nil }
        return value
    }

    private var poolStructure: PoolStructure {
        let desc = customPayoutDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return PoolStructure(
            poolType: poolTypeOption.poolType,
            payoutStyle: payoutStyleOption.payoutStyle,
            totalPoolAmount: totalPoolAmount,
            currencyCode: "USD",
            customPayoutDescription: desc.isEmpty ? nil : desc
        )
    }

    private var effectivePoolStructure: PoolStructure {
        prefillStructure ?? poolStructure
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Pool Name") {
                    TextField("Enter pool name", text: $poolName)
                }

                Section("When do we pay?") {
                    Picker("Pool type", selection: $poolTypeOption) {
                        ForEach(PoolTypeOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)

                    Button {
                        showPoolStructureInfo = true
                    } label: {
                        Label("How pool types work", systemImage: "info.circle")
                            .font(.subheadline)
                            .foregroundColor(AppColors.fieldGreen)
                    }
                }

                Section("Payouts") {
                    Picker("Payout style", selection: $payoutStyleOption) {
                        ForEach(PayoutStyleOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)

                    HStack {
                        Text("Total pool ($)")
                        TextField("Optional", text: $totalPoolAmountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    .font(.subheadline)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Describe how this pool pays (optional)")
                            .font(.subheadline)
                        TextField("e.g. $25 per quarter, halftime pays double", text: $customPayoutDescription, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            suggestPoolTypeFromDescription()
                        } label: {
                            Label("Suggest from description", systemImage: "sparkles")
                                .font(.subheadline)
                                .foregroundColor(AppColors.fieldGreen)
                        }
                    }
                }

                Section("Teams") {
                    Picker("Home Team (Columns)", selection: $selectedHomeTeam) {
                        ForEach(Team.allTeams, id: \.id) { team in
                            Text(team.name).tag(team)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .onChange(of: selectedHomeTeam) { _, new in
                        if new.id == selectedAwayTeam.id, let other = Team.allTeams.first(where: { $0.id != new.id }) {
                            selectedAwayTeam = other
                        }
                    }

                    Picker("Away Team (Rows)", selection: $selectedAwayTeam) {
                        ForEach(Team.allTeams, id: \.id) { team in
                            Text(team.name).tag(team)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .onChange(of: selectedAwayTeam) { _, new in
                        if new.id == selectedHomeTeam.id, let other = Team.allTeams.first(where: { $0.id != new.id }) {
                            selectedHomeTeam = other
                        }
                    }

                    if selectedHomeTeam.id == selectedAwayTeam.id {
                        Text("Pick two different teams for the matchup.")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.dangerRed)
                    }
                }

                Section("Preview") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Circle()
                                .fill(Color(hex: selectedAwayTeam.primaryColor) ?? .red)
                                .frame(width: 30, height: 30)
                                .overlay(Text(selectedAwayTeam.abbreviation).font(.caption2).fontWeight(.bold).foregroundColor(.white))
                            Text("vs").foregroundColor(DesignSystem.Colors.textSecondary)
                            Circle()
                                .fill(Color(hex: selectedHomeTeam.primaryColor) ?? .blue)
                                .frame(width: 30, height: 30)
                                .overlay(Text(selectedHomeTeam.abbreviation).font(.caption2).fontWeight(.bold).foregroundColor(.white))
                            Spacer()
                        }
                        Text(effectivePoolStructure.periodLabels.joined(separator: " · "))
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        if !effectivePoolStructure.payoutDescriptions.isEmpty {
                            Text(effectivePoolStructure.payoutDescriptions.joined(separator: "  "))
                                .font(.caption)
                                .foregroundColor(AppColors.fieldGreen)
                        }
                    }
                }
            }
            .navigationTitle("New Pool")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let name = poolName.isEmpty ? "Pool \(Date().formatted(date: .abbreviated, time: .omitted))" : poolName
                        let structure = effectivePoolStructure
                        let newPool = BoxGrid(
                            name: name,
                            homeTeam: selectedHomeTeam,
                            awayTeam: selectedAwayTeam,
                            poolStructure: structure
                        )
                        onSave(newPool)
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedHomeTeam.id == selectedAwayTeam.id)
                }
            }
            .onAppear {
                if let p = prefill {
                    poolName = p.poolName
                    selectedHomeTeam = p.homeTeam
                    selectedAwayTeam = p.awayTeam
                    prefillStructure = p.suggestedPoolStructure
                }
            }
            .onChange(of: customPayoutDescription) { _, newValue in
                if prefillStructure != nil, !newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                    prefillStructure = nil
                }
            }
            .sheet(isPresented: $showPoolStructureInfo) {
                PoolStructureInfoSheet()
            }
        }
    }

    /// Suggest pool type from free-text description (keyword matching; LLM could be wired here later).
    private func suggestPoolTypeFromDescription() {
        let t = customPayoutDescription.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !t.isEmpty else { return }
        if t.contains("first score") || t.contains("first score change") || t.contains("first td") || t.contains("first field goal") {
            poolTypeOption = .firstScore
            prefillStructure = nil
            return
        }
        if t.contains("halftime") && (t.contains("final") || t.contains("end")) {
            poolTypeOption = .halftimeAndFinal
            prefillStructure = nil
            return
        }
        if t.contains("halftime") {
            poolTypeOption = .halftimeOnly
            prefillStructure = nil
            return
        }
        if t.contains("final") || t.contains("end of game") || t.contains("full game") {
            poolTypeOption = .finalOnly
            prefillStructure = nil
            return
        }
        if t.contains("quarter") || t.contains("q1") || t.contains("q2") || t.contains("q3") || t.contains("q4") {
            poolTypeOption = .byQuarter
            prefillStructure = nil
        }
    }
}

// MARK: - Pool structure info sheet
struct PoolStructureInfoSheet: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("By quarter (Q1–Q4)") {
                    Text("Winner is determined by the last digit of each team’s score at the end of Q1, Q2, Q3, and Q4. Four payouts.")
                }
                Section("Halftime only") {
                    Text("One payout: winner at the end of the first half (Q2).")
                }
                Section("Final score only") {
                    Text("One payout: winner when the game ends.")
                }
                Section("First score") {
                    Text("One payout: winner the first time the score changes from 0–0 (first field goal, TD, or safety).")
                }
                Section("Halftime + Final") {
                    Text("Two payouts: halftime and final score.")
                }
            }
            .navigationTitle("Pool types")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    PoolsListView()
        .environmentObject(AppState())
}

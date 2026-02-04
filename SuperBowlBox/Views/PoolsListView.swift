import SwiftUI

struct PoolsListView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingNewPoolSheet = false
    @State private var showingCreateFromGame = false
    @State private var newPoolPrefill: NewPoolPrefill?
    @State private var showingScanner = false
    @State private var poolToDelete: BoxGrid?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if appState.pools.isEmpty {
                    EmptyPoolsView(
                        onCreateNew: { newPoolPrefill = nil; showingNewPoolSheet = true },
                        onCreateFromGame: { showingCreateFromGame = true },
                        onScan: { showingScanner = true }
                    )
                } else {
                        List {
                            ForEach(Array(appState.pools.enumerated()), id: \.element.id) { index, pool in
                                NavigationLink {
                                    GridDetailView(pool: binding(for: pool))
                                } label: {
                                    PoolRowView(pool: pool, score: appState.scoreService.currentScore)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        poolToDelete = pool
                                        showingDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .listRowBackground(Color(.secondarySystemGroupedBackground).opacity(0.6))
                            }
                        }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                }
            }
            .background(AppColors.screenBackground)
            .navigationTitle("My Pools")
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
                            Label("Scan Pool Sheet", systemImage: "camera.viewfinder")
                        }
                    } label: {
                        Image(systemName: "plus")
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
                        newPoolPrefill = NewPoolPrefill(
                            poolName: "\(game.awayTeam.abbreviation) @ \(game.homeTeam.abbreviation)",
                            homeTeam: game.homeTeam,
                            awayTeam: game.awayTeam,
                            suggestedPoolStructure: PoolStructure.defaultFor(sport: game.sport)
                        )
                        showingCreateFromGame = false
                        showingNewPoolSheet = true
                    },
                    onCancel: { showingCreateFromGame = false }
                )
            }
            .sheet(isPresented: $showingScanner) {
                ScannerView { scannedPool in
                    HapticService.success()
                    appState.addPool(scannedPool)
                    showingScanner = false
                }
            }
            .alert("Delete Pool?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let pool = poolToDelete,
                       let index = appState.pools.firstIndex(where: { $0.id == pool.id }) {
                        HapticService.impactHeavy()
                        appState.removePool(at: index)
                    }
                }
            } message: {
                if let pool = poolToDelete {
                    Text("Are you sure you want to delete '\(pool.name)'? This cannot be undone.")
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

struct PoolRowView: View {
    let pool: BoxGrid
    let score: GameScore?

    var winner: BoxSquare? {
        guard let score = score else { return nil }
        return pool.winningSquare(for: score)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Mini grid preview
            MiniGridPreview(pool: pool, score: score)
                .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(pool.name)
                    .font(.headline)
                    .fontWeight(.semibold)

                Text("\(pool.awayTeam.abbreviation) vs \(pool.homeTeam.abbreviation)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(pool.resolvedPoolStructure.periodLabels.joined(separator: " · "))
                    .font(.caption2)
                    .foregroundColor(AppColors.fieldGreen.opacity(0.9))

                HStack(spacing: 12) {
                    Label("\(pool.filledCount)/100", systemImage: "square.grid.3x3")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if let winner = winner {
                        HStack(spacing: 4) {
                            Image(systemName: "trophy.fill")
                                .foregroundColor(AppColors.gold)
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
        .background(Color(.systemGray4))
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
        return Color(.systemGray5)
    }
}

struct EmptyPoolsView: View {
    let onCreateNew: () -> Void
    let onCreateFromGame: () -> Void
    let onScan: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "square.grid.3x3.topleft.filled")
                .font(.system(size: 60))
                .foregroundColor(AppColors.fieldGreen)

            VStack(spacing: 8) {
                Text("No Pools Yet")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Create a pool from a live game, build one from scratch, or scan a sheet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button {
                    onCreateNew()
                } label: {
                    Label("Create New Pool", systemImage: "plus.square.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.fieldGreen)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Button {
                    onCreateFromGame()
                } label: {
                    Label("Create from Game", systemImage: "sportscourt")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }

                Button {
                    onScan()
                } label: {
                    Label("Scan Pool Sheet", systemImage: "camera.viewfinder")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 40)
        }
        .padding()
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
        PoolStructure(
            poolType: poolTypeOption.poolType,
            payoutStyle: payoutStyleOption.payoutStyle,
            totalPoolAmount: totalPoolAmount,
            currencyCode: "USD"
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
                }

                Section("Teams") {
                    Picker("Home Team (Columns)", selection: $selectedHomeTeam) {
                        ForEach(Team.allTeams, id: \.id) { team in
                            Text(team.name).tag(team)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    Picker("Away Team (Rows)", selection: $selectedAwayTeam) {
                        ForEach(Team.allTeams, id: \.id) { team in
                            Text(team.name).tag(team)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section("Preview") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Circle()
                                .fill(Color(hex: selectedAwayTeam.primaryColor) ?? .red)
                                .frame(width: 30, height: 30)
                                .overlay(Text(selectedAwayTeam.abbreviation).font(.caption2).fontWeight(.bold).foregroundColor(.white))
                            Text("vs").foregroundColor(.secondary)
                            Circle()
                                .fill(Color(hex: selectedHomeTeam.primaryColor) ?? .blue)
                                .frame(width: 30, height: 30)
                                .overlay(Text(selectedHomeTeam.abbreviation).font(.caption2).fontWeight(.bold).foregroundColor(.white))
                            Spacer()
                        }
                        Text(effectivePoolStructure.periodLabels.joined(separator: " · "))
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                        let newPool = BoxGrid(
                            name: poolName.isEmpty ? "Pool \(Date().formatted(date: .abbreviated, time: .omitted))" : poolName,
                            homeTeam: selectedHomeTeam,
                            awayTeam: selectedAwayTeam,
                            poolStructure: effectivePoolStructure
                        )
                        onSave(newPool)
                    }
                    .fontWeight(.semibold)
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
            .sheet(isPresented: $showPoolStructureInfo) {
                PoolStructureInfoSheet()
            }
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

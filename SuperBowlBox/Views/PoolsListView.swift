import SwiftUI

struct PoolsListView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingNewPoolSheet = false
    @State private var showingScanner = false
    @State private var poolToDelete: BoxGrid?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if appState.pools.isEmpty {
                    EmptyPoolsView(
                        onCreateNew: { showingNewPoolSheet = true },
                        onScan: { showingScanner = true }
                    )
                } else {
                    List {
                        ForEach(appState.pools) { pool in
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
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("My Pools")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingNewPoolSheet = true
                        } label: {
                            Label("Create New Pool", systemImage: "plus.square")
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
                NewPoolSheet { pool in
                    appState.addPool(pool)
                    showingNewPoolSheet = false
                }
            }
            .sheet(isPresented: $showingScanner) {
                ScannerView { scannedPool in
                    appState.addPool(scannedPool)
                    showingScanner = false
                }
            }
            .alert("Delete Pool?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let pool = poolToDelete,
                       let index = appState.pools.firstIndex(where: { $0.id == pool.id }) {
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

                Text("Create a new pool or scan an existing sheet to get started")
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

struct NewPoolSheet: View {
    let onSave: (BoxGrid) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var poolName = ""
    @State private var selectedHomeTeam = Team.chiefs
    @State private var selectedAwayTeam = Team.eagles

    var body: some View {
        NavigationStack {
            Form {
                Section("Pool Name") {
                    TextField("Enter pool name", text: $poolName)
                }

                Section("Home Team (Columns)") {
                    Picker("Home Team", selection: $selectedHomeTeam) {
                        ForEach(Team.allTeams, id: \.id) { team in
                            Text(team.name).tag(team)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section("Away Team (Rows)") {
                    Picker("Away Team", selection: $selectedAwayTeam) {
                        ForEach(Team.allTeams, id: \.id) { team in
                            Text(team.name).tag(team)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            Circle()
                                .fill(Color(hex: selectedAwayTeam.primaryColor) ?? .red)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Text(selectedAwayTeam.abbreviation)
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                )

                            Text("vs")
                                .foregroundColor(.secondary)

                            Circle()
                                .fill(Color(hex: selectedHomeTeam.primaryColor) ?? .blue)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Text(selectedHomeTeam.abbreviation)
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                )

                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("New Pool")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let newPool = BoxGrid(
                            name: poolName.isEmpty ? "Pool \(Date().formatted(date: .abbreviated, time: .omitted))" : poolName,
                            homeTeam: selectedHomeTeam,
                            awayTeam: selectedAwayTeam
                        )
                        onSave(newPool)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    PoolsListView()
        .environmentObject(AppState())
}

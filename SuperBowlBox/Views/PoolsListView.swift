import SwiftUI

struct PoolsListView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingNewPoolSheet = false
    @State private var showingScanner = false
    @State private var poolToDelete: BoxGrid?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                if appState.pools.isEmpty {
                    EmptyPoolsView(
                        onCreateNew: { showingNewPoolSheet = true },
                        onScan: { showingScanner = true }
                    )
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            ForEach(appState.pools) { pool in
                                NavigationLink {
                                    GridDetailView(pool: binding(for: pool))
                                } label: {
                                    PoolCardView(pool: pool, score: appState.scoreService.currentScore)
                                }
                                .buttonStyle(ScaleButtonStyle())
                                .contextMenu {
                                    Button(role: .destructive) {
                                        poolToDelete = pool
                                        showingDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 120)
                    }
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("My Pools")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            Haptics.selection()
                            showingNewPoolSheet = true
                        } label: {
                            Label("Create New Pool", systemImage: "plus.square")
                        }

                        Button {
                            Haptics.selection()
                            showingScanner = true
                        } label: {
                            Label("Scan Pool Sheet", systemImage: "camera.viewfinder")
                        }
                    } label: {
                        Image(systemName: "plus.app.fill")
                            .font(.system(size: 24))
                            .foregroundColor(DesignSystem.Colors.accent)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .toolbarBackground(DesignSystem.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
                        Haptics.impact(.medium)
                        appState.removePool(at: index)
                    }
                }
            } message: {
                if let pool = poolToDelete {
                    Text("Are you sure you want to delete '\(pool.name)'? This cannot be undone.")
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    func binding(for pool: BoxGrid) -> Binding<BoxGrid> {
        guard let index = appState.pools.firstIndex(where: { $0.id == pool.id }) else {
            return .constant(pool)
        }
        return $appState.pools[index]
    }
}

// MARK: - Pool Card View
struct PoolCardView: View {
    let pool: BoxGrid
    let score: GameScore?

    var winner: BoxSquare? {
        guard let score = score else { return nil }
        return pool.winningSquare(for: score)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Mini grid preview with glow
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(DesignSystem.Colors.surfaceElevated)
                    .frame(width: 72, height: 72)

                MiniGridPreview(pool: pool, score: score)
                    .frame(width: 60, height: 60)
            }
            .shadow(color: winner != nil ? DesignSystem.Colors.liveGlow : .clear, radius: 8)

            VStack(alignment: .leading, spacing: 6) {
                Text(pool.name)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                HStack(spacing: 8) {
                    TeamBadge(team: pool.awayTeam, size: 22)
                    Text("vs")
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundColor(DesignSystem.Colors.textMuted)
                    TeamBadge(team: pool.homeTeam, size: 22)
                }

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "tablecells")
                            .font(.system(size: 10))
                        Text("\(pool.filledCount)/100")
                    }
                    .font(DesignSystem.Typography.captionSmall)
                    .foregroundColor(DesignSystem.Colors.textTertiary)

                    if let winner = winner {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 10))
                            Text(winner.displayName)
                        }
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundColor(DesignSystem.Colors.gold)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.textMuted)
        }
        .padding(16)
        .glassCard()
    }
}

struct TeamBadge: View {
    let team: Team
    let size: CGFloat

    var teamColor: Color {
        Color(hex: team.primaryColor) ?? DesignSystem.Colors.accent
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(teamColor.gradient)
                .frame(width: size, height: size)

            Text(team.abbreviation)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundColor(.white)
        }
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
        .cornerRadius(4)
    }

    func cellColor(square: BoxSquare, isWinning: Bool) -> Color {
        if isWinning {
            return DesignSystem.Colors.live
        } else if square.isWinner {
            return DesignSystem.Colors.gold
        } else if !square.isEmpty {
            return DesignSystem.Colors.accent.opacity(0.5)
        }
        return DesignSystem.Colors.surface
    }
}

// MARK: - Empty Pools View
struct EmptyPoolsView: View {
    let onCreateNew: () -> Void
    let onScan: () -> Void
    @State private var iconPulse = false

    var body: some View {
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.accent.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(iconPulse ? 1.1 : 1.0)

                Image(systemName: "rectangle.split.3x3")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignSystem.Colors.accent, DesignSystem.Colors.accent.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    iconPulse = true
                }
            }

            VStack(spacing: 12) {
                Text("No Pools Yet")
                    .font(DesignSystem.Typography.title)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("Create a new pool or scan an existing sheet to get started")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                Button {
                    Haptics.impact(.medium)
                    onCreateNew()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.square.fill")
                            .font(.system(size: 18))
                        Text("Create New Pool")
                            .font(DesignSystem.Typography.bodyMedium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [DesignSystem.Colors.accent, DesignSystem.Colors.accent.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: DesignSystem.Colors.accentGlow, radius: 12, y: 4)
                }

                Button {
                    Haptics.impact(.light)
                    onScan()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 18))
                        Text("Scan Pool Sheet")
                            .font(DesignSystem.Typography.bodyMedium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(DesignSystem.Colors.surfaceElevated)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(DesignSystem.Colors.glassBorder, lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }
}

// MARK: - New Pool Sheet
struct NewPoolSheet: View {
    let onSave: (BoxGrid) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var poolName = ""
    @State private var selectedHomeTeam = Team.chiefs
    @State private var selectedAwayTeam = Team.eagles

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Pool Name
                        VStack(alignment: .leading, spacing: 12) {
                            Text("POOL NAME")
                                .font(DesignSystem.Typography.captionSmall)
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                                .tracking(1)

                            TextField("Enter pool name", text: $poolName)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .padding()
                                .background(DesignSystem.Colors.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(DesignSystem.Colors.glassBorder, lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, 20)

                        // Team Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("HOME TEAM (COLUMNS)")
                                .font(DesignSystem.Typography.captionSmall)
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                                .tracking(1)

                            TeamPickerButton(
                                selectedTeam: $selectedHomeTeam,
                                label: "Home Team"
                            )
                        }
                        .padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("AWAY TEAM (ROWS)")
                                .font(DesignSystem.Typography.captionSmall)
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                                .tracking(1)

                            TeamPickerButton(
                                selectedTeam: $selectedAwayTeam,
                                label: "Away Team"
                            )
                        }
                        .padding(.horizontal, 20)

                        // Preview
                        VStack(alignment: .leading, spacing: 12) {
                            Text("MATCHUP PREVIEW")
                                .font(DesignSystem.Typography.captionSmall)
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                                .tracking(1)

                            HStack(spacing: 20) {
                                TeamPreviewCard(team: selectedAwayTeam, role: "Away")

                                Text("VS")
                                    .font(DesignSystem.Typography.captionSmall)
                                    .foregroundColor(DesignSystem.Colors.textMuted)

                                TeamPreviewCard(team: selectedHomeTeam, role: "Home")
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity)
                            .glassCard()
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle("New Pool")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DesignSystem.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Haptics.impact(.medium)
                        let newPool = BoxGrid(
                            name: poolName.isEmpty ? "Pool \(Date().formatted(date: .abbreviated, time: .omitted))" : poolName,
                            homeTeam: selectedHomeTeam,
                            awayTeam: selectedAwayTeam
                        )
                        onSave(newPool)
                    }
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct TeamPickerButton: View {
    @Binding var selectedTeam: Team
    let label: String
    @State private var showingPicker = false

    var teamColor: Color {
        Color(hex: selectedTeam.primaryColor) ?? DesignSystem.Colors.accent
    }

    var body: some View {
        Button {
            Haptics.selection()
            showingPicker = true
        } label: {
            HStack {
                ZStack {
                    Circle()
                        .fill(teamColor.gradient)
                        .frame(width: 40, height: 40)

                    Text(selectedTeam.abbreviation)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedTeam.name)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text(selectedTeam.city)
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textMuted)
            }
            .padding()
            .background(DesignSystem.Colors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(DesignSystem.Colors.glassBorder, lineWidth: 1)
            )
        }
        .sheet(isPresented: $showingPicker) {
            TeamPickerSheet(selectedTeam: $selectedTeam)
        }
    }
}

struct TeamPickerSheet: View {
    @Binding var selectedTeam: Team
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Team.allTeams, id: \.id) { team in
                            TeamSelectionRow(
                                team: team,
                                isSelected: team.id == selectedTeam.id
                            ) {
                                Haptics.selection()
                                selectedTeam = team
                                dismiss()
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Select Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DesignSystem.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct TeamSelectionRow: View {
    let team: Team
    let isSelected: Bool
    let onTap: () -> Void

    var teamColor: Color {
        Color(hex: team.primaryColor) ?? DesignSystem.Colors.accent
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(teamColor.gradient)
                        .frame(width: 44, height: 44)

                    Text(team.abbreviation)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(team.name)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text(team.city)
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(DesignSystem.Colors.accent)
                }
            }
            .padding(12)
            .background(
                isSelected ? DesignSystem.Colors.accent.opacity(0.15) : DesignSystem.Colors.surfaceElevated
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? DesignSystem.Colors.accent.opacity(0.3) : DesignSystem.Colors.glassBorder, lineWidth: 1)
            )
        }
    }
}

struct TeamPreviewCard: View {
    let team: Team
    let role: String

    var teamColor: Color {
        Color(hex: team.primaryColor) ?? DesignSystem.Colors.accent
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(teamColor.gradient)
                    .frame(width: 48, height: 48)

                Text(team.abbreviation)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            .shadow(color: teamColor.opacity(0.4), radius: 8, y: 2)

            Text(team.name)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text(role)
                .font(DesignSystem.Typography.captionSmall)
                .foregroundColor(DesignSystem.Colors.textMuted)
        }
    }
}

// MARK: - Scale Button Style (if not already defined)
extension PoolsListView {
    struct ScaleButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
        }
    }
}

#Preview {
    PoolsListView()
        .environmentObject(AppState())
}

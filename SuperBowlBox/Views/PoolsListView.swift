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
                // Animated Background
                AnimatedMeshBackground()
                TechGridBackground()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("POOLS")
                                .font(.system(size: 28, weight: .black, design: .monospaced))
                                .foregroundStyle(DesignSystem.Colors.cyberGradient)

                            Text("ACTIVE GAMES")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(DesignSystem.Colors.textMuted)
                                .tracking(2)
                        }

                        Spacer()

                        // Add button
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
                                Label("Scan Pool Sheet", systemImage: "text.viewfinder")
                            }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(DesignSystem.Colors.cyberGradient)
                                    .frame(width: 44, height: 44)

                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .shadow(color: DesignSystem.Colors.accentGlow, radius: 10)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    .padding(.bottom, 24)

                    if appState.pools.isEmpty {
                        Spacer()
                        EmptyPoolsMatrix(
                            onCreateNew: { showingNewPoolSheet = true },
                            onScan: { showingScanner = true }
                        )
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 16) {
                                ForEach(appState.pools) { pool in
                                    NavigationLink {
                                        GridDetailView(pool: binding(for: pool))
                                    } label: {
                                        PoolMatrixCard(pool: pool, score: appState.scoreService.currentScore)
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
                            .padding(.bottom, 140)
                        }
                    }
                }
            }
            .preferredColorScheme(.dark)
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
    }

    func binding(for pool: BoxGrid) -> Binding<BoxGrid> {
        guard let index = appState.pools.firstIndex(where: { $0.id == pool.id }) else {
            return .constant(pool)
        }
        return $appState.pools[index]
    }
}

// MARK: - Pool Matrix Card
struct PoolMatrixCard: View {
    let pool: BoxGrid
    let score: GameScore?
    @State private var hoverScale: CGFloat = 1.0

    var winner: BoxSquare? {
        guard let score = score else { return nil }
        return pool.winningSquare(for: score)
    }

    var winningPosition: (row: Int, column: Int)? {
        guard let score = score else { return nil }
        return pool.winningPosition(homeDigit: score.homeLastDigit, awayDigit: score.awayLastDigit)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Mini matrix preview
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(DesignSystem.Colors.surface)
                    .frame(width: 80, height: 80)

                // 10x10 mini grid
                VStack(spacing: 0.5) {
                    ForEach(0..<10, id: \.self) { row in
                        HStack(spacing: 0.5) {
                            ForEach(0..<10, id: \.self) { col in
                                let square = pool.squares[row][col]
                                let isWinning = winningPosition?.row == row && winningPosition?.column == col

                                Rectangle()
                                    .fill(cellColor(square: square, isWinning: isWinning))
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))

                // Glow overlay for winner
                if winner != nil {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(DesignSystem.Colors.live, lineWidth: 2)
                        .shadow(color: DesignSystem.Colors.liveGlow, radius: 8)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                // Pool name
                Text(pool.name.uppercased())
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .tracking(1)

                // Teams
                HStack(spacing: 8) {
                    TeamMicroBadge(team: pool.awayTeam)
                    Text("vs")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.textMuted)
                    TeamMicroBadge(team: pool.homeTeam)
                }

                // Stats row
                HStack(spacing: 16) {
                    // Fill progress
                    HStack(spacing: 6) {
                        // Mini progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(DesignSystem.Colors.surface)
                                    .frame(height: 4)

                                RoundedRectangle(cornerRadius: 2)
                                    .fill(DesignSystem.Colors.accent)
                                    .frame(width: geo.size.width * CGFloat(pool.filledCount) / 100, height: 4)
                            }
                        }
                        .frame(width: 40, height: 4)

                        Text("\(pool.filledCount)/100")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }

                    // Current winner
                    if let winner = winner {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 10))
                                .foregroundColor(DesignSystem.Colors.gold)

                            Text(winner.displayName.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(DesignSystem.Colors.gold)
                                .lineLimit(1)
                        }
                    }
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(DesignSystem.Colors.textMuted)
        }
        .padding(16)
        .neonCard(
            winner != nil ? DesignSystem.Colors.live : DesignSystem.Colors.accent,
            intensity: winner != nil ? 0.25 : 0.15
        )
    }

    func cellColor(square: BoxSquare, isWinning: Bool) -> Color {
        if isWinning { return DesignSystem.Colors.live }
        if square.isWinner { return DesignSystem.Colors.gold }
        if !square.isEmpty { return DesignSystem.Colors.accent.opacity(0.5) }
        return DesignSystem.Colors.surfaceElevated
    }
}

struct TeamMicroBadge: View {
    let team: Team

    var teamColor: Color {
        Color(hex: team.primaryColor) ?? DesignSystem.Colors.accent
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(teamColor.gradient)
                .frame(width: 22, height: 22)

            Text(team.abbreviation)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Empty Pools Matrix
struct EmptyPoolsMatrix: View {
    let onCreateNew: () -> Void
    let onScan: () -> Void
    @State private var gridPulse = false
    @State private var scanLine: CGFloat = 0

    var body: some View {
        VStack(spacing: 32) {
            // Animated matrix grid
            ZStack {
                // Background grid
                VStack(spacing: 2) {
                    ForEach(0..<8, id: \.self) { row in
                        HStack(spacing: 2) {
                            ForEach(0..<8, id: \.self) { col in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(DesignSystem.Colors.surface)
                                    .frame(width: 12, height: 12)
                                    .opacity(gridPulse ? 0.3 : 0.6)
                            }
                        }
                    }
                }

                // Scanning line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, DesignSystem.Colors.accent, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 100, height: 3)
                    .offset(y: scanLine * 60 - 30)
                    .blur(radius: 2)

                // Center icon
                Image(systemName: "cube.transparent.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(DesignSystem.Colors.cyberGradient)
                    .scaleEffect(gridPulse ? 1.05 : 1.0)
            }
            .frame(width: 120, height: 120)
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    gridPulse = true
                }
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    scanLine = 1
                }
            }

            VStack(spacing: 12) {
                Text("NO ACTIVE POOLS")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .tracking(3)

                Text("Create a new pool or scan an\nexisting sheet to begin tracking")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button {
                    Haptics.impact(.medium)
                    onCreateNew()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.square.fill")
                            .font(.system(size: 18))
                        Text("CREATE POOL")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .tracking(2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(DesignSystem.Colors.cyberGradient)
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
                        Text("SCAN SHEET")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .tracking(2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(DesignSystem.Colors.surface)
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
        .padding(40)
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
                AnimatedMeshBackground()
                TechGridBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        // Pool Name
                        VStack(alignment: .leading, spacing: 12) {
                            Text("POOL IDENTIFIER")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(DesignSystem.Colors.textMuted)
                                .tracking(2)

                            TextField("Enter pool name", text: $poolName)
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .padding(16)
                                .background(DesignSystem.Colors.surface)
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
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(DesignSystem.Colors.textMuted)
                                .tracking(2)

                            TeamSelectorButton(
                                selectedTeam: $selectedHomeTeam,
                                label: "Home Team"
                            )
                        }
                        .padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("AWAY TEAM (ROWS)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(DesignSystem.Colors.textMuted)
                                .tracking(2)

                            TeamSelectorButton(
                                selectedTeam: $selectedAwayTeam,
                                label: "Away Team"
                            )
                        }
                        .padding(.horizontal, 20)

                        // Preview
                        VStack(alignment: .leading, spacing: 12) {
                            Text("MATCHUP PREVIEW")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(DesignSystem.Colors.textMuted)
                                .tracking(2)

                            HStack(spacing: 20) {
                                TeamPreviewUnit(team: selectedAwayTeam, role: "AWAY")
                                Text("VS")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(DesignSystem.Colors.textMuted)
                                TeamPreviewUnit(team: selectedHomeTeam, role: "HOME")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(24)
                            .neonCard(DesignSystem.Colors.accent, intensity: 0.15)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle("New Pool")
            .navigationBarTitleDisplayMode(.inline)
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
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(DesignSystem.Colors.cyberGradient)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct TeamSelectorButton: View {
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
                        .frame(width: 44, height: 44)

                    Text(selectedTeam.abbreviation)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                .shadow(color: teamColor.opacity(0.4), radius: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedTeam.name.uppercased())
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text(selectedTeam.city.uppercased())
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textMuted)
            }
            .padding(16)
            .background(DesignSystem.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(DesignSystem.Colors.glassBorder, lineWidth: 1)
            )
        }
        .sheet(isPresented: $showingPicker) {
            TeamPickerMatrix(selectedTeam: $selectedTeam)
        }
    }
}

struct TeamPickerMatrix: View {
    @Binding var selectedTeam: Team
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedMeshBackground()
                TechGridBackground()

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
                    Text(team.name.uppercased())
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text(team.city.uppercased())
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(DesignSystem.Colors.cyberGradient)
                }
            }
            .padding(12)
            .background(
                isSelected ? DesignSystem.Colors.accent.opacity(0.15) : DesignSystem.Colors.surface
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? DesignSystem.Colors.accent.opacity(0.3) : DesignSystem.Colors.glassBorder, lineWidth: 1)
            )
        }
    }
}

struct TeamPreviewUnit: View {
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
                    .frame(width: 52, height: 52)

                Text(team.abbreviation)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            .shadow(color: teamColor.opacity(0.4), radius: 10, y: 2)

            Text(team.name.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text(role)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(DesignSystem.Colors.textMuted)
        }
    }
}

#Preview {
    PoolsListView()
        .environmentObject(AppState())
}

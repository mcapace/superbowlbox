import SwiftUI

struct GridDetailView: View {
    @Binding var pool: BoxGrid
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSquare: BoxSquare?
    @State private var showingEditSheet = false
    @State private var showingEditRulesSheet = false
    @State private var showingEditMatchupSheet = false
    @State private var zoomScale: CGFloat = 1.0
    @State private var showingShareSheet = false
    @State private var showingDeletePoolConfirmation = false
    @State private var showingPayoutRulesModal = false
    @State private var lastZoomScale: CGFloat = 1.0

    var score: GameScore? {
        appState.scoreService.currentScore
    }

    /// Winning square from live score (API). Correct when this pool's teams match the featured game.
    var winningPosition: (row: Int, column: Int)? {
        guard let score = score else { return nil }
        return pool.winningPosition(homeDigit: score.homeLastDigit, awayDigit: score.awayLastDigit)
    }

    /// Cell size so grid fits on screen (1 corner + 10 cells); clamped for readability.
    private static let minCellSize: CGFloat = 26
    private static let maxCellSize: CGFloat = 44
    private static let minZoom: CGFloat = 0.5
    private static let maxZoom: CGFloat = 3.0

    var body: some View {
        GeometryReader { outer in
            let availableWidth = outer.size.width - 2 * DesignSystem.Layout.screenInset
            let fitCellSize = min(Self.maxCellSize, max(Self.minCellSize, availableWidth / 11))
            let cellSize = fitCellSize * zoomScale

            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                VStack(spacing: 0) {
                    // Pool type line — tap to view payout rules
                    Button {
                        HapticService.impactLight()
                        showingPayoutRulesModal = true
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label(pool.resolvedPoolStructure.poolTypeLabel, systemImage: "calendar.badge.clock")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.liveGreen)
                                Spacer()
                                Text("View payout rules")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                            }
                            if let score = score, let info = pool.scoreChangeInfo(for: score) {
                                let formatter: NumberFormatter = {
                                    let f = NumberFormatter()
                                    f.numberStyle = .currency
                                    f.currencyCode = pool.resolvedPoolStructure.currencyCode
                                    f.maximumFractionDigits = 0
                                    return f
                                }()
                                let paidStr = formatter.string(from: NSNumber(value: info.paid)) ?? "$\(Int(info.paid))"
                                let remStr = formatter.string(from: NSNumber(value: info.remainder)) ?? "$\(Int(info.remainder))"
                                Text("\(info.count) score changes · \(paidStr) paid · \(remStr) to final")
                                    .font(.system(size: 11))
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: DesignSystem.Layout.glassCornerRadius)
                                .fill(.ultraThinMaterial)
                            RoundedRectangle(cornerRadius: DesignSystem.Layout.glassCornerRadius)
                                .fill(DesignSystem.Colors.backgroundTertiary.opacity(0.6))
                            RoundedRectangle(cornerRadius: DesignSystem.Layout.glassCornerRadius)
                                .strokeBorder(DesignSystem.Colors.glassBorder, lineWidth: 0.8)
                        }
                    )
                    .glassDepthShadows()
                    .padding(.horizontal)
                    .padding(.bottom, 10)

                    // Grid: corner = matchup (Away = rows, Home = cols) — logos prominent with depth
                    HStack(spacing: 0) {
                        let logoSize = max(26, min(cellSize * 0.58, 36))
                        VStack(spacing: 0) {
                            GridCornerTeamBadge(team: pool.awayTeam, axisLabel: "Rows", logoSize: logoSize)
                            Rectangle()
                                .fill(DesignSystem.Colors.glassBorder)
                                .frame(height: 0.8)
                            GridCornerTeamBadge(team: pool.homeTeam, axisLabel: "Cols", logoSize: logoSize)
                        }
                        .frame(width: cellSize, height: cellSize)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(.ultraThinMaterial)
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(DesignSystem.Colors.backgroundTertiary.opacity(0.7))
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(DesignSystem.Colors.glassBorder, lineWidth: 0.8)
                            }
                        )
                        .glassDepthShadows()

                        ForEach(0..<10, id: \.self) { col in
                            let isWinningCol = winningPosition?.column == col
                            Text("\(pool.homeNumbers[col])")
                                .font(.system(size: cellSize * 0.38, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(.white)
                                .frame(width: cellSize, height: cellSize)
                                .background(
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isWinningCol ? DesignSystem.Colors.liveGreen : (Color(hex: pool.homeTeam.primaryColor) ?? .blue).opacity(0.9))
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(.ultraThinMaterial.opacity(0.25))
                                        RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                                    }
                                )
                                .shadow(color: Color.black.opacity(0.35), radius: 1, x: 0, y: 1)
                                .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                        }
                    }

                    ForEach(0..<10, id: \.self) { row in
                        HStack(spacing: 0) {
                            let isWinningRow = winningPosition?.row == row
                            Text("\(pool.awayNumbers[row])")
                                .font(.system(size: cellSize * 0.38, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(.white)
                                .frame(width: cellSize, height: cellSize)
                                .background(
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isWinningRow ? DesignSystem.Colors.liveGreen : (Color(hex: pool.awayTeam.primaryColor) ?? .red).opacity(0.9))
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(.ultraThinMaterial.opacity(0.25))
                                        RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                                    }
                                )
                                .shadow(color: Color.black.opacity(0.35), radius: 1, x: 0, y: 1)
                                .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)

                            ForEach(0..<10, id: \.self) { col in
                                let square = pool.squares[row][col]
                                let isWinning = winningPosition?.row == row && winningPosition?.column == col
                                let ownerLabels = pool.effectiveOwnerLabels(globalName: appState.myName)
                                let isHighlighted = !ownerLabels.isEmpty && pool.isOwnerSquare(square, ownerLabels: ownerLabels)

                                FullGridCellView(
                                    square: square,
                                    isWinning: isWinning,
                                    isHighlighted: isHighlighted,
                                    size: cellSize
                                )
                                .onTapGesture {
                                    HapticService.impactLight()
                                    selectedSquare = square
                                    showingEditSheet = true
                                }
                            }
                        }
                    }
                }
                .padding()
                .contentShape(Rectangle())
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let proposed = lastZoomScale * value
                            zoomScale = min(Self.maxZoom, max(Self.minZoom, proposed))
                        }
                        .onEnded { _ in
                            lastZoomScale = zoomScale
                        }
                )
            }
        }
        .padding(.horizontal, 0)
        .navigationTitle(pool.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if !pool.isLocked {
                        Button {
                            showingEditRulesSheet = true
                        } label: {
                            Label("Edit payout rules", systemImage: "list.bullet.rectangle")
                        }

                        Button {
                            showingEditMatchupSheet = true
                        } label: {
                            Label("Edit matchup (teams)", systemImage: "sportscourt")
                        }

                        Button {
                            pool.randomizeNumbers()
                            appState.updatePool(pool)
                        } label: {
                            Label("Randomize Numbers", systemImage: "shuffle")
                        }

                        Button(role: .destructive) {
                            pool = BoxGrid(
                                name: pool.name,
                                homeTeam: pool.homeTeam,
                                awayTeam: pool.awayTeam,
                                poolStructure: pool.resolvedPoolStructure,
                                isLocked: pool.isLocked,
                                isOwner: pool.isOwner
                            )
                            appState.updatePool(pool)
                        } label: {
                            Label("Clear All Names", systemImage: "trash")
                        }

                        Divider()
                    }

                    Button {
                        showingShareSheet = true
                    } label: {
                        Label("Share Grid", systemImage: "square.and.arrow.up")
                    }

                    Divider()

                    Button(role: .destructive) {
                        showingDeletePoolConfirmation = true
                    } label: {
                        Label(pool.isOwner ? "Delete pool" : "Remove from my list", systemImage: "trash.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }

            ToolbarItem(placement: .bottomBar) {
                HStack {
                    // Zoom controls
                    Button {
                        HapticService.impactLight()
                        withAnimation(.appSpring) {
                            zoomScale = max(0.5, zoomScale - 0.25)
                        }
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }

                    Text("\(Int(zoomScale * 100))%")
                        .font(.caption)
                        .frame(width: 50)

                    Button {
                        HapticService.impactLight()
                        withAnimation(.appSpring) {
                            zoomScale = min(2.0, zoomScale + 0.25)
                        }
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }

                    Spacer()

                    if let score = score {
                        HStack(spacing: 4) {
                            Text("Winner:")
                                .font(.system(size: 12))
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                            Text("\(score.awayLastDigit)–\(score.homeLastDigit)")
                                .font(.system(size: 15, weight: .bold))
                                .monospacedDigit()
                                .foregroundColor(DesignSystem.Colors.liveGreen)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            if let square = selectedSquare {
                SquareEditSheet(
                    pool: $pool,
                    square: square,
                    onSave: { newName in
                        pool.updateSquare(row: square.row, column: square.column, playerName: newName)
                        appState.updatePool(pool)
                        showingEditSheet = false
                    }
                )
                .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showingEditRulesSheet) {
            EditPoolRulesSheet(
                pool: $pool,
                onSave: {
                    appState.updatePool(pool)
                    showingEditRulesSheet = false
                },
                onCancel: { showingEditRulesSheet = false }
            )
            .environmentObject(appState)
        }
        .sheet(isPresented: $showingEditMatchupSheet) {
            EditMatchupSheet(
                pool: $pool,
                onSave: {
                    appState.updatePool(pool)
                    showingEditMatchupSheet = false
                },
                onCancel: { showingEditMatchupSheet = false }
            )
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [exportGridAsImage()])
        }
        .sheet(isPresented: $showingPayoutRulesModal) {
            PayoutRulesModalView(
                pool: pool,
                onDismiss: { showingPayoutRulesModal = false }
            )
        }
        .alert(pool.isOwner ? "Delete pool?" : "Remove from my list?", isPresented: $showingDeletePoolConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button(pool.isOwner ? "Delete" : "Remove", role: .destructive) {
                if let index = appState.pools.firstIndex(where: { $0.id == pool.id }) {
                    HapticService.impactHeavy()
                    appState.removePool(at: index)
                    dismiss()
                }
            }
        } message: {
            Text(pool.isOwner
                 ? "'\(pool.name)' will be removed from this device. It does not delete the pool from the system if it was shared."
                 : "'\(pool.name)' will be removed from your list only. The pool stays in the system for the host and others.")
        }
    }

    func exportGridAsImage() -> String {
        // Simple text export for now
        var text = "\(pool.name)\n"
        text += "\(pool.awayTeam.abbreviation) vs \(pool.homeTeam.abbreviation)\n\n"
        text += "     " + pool.homeNumbers.map { String($0) }.joined(separator: "  ") + "\n"
        text += "   " + String(repeating: "-", count: 40) + "\n"

        for (rowIndex, row) in pool.squares.enumerated() {
            text += " \(pool.awayNumbers[rowIndex]) | "
            text += row.map { $0.initials.isEmpty ? "__" : $0.initials }.joined(separator: " ")
            text += "\n"
        }

        return text
    }
}

// MARK: - Edit pool matchup (fix home/away teams when same team was saved twice)
struct EditMatchupSheet: View {
    @Binding var pool: BoxGrid
    let onSave: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedHomeTeam: Team
    @State private var selectedAwayTeam: Team

    init(pool: Binding<BoxGrid>, onSave: @escaping () -> Void, onCancel: @escaping () -> Void) {
        _pool = pool
        self.onSave = onSave
        self.onCancel = onCancel
        _selectedHomeTeam = State(initialValue: pool.wrappedValue.homeTeam)
        _selectedAwayTeam = State(initialValue: pool.wrappedValue.awayTeam)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Set the two teams for this pool. Rows = away team, columns = home team.")
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
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
                        Text("Pick two different teams.")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.dangerRed)
                    }
                }
                Section("Preview") {
                    HStack(spacing: 12) {
                        TeamLogoView(team: selectedAwayTeam, size: 36)
                        Text("vs")
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                        TeamLogoView(team: selectedHomeTeam, size: 36)
                        Spacer()
                        Text("\(selectedAwayTeam.abbreviation) vs \(selectedHomeTeam.abbreviation)")
                            .font(.subheadline)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }
            .navigationTitle("Edit matchup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        pool.homeTeam = selectedHomeTeam
                        pool.awayTeam = selectedAwayTeam
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedHomeTeam.id == selectedAwayTeam.id)
                }
            }
        }
    }
}

// MARK: - Grid corner team badge (logo-first with depth)
private struct GridCornerTeamBadge: View {
    let team: Team
    let axisLabel: String
    let logoSize: CGFloat

    var body: some View {
        VStack(spacing: 3) {
            // Logo as primary element with raised-badge look
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.cardShadow.opacity(0.35))
                    .frame(width: logoSize + 4, height: logoSize + 4)
                    .blur(radius: 2)
                    .offset(x: 0, y: 1)
                TeamLogoView(team: team, size: logoSize)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.5), Color.white.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                    )
            }
            Text(team.abbreviation)
                .font(.system(size: max(8, logoSize * 0.28), weight: .bold))
                .foregroundColor(DesignSystem.Colors.textPrimary)
            Text(axisLabel)
                .font(.system(size: max(6, logoSize * 0.2), weight: .medium))
                .foregroundColor(DesignSystem.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct FullGridCellView: View {
    let square: BoxSquare
    let isWinning: Bool
    let isHighlighted: Bool
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            // Base color + liquid glass layer + top highlight for 3D bevel
            RoundedRectangle(cornerRadius: 6)
                .fill(cellColor)
                .frame(width: size, height: size)
            RoundedRectangle(cornerRadius: 6)
                .fill(.ultraThinMaterial.opacity(glassOpacity))
                .frame(width: size, height: size)
            // Top-edge highlight for depth
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.35), Color.white.opacity(0.05), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
                .frame(width: size, height: size)

            VStack(spacing: 2) {
                if !square.isEmpty {
                    Text(square.initials)
                        .font(.system(size: size * 0.32, weight: .semibold))
                        .foregroundColor(textColor)
                        .shadow(color: Color.black.opacity(0.25), radius: 0.5, x: 0, y: 0.5)

                    Text(square.playerName.prefix(6))
                        .font(.system(size: size * 0.18))
                        .foregroundColor(textColor.opacity(0.9))
                        .lineLimit(1)
                }
            }

            if isWinning {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.white, lineWidth: 2)
                    .frame(width: size, height: size)
            }

            if square.isWinner && !square.quarterWins.isEmpty {
                VStack {
                    HStack {
                        Spacer()
                        ForEach(square.quarterWins, id: \.self) { q in
                            Text("Q\(q)")
                                .font(.system(size: size * 0.14, weight: .bold))
                                .foregroundColor(.white)
                                .padding(2)
                                .background(DesignSystem.Colors.winnerGold)
                                .cornerRadius(2)
                        }
                    }
                    Spacer()
                }
                .frame(width: size, height: size)
                .padding(2)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isWinning ? Color.white.opacity(0.6) : DesignSystem.Colors.glassBorder, lineWidth: isWinning ? 1 : 0.6)
        )
        .glassDepthShadows()
    }

    private var glassOpacity: Double {
        if isWinning { return 0.15 }
        if isHighlighted { return 0.2 }
        return 0.3
    }

    var cellColor: Color {
        if isWinning {
            return DesignSystem.Colors.liveGreen
        } else if isHighlighted {
            return DesignSystem.Colors.winnerGold.opacity(0.7)
        } else if square.isWinner {
            return DesignSystem.Colors.winnerGold.opacity(0.45)
        } else if !square.isEmpty {
            return DesignSystem.Colors.accentBlue.opacity(0.4)
        } else {
            return DesignSystem.Colors.backgroundTertiary.opacity(0.9)
        }
    }

    var textColor: Color {
        if isWinning || isHighlighted { return .white }
        return DesignSystem.Colors.textPrimary
    }
}

struct SquareEditSheet: View {
    @Binding var pool: BoxGrid
    let square: BoxSquare
    let onSave: (String) -> Void
    @State private var playerName: String = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Square Info
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Row Number")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            Text("\(pool.awayNumbers[square.row])")
                                .font(.title)
                                .fontWeight(.bold)
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("Column Number")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            Text("\(pool.homeNumbers[square.column])")
                                .font(.title)
                                .fontWeight(.bold)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(DesignSystem.Colors.surfaceElevated)
                    )

                    Text("Position: (\(square.row), \(square.column))")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                // Name Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Player Name")
                        .font(.headline)

                    TextField("Enter name", text: $playerName)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                        .autocorrectionDisabled()
                }

                // Quick select from existing names
                if !pool.allPlayers.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick Select")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(pool.allPlayers.prefix(10), id: \.self) { name in
                                    Button {
                                        playerName = name
                                    } label: {
                                        Text(name)
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(playerName == name ? AppColors.fieldGreen : DesignSystem.Colors.surfaceElevated)
                                            )
                                            .foregroundColor(playerName == name ? .white : DesignSystem.Colors.textPrimary)
                                    }
                                }
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Edit Square")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(playerName)
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                playerName = square.playerName
            }
        }
    }
}

// MARK: - Edit pool payout rules (after import)
struct EditPoolRulesSheet: View {
    @Binding var pool: BoxGrid
    let onSave: () -> Void
    let onCancel: () -> Void
    @EnvironmentObject var appState: AppState

    @State private var rulesText: String = ""
    @State private var payoutParseInProgress = false
    @State private var payoutParsedSummary: String?
    @State private var payoutParseError: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("How does this pool pay out? (e.g. $25 per quarter, halftime pays double)")
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                TextEditor(text: $rulesText)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(DesignSystem.Colors.surfaceElevated)
                    )
                    .overlay(
                        Group {
                            if rulesText.isEmpty {
                                Text("e.g. $25 per quarter, halftime pays double")
                                    .font(.body)
                                    .foregroundColor(DesignSystem.Colors.textSecondary.opacity(0.6))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 16)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                    .allowsHitTesting(false)
                            }
                        }
                    )

                if PayoutParseConfig.usePayoutParse && !rulesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        parsePayoutRulesWithAI()
                    } label: {
                        if payoutParseInProgress {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Parse with AI")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.fieldGreen)
                        }
                    }
                    .disabled(payoutParseInProgress)
                }

                if let summary = payoutParsedSummary {
                    Text(summary)
                        .font(.caption)
                        .foregroundColor(AppColors.fieldGreen)
                }
                if let error = payoutParseError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Payout rules")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveRulesAndDismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(payoutParseInProgress)
                }
            }
            .onAppear {
                rulesText = pool.resolvedPoolStructure.customPayoutDescription ?? ""
            }
        }
    }

    /// Save rules: AI (Lambda) powers logic when backend is configured. Grid, modal, and payouts use only the parsed structure from the API.
    private func saveRulesAndDismiss() {
        let text = rulesText.trimmingCharacters(in: .whitespacesAndNewlines)
        var ps = pool.poolStructure ?? PoolStructure.standardQuarterly
        ps.customPayoutDescription = text.isEmpty ? nil : text

        if !text.isEmpty && PayoutParseConfig.usePayoutParse {
            payoutParseError = nil
            payoutParseInProgress = true
            Task {
                do {
                    let parsed = try await PayoutParseService.parse(payoutDescription: text)
                    await MainActor.run {
                        var merged = parsed
                        merged.customPayoutDescription = text
                        pool.poolStructure = merged
                        payoutParseInProgress = false
                        onSave()
                    }
                } catch {
                    await MainActor.run {
                        pool.poolStructure = ps
                        payoutParseError = error.localizedDescription
                        payoutParseInProgress = false
                        onSave()
                    }
                }
            }
        } else {
            payoutParseError = nil
            pool.poolStructure = ps
            onSave()
        }
    }

    /// Parse with AI only (no local fallback). Grid and modal use this structure.
    private func parsePayoutRulesWithAI() {
        let text = rulesText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        payoutParseError = nil
        payoutParsedSummary = nil
        payoutParseInProgress = true
        Task {
            do {
                let parsed = try await PayoutParseService.parse(payoutDescription: text)
                await MainActor.run {
                    var merged = parsed
                    merged.customPayoutDescription = text
                    pool.poolStructure = merged
                    payoutParsedSummary = "Parsed: \(merged.periodLabels.joined(separator: ", "))" + (merged.payoutDescriptions.isEmpty ? "" : " · \(merged.payoutDescriptions.joined(separator: ", "))")
                    payoutParseInProgress = false
                }
            } catch {
                await MainActor.run {
                    payoutParseError = error.localizedDescription
                    payoutParsedSummary = nil
                    payoutParseInProgress = false
                }
            }
        }
    }
}

// MARK: - Payout rules modal (parsed, professional summary when user taps "View payout rules")
struct PayoutRulesModalView: View {
    let pool: BoxGrid
    let onDismiss: () -> Void

    private var structure: PoolStructure { pool.structureForPayoutModal }

    /// Main copy: AI-readable summary when available, otherwise formatted structure summary.
    private var primaryRulesText: String {
        if let ai = structure.readableRulesSummary, !ai.isEmpty {
            return ai
        }
        return structure.professionalPayoutSummary
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(primaryRulesText)
                        .font(.body)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    if let raw = structure.customPayoutDescription, !raw.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("As you entered")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            Text(raw)
                                .font(.subheadline)
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                                .italic()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 20)
            }
            .background(DesignSystem.Colors.backgroundPrimary)
            .navigationTitle("Payout rules")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        HapticService.impactLight()
                        onDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        GridDetailView(pool: .constant(BoxGrid.empty))
            .environmentObject(AppState())
    }
}

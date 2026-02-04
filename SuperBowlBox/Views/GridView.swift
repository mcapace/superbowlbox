import SwiftUI

struct GridDetailView: View {
    @Binding var pool: BoxGrid
    @EnvironmentObject var appState: AppState
    @State private var selectedSquare: BoxSquare?
    @State private var showingEditSheet = false
    @State private var zoomScale: CGFloat = 1.0
    @State private var showingShareSheet = false

    var score: GameScore? {
        appState.scoreService.currentScore
    }

    var winningPosition: (row: Int, column: Int)? {
        guard let score = score else { return nil }
        return pool.winningPosition(homeDigit: score.homeLastDigit, awayDigit: score.awayLastDigit)
    }

    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            VStack(spacing: 0) {
                // Pool structure & payouts summary
                HStack {
                    Label(pool.resolvedPoolStructure.periodLabels.joined(separator: " · "), systemImage: "calendar.badge.clock")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.fieldGreen)
                    Spacer()
                    if !pool.resolvedPoolStructure.payoutDescriptions.isEmpty {
                        Text(pool.resolvedPoolStructure.payoutDescriptions.joined(separator: "  "))
                            .font(AppTypography.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6).opacity(0.6))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.bottom, 8)

                // Team header for columns (Home team)
                HStack(spacing: 0) {
                    // Corner cell with team info
                    VStack(spacing: 2) {
                        Text(pool.awayTeam.abbreviation)
                            .font(.caption2)
                            .fontWeight(.bold)
                        Rectangle()
                            .fill(Color.secondary)
                            .frame(height: 1)
                            .rotationEffect(.degrees(-45))
                        Text(pool.homeTeam.abbreviation)
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .frame(width: 44, height: 44)
                    .background(Color(.systemGray4))

                    // Column numbers (home team)
                    ForEach(0..<10, id: \.self) { col in
                        let isWinningCol = winningPosition?.column == col
                        Text("\(pool.homeNumbers[col])")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .frame(width: 44, height: 44)
                            .background(
                                isWinningCol ?
                                    AppColors.fieldGreen :
                                    (Color(hex: pool.homeTeam.primaryColor) ?? .blue)
                            )
                            .foregroundColor(.white)
                    }
                }

                // Grid rows
                ForEach(0..<10, id: \.self) { row in
                    HStack(spacing: 0) {
                        // Row number (away team)
                        let isWinningRow = winningPosition?.row == row
                        Text("\(pool.awayNumbers[row])")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .frame(width: 44, height: 44)
                            .background(
                                isWinningRow ?
                                    AppColors.fieldGreen :
                                    (Color(hex: pool.awayTeam.primaryColor) ?? .red)
                            )
                            .foregroundColor(.white)

                        // Grid cells
                        ForEach(0..<10, id: \.self) { col in
                            let square = pool.squares[row][col]
                            let isWinning = winningPosition?.row == row && winningPosition?.column == col
                            let ownerLabels = pool.effectiveOwnerLabels(globalName: appState.myName)
                            let isHighlighted = !ownerLabels.isEmpty && pool.isOwnerSquare(square, ownerLabels: ownerLabels)

                            FullGridCellView(
                                square: square,
                                isWinning: isWinning,
                                isHighlighted: isHighlighted
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
            .scaleEffect(zoomScale)
        }
        .navigationTitle(pool.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingShareSheet = true
                    } label: {
                        Label("Share Grid", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        pool.randomizeNumbers()
                        appState.updatePool(pool)
                    } label: {
                        Label("Randomize Numbers", systemImage: "shuffle")
                    }

                    Divider()

                    Button(role: .destructive) {
                        pool = BoxGrid(
                            name: pool.name,
                            homeTeam: pool.homeTeam,
                            awayTeam: pool.awayTeam,
                            poolStructure: pool.resolvedPoolStructure
                        )
                        appState.updatePool(pool)
                    } label: {
                        Label("Clear All Names", systemImage: "trash")
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

                    // Current score indicator
                    if let score = score {
                        HStack(spacing: 4) {
                            Text("Winner:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(score.awayLastDigit)-\(score.homeLastDigit)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.fieldGreen)
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
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [exportGridAsImage()])
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

struct FullGridCellView: View {
    let square: BoxSquare
    let isWinning: Bool
    let isHighlighted: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(cellColor)
                .frame(width: 44, height: 44)

            VStack(spacing: 2) {
                if !square.isEmpty {
                    Text(square.initials)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textColor)

                    Text(square.playerName.prefix(6))
                        .font(.system(size: 8))
                        .foregroundColor(textColor.opacity(0.8))
                        .lineLimit(1)
                }
            }

            if isWinning {
                Rectangle()
                    .stroke(AppColors.gold, lineWidth: 3)
                    .frame(width: 44, height: 44)
            }

            if square.isWinner && !square.quarterWins.isEmpty {
                VStack {
                    HStack {
                        Spacer()
                        ForEach(square.quarterWins, id: \.self) { q in
                            Text("Q\(q)")
                                .font(.system(size: 6, weight: .bold))
                                .foregroundColor(.white)
                                .padding(2)
                                .background(AppColors.gold)
                                .cornerRadius(2)
                        }
                    }
                    Spacer()
                }
                .frame(width: 44, height: 44)
                .padding(2)
            }
        }
        .border(Color(.systemGray4), width: 0.5)
    }

    var cellColor: Color {
        if isWinning {
            return AppColors.fieldGreen
        } else if isHighlighted {
            return .orange.opacity(0.6)
        } else if square.isWinner {
            return AppColors.gold.opacity(0.4)
        } else if !square.isEmpty {
            return Color(.systemGray6)
        } else {
            return Color(.systemBackground)
        }
    }

    var textColor: Color {
        if isWinning {
            return .white
        }
        return .primary
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
                                .foregroundColor(.secondary)
                            Text("\(pool.awayNumbers[square.row])")
                                .font(.title)
                                .fontWeight(.bold)
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("Column Number")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(pool.homeNumbers[square.column])")
                                .font(.title)
                                .fontWeight(.bold)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )

                    Text("Position: (\(square.row), \(square.column))")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                            .foregroundColor(.secondary)

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
                                                    .fill(playerName == name ? AppColors.fieldGreen : Color(.systemGray5))
                                            )
                                            .foregroundColor(playerName == name ? .white : .primary)
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

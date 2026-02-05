import SwiftUI

struct GridDetailView: View {
    @Binding var pool: BoxGrid
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var selectedSquare: BoxSquare?
    @State private var showingEditSheet = false
    @State private var zoomScale: CGFloat = 1.0
    @State private var showingShareSheet = false
    @State private var showingMenu = false

    var score: GameScore? {
        appState.scoreService.currentScore
    }

    var winningPosition: (row: Int, column: Int)? {
        guard let score = score else { return nil }
        return pool.winningPosition(homeDigit: score.homeLastDigit, awayDigit: score.awayLastDigit)
    }

    var body: some View {
        ZStack {
            // Background
            DesignSystem.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Navigation Bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(DesignSystem.Colors.surfaceElevated)
                            .clipShape(Circle())
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        Text(pool.name)
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        if let score = score {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(DesignSystem.Colors.live)
                                    .frame(width: 6, height: 6)
                                Text("\(score.awayScore)-\(score.homeScore)")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.live)
                            }
                        }
                    }

                    Spacer()

                    Button {
                        showingMenu = true
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(DesignSystem.Colors.surfaceElevated)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Live Score Bar
                if let score = score, score.isGameActive {
                    LiveScoreBar(score: score)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                }

                // Grid
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    ImmersiveGrid(
                        pool: pool,
                        winningPosition: winningPosition,
                        myName: appState.myName,
                        onSquareTap: { square in
                            selectedSquare = square
                            showingEditSheet = true
                            Haptics.impact(.light)
                        }
                    )
                    .scaleEffect(zoomScale)
                    .padding(20)
                }

                // Bottom Controls
                GridControls(
                    zoomScale: $zoomScale,
                    winningDigits: score.map { "\($0.awayLastDigit)-\($0.homeLastDigit)" }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingEditSheet) {
            if let square = selectedSquare {
                SquareEditSheet(
                    pool: $pool,
                    square: square,
                    onSave: { newName in
                        pool.updateSquare(row: square.row, column: square.column, playerName: newName)
                        appState.updatePool(pool)
                        showingEditSheet = false
                        Haptics.notification(.success)
                    }
                )
                .presentationDetents([.medium])
                .presentationBackground(.ultraThinMaterial)
            }
        }
        .confirmationDialog("Grid Options", isPresented: $showingMenu) {
            Button("Share Grid") {
                showingShareSheet = true
            }
            Button("Randomize Numbers") {
                pool.randomizeNumbers()
                appState.updatePool(pool)
                Haptics.notification(.success)
            }
            Button("Clear All Names", role: .destructive) {
                pool = BoxGrid(name: pool.name, homeTeam: pool.homeTeam, awayTeam: pool.awayTeam)
                appState.updatePool(pool)
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [exportGridAsText()])
        }
    }

    func exportGridAsText() -> String {
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

// MARK: - Live Score Bar
struct LiveScoreBar: View {
    let score: GameScore
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Circle()
                    .fill(DesignSystem.Colors.live)
                    .frame(width: 8, height: 8)
                    .scaleEffect(pulse ? 1.3 : 1.0)

                Text("LIVE")
                    .font(DesignSystem.Typography.captionSmall)
                    .foregroundColor(DesignSystem.Colors.live)
            }

            Spacer()

            HStack(spacing: 12) {
                Text(score.awayTeam.abbreviation)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Text("\(score.awayScore)")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("-")
                    .foregroundColor(DesignSystem.Colors.textMuted)

                Text("\(score.homeScore)")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text(score.homeTeam.abbreviation)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Spacer()

            Text("Q\(score.quarter)")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: DesignSystem.Radius.lg)
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Immersive Grid
struct ImmersiveGrid: View {
    let pool: BoxGrid
    let winningPosition: (row: Int, column: Int)?
    let myName: String
    let onSquareTap: (BoxSquare) -> Void

    let cellSize: CGFloat = 52

    var body: some View {
        VStack(spacing: 2) {
            // Header row
            HStack(spacing: 2) {
                // Corner cell
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(DesignSystem.Colors.surfaceElevated)

                    VStack(spacing: 0) {
                        Text(pool.awayTeam.abbreviation)
                            .font(.system(size: 9, weight: .bold))
                        Rectangle()
                            .fill(DesignSystem.Colors.textMuted)
                            .frame(width: 20, height: 1)
                            .rotationEffect(.degrees(-45))
                        Text(pool.homeTeam.abbreviation)
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                .frame(width: cellSize, height: cellSize)

                // Column headers
                ForEach(0..<10, id: \.self) { col in
                    let isWinning = winningPosition?.column == col

                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                isWinning ?
                                    DesignSystem.Colors.live :
                                    DesignSystem.Colors.accent.opacity(0.8)
                            )

                        Text("\(pool.homeNumbers[col])")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .frame(width: cellSize, height: cellSize)
                    .shadow(
                        color: isWinning ? DesignSystem.Colors.liveGlow : .clear,
                        radius: 8
                    )
                }
            }

            // Grid rows
            ForEach(0..<10, id: \.self) { row in
                HStack(spacing: 2) {
                    // Row header
                    let isWinningRow = winningPosition?.row == row

                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                isWinningRow ?
                                    DesignSystem.Colors.live :
                                    DesignSystem.Colors.danger.opacity(0.8)
                            )

                        Text("\(pool.awayNumbers[row])")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .frame(width: cellSize, height: cellSize)
                    .shadow(
                        color: isWinningRow ? DesignSystem.Colors.liveGlow : .clear,
                        radius: 8
                    )

                    // Cells
                    ForEach(0..<10, id: \.self) { col in
                        let square = pool.squares[row][col]
                        let isWinning = winningPosition?.row == row && winningPosition?.column == col
                        let isMine = !myName.isEmpty &&
                            square.playerName.lowercased().contains(myName.lowercased())

                        ImmersiveGridCell(
                            square: square,
                            isWinning: isWinning,
                            isMine: isMine,
                            size: cellSize
                        )
                        .onTapGesture {
                            onSquareTap(square)
                        }
                    }
                }
            }
        }
    }
}

struct ImmersiveGridCell: View {
    let square: BoxSquare
    let isWinning: Bool
    let isMine: Bool
    let size: CGFloat

    @State private var isPressed = false

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 6)
                .fill(cellBackground)

            // Glow for winners
            if isWinning {
                RoundedRectangle(cornerRadius: 6)
                    .fill(DesignSystem.Colors.live)
                    .blur(radius: 8)
                    .opacity(0.5)
            }

            // Content
            VStack(spacing: 2) {
                if !square.isEmpty {
                    Text(square.initials)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(textColor)

                    Text(String(square.playerName.prefix(6)))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(textColor.opacity(0.7))
                        .lineLimit(1)
                }
            }

            // Border
            RoundedRectangle(cornerRadius: 6)
                .stroke(borderColor, lineWidth: isWinning ? 2 : 1)

            // Quarter wins badges
            if !square.quarterWins.isEmpty {
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 2) {
                            ForEach(square.quarterWins.prefix(2), id: \.self) { q in
                                Text("Q\(q)")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 1)
                                    .background(DesignSystem.Colors.gold)
                                    .cornerRadius(3)
                            }
                        }
                        .padding(3)
                    }
                    Spacer()
                }
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(DesignSystem.Animation.springSnappy, value: isPressed)
        .shadow(
            color: isWinning ? DesignSystem.Colors.liveGlow : .clear,
            radius: 12
        )
    }

    var cellBackground: Color {
        if isWinning {
            return DesignSystem.Colors.live
        } else if isMine {
            return DesignSystem.Colors.gold.opacity(0.6)
        } else if square.isWinner {
            return DesignSystem.Colors.gold.opacity(0.3)
        } else if !square.isEmpty {
            return DesignSystem.Colors.surfaceElevated
        }
        return DesignSystem.Colors.surface
    }

    var textColor: Color {
        if isWinning || isMine {
            return .white
        }
        return DesignSystem.Colors.textPrimary
    }

    var borderColor: Color {
        if isWinning {
            return DesignSystem.Colors.gold
        } else if isMine {
            return DesignSystem.Colors.gold.opacity(0.5)
        }
        return DesignSystem.Colors.glassBorder
    }
}

// MARK: - Grid Controls
struct GridControls: View {
    @Binding var zoomScale: CGFloat
    let winningDigits: String?

    var body: some View {
        HStack {
            // Zoom controls
            HStack(spacing: 12) {
                Button {
                    withAnimation(DesignSystem.Animation.springSnappy) {
                        zoomScale = max(0.5, zoomScale - 0.25)
                    }
                    Haptics.impact(.light)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(DesignSystem.Colors.surfaceElevated)
                        .clipShape(Circle())
                }

                Text("\(Int(zoomScale * 100))%")
                    .font(DesignSystem.Typography.mono)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .frame(width: 50)

                Button {
                    withAnimation(DesignSystem.Animation.springSnappy) {
                        zoomScale = min(2.0, zoomScale + 0.25)
                    }
                    Haptics.impact(.light)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(DesignSystem.Colors.surfaceElevated)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassCard(cornerRadius: DesignSystem.Radius.full)

            Spacer()

            // Winning digits
            if let digits = winningDigits {
                HStack(spacing: 8) {
                    Text("WINNER")
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundColor(DesignSystem.Colors.textTertiary)

                    Text(digits)
                        .font(DesignSystem.Typography.monoLarge)
                        .foregroundColor(DesignSystem.Colors.live)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassCard(cornerRadius: DesignSystem.Radius.full)
            }
        }
    }
}

// MARK: - Square Edit Sheet
struct SquareEditSheet: View {
    @Binding var pool: BoxGrid
    let square: BoxSquare
    let onSave: (String) -> Void
    @State private var playerName: String = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Square Info
                    HStack(spacing: 24) {
                        VStack(spacing: 4) {
                            Text("ROW")
                                .font(DesignSystem.Typography.captionSmall)
                                .foregroundColor(DesignSystem.Colors.textTertiary)

                            Text("\(pool.awayNumbers[square.row])")
                                .font(DesignSystem.Typography.scoreMedium)
                                .foregroundColor(DesignSystem.Colors.danger)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .glassCard(cornerRadius: DesignSystem.Radius.lg)

                        VStack(spacing: 4) {
                            Text("COL")
                                .font(DesignSystem.Typography.captionSmall)
                                .foregroundColor(DesignSystem.Colors.textTertiary)

                            Text("\(pool.homeNumbers[square.column])")
                                .font(DesignSystem.Typography.scoreMedium)
                                .foregroundColor(DesignSystem.Colors.accent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .glassCard(cornerRadius: DesignSystem.Radius.lg)
                    }

                    // Name Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PLAYER NAME")
                            .font(DesignSystem.Typography.captionSmall)
                            .foregroundColor(DesignSystem.Colors.textTertiary)

                        TextField("Enter name", text: $playerName)
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .padding()
                            .background(DesignSystem.Colors.surfaceElevated)
                            .cornerRadius(DesignSystem.Radius.md)
                            .autocorrectionDisabled()
                    }

                    // Quick select
                    if !pool.allPlayers.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("QUICK SELECT")
                                .font(DesignSystem.Typography.captionSmall)
                                .foregroundColor(DesignSystem.Colors.textTertiary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(pool.allPlayers.prefix(10), id: \.self) { name in
                                        Button {
                                            playerName = name
                                            Haptics.selection()
                                        } label: {
                                            Text(name)
                                                .font(DesignSystem.Typography.caption)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(
                                                    Capsule()
                                                        .fill(playerName == name ?
                                                              DesignSystem.Colors.accent :
                                                              DesignSystem.Colors.surfaceElevated)
                                                )
                                                .foregroundColor(playerName == name ?
                                                                .white :
                                                                DesignSystem.Colors.textSecondary)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Spacer()

                    // Save Button
                    Button {
                        onSave(playerName)
                    } label: {
                        Text("Save")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(DesignSystem.Colors.accent)
                            .cornerRadius(DesignSystem.Radius.lg)
                    }
                }
                .padding(24)
            }
            .navigationTitle("Edit Square")
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
            .onAppear {
                playerName = square.playerName
            }
        }
    }
}

// MARK: - Share Sheet
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

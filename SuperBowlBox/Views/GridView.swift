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
    @State private var highlightMySquares = false
    @State private var gridOffset: CGSize = .zero

    var score: GameScore? {
        appState.scoreService.currentScore
    }

    var winningPosition: (row: Int, column: Int)? {
        guard let score = score else { return nil }
        return pool.winningPosition(homeDigit: score.homeLastDigit, awayDigit: score.awayLastDigit)
    }

    // Calculate hunt info for cells
    func huntInfo(for square: BoxSquare) -> (pointsAway: Int, team: String)? {
        guard let score = score else { return nil }
        let rowDigit = pool.awayNumbers[square.row]
        let colDigit = pool.homeNumbers[square.column]

        // Check if away digit matches and home needs points
        if score.awayLastDigit == rowDigit {
            let homeDiff = pointsToDigit(from: score.homeScore, to: colDigit)
            if homeDiff > 0 && homeDiff <= 7 {
                return (homeDiff, score.homeTeam.abbreviation)
            }
        }

        // Check if home digit matches and away needs points
        if score.homeLastDigit == colDigit {
            let awayDiff = pointsToDigit(from: score.awayScore, to: rowDigit)
            if awayDiff > 0 && awayDiff <= 7 {
                return (awayDiff, score.awayTeam.abbreviation)
            }
        }

        return nil
    }

    func pointsToDigit(from currentScore: Int, to targetDigit: Int) -> Int {
        let currentDigit = currentScore % 10
        if currentDigit == targetDigit { return 0 }
        var diff = targetDigit - currentDigit
        if diff < 0 { diff += 10 }
        return diff
    }

    var body: some View {
        ZStack {
            // Background
            DesignSystem.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Compact Navigation + Score Header
                CompactGridHeader(
                    pool: pool,
                    score: score,
                    onBack: { dismiss() },
                    onMenu: { showingMenu = true }
                )

                // Grid with pinch-to-zoom
                GeometryReader { geometry in
                    ScrollView([.horizontal, .vertical], showsIndicators: false) {
                        ImmersiveGrid(
                            pool: pool,
                            winningPosition: winningPosition,
                            myName: appState.myName,
                            highlightMine: highlightMySquares,
                            huntInfoProvider: huntInfo,
                            onSquareTap: { square in
                                selectedSquare = square
                                showingEditSheet = true
                                Haptics.impact(.light)
                            }
                        )
                        .scaleEffect(zoomScale, anchor: .center)
                        .frame(
                            width: max(geometry.size.width, 600 * zoomScale),
                            height: max(geometry.size.height, 600 * zoomScale)
                        )
                    }
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let newScale = zoomScale * value
                                zoomScale = min(max(newScale, 0.5), 2.5)
                            }
                            .onEnded { _ in
                                Haptics.impact(.light)
                            }
                    )
                }

                // Bottom Controls
                GridBottomBar(
                    zoomScale: $zoomScale,
                    highlightMySquares: $highlightMySquares,
                    myName: appState.myName,
                    winningDigits: score.map { "\($0.awayLastDigit)-\($0.homeLastDigit)" }
                )
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

// MARK: - Compact Grid Header
struct CompactGridHeader: View {
    let pool: BoxGrid
    let score: GameScore?
    let onBack: () -> Void
    let onMenu: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Navigation row
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(DesignSystem.Colors.surfaceElevated)
                        .clipShape(Circle())
                }

                Spacer()

                Text(pool.name)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                Button(action: onMenu) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(DesignSystem.Colors.surfaceElevated)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)

            // Compact score bar (always visible)
            if let score = score {
                HStack(spacing: 12) {
                    // Live indicator
                    if score.isGameActive {
                        HStack(spacing: 6) {
                            LivePulseIndicator(isLive: true, size: 8)
                            Text("Q\(score.quarter)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(DesignSystem.Colors.live)
                        }
                    }

                    Spacer()

                    // Score display
                    HStack(spacing: 8) {
                        Text(score.awayTeam.abbreviation)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        HStack(spacing: 4) {
                            Text("\(score.awayScore)")
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundColor(DesignSystem.Colors.textPrimary)

                            Text("-")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.textMuted)

                            Text("\(score.homeScore)")
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                        }

                        Text(score.homeTeam.abbreviation)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    Spacer()

                    // Winning numbers badge
                    HStack(spacing: 4) {
                        Image(systemName: "target")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.gold)

                        Text("\(score.awayLastDigit)-\(score.homeLastDigit)")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.gold)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(DesignSystem.Colors.gold.opacity(0.15))
                    .clipShape(Capsule())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(DesignSystem.Colors.surface.opacity(0.8))
            }
        }
        .background(DesignSystem.Colors.background)
    }
}

// MARK: - Immersive Grid
struct ImmersiveGrid: View {
    let pool: BoxGrid
    let winningPosition: (row: Int, column: Int)?
    let myName: String
    var highlightMine: Bool = false
    var huntInfoProvider: ((BoxSquare) -> (pointsAway: Int, team: String)?)?
    let onSquareTap: (BoxSquare) -> Void

    let cellSize: CGFloat = 52

    var body: some View {
        VStack(spacing: 2) {
            // Header row
            HStack(spacing: 2) {
                // Corner cell with team labels
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(DesignSystem.Colors.surfaceElevated)

                    VStack(spacing: 2) {
                        // Away team (rows)
                        HStack(spacing: 2) {
                            Circle()
                                .fill(Color(hex: pool.awayTeam.primaryColor) ?? DesignSystem.Colors.danger)
                                .frame(width: 8, height: 8)
                            Text(pool.awayTeam.abbreviation)
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(DesignSystem.Colors.textTertiary)

                        Text("Rows")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.textMuted)

                        Rectangle()
                            .fill(DesignSystem.Colors.glassBorder)
                            .frame(width: 30, height: 1)

                        // Home team (cols)
                        HStack(spacing: 2) {
                            Circle()
                                .fill(Color(hex: pool.homeTeam.primaryColor) ?? DesignSystem.Colors.accent)
                                .frame(width: 8, height: 8)
                            Text(pool.homeTeam.abbreviation)
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(DesignSystem.Colors.textTertiary)

                        Text("Cols")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.textMuted)
                    }
                }
                .frame(width: cellSize, height: cellSize)

                // Column headers (home team numbers)
                ForEach(0..<10, id: \.self) { col in
                    let isWinning = winningPosition?.column == col

                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                isWinning ?
                                    DesignSystem.Colors.live :
                                    (Color(hex: pool.homeTeam.primaryColor) ?? DesignSystem.Colors.accent).opacity(0.8)
                            )

                        Text("\(pool.homeNumbers[col])")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .frame(width: cellSize, height: cellSize)
                    .shadow(color: isWinning ? DesignSystem.Colors.liveGlow : .clear, radius: 8)
                    .overlay(
                        isWinning ?
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(DesignSystem.Colors.gold, lineWidth: 2)
                            : nil
                    )
                }
            }

            // Grid rows
            ForEach(0..<10, id: \.self) { row in
                HStack(spacing: 2) {
                    // Row header (away team numbers)
                    let isWinningRow = winningPosition?.row == row

                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                isWinningRow ?
                                    DesignSystem.Colors.live :
                                    (Color(hex: pool.awayTeam.primaryColor) ?? DesignSystem.Colors.danger).opacity(0.8)
                            )

                        Text("\(pool.awayNumbers[row])")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .frame(width: cellSize, height: cellSize)
                    .shadow(color: isWinningRow ? DesignSystem.Colors.liveGlow : .clear, radius: 8)
                    .overlay(
                        isWinningRow ?
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(DesignSystem.Colors.gold, lineWidth: 2)
                            : nil
                    )

                    // Cells
                    ForEach(0..<10, id: \.self) { col in
                        let square = pool.squares[row][col]
                        let isWinning = winningPosition?.row == row && winningPosition?.column == col
                        let isMine = !myName.isEmpty &&
                            square.playerName.lowercased().contains(myName.lowercased())
                        let huntInfo = huntInfoProvider?(square)

                        ImmersiveGridCell(
                            square: square,
                            isWinning: isWinning,
                            isMine: isMine,
                            isHighlighted: highlightMine && isMine,
                            huntInfo: huntInfo,
                            size: cellSize
                        )
                        .onTapGesture {
                            onSquareTap(square)
                        }
                    }
                }
            }
        }
        .padding(12)
    }
}

struct ImmersiveGridCell: View {
    let square: BoxSquare
    let isWinning: Bool
    let isMine: Bool
    var isHighlighted: Bool = false
    var huntInfo: (pointsAway: Int, team: String)? = nil
    let size: CGFloat

    @State private var isPressed = false
    @State private var glowIntensity: Double = 0.4
    @State private var borderPulse: CGFloat = 1.0
    @State private var highlightPulse: CGFloat = 1.0

    var isOnHunt: Bool {
        huntInfo != nil
    }

    var huntColor: Color {
        guard let info = huntInfo else { return .clear }
        switch info.pointsAway {
        case 1...3: return DesignSystem.Colors.danger
        case 4...5: return DesignSystem.Colors.gold
        default: return DesignSystem.Colors.accent
        }
    }

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 6)
                .fill(cellBackground)

            // Animated glow for winners
            if isWinning {
                RoundedRectangle(cornerRadius: 6)
                    .fill(DesignSystem.Colors.live)
                    .blur(radius: 12)
                    .opacity(glowIntensity)

                // Pulsing border
                RoundedRectangle(cornerRadius: 6)
                    .stroke(DesignSystem.Colors.gold, lineWidth: 2)
                    .scaleEffect(borderPulse)
                    .opacity(2 - Double(borderPulse))
            }

            // Highlight pulse for "Find My Squares"
            if isHighlighted {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(DesignSystem.Colors.gold, lineWidth: 3)
                    .scaleEffect(highlightPulse)
                    .opacity(2 - Double(highlightPulse))
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
                .stroke(borderColor, lineWidth: borderWidth)

            // Quarter wins badges (top right)
            if !square.quarterWins.isEmpty && !isWinning {
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

            // Winner crown icon (top left)
            if isWinning {
                VStack {
                    HStack {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.gold)
                            .shadow(color: DesignSystem.Colors.goldGlow, radius: 4)
                            .padding(3)
                        Spacer()
                    }
                    Spacer()
                }
            }

            // Hunt indicator (bottom)
            if isOnHunt && !isWinning, let info = huntInfo {
                VStack {
                    Spacer()
                    Text("+\(info.pointsAway)")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundColor(huntColor)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(huntColor.opacity(0.2))
                        .clipShape(Capsule())
                        .padding(.bottom, 2)
                }
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(DesignSystem.Animation.springSnappy, value: isPressed)
        .shadow(color: isWinning ? DesignSystem.Colors.liveGlow : .clear, radius: 12)
        .shadow(color: isWinning ? DesignSystem.Colors.goldGlow : .clear, radius: 20)
        .shadow(color: isHighlighted ? DesignSystem.Colors.goldGlow : .clear, radius: 8)
        .onAppear {
            if isWinning {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    glowIntensity = 0.8
                }
                withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    borderPulse = 1.3
                }
            }
            if isHighlighted {
                withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    highlightPulse = 1.5
                }
            }
        }
    }

    var cellBackground: Color {
        if isWinning {
            return DesignSystem.Colors.live
        } else if isMine {
            return DesignSystem.Colors.gold.opacity(0.5)
        } else if isOnHunt {
            return huntColor.opacity(0.15)
        } else if square.isWinner {
            return DesignSystem.Colors.gold.opacity(0.25)
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
            return DesignSystem.Colors.gold
        } else if isOnHunt {
            return huntColor.opacity(0.6)
        }
        return DesignSystem.Colors.glassBorder
    }

    var borderWidth: CGFloat {
        if isWinning { return 2 }
        if isMine { return 2 }
        if isOnHunt { return 1.5 }
        return 1
    }
}

// MARK: - Grid Bottom Bar
struct GridBottomBar: View {
    @Binding var zoomScale: CGFloat
    @Binding var highlightMySquares: Bool
    let myName: String
    let winningDigits: String?

    var body: some View {
        HStack(spacing: 12) {
            // Zoom controls
            HStack(spacing: 8) {
                Button {
                    withAnimation(DesignSystem.Animation.springSnappy) {
                        zoomScale = max(0.5, zoomScale - 0.25)
                    }
                    Haptics.impact(.light)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(DesignSystem.Colors.surfaceElevated)
                        .clipShape(Circle())
                }

                Text("\(Int(zoomScale * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .frame(width: 45)

                Button {
                    withAnimation(DesignSystem.Animation.springSnappy) {
                        zoomScale = min(2.5, zoomScale + 0.25)
                    }
                    Haptics.impact(.light)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(DesignSystem.Colors.surfaceElevated)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(DesignSystem.Colors.surface.opacity(0.9))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(DesignSystem.Colors.glassBorder, lineWidth: 1)
            )

            // Find My Squares button
            if !myName.isEmpty {
                Button {
                    withAnimation(DesignSystem.Animation.springSnappy) {
                        highlightMySquares.toggle()
                    }
                    Haptics.impact(.medium)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: highlightMySquares ? "person.fill.viewfinder" : "person.viewfinder")
                            .font(.system(size: 14, weight: .semibold))

                        Text("MINE")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(highlightMySquares ? .white : DesignSystem.Colors.gold)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        highlightMySquares ?
                            DesignSystem.Colors.gold :
                            DesignSystem.Colors.gold.opacity(0.15)
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(DesignSystem.Colors.gold.opacity(0.3), lineWidth: 1)
                    )
                }
            }

            Spacer()

            // Legend
            HStack(spacing: 12) {
                LegendDot(color: DesignSystem.Colors.live, label: "WIN")
                LegendDot(color: DesignSystem.Colors.gold, label: "MINE")
                LegendDot(color: DesignSystem.Colors.danger, label: "HUNT")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(DesignSystem.Colors.surface.opacity(0.9))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(DesignSystem.Colors.glassBorder, lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(DesignSystem.Colors.background)
    }
}

struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(DesignSystem.Colors.textMuted)
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

import SwiftUI

struct MySquaresView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchName: String = ""
    @FocusState private var isSearchFocused: Bool

    var effectiveName: String {
        searchName.isEmpty ? appState.myName : searchName
    }

    var body: some View {
        ZStack {
            // Animated Background
            AnimatedMeshBackground()
            TechGridBackground()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MY SQUARES")
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                            .foregroundStyle(DesignSystem.Colors.cyberGradient)

                        Text("PORTFOLIO TRACKER")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.textMuted)
                            .tracking(2)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 20)

                // Search bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isSearchFocused ? DesignSystem.Colors.accent : DesignSystem.Colors.textMuted)

                    TextField("Search identity...", text: $searchName)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .autocorrectionDisabled()
                        .focused($isSearchFocused)

                    if !searchName.isEmpty {
                        Button {
                            Haptics.selection()
                            searchName = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(DesignSystem.Colors.textMuted)
                        }
                    }
                }
                .padding(14)
                .background(DesignSystem.Colors.surface.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isSearchFocused ?
                                DesignSystem.Colors.accent.opacity(0.5) :
                                DesignSystem.Colors.glassBorder,
                            lineWidth: 1
                        )
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                if effectiveName.isEmpty {
                    Spacer()
                    EmptyIdentityView()
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            // Stats Command Center
                            StatsCommandCenter(name: effectiveName, pools: appState.pools)

                            // Squares by pool
                            ForEach(appState.pools) { pool in
                                let squares = pool.squares(for: effectiveName)
                                if !squares.isEmpty {
                                    PoolPortfolioCard(
                                        pool: pool,
                                        squares: squares,
                                        score: appState.scoreService.currentScore
                                    )
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
        .onAppear {
            if searchName.isEmpty && !appState.myName.isEmpty {
                searchName = appState.myName
            }
        }
    }
}

// MARK: - Empty Identity View
struct EmptyIdentityView: View {
    @State private var scanRotation: Double = 0

    var body: some View {
        VStack(spacing: 32) {
            ZStack {
                // Scanning circles
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(DesignSystem.Colors.accent.opacity(0.1), lineWidth: 1)
                        .frame(width: 100 + CGFloat(i) * 40)
                }

                Circle()
                    .trim(from: 0, to: 0.2)
                    .stroke(DesignSystem.Colors.accent, lineWidth: 2)
                    .frame(width: 140)
                    .rotationEffect(.degrees(scanRotation))

                Image(systemName: "person.crop.rectangle.badge.plus")
                    .font(.system(size: 44))
                    .foregroundStyle(DesignSystem.Colors.cyberGradient)
            }
            .onAppear {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    scanRotation = 360
                }
            }

            VStack(spacing: 12) {
                Text("IDENTITY REQUIRED")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .tracking(3)

                Text("Enter your name to locate\nyour squares in the matrix")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
    }
}

// MARK: - Stats Command Center
struct StatsCommandCenter: View {
    let name: String
    let pools: [BoxGrid]
    @State private var animateRings = false

    var totalSquares: Int {
        pools.reduce(0) { $0 + $1.squares(for: name).count }
    }

    var winningSquares: Int {
        pools.reduce(0) { total, pool in
            total + pool.squares(for: name).filter { $0.isWinner }.count
        }
    }

    var poolsCount: Int {
        pools.filter { !$0.squares(for: name).isEmpty }.count
    }

    var initials: String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else if let first = words.first {
            return String(first.prefix(2)).uppercased()
        }
        return "??"
    }

    var body: some View {
        VStack(spacing: 24) {
            // Identity header
            HStack(spacing: 16) {
                // Avatar with orbital ring
                ZStack {
                    OrbitalRing(
                        progress: min(Double(totalSquares) / 20.0, 1.0),
                        color: DesignSystem.Colors.accent,
                        size: 70,
                        lineWidth: 3
                    )

                    Circle()
                        .fill(DesignSystem.Colors.cyberGradient)
                        .frame(width: 52, height: 52)

                    Text(initials)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                .glow(DesignSystem.Colors.accent, radius: 12)

                VStack(alignment: .leading, spacing: 4) {
                    Text("TRACKING")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.textMuted)
                        .tracking(2)

                    Text(name.uppercased())
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .tracking(1)
                }

                Spacer()
            }

            // Stats grid
            HStack(spacing: 0) {
                StatOrbital(
                    value: totalSquares,
                    label: "SQUARES",
                    color: DesignSystem.Colors.accent,
                    progress: min(Double(totalSquares) / 50.0, 1.0)
                )

                Rectangle()
                    .fill(DesignSystem.Colors.glassBorder)
                    .frame(width: 1, height: 70)

                StatOrbital(
                    value: winningSquares,
                    label: "WINS",
                    color: DesignSystem.Colors.gold,
                    progress: totalSquares > 0 ? Double(winningSquares) / Double(totalSquares) : 0
                )

                Rectangle()
                    .fill(DesignSystem.Colors.glassBorder)
                    .frame(width: 1, height: 70)

                StatOrbital(
                    value: poolsCount,
                    label: "POOLS",
                    color: DesignSystem.Colors.live,
                    progress: min(Double(poolsCount) / 5.0, 1.0)
                )
            }
        }
        .padding(24)
        .neonCard(DesignSystem.Colors.accent, intensity: 0.2)
    }
}

struct StatOrbital: View {
    let value: Int
    let label: String
    let color: Color
    let progress: Double

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 3)
                    .frame(width: 50, height: 50)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))

                AnimatedCounter(
                    value: value,
                    font: .system(size: 20, weight: .black, design: .monospaced),
                    color: color
                )
            }

            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(DesignSystem.Colors.textMuted)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Pool Portfolio Card
struct PoolPortfolioCard: View {
    let pool: BoxGrid
    let squares: [BoxSquare]
    let score: GameScore?

    var currentWinningSquare: BoxSquare? {
        guard let score = score else { return nil }
        return pool.winningSquare(for: score)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 10) {
                    // Team badges
                    ZStack {
                        Circle()
                            .fill(Color(hex: pool.awayTeam.primaryColor)?.gradient ?? DesignSystem.Colors.danger.gradient)
                            .frame(width: 28, height: 28)

                        Text(pool.awayTeam.abbreviation)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    }

                    ZStack {
                        Circle()
                            .fill(Color(hex: pool.homeTeam.primaryColor)?.gradient ?? DesignSystem.Colors.accent.gradient)
                            .frame(width: 28, height: 28)

                        Text(pool.homeTeam.abbreviation)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(pool.name.uppercased())
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .tracking(1)

                        Text("\(pool.awayTeam.abbreviation) vs \(pool.homeTeam.abbreviation)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                }

                Spacer()

                // Count badge
                Text("\(squares.count)")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundStyle(DesignSystem.Colors.cyberGradient)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(DesignSystem.Colors.accent.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Grid of my numbers
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(squares) { square in
                    let isCurrentWinner = currentWinningSquare?.id == square.id
                    SquareMatrixCell(
                        pool: pool,
                        square: square,
                        isCurrentWinner: isCurrentWinner
                    )
                }
            }
        }
        .padding(20)
        .neonCard(
            currentWinningSquare != nil ? DesignSystem.Colors.live : DesignSystem.Colors.accent,
            intensity: currentWinningSquare != nil ? 0.3 : 0.15
        )
    }
}

// MARK: - Square Matrix Cell
struct SquareMatrixCell: View {
    let pool: BoxGrid
    let square: BoxSquare
    let isCurrentWinner: Bool
    @State private var winnerPulse = false

    var rowNumber: Int {
        pool.awayNumbers[square.row]
    }

    var colNumber: Int {
        pool.homeNumbers[square.column]
    }

    var body: some View {
        VStack(spacing: 6) {
            // Numbers
            HStack(spacing: 4) {
                Text("\(rowNumber)")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                Text("-")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textMuted)
                Text("\(colNumber)")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
            }
            .foregroundColor(isCurrentWinner ? .white : DesignSystem.Colors.textPrimary)

            // Status badge
            if isCurrentWinner {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                        .scaleEffect(winnerPulse ? 1.3 : 1.0)

                    Text("LIVE")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                }
                .foregroundColor(.white)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        winnerPulse = true
                    }
                }
            } else if !square.quarterWins.isEmpty {
                HStack(spacing: 3) {
                    ForEach(square.quarterWins, id: \.self) { q in
                        Text("Q\(q)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.gold)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isCurrentWinner ? DesignSystem.Colors.live : DesignSystem.Colors.glassBorder,
                    lineWidth: isCurrentWinner ? 2 : 1
                )
        )
        .shadow(
            color: isCurrentWinner ? DesignSystem.Colors.liveGlow : .clear,
            radius: 12
        )
    }

    var backgroundColor: Color {
        if isCurrentWinner {
            return DesignSystem.Colors.live
        } else if !square.quarterWins.isEmpty {
            return DesignSystem.Colors.gold.opacity(0.15)
        }
        return DesignSystem.Colors.surfaceElevated
    }
}

#Preview {
    MySquaresView()
        .environmentObject(AppState())
}

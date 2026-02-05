import SwiftUI

struct MySquaresView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchName: String = ""
    @FocusState private var isSearchFocused: Bool

    var effectiveName: String {
        searchName.isEmpty ? appState.myName : searchName
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.textMuted)

                        TextField("Search by name", text: $searchName)
                            .font(DesignSystem.Typography.body)
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
                    .background(DesignSystem.Colors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isSearchFocused ? DesignSystem.Colors.accent.opacity(0.5) : DesignSystem.Colors.glassBorder,
                                lineWidth: 1
                            )
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    if effectiveName.isEmpty {
                        Spacer()
                        EmptyNameView()
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 20) {
                                // Summary card
                                MySquaresSummaryCard(name: effectiveName, pools: appState.pools)

                                // Squares by pool
                                ForEach(appState.pools) { pool in
                                    let squares = pool.squares(for: effectiveName)
                                    if !squares.isEmpty {
                                        PoolSquaresCard(
                                            pool: pool,
                                            squares: squares,
                                            score: appState.scoreService.currentScore
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 120)
                        }
                    }
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("My Squares")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
            }
            .toolbarBackground(DesignSystem.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
                if searchName.isEmpty && !appState.myName.isEmpty {
                    searchName = appState.myName
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Empty Name View
struct EmptyNameView: View {
    @State private var iconBounce = false

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.accent.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "person.crop.square.badge.magnifyingglass")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignSystem.Colors.accent, DesignSystem.Colors.accent.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .offset(y: iconBounce ? -4 : 0)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    iconBounce = true
                }
            }

            VStack(spacing: 8) {
                Text("Enter Your Name")
                    .font(DesignSystem.Typography.title)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("Search for your name to see all your squares across pools")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
}

// MARK: - Summary Card
struct MySquaresSummaryCard: View {
    let name: String
    let pools: [BoxGrid]

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

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TRACKING")
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundColor(DesignSystem.Colors.textMuted)
                        .tracking(1)

                    Text(name)
                        .font(DesignSystem.Typography.title)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                Spacer()

                // Avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [DesignSystem.Colors.accent, DesignSystem.Colors.accent.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)

                    Text(initials)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                .shadow(color: DesignSystem.Colors.accentGlow, radius: 8, y: 2)
            }

            // Stats
            HStack(spacing: 0) {
                StatBlock(value: "\(totalSquares)", label: "Squares", color: DesignSystem.Colors.accent)

                Rectangle()
                    .fill(DesignSystem.Colors.glassBorder)
                    .frame(width: 1, height: 50)

                StatBlock(value: "\(winningSquares)", label: "Wins", color: DesignSystem.Colors.gold)

                Rectangle()
                    .fill(DesignSystem.Colors.glassBorder)
                    .frame(width: 1, height: 50)

                StatBlock(value: "\(poolsCount)", label: "Pools", color: DesignSystem.Colors.live)
            }
        }
        .padding(20)
        .glassCard()
    }

    var initials: String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else if let first = words.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }
}

struct StatBlock: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(DesignSystem.Typography.scoreMedium)
                .foregroundColor(color)

            Text(label)
                .font(DesignSystem.Typography.captionSmall)
                .foregroundColor(DesignSystem.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Pool Squares Card
struct PoolSquaresCard: View {
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
                HStack(spacing: 8) {
                    TeamBadge(team: pool.awayTeam, size: 24)
                    TeamBadge(team: pool.homeTeam, size: 24)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(pool.name)
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text("\(pool.awayTeam.abbreviation) vs \(pool.homeTeam.abbreviation)")
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }

                Spacer()

                Text("\(squares.count)")
                    .font(DesignSystem.Typography.scoreMedium)
                    .foregroundColor(DesignSystem.Colors.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(DesignSystem.Colors.accent.opacity(0.15))
                    .clipShape(Capsule())
            }

            // Grid of my numbers
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(squares) { square in
                    let isCurrentWinner = currentWinningSquare?.id == square.id
                    SquareNumberCell(
                        pool: pool,
                        square: square,
                        isCurrentWinner: isCurrentWinner
                    )
                }
            }
        }
        .padding(20)
        .glassCard()
    }
}

// MARK: - Square Number Cell
struct SquareNumberCell: View {
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
                    .font(DesignSystem.Typography.monoLarge)
                Text("-")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textMuted)
                Text("\(colNumber)")
                    .font(DesignSystem.Typography.monoLarge)
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
                        .font(.system(size: 9, weight: .bold))
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
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.gold)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
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
            radius: 8
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

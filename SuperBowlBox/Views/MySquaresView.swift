import SwiftUI

struct MySquaresView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchName: String = ""

    /// When search is empty we show "my" squares using per-pool owner labels (or global myName). We have something to show if search is non-empty or global name is set or any pool has owner labels.
    var hasAnythingToShow: Bool {
        if !searchName.isEmpty { return true }
        if !appState.myName.isEmpty { return true }
        return appState.pools.contains { !$0.effectiveOwnerLabels(globalName: appState.myName).isEmpty }
    }

    var effectiveName: String {
        searchName.isEmpty ? appState.myName : searchName
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SportsbookBackgroundView()
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    TextField("Search by name", text: $searchName)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()

                    if !searchName.isEmpty {
                        Button {
                            searchName = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
                .padding(DesignSystem.Layout.cardPadding)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall)
                        .fill(DesignSystem.Colors.cardSurface)
                        .overlay(RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall).strokeBorder(DesignSystem.Colors.cardBorder, lineWidth: 1))
                )
                .padding(.horizontal, DesignSystem.Layout.screenInset)
                .padding(.vertical, 16)

                if !hasAnythingToShow {
                    EmptyNameView()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: DesignSystem.Layout.sectionSpacing) {
                            SectionHeaderView(title: "Summary")
                            MySquaresSummaryCard(
                                pools: appState.pools,
                                globalMyName: appState.myName,
                                searchName: searchName
                            )
                            .padding(.horizontal, DesignSystem.Layout.screenInset)

                            SectionHeaderView(title: "By Pool")
                            ForEach(appState.pools) { pool in
                                let squares = searchName.isEmpty
                                    ? pool.squaresForOwner(ownerLabels: pool.effectiveOwnerLabels(globalName: appState.myName))
                                    : pool.squares(for: searchName)
                                if !squares.isEmpty {
                                    PoolSquaresCard(
                                        pool: pool,
                                        squares: squares,
                                        score: appState.scoreService.currentScore
                                    )
                                    .padding(.horizontal, DesignSystem.Layout.screenInset)
                                }
                            }
                        }
                        .padding(.vertical, 24)
                    }
                }
            }
            }
            .toolbarBackground(DesignSystem.Colors.backgroundSecondary, for: .navigationBar)
            .navigationTitle("My Squares")
        }
    }
}

struct EmptyNameView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.square.badge.magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(DesignSystem.Colors.textTertiary)

            Text("Enter Your Name")
                .font(DesignSystem.Typography.title)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text("Search for your name to see all your squares across pools")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }
}

struct MySquaresSummaryCard: View {
    let pools: [BoxGrid]
    let globalMyName: String
    let searchName: String

    /// When searchName is empty, use per-pool owner labels (how your name appears on each sheet).
    private var isOwnerMode: Bool { searchName.isEmpty }

    var totalSquares: Int {
        if isOwnerMode {
            return pools.reduce(0) { acc, pool in
                acc + pool.squaresForOwner(ownerLabels: pool.effectiveOwnerLabels(globalName: globalMyName)).count
            }
        }
        return pools.reduce(0) { $0 + $1.squares(for: searchName).count }
    }

    var winningSquares: Int {
        if isOwnerMode {
            return pools.reduce(0) { total, pool in
                total + pool.squaresForOwner(ownerLabels: pool.effectiveOwnerLabels(globalName: globalMyName)).filter { $0.isWinner }.count
            }
        }
        return pools.reduce(0) { total, pool in
            total + pool.squares(for: searchName).filter { $0.isWinner }.count
        }
    }

    var poolCount: Int {
        if isOwnerMode {
            return pools.filter { !$0.squaresForOwner(ownerLabels: $0.effectiveOwnerLabels(globalName: globalMyName)).isEmpty }.count
        }
        return pools.filter { !$0.squares(for: searchName).isEmpty }.count
    }

    var displayLabel: String {
        isOwnerMode ? "My squares" : searchName
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isOwnerMode ? "Your squares" : "Searching for")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text(displayLabel)
                        .font(DesignSystem.Typography.title)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                Spacer()
            }

            HStack(spacing: 24) {
                VStack {
                    Text("\(totalSquares)")
                        .font(DesignSystem.Typography.scoreMedium)
                        .foregroundColor(DesignSystem.Colors.accentBlue)
                    Text("Total Squares")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Divider()
                    .frame(height: 40)

                VStack {
                    Text("\(winningSquares)")
                        .font(DesignSystem.Typography.scoreMedium)
                        .foregroundColor(DesignSystem.Colors.winnerGold)
                    Text("Quarter Wins")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Divider()
                    .frame(height: 40)

                VStack {
                    Text("\(poolCount)")
                        .font(DesignSystem.Typography.scoreMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text("Pools")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
        }
        .sportsbookCard()
    }
}

struct PoolSquaresCard: View {
    let pool: BoxGrid
    let squares: [BoxSquare]
    let score: GameScore?

    var currentWinningSquare: BoxSquare? {
        guard let score = score else { return nil }
        return pool.winningSquare(for: score)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(pool.name)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                Text("\(squares.count) squares")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            // Grid of my numbers
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
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
        .sportsbookCard()
    }
}

struct SquareNumberCell: View {
    let pool: BoxGrid
    let square: BoxSquare
    let isCurrentWinner: Bool

    var rowNumber: Int {
        pool.awayNumbers[square.row]
    }

    var colNumber: Int {
        pool.homeNumbers[square.column]
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                Text("\(rowNumber)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text("-")
                    .font(.system(size: 14))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                Text("\(colNumber)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }

            if isCurrentWinner {
                HStack(spacing: 2) {
                    Image(systemName: "person.text.rectangle")
                        .font(.system(size: 8))
                    Text("LIVE")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(DesignSystem.Colors.liveGreen)
                .cornerRadius(4)
            } else if !square.quarterWins.isEmpty {
                HStack(spacing: 2) {
                    ForEach(square.quarterWins, id: \.self) { q in
                        Text("Q\(q)")
                            .font(.system(size: 8, weight: .bold))
                    }
                }
                .foregroundColor(DesignSystem.Colors.winnerGold)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isCurrentWinner ? DesignSystem.Colors.winnerGold : Color.clear, lineWidth: 2)
        )
    }

    var backgroundColor: Color {
        if isCurrentWinner {
            return DesignSystem.Colors.liveGreen.opacity(0.2)
        } else if !square.quarterWins.isEmpty {
            return DesignSystem.Colors.winnerGold.opacity(0.15)
        }
        return DesignSystem.Colors.backgroundTertiary
    }
}

#Preview {
    MySquaresView()
        .environmentObject(AppState())
}

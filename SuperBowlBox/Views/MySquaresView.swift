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
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search by name", text: $searchName)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()

                    if !searchName.isEmpty {
                        Button {
                            searchName = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(AppCardStyle.cardPaddingCompact)
                .background(
                    RoundedRectangle(cornerRadius: AppCardStyle.cornerRadiusSmall)
                        .fill(Color(.systemGray6))
                        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
                )
                .padding(.horizontal, AppCardStyle.screenHorizontalInset)
                .padding(.vertical, 16)

                if !hasAnythingToShow {
                    EmptyNameView()
                } else {
                    ScrollView {
                        VStack(spacing: AppCardStyle.sectionSpacing) {
                            MySquaresSummaryCard(
                                pools: appState.pools,
                                globalMyName: appState.myName,
                                searchName: searchName
                            )
                            .padding(.horizontal, AppCardStyle.screenHorizontalInset)

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
                                    .padding(.horizontal, AppCardStyle.screenHorizontalInset)
                                }
                            }
                        }
                        .padding(.vertical, 24)
                    }
                }
            }
            .background(AppColors.screenBackground)
            .toolbarBackground(AppColors.screenBackground, for: .navigationBar)
            .navigationTitle("My Squares")
        }
    }
}

struct EmptyNameView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.square.badge.magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("Enter Your Name")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Search for your name to see all your squares across pools")
                .font(.subheadline)
                .foregroundColor(.secondary)
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
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(displayLabel)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                Spacer()
            }

            HStack(spacing: 24) {
                VStack {
                    Text("\(totalSquares)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.fieldGreen)
                    Text("Total Squares")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()
                    .frame(height: 40)

                VStack {
                    Text("\(winningSquares)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.gold)
                    Text("Quarter Wins")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()
                    .frame(height: 40)

                VStack {
                    Text("\(poolCount)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("Pools")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .card()
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
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(squares.count) squares")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
        .card()
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
                    .foregroundColor(.secondary)
                Text("\(colNumber)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }

            if isCurrentWinner {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                    Text("LIVE")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(AppColors.fieldGreen)
                .cornerRadius(4)
            } else if !square.quarterWins.isEmpty {
                HStack(spacing: 2) {
                    ForEach(square.quarterWins, id: \.self) { q in
                        Text("Q\(q)")
                            .font(.system(size: 8, weight: .bold))
                    }
                }
                .foregroundColor(AppColors.gold)
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
                .stroke(isCurrentWinner ? AppColors.gold : Color.clear, lineWidth: 2)
        )
    }

    var backgroundColor: Color {
        if isCurrentWinner {
            return AppColors.fieldGreen.opacity(0.2)
        } else if !square.quarterWins.isEmpty {
            return AppColors.gold.opacity(0.15)
        }
        return Color(.systemGray6)
    }
}

#Preview {
    MySquaresView()
        .environmentObject(AppState())
}

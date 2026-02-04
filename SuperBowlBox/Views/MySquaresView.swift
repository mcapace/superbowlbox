import SwiftUI

struct MySquaresView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchName: String = ""

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
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding()

                if effectiveName.isEmpty {
                    EmptyNameView()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Summary card
                            MySquaresSummaryCard(name: effectiveName, pools: appState.pools)
                                .padding(.horizontal)

                            // Squares by pool
                            ForEach(appState.pools) { pool in
                                let squares = pool.squares(for: effectiveName)
                                if !squares.isEmpty {
                                    PoolSquaresCard(
                                        pool: pool,
                                        squares: squares,
                                        score: appState.scoreService.currentScore
                                    )
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("My Squares")
            .onAppear {
                if searchName.isEmpty && !appState.myName.isEmpty {
                    searchName = appState.myName
                }
            }
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

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Searching for")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(name)
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
                    Text("\(pools.filter { !$0.squares(for: name).isEmpty }.count)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("Pools")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
                .shadow(color: AppColors.cardShadow, radius: 10, y: 5)
        )
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
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground)
                .shadow(color: AppColors.cardShadow, radius: 10, y: 5)
        )
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

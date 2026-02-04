import SwiftUI

struct SquareDetailView: View {
    let pool: BoxGrid
    let square: BoxSquare
    let score: GameScore?
    @Environment(\.dismiss) var dismiss

    var rowNumber: Int {
        pool.awayNumbers[square.row]
    }

    var colNumber: Int {
        pool.homeNumbers[square.column]
    }

    var isCurrentWinner: Bool {
        guard let score = score else { return false }
        return score.awayLastDigit == rowNumber && score.homeLastDigit == colNumber
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Player card
                    VStack(spacing: 16) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: isCurrentWinner ?
                                            [AppColors.gold, AppColors.gold.opacity(0.7)] :
                                            [AppColors.fieldGreen, AppColors.fieldGreen.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)

                            Text(square.initials)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            if isCurrentWinner {
                                Image(systemName: "crown.fill")
                                    .font(.title2)
                                    .foregroundColor(AppColors.gold)
                                    .offset(y: -60)
                            }
                        }
                        .shadow(
                            color: (isCurrentWinner ? AppColors.gold : AppColors.fieldGreen).opacity(0.3),
                            radius: 15,
                            y: 8
                        )

                        Text(square.displayName)
                            .font(.title)
                            .fontWeight(.bold)

                        if isCurrentWinner {
                            Text("CURRENT WINNER!")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(AppColors.fieldGreen)
                                )
                        }
                    }
                    .padding(.top, 20)

                    // Numbers card
                    VStack(spacing: 16) {
                        Text("Square Numbers")
                            .font(.headline)

                        HStack(spacing: 40) {
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(Color(hex: pool.awayTeam.primaryColor) ?? .red)
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Text("\(rowNumber)")
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    )

                                Text(pool.awayTeam.abbreviation)
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text("Row")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            VStack(spacing: 8) {
                                Circle()
                                    .fill(Color(hex: pool.homeTeam.primaryColor) ?? .blue)
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Text("\(colNumber)")
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    )

                                Text(pool.homeTeam.abbreviation)
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text("Column")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray6))
                    )

                    // Win conditions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Winning Scenarios")
                            .font(.headline)

                        Text("This square wins when:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 8) {
                            WinScenarioRow(
                                awayTeam: pool.awayTeam.abbreviation,
                                homeTeam: pool.homeTeam.abbreviation,
                                awayScore: rowNumber,
                                homeScore: colNumber,
                                example: "\(rowNumber)-\(colNumber)"
                            )

                            WinScenarioRow(
                                awayTeam: pool.awayTeam.abbreviation,
                                homeTeam: pool.homeTeam.abbreviation,
                                awayScore: rowNumber + 10,
                                homeScore: colNumber + 10,
                                example: "\(rowNumber + 10)-\(colNumber + 10)"
                            )

                            WinScenarioRow(
                                awayTeam: pool.awayTeam.abbreviation,
                                homeTeam: pool.homeTeam.abbreviation,
                                awayScore: rowNumber + 20,
                                homeScore: colNumber + 20,
                                example: "\(rowNumber + 20)-\(colNumber + 20)"
                            )
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray6))
                    )

                    // Period wins (quarters, halftime, final, first score)
                    if !square.allWonPeriodLabels.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "trophy.fill")
                                    .foregroundColor(AppColors.gold)
                                Text("Wins")
                                    .font(.headline)
                            }

                            HStack(spacing: 12) {
                                ForEach(square.allWonPeriodLabels, id: \.self) { label in
                                    VStack {
                                        Text(label)
                                            .font(.title3)
                                            .fontWeight(.bold)
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(AppColors.fieldGreen)
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(AppColors.gold.opacity(0.2))
                                    )
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemGray6))
                        )
                    }

                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("Square Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct WinScenarioRow: View {
    let awayTeam: String
    let homeTeam: String
    let awayScore: Int
    let homeScore: Int
    let example: String

    var body: some View {
        HStack {
            Text("\(awayTeam) \(awayScore) - \(homeScore) \(homeTeam)")
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            Text("Last digits: \(awayScore % 10)-\(homeScore % 10)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
        )
    }
}

#Preview {
    SquareDetailView(
        pool: BoxGrid.empty,
        square: BoxSquare(playerName: "John Smith", row: 3, column: 7),
        score: GameScore.mock
    )
}

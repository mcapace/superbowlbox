import SwiftUI

struct ScoreOverlayView: View {
    let score: GameScore
    let pool: BoxGrid
    @Binding var isExpanded: Bool

    var winner: BoxSquare? {
        pool.winningSquare(for: score)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Compact view (always visible)
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    // Live indicator
                    if score.isGameActive {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                    }

                    // Score
                    Text("\(score.awayTeam.abbreviation) \(score.awayScore)")
                        .fontWeight(.bold)
                    Text("-")
                        .foregroundColor(.secondary)
                    Text("\(score.homeScore) \(score.homeTeam.abbreviation)")
                        .fontWeight(.bold)

                    Spacer()

                    // Winning numbers
                    HStack(spacing: 4) {
                        Text("\(score.awayLastDigit)-\(score.homeLastDigit)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.fieldGreen)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
                )
            }
            .buttonStyle(.plain)

            // Expanded view
            if isExpanded {
                VStack(spacing: 16) {
                    Divider()

                    // Quarter info
                    HStack {
                        Text(score.gameStatusText)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        if let winner = winner {
                            HStack(spacing: 4) {
                                Image(systemName: "trophy.fill")
                                    .foregroundColor(AppColors.gold)
                                Text(winner.displayName)
                                    .fontWeight(.semibold)
                            }
                            .font(.caption)
                        }
                    }

                    // Quarter breakdown
                    if score.isGameActive || score.isGameOver {
                        QuarterBreakdownView(score: score, pool: pool)
                    }
                }
                .padding([.horizontal, .bottom])
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

struct QuarterBreakdownView: View {
    let score: GameScore
    let pool: BoxGrid

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...4, id: \.self) { quarter in
                QuarterCell(
                    quarter: quarter,
                    score: score,
                    pool: pool,
                    isCurrent: score.quarter == quarter && score.isGameActive
                )
            }
        }
    }
}

struct QuarterCell: View {
    let quarter: Int
    let score: GameScore
    let pool: BoxGrid
    let isCurrent: Bool

    var quarterScore: (home: Int, away: Int)? {
        score.quarterScores.scoreForQuarter(quarter)
    }

    var winner: BoxSquare? {
        guard let qs = quarterScore else { return nil }
        return pool.squares.flatMap { $0 }.first { square in
            pool.homeNumbers[square.column] == (qs.home % 10) &&
            pool.awayNumbers[square.row] == (qs.away % 10)
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("Q\(quarter)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(isCurrent ? .white : .secondary)

            if let qs = quarterScore {
                Text("\(qs.away % 10)-\(qs.home % 10)")
                    .font(.caption)
                    .fontWeight(.semibold)
            } else if quarter <= score.quarter || score.isGameOver {
                Text("--")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("--")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let winner = winner {
                Text(winner.initials)
                    .font(.system(size: 8))
                    .foregroundColor(isCurrent ? .white : AppColors.gold)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isCurrent ? AppColors.fieldGreen : Color(.systemGray6))
        )
    }
}

// MARK: - Floating Score Pill
struct FloatingScorePill: View {
    let score: GameScore
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 8) {
            if score.isGameActive {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
            }

            Text("\(score.awayTeam.abbreviation) \(score.awayScore) - \(score.homeScore) \(score.homeTeam.abbreviation)")
                .font(.caption)
                .fontWeight(.semibold)

            Text("(\(score.awayLastDigit)-\(score.homeLastDigit))")
                .font(.caption2)
                .foregroundColor(AppColors.fieldGreen)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    VStack {
        ScoreOverlayView(
            score: GameScore.mock,
            pool: BoxGrid.empty,
            isExpanded: .constant(true)
        )
        .padding()

        FloatingScorePill(score: GameScore.mock)
    }
}

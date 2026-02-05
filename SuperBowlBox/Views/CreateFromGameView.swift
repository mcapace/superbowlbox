import SwiftUI

// MARK: - Create pool from a live/upcoming game (pick sport → pick game)

struct CreateFromGameView: View {
    let onSelect: (ListableGame) -> Void
    let onCancel: () -> Void

    @StateObject private var gamesService = GamesService()
    @State private var selectedSport: Sport = .nfl

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Sport picker (scrollable chips so we can add more sports)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Sport.allCases) { sport in
                            Button {
                                HapticService.selection()
                                selectedSport = sport
                            } label: {
                                Text(sport.displayName)
                                    .font(AppTypography.callout)
                                    .fontWeight(selectedSport == sport ? .semibold : .regular)
                                    .foregroundColor(selectedSport == sport ? .white : .primary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(selectedSport == sport ? AppColors.fieldGreen : DesignSystem.Colors.surfaceElevated)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)

                if gamesService.isLoading {
                    Spacer()
                    ProgressView("Loading games…")
                    Spacer()
                } else if let error = gamesService.error, gamesService.games.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "sportscourt")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(error)
                            .font(AppTypography.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    Spacer()
                } else {
                    List(gamesService.games) { game in
                        Button {
                            HapticService.impactMedium()
                            onSelect(game)
                        } label: {
                            GameRowView(game: game)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Create from Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
            .task(id: selectedSport) {
                await gamesService.fetchGames(sport: selectedSport)
            }
        }
    }
}

private struct GameRowView: View {
    let game: ListableGame

    var body: some View {
        HStack(spacing: 16) {
            // Away team
            Circle()
                .fill(Color(hex: game.awayTeam.primaryColor) ?? .gray)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(game.awayTeam.abbreviation)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("\(game.awayTeam.abbreviation) @ \(game.homeTeam.abbreviation)")
                    .font(AppTypography.headline)
                Text(game.statusShort)
                    .font(AppTypography.caption2)
                    .foregroundColor(game.statusShort == "Live" ? .red : .secondary)
            }

            Spacer()

            Circle()
                .fill(Color(hex: game.homeTeam.primaryColor) ?? .gray)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(game.homeTeam.abbreviation)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    CreateFromGameView(
        onSelect: { _ in },
        onCancel: { }
    )
}

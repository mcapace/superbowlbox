import SwiftUI
import UIKit

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
            .navigationTitle("Upcoming Games")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    AppNavBrandView()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
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
        HStack(spacing: 0) {
            TeamLogoView(team: game.awayTeam, size: 40)
                .frame(width: 40, height: 40)
            Spacer(minLength: 0)
            VStack(alignment: .center, spacing: 2) {
                Text("\(game.awayTeam.abbreviation) vs \(game.homeTeam.abbreviation)")
                    .font(AppTypography.headline)
                Text(game.statusShort)
                    .font(AppTypography.caption2)
                    .foregroundColor(game.statusShort == "Live" ? .red : .secondary)
            }
            Spacer(minLength: 0)
            TeamLogoView(team: game.homeTeam, size: 40)
                .frame(width: 40, height: 40)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

struct TeamLogoView: View {
    let team: Team
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: team.primaryColor) ?? .gray)
                .frame(width: size, height: size)
            if let urlString = team.displayLogoURL, let url = URL(string: urlString) {
                LogoImageView(url: url, fallbackText: team.abbreviation, size: size)
            } else {
                Text(team.abbreviation)
                    .font(.system(size: size * 0.3, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    CreateFromGameView(
        onSelect: { _ in },
        onCancel: { }
    )
}

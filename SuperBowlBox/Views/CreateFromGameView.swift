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
            TeamLogoView(team: game.awayTeam, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(game.awayTeam.abbreviation) vs \(game.homeTeam.abbreviation)")
                    .font(AppTypography.headline)
                Text(game.statusShort)
                    .font(AppTypography.caption2)
                    .foregroundColor(game.statusShort == "Live" ? .red : .secondary)
            }

            Spacer()

            TeamLogoView(team: game.homeTeam, size: 40)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
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
                LogoAsyncImage(url: url, fallbackText: team.abbreviation, size: size)
            } else {
                Text(team.abbreviation)
                    .font(.system(size: size * 0.3, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Loads a logo from URL with a browser User-Agent so CDNs (e.g. ESPN) serve the image.
private struct LogoAsyncImage: View {
    let url: URL
    let fallbackText: String
    let size: CGFloat
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.8, height: size * 0.8)
                    .clipShape(Circle())
            } else if failed {
                Text(fallbackText)
                    .font(.system(size: size * 0.3, weight: .bold))
                    .foregroundColor(.white)
            } else {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.7)
            }
        }
        .task(id: url) {
            guard image == nil, !failed else { return }
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                if let uiImage = UIImage(data: data) {
                    image = uiImage
                } else {
                    failed = true
                }
            } catch {
                failed = true
            }
        }
    }
}

#Preview {
    CreateFromGameView(
        onSelect: { _ in },
        onCancel: { }
    )
}

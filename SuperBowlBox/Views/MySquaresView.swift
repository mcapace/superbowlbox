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
                    ZStack {
                        RoundedRectangle(cornerRadius: DesignSystem.Layout.glassCornerRadius)
                            .fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: DesignSystem.Layout.glassCornerRadius)
                            .strokeBorder(DesignSystem.Colors.glassBorder, lineWidth: 0.8)
                    }
                )
                .glassBevelHighlight(cornerRadius: DesignSystem.Layout.glassCornerRadius)
                .glassDepthShadowsEnhanced()
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
            .navigationTitle("My Boxes")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    AppNavBrandView()
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
                .foregroundColor(DesignSystem.Colors.textTertiary)

            Text("Enter Your Name")
                .font(DesignSystem.Typography.title)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text("Search for your name to see all your boxes across pools")
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
        isOwnerMode ? "My boxes" : searchName
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isOwnerMode ? "Your boxes" : "Searching for")
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
                    Text("Total Boxes")
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
        .liquidGlassCard(cornerRadius: DesignSystem.Layout.glassCornerRadius)
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

    /// One-line payout summary for this pool (e.g. "Quarters · $25 each" or "25% per period").
    private var payoutSummary: String {
        let s = pool.resolvedPoolStructure
        let first = s.payoutDescriptions.first ?? "—"
        if s.payoutDescriptions.count > 1, s.payoutDescriptions.allSatisfy({ $0 == first }) {
            return "\(s.poolTypeLabel) · \(first) each"
        }
        if let total = s.totalPoolAmount, total > 0 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = s.currencyCode
            formatter.maximumFractionDigits = 0
            let totalStr = formatter.string(from: NSNumber(value: total)) ?? "$\(Int(total))"
            return "\(s.poolTypeLabel) · \(totalStr) pool"
        }
        return s.poolTypeLabel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Pool name + box count
            HStack {
                Text(pool.name)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Spacer()
                Text("\(squares.count) \(squares.count == 1 ? "box" : "boxes")")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            // Matchup with team logos (away = rows, home = columns)
            HStack(spacing: 10) {
                TeamLogoView(team: pool.awayTeam, size: 32)
                Text("vs")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                TeamLogoView(team: pool.homeTeam, size: 32)
                Spacer()
            }
            .padding(.vertical, 4)

            // Payout summary
            HStack(spacing: 6) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.winnerGold.opacity(0.9))
                Text(payoutSummary)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            // Grid of my boxes with numbers + payouts
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
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
        .liquidGlassCard(cornerRadius: DesignSystem.Layout.glassCornerRadius)
    }
}

struct SquareNumberCell: View {
    let pool: BoxGrid
    let square: BoxSquare
    let isCurrentWinner: Bool

    var awayNumber: Int { pool.awayNumbers[square.row] }
    var homeNumber: Int { pool.homeNumbers[square.column] }

    /// Payout amount for a given period index (e.g. "Q1" → $25).
    private func payoutForPeriod(_ index: Int) -> String? {
        guard index >= 0, index < pool.resolvedPoolStructure.periods.count else { return nil }
        if let amount = pool.resolvedPoolStructure.amountPerPeriod(at: index), amount > 0 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = pool.resolvedPoolStructure.currencyCode
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: amount))
        }
        return pool.resolvedPoolStructure.payoutDescriptions[safe: index]
    }

    /// Won payouts for this square (e.g. "Q1: $25", "Halftime: $50").
    private var wonPayoutLines: [String] {
        let struct_ = pool.resolvedPoolStructure
        return square.allWonPeriodLabels.compactMap { label in
            guard let idx = struct_.periods.firstIndex(where: { $0.displayLabel == label }) else { return label }
            if let amt = payoutForPeriod(idx) { return "\(label): \(amt)" }
            return label
        }
    }

    /// One short line for potential payout per period (e.g. "$25/period" or "25% each").
    private var potentialPayoutLine: String? {
        let s = pool.resolvedPoolStructure
        guard let first = s.payoutDescriptions.first, !first.isEmpty else { return nil }
        if s.payoutDescriptions.count > 1, s.payoutDescriptions.allSatisfy({ $0 == first }) {
            return "\(first)/period"
        }
        return first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Square combo: Away # – Home # with team context
            HStack(spacing: 6) {
                VStack(spacing: 2) {
                    TeamLogoView(team: pool.awayTeam, size: 22)
                    Text("\(awayNumber)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                Text("–")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                VStack(spacing: 2) {
                    TeamLogoView(team: pool.homeTeam, size: 22)
                    Text("\(homeNumber)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                Spacer(minLength: 0)
            }

            // Status: LIVE or quarter wins
            if isCurrentWinner {
                HStack(spacing: 4) {
                    Image(systemName: "livephoto")
                        .font(.system(size: 9))
                    Text("LIVE")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(DesignSystem.Colors.liveGreen)
                .cornerRadius(6)
            } else if !square.quarterWins.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Won")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.winnerGold)
                    ForEach(wonPayoutLines, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            } else if let potential = potentialPayoutLine {
                Text("Potential: \(potential)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundColor)
                if !isCurrentWinner && square.quarterWins.isEmpty {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial.opacity(0.5))
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isCurrentWinner ? DesignSystem.Colors.liveGreen : DesignSystem.Colors.glassBorder.opacity(0.5), lineWidth: isCurrentWinner ? 2 : 0.6)
        )
        .glassBevelHighlight(cornerRadius: 10)
        .glassDepthShadowsEnhanced()
    }

    var backgroundColor: Color {
        if isCurrentWinner {
            return DesignSystem.Colors.liveGreen.opacity(0.2)
        } else if !square.quarterWins.isEmpty {
            return DesignSystem.Colors.winnerGold.opacity(0.15)
        }
        return DesignSystem.Colors.backgroundTertiary.opacity(0.8)
    }
}

// Safe array subscript for payout descriptions.
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    MySquaresView()
        .environmentObject(AppState())
}

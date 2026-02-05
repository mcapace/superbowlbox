import SwiftUI

/// Shown after user picks a game: enter your number(s) for each team and optionally add more boxes.
struct EnterMyNumbersView: View {
    let game: ListableGame
    let onSave: (BoxGrid) -> Void
    let onCancel: () -> Void

    @EnvironmentObject var appState: AppState

    @State private var poolName: String = ""
    @State private var boxes: [(homeDigit: Int, awayDigit: Int)] = [(0, 0)]
    @State private var ownerName: String = ""
    @State private var payoutTypeOption: PayoutTypeOption = .byQuarter
    @State private var totalPoolAmountText: String = ""
    @State private var customPayoutDescription: String = ""

    private var totalPoolAmount: Double? {
        guard !totalPoolAmountText.isEmpty,
              let v = Double(totalPoolAmountText.trimmingCharacters(in: .whitespaces)),
              v >= 0 else { return nil }
        return v
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Pool name", text: $poolName)
                } header: {
                    Text("Pool Name")
                }

                Section {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(Color(hex: game.awayTeam.primaryColor) ?? .gray)
                            .frame(width: 44, height: 44)
                            .overlay(Text(game.awayTeam.abbreviation).font(.caption2).fontWeight(.bold).foregroundColor(.white))
                        Text("vs")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Circle()
                            .fill(Color(hex: game.homeTeam.primaryColor) ?? .gray)
                            .frame(width: 44, height: 44)
                            .overlay(Text(game.homeTeam.abbreviation).font(.caption2).fontWeight(.bold).foregroundColor(.white))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } header: {
                    Text("Game")
                }

                Section {
                    TextField("Your name (as on sheet)", text: $ownerName)
                        .textContentType(.name)
                } header: {
                    Text("Your Name")
                } footer: {
                    Text("Used to find and highlight your squares in this pool.")
                }

                Section {
                    ForEach(Array(boxes.enumerated()), id: \.offset) { index, _ in
                        MyBoxRow(
                            homeTeam: game.homeTeam,
                            awayTeam: game.awayTeam,
                            homeDigit: Binding(
                                get: { boxes[index].homeDigit },
                                set: { newVal in
                                    var b = boxes
                                    b[index].homeDigit = newVal
                                    boxes = b
                                }
                            ),
                            awayDigit: Binding(
                                get: { boxes[index].awayDigit },
                                set: { newVal in
                                    var b = boxes
                                    b[index].awayDigit = newVal
                                    boxes = b
                                }
                            ),
                            boxNumber: index + 1,
                            onRemove: boxes.count > 1 ? { boxes.remove(at: index) } : nil
                        )
                    }

                    Button {
                        HapticService.selection()
                        boxes.append((0, 0))
                    } label: {
                        Label("Add another box", systemImage: "plus.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(AppColors.fieldGreen)
                    }
                } header: {
                    Text("Your numbers")
                } footer: {
                    Text("Enter the column number (home team) and row number (away team) for each of your squares.")
                }

                Section {
                    Picker("When do we pay?", selection: $payoutTypeOption) {
                        ForEach(PayoutTypeOption.allCases, id: \.self) { o in
                            Text(o.label).tag(o)
                        }
                    }
                    .pickerStyle(.menu)

                    HStack {
                        Text("Total pool ($)")
                        TextField("Optional", text: $totalPoolAmountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Describe payouts (optional)")
                            .font(.subheadline)
                        TextField("e.g. $25 per quarter, halftime pays double", text: $customPayoutDescription, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)
                    }
                } header: {
                    Text("How do payouts work?")
                } footer: {
                    Text("Every pool is different. Choose when winners are paid, or type how this pool works so the app can track your winnings.")
                }
            }
            .navigationTitle("Your Numbers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create Pool") {
                        createAndSave()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if poolName.isEmpty {
                    poolName = "\(game.awayTeam.abbreviation) @ \(game.homeTeam.abbreviation)"
                }
                if ownerName.isEmpty, !appState.myName.isEmpty {
                    ownerName = appState.myName
                }
            }
        }
    }

    private func createAndSave() {
        let name = poolName.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = name.isEmpty ? "\(game.awayTeam.abbreviation) @ \(game.homeTeam.abbreviation)" : name
        let owner = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = owner.isEmpty ? nil : [owner]

        let structure = payoutStructure()
        var pool = BoxGrid(
            name: displayName,
            homeTeam: game.homeTeam,
            awayTeam: game.awayTeam,
            homeNumbers: Array(0...9).shuffled(),
            awayNumbers: Array(0...9).shuffled(),
            poolStructure: structure,
            ownerLabels: label
        )

        for box in boxes {
            if let pos = pool.winningPosition(homeDigit: box.homeDigit, awayDigit: box.awayDigit) {
                pool.updateSquare(row: pos.row, column: pos.column, playerName: owner.isEmpty ? "You" : owner)
            }
        }

        onSave(pool)
    }

    private func payoutStructure() -> PoolStructure {
        let desc = customPayoutDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        var s = PoolStructure(
            poolType: payoutTypeOption.poolType,
            payoutStyle: .equalSplit,
            totalPoolAmount: totalPoolAmount,
            currencyCode: "USD",
            customPayoutDescription: desc.isEmpty ? nil : desc
        )
        if totalPoolAmount != nil, payoutTypeOption.periodCount > 0 {
            let pct = 100 / payoutTypeOption.periodCount
            s = PoolStructure(
                poolType: payoutTypeOption.poolType,
                payoutStyle: .percentage(Array(repeating: Double(pct), count: payoutTypeOption.periodCount)),
                totalPoolAmount: totalPoolAmount,
                currencyCode: "USD",
                customPayoutDescription: desc.isEmpty ? nil : desc
            )
        }
        return s
    }
}

// MARK: - Payout type for "from game" flow
private enum PayoutTypeOption: String, CaseIterable {
    case byQuarter = "By quarter (Q1–Q4)"
    case halftimeOnly = "Halftime only"
    case finalOnly = "Final score only"
    case firstScore = "First score"
    case halftimeAndFinal = "Halftime + Final"

    var label: String { rawValue }

    var poolType: PoolType {
        switch self {
        case .byQuarter: return .byQuarter([1, 2, 3, 4])
        case .halftimeOnly: return .halftimeOnly
        case .finalOnly: return .finalOnly
        case .firstScore: return .firstScoreChange
        case .halftimeAndFinal: return .halftimeAndFinal
        }
    }

    var periodCount: Int {
        switch self {
        case .byQuarter: return 4
        case .halftimeOnly, .finalOnly, .firstScore: return 1
        case .halftimeAndFinal: return 2
        }
    }
}

private struct MyBoxRow: View {
    let homeTeam: Team
    let awayTeam: Team
    @Binding var homeDigit: Int
    @Binding var awayDigit: Int
    let boxNumber: Int
    let onRemove: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Box \(boxNumber)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                if let onRemove = onRemove {
                    Button {
                        HapticService.impactLight()
                        onRemove()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(DesignSystem.Colors.dangerRed)
                    }
                }
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(homeTeam.abbreviation) (column)")
                        .font(.caption2)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Picker("", selection: $homeDigit) {
                        ForEach(0...9, id: \.self) { n in
                            Text("\(n)").tag(n)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(awayTeam.abbreviation) (row)")
                        .font(.caption2)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Picker("", selection: $awayDigit) {
                        ForEach(0...9, id: \.self) { n in
                            Text("\(n)").tag(n)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    EnterMyNumbersView(
        game: ListableGame(
            id: "1",
            name: "Chiefs vs 49ers",
            homeTeam: .fortyNiners,
            awayTeam: .chiefs,
            status: "Scheduled",
            sport: .nfl
        ),
        onSave: { _ in },
        onCancel: { }
    )
    .environmentObject(AppState())
}

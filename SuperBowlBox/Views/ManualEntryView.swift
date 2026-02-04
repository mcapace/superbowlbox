import SwiftUI

struct ManualEntryView: View {
    let onSave: (BoxGrid) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var currentStep = 0
    @State private var poolName = ""
    @State private var homeTeam = Team.chiefs
    @State private var awayTeam = Team.eagles
    @State private var homeNumbers: [Int] = Array(0...9)
    @State private var awayNumbers: [Int] = Array(0...9)
    @State private var grid: [[String]] = Array(repeating: Array(repeating: "", count: 10), count: 10)
    @State private var currentRow = 0
    @State private var quickNames: [String] = []
    @State private var showingNameInput = false
    @State private var newQuickName = ""

    var body: some View {
        NavigationStack {
            VStack {
                // Progress indicator
                ProgressBar(currentStep: currentStep, totalSteps: 4)
                    .padding()

                // Step content
                switch currentStep {
                case 0:
                    PoolInfoStep(
                        poolName: $poolName,
                        homeTeam: $homeTeam,
                        awayTeam: $awayTeam
                    )
                case 1:
                    NumbersStep(
                        homeTeam: homeTeam,
                        awayTeam: awayTeam,
                        homeNumbers: $homeNumbers,
                        awayNumbers: $awayNumbers
                    )
                case 2:
                    NamesEntryStep(
                        grid: $grid,
                        currentRow: $currentRow,
                        quickNames: $quickNames,
                        homeNumbers: homeNumbers,
                        awayNumbers: awayNumbers,
                        homeTeam: homeTeam,
                        awayTeam: awayTeam,
                        onAddQuickName: { showingNameInput = true }
                    )
                case 3:
                    ReviewStep(
                        poolName: poolName,
                        homeTeam: homeTeam,
                        awayTeam: awayTeam,
                        homeNumbers: homeNumbers,
                        awayNumbers: awayNumbers,
                        grid: grid
                    )
                default:
                    EmptyView()
                }

                Spacer()

                // Navigation buttons
                HStack {
                    if currentStep > 0 {
                        Button {
                            withAnimation {
                                currentStep -= 1
                            }
                        } label: {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }

                    Button {
                        if currentStep < 3 {
                            withAnimation {
                                currentStep += 1
                            }
                        } else {
                            savePool()
                        }
                    } label: {
                        HStack {
                            Text(currentStep == 3 ? "Create Pool" : "Next")
                            if currentStep < 3 {
                                Image(systemName: "chevron.right")
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(AppColors.fieldGreen)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Create Pool")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Add Quick Name", isPresented: $showingNameInput) {
                TextField("Name", text: $newQuickName)
                Button("Add") {
                    if !newQuickName.isEmpty {
                        quickNames.append(newQuickName)
                        newQuickName = ""
                    }
                }
                Button("Cancel", role: .cancel) {
                    newQuickName = ""
                }
            }
        }
    }

    private func savePool() {
        var pool = BoxGrid(
            name: poolName.isEmpty ? "My Pool" : poolName,
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            homeNumbers: homeNumbers,
            awayNumbers: awayNumbers
        )

        for row in 0..<10 {
            for col in 0..<10 {
                pool.updateSquare(row: row, column: col, playerName: grid[row][col])
            }
        }

        onSave(pool)
        dismiss()
    }
}

// MARK: - Progress Bar
struct ProgressBar: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Rectangle()
                    .fill(step <= currentStep ? AppColors.fieldGreen : Color(.systemGray4))
                    .frame(height: 4)
                    .cornerRadius(2)
            }
        }
    }
}

// MARK: - Step 1: Pool Info
struct PoolInfoStep: View {
    @Binding var poolName: String
    @Binding var homeTeam: Team
    @Binding var awayTeam: Team

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Step 1: Pool Information")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Name your pool and select the teams")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Pool Name")
                        .font(.headline)
                    TextField("e.g., Office Pool 2025", text: $poolName)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Home Team (Columns)")
                        .font(.headline)
                    TeamPicker(selectedTeam: $homeTeam)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Away Team (Rows)")
                        .font(.headline)
                    TeamPicker(selectedTeam: $awayTeam)
                }
            }
            .padding()
        }
    }
}

struct TeamPicker: View {
    @Binding var selectedTeam: Team

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Team.allTeams, id: \.id) { team in
                    Button {
                        selectedTeam = team
                    } label: {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: team.primaryColor) ?? .gray)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Text(team.abbreviation)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(selectedTeam.id == team.id ? AppColors.fieldGreen : Color.clear, lineWidth: 3)
                                )

                            Text(team.abbreviation)
                                .font(.caption2)
                                .foregroundColor(selectedTeam.id == team.id ? AppColors.fieldGreen : .secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Step 2: Numbers
struct NumbersStep: View {
    let homeTeam: Team
    let awayTeam: Team
    @Binding var homeNumbers: [Int]
    @Binding var awayNumbers: [Int]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Step 2: Numbers")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Set the numbers for each team or randomize")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Home team numbers
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("\(homeTeam.abbreviation) - Columns")
                            .font(.headline)
                        Spacer()
                        Button("Shuffle") {
                            withAnimation {
                                homeNumbers.shuffle()
                            }
                        }
                        .font(.caption)
                        .foregroundColor(AppColors.fieldGreen)
                    }

                    NumbersRow(numbers: homeNumbers, color: Color(hex: homeTeam.primaryColor) ?? .blue)
                }

                // Away team numbers
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("\(awayTeam.abbreviation) - Rows")
                            .font(.headline)
                        Spacer()
                        Button("Shuffle") {
                            withAnimation {
                                awayNumbers.shuffle()
                            }
                        }
                        .font(.caption)
                        .foregroundColor(AppColors.fieldGreen)
                    }

                    NumbersRow(numbers: awayNumbers, color: Color(hex: awayTeam.primaryColor) ?? .red)
                }

                // Randomize both
                Button {
                    withAnimation {
                        homeNumbers.shuffle()
                        awayNumbers.shuffle()
                    }
                } label: {
                    Label("Randomize Both", systemImage: "shuffle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }

                // Note
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("In traditional pools, numbers are randomized after all squares are sold to keep it fair.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                )
            }
            .padding()
        }
    }
}

struct NumbersRow: View {
    let numbers: [Int]
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<10, id: \.self) { index in
                Text("\(numbers[index])")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .frame(width: 28, height: 28)
                    .background(color.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }
        }
    }
}

// MARK: - Step 3: Names Entry
struct NamesEntryStep: View {
    @Binding var grid: [[String]]
    @Binding var currentRow: Int
    @Binding var quickNames: [String]
    let homeNumbers: [Int]
    let awayNumbers: [Int]
    let homeTeam: Team
    let awayTeam: Team
    let onAddQuickName: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Step 3: Enter Names")
                    .font(.title2)
                    .fontWeight(.bold)
                HStack {
                    Text("Row \(currentRow + 1) of 10")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Number: \(awayNumbers[currentRow])")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: awayTeam.primaryColor)?.opacity(0.8) ?? .red)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal)

            // Quick names
            if !quickNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(quickNames, id: \.self) { name in
                            Button {
                                // Fill next empty cell with this name
                                if let col = grid[currentRow].firstIndex(where: { $0.isEmpty }) {
                                    grid[currentRow][col] = name
                                }
                            } label: {
                                Text(name)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(AppColors.fieldGreen.opacity(0.2))
                                    )
                                    .foregroundColor(AppColors.fieldGreen)
                            }
                        }

                        Button {
                            onAddQuickName()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(AppColors.fieldGreen)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            // Row entry
            ScrollView {
                VStack(spacing: 8) {
                    // Header
                    HStack(spacing: 4) {
                        Text("#")
                            .font(.caption2)
                            .frame(width: 24)
                        ForEach(0..<10, id: \.self) { col in
                            Text("\(homeNumbers[col])")
                                .font(.system(size: 10, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                                .background(Color(hex: homeTeam.primaryColor)?.opacity(0.8) ?? .blue)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }

                    // Current row
                    HStack(spacing: 4) {
                        Text("\(awayNumbers[currentRow])")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 24, height: 36)
                            .background(Color(hex: awayTeam.primaryColor)?.opacity(0.8) ?? .red)
                            .foregroundColor(.white)
                            .cornerRadius(4)

                        ForEach(0..<10, id: \.self) { col in
                            TextField("", text: $grid[currentRow][col])
                                .font(.system(size: 10))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(Color(.systemGray6))
                                .cornerRadius(4)
                        }
                    }
                }
                .padding(.horizontal)

                // Row navigation
                HStack {
                    Button {
                        if currentRow > 0 {
                            currentRow -= 1
                        }
                    } label: {
                        Image(systemName: "chevron.up")
                            .padding()
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                    }
                    .disabled(currentRow == 0)

                    Spacer()

                    Text("Row \(currentRow + 1)")
                        .font(.headline)

                    Spacer()

                    Button {
                        if currentRow < 9 {
                            currentRow += 1
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .padding()
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                    }
                    .disabled(currentRow == 9)
                }
                .padding()

                // Fill options
                HStack(spacing: 12) {
                    Button {
                        grid[currentRow] = Array(repeating: "", count: 10)
                    } label: {
                        Label("Clear Row", systemImage: "trash")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    if !quickNames.isEmpty {
                        Button {
                            for col in 0..<10 {
                                if grid[currentRow][col].isEmpty {
                                    grid[currentRow][col] = quickNames.randomElement() ?? ""
                                }
                            }
                        } label: {
                            Label("Fill Random", systemImage: "dice")
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Step 4: Review
struct ReviewStep: View {
    let poolName: String
    let homeTeam: Team
    let awayTeam: Team
    let homeNumbers: [Int]
    let awayNumbers: [Int]
    let grid: [[String]]

    var filledCount: Int {
        grid.flatMap { $0 }.filter { !$0.isEmpty }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Step 4: Review")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Review your pool before saving")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Pool info
                VStack(spacing: 12) {
                    HStack {
                        Text("Pool Name")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(poolName.isEmpty ? "My Pool" : poolName)
                            .fontWeight(.semibold)
                    }

                    Divider()

                    HStack {
                        Text("Teams")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(awayTeam.abbreviation) vs \(homeTeam.abbreviation)")
                            .fontWeight(.semibold)
                    }

                    Divider()

                    HStack {
                        Text("Squares Filled")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(filledCount) / 100")
                            .fontWeight(.semibold)
                            .foregroundColor(filledCount == 100 ? .green : .orange)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )

                // Mini preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("Grid Preview")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ReviewGridPreview(
                        grid: grid,
                        homeNumbers: homeNumbers,
                        awayNumbers: awayNumbers,
                        homeColor: Color(hex: homeTeam.primaryColor) ?? .blue,
                        awayColor: Color(hex: awayTeam.primaryColor) ?? .red
                    )
                }

                // Warning if not complete
                if filledCount < 100 {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Your pool has \(100 - filledCount) empty squares. You can still create it and fill them later.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange.opacity(0.1))
                    )
                }
            }
            .padding()
        }
    }
}

struct ReviewGridPreview: View {
    let grid: [[String]]
    let homeNumbers: [Int]
    let awayNumbers: [Int]
    let homeColor: Color
    let awayColor: Color

    var body: some View {
        VStack(spacing: 1) {
            // Header
            HStack(spacing: 1) {
                Color.clear.frame(width: 20, height: 20)
                ForEach(0..<10, id: \.self) { col in
                    Text("\(homeNumbers[col])")
                        .font(.system(size: 8, weight: .bold))
                        .frame(width: 20, height: 20)
                        .background(homeColor.opacity(0.8))
                        .foregroundColor(.white)
                }
            }

            // Rows
            ForEach(0..<10, id: \.self) { row in
                HStack(spacing: 1) {
                    Text("\(awayNumbers[row])")
                        .font(.system(size: 8, weight: .bold))
                        .frame(width: 20, height: 20)
                        .background(awayColor.opacity(0.8))
                        .foregroundColor(.white)

                    ForEach(0..<10, id: \.self) { col in
                        let name = grid[row][col]
                        Rectangle()
                            .fill(name.isEmpty ? Color(.systemGray5) : Color.blue.opacity(0.4))
                            .frame(width: 20, height: 20)
                            .overlay(
                                Text(String(name.prefix(2)).uppercased())
                                    .font(.system(size: 6))
                                    .foregroundColor(.white)
                            )
                    }
                }
            }
        }
        .background(Color(.systemGray4))
        .cornerRadius(8)
    }
}

#Preview {
    ManualEntryView { _ in }
}

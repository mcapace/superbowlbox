import SwiftUI
import PhotosUI

struct ScannerView: View {
    let onPoolScanned: (BoxGrid) -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @StateObject private var visionService = VisionService()
    @StateObject private var gamesService = GamesService()

    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var selectedImage: UIImage?
    @State private var scannedPool: BoxGrid?
    @State private var showingManualEntry = false
    @State private var scanProgress: ScanProgress = .selectingGame
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedSport: Sport = .nfl
    @State private var selectedGameForScan: ListableGame?
    /// Name(s) and pool name entered before OCR, so we match and pre-fill the review step.
    @State private var ownerNameFieldsBeforeScan: [String] = [""]
    @State private var poolNameBeforeScan: String = ""

    enum ScanProgress {
        case selectingGame
        case idle
        case enteringName
        case processing
        case reviewing
        case error(String)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                switch scanProgress {
                case .selectingGame:
                    SelectGameForScanView(
                        gamesService: gamesService,
                        selectedSport: $selectedSport,
                        selectedGame: $selectedGameForScan,
                        onContinue: {
                            HapticService.selection()
                            scanProgress = .idle
                        },
                        onSkip: {
                            selectedGameForScan = nil
                            scanProgress = .idle
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))

                case .idle:
                    IdleScanView(
                        onCameraSelected: { showingCamera = true },
                        onPhotoSelected: { showingImagePicker = true },
                        onManualEntry: { showingManualEntry = true }
                    )

                case .enteringName:
                    if let image = selectedImage {
                        EnterNameForScanView(
                            image: image,
                            ownerNameFields: $ownerNameFieldsBeforeScan,
                            poolName: $poolNameBeforeScan,
                            onContinue: { startOCRWithEnteredName() },
                            onChooseDifferentImage: {
                                selectedImage = nil
                                scanProgress = .idle
                            }
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }

                case .processing:
                    ProcessingScanView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))

                case .reviewing:
                    if scannedPool != nil {
                        ReviewScanView(
                            pool: $scannedPool.unwrap(default: BoxGrid.empty),
                            image: selectedImage,
                            onConfirm: { poolToSave in
                                HapticService.success()
                                var pool = poolToSave
                                if pool.name == "Scanned Pool" || pool.name.isEmpty, let game = selectedGameForScan {
                                    pool.name = "\(game.awayTeam.abbreviation) @ \(game.homeTeam.abbreviation)"
                                }
                                onPoolScanned(pool)
                                dismiss()
                            },
                            onRetry: {
                                HapticService.impactLight()
                                scanProgress = .idle
                                selectedImage = nil
                                scannedPool = nil
                                ownerNameFieldsBeforeScan = [""]
                                poolNameBeforeScan = ""
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98)),
                            removal: .opacity
                        ))
                    }

                case .error(let message):
                    ErrorScanView(
                        message: message,
                        onRetry: {
                            HapticService.impactMedium()
                            scanProgress = .selectingGame
                            selectedImage = nil
                            ownerNameFieldsBeforeScan = [""]
                            poolNameBeforeScan = ""
                        },
                        onManualEntry: {
                            HapticService.selection()
                            showingManualEntry = true
                        }
                    )
                }
            }
            .navigationTitle("Scan Pool Sheet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraView(
                    onCapture: { handleCapturedImage($0) },
                    onCaptureFailed: { error in
                        scanProgress = .error(error.localizedDescription)
                        showingCamera = false
                    },
                    onDismiss: { showingCamera = false }
                )
            }
            .photosPicker(isPresented: $showingImagePicker, selection: $selectedItem, matching: .images)
            .onChange(of: selectedItem) { _, newValue in
                if let item = newValue {
                    loadImage(from: item)
                }
            }
            .sheet(isPresented: $showingManualEntry) {
                ManualEntryView { pool in
                    onPoolScanned(pool)
                    dismiss()
                }
                .environmentObject(appState)
            }
            .background(SportsbookBackgroundView())
        }
    }

    private func loadImage(from item: PhotosPickerItem) {
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    handleCapturedImage(image)
                }
            }
        }
    }

    private func handleCapturedImage(_ image: UIImage) {
        // Called on main from camera delegate. Update state immediately so the sheet dismisses
        // and we show "Your name as on sheet" before any VC dismiss runs.
        showingCamera = false
        selectedImage = image
        ownerNameFieldsBeforeScan = [""]
        poolNameBeforeScan = ""
        if !appState.myName.isEmpty {
            ownerNameFieldsBeforeScan[0] = appState.myName
        }
        withAnimation(.appReveal) {
            scanProgress = .enteringName
        }
    }

    /// Run OCR after user has entered their name as on sheet; then match and show review.
    private func startOCRWithEnteredName() {
        guard let image = selectedImage else { return }
        Task { @MainActor in
            withAnimation(.appReveal) {
                scanProgress = .processing
            }
        }
        Task {
            do {
                let pool = try await visionService.processImage(image)
                let names = ownerNameFieldsBeforeScan
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                let poolName = poolNameBeforeScan.trimmingCharacters(in: .whitespacesAndNewlines)
                await MainActor.run {
                    var poolToReview = pool
                    poolToReview.ownerLabels = names.isEmpty ? nil : names
                    poolToReview.name = poolName.isEmpty ? "Scanned Pool" : poolName
                    // Use selected game for team identities; confirm column/row order from the scan
                    if let game = selectedGameForScan {
                        let ocrColumnTeam = pool.homeTeam   // OCR: team on columns (header row)
                        let ocrRowTeam = pool.awayTeam     // OCR: team on rows (left strip)
                        if ocrColumnTeam.id == game.homeTeam.id {
                            poolToReview.homeTeam = game.homeTeam
                            poolToReview.awayTeam = game.awayTeam
                        } else if ocrColumnTeam.id == game.awayTeam.id {
                            poolToReview.homeTeam = game.awayTeam
                            poolToReview.awayTeam = game.homeTeam
                        } else if ocrRowTeam.id == game.awayTeam.id {
                            poolToReview.homeTeam = game.homeTeam
                            poolToReview.awayTeam = game.awayTeam
                        } else if ocrRowTeam.id == game.homeTeam.id {
                            poolToReview.homeTeam = game.awayTeam
                            poolToReview.awayTeam = game.homeTeam
                        } else {
                            // OCR didn’t match (e.g. unknown); default to game order
                            poolToReview.homeTeam = game.homeTeam
                            poolToReview.awayTeam = game.awayTeam
                        }
                    }
                    scannedPool = poolToReview
                    withAnimation(.appEntrance) {
                        scanProgress = .reviewing
                    }
                    HapticService.success()
                }
            } catch {
                await MainActor.run {
                    withAnimation(.appReveal) {
                        scanProgress = .error(error.localizedDescription)
                    }
                    HapticService.error()
                }
            }
        }
    }
}

// MARK: - Idle View
// MARK: - Select game then scan (sport → game → scan flow)
struct SelectGameForScanView: View {
    @ObservedObject var gamesService: GamesService
    @Binding var selectedSport: Sport
    @Binding var selectedGame: ListableGame?
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Choose sport & game for this pool")
                .font(.headline)
                .multilineTextAlignment(.center)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Sport.allCases) { sport in
                        Button {
                            HapticService.selection()
                            selectedSport = sport
                        } label: {
                            Text(sport.displayName)
                                .font(.callout)
                                .fontWeight(selectedSport == sport ? .semibold : .regular)
                                .foregroundColor(selectedSport == sport ? .white : .primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(selectedSport == sport ? AppColors.fieldGreen : DesignSystem.Colors.surfaceElevated))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }

            if gamesService.isLoading {
                ProgressView("Loading games…")
                    .padding()
            } else if let err = gamesService.error, gamesService.games.isEmpty {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(gamesService.games) { game in
                            Button {
                                HapticService.selection()
                                selectedGame = game
                            } label: {
                                HStack(spacing: 12) {
                                    TeamLogoView(team: game.awayTeam, size: 32)
                                    Text("\(game.awayTeam.abbreviation) @ \(game.homeTeam.abbreviation)")
                                        .font(.subheadline)
                                        .fontWeight(selectedGame?.id == game.id ? .semibold : .regular)
                                    Spacer()
                                    TeamLogoView(team: game.homeTeam, size: 32)
                                    if selectedGame?.id == game.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(AppColors.fieldGreen)
                                    }
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(RoundedRectangle(cornerRadius: 8).fill(selectedGame?.id == game.id ? AppColors.fieldGreen.opacity(0.2) : DesignSystem.Colors.surfaceElevated))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxHeight: 220)
            }

            HStack(spacing: 12) {
                Button {
                    onSkip()
                } label: {
                    Text("Skip")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(DesignSystem.Colors.surfaceElevated)
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
                Button {
                    onContinue()
                } label: {
                    Text("Continue to scan")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.fieldGreen)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
        }
        .padding()
        .task(id: selectedSport) {
            await gamesService.fetchGames(sport: selectedSport)
        }
    }
}

struct IdleScanView: View {
    let onCameraSelected: () -> Void
    let onPhotoSelected: () -> Void
    let onManualEntry: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            // Illustration
            VStack(spacing: 16) {
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DesignSystem.Colors.accentBlue, DesignSystem.Colors.accentBlue.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Text("Scan Your Pool Sheet")
                    .font(DesignSystem.Typography.title)
                    .fontWeight(.bold)

                Text("Take a photo or choose an image of your pool or box sheet")
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Action buttons (with staggered entrance feel)
            VStack(spacing: 16) {
                Button {
                    onCameraSelected()
                } label: {
                    HStack {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                        VStack(alignment: .leading) {
                            Text("Take Photo")
                                .font(.headline)
                            Text("Use camera to capture sheet")
                                .font(.caption)
                                .opacity(0.8)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppColors.fieldGreen)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(AppColors.techCyan.opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    onPhotoSelected()
                } label: {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title2)
                        VStack(alignment: .leading) {
                            Text("Choose Photo")
                                .font(.headline)
                            Text("Select from photo library")
                                .font(.caption)
                                .opacity(0.8)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(DesignSystem.Colors.surfaceElevated)
                    )
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    onManualEntry()
                } label: {
                    HStack {
                        Image(systemName: "square.and.pencil")
                            .font(.title2)
                        VStack(alignment: .leading) {
                            Text("Manual Entry")
                                .font(.headline)
                            Text("Enter names manually")
                                .font(.caption)
                                .opacity(0.8)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(DesignSystem.Colors.surfaceElevated)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal)

            Spacer()

            // Tips
            VStack(alignment: .leading, spacing: 8) {
                Text("Tips for best results:")
                    .font(.caption)
                    .fontWeight(.semibold)

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text("Ensure good lighting and keep the sheet flat")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "crop")
                        .foregroundColor(AppColors.fieldGreen)
                    Text("Include the full grid with all numbers visible")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(DesignSystem.Colors.surfaceElevated)
            )
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

// MARK: - Enter Name (before OCR) – name as on sheet, then we match via OCR
struct EnterNameForScanView: View {
    let image: UIImage
    @Binding var ownerNameFields: [String]
    @Binding var poolName: String
    let onContinue: () -> Void
    let onChooseDifferentImage: () -> Void
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("We’ll use your name to find and highlight your boxes on the sheet.")
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                // Thumbnail
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(DesignSystem.Colors.textMuted, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Your name as it appears on the sheet")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Enter exactly how your name is written on the pool sheet so we can match it.")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    ForEach(ownerNameFields.indices, id: \.self) { index in
                        HStack {
                            TextField("Name on sheet", text: $ownerNameFields[index])
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                            if ownerNameFields.count > 1 {
                                Button {
                                    ownerNameFields.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    Button {
                        ownerNameFields.append("")
                    } label: {
                        Label("I have more than one box", systemImage: "plus.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(AppColors.fieldGreen)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(DesignSystem.Colors.surfaceElevated)
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Pool name (optional)")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    TextField("e.g. Super Bowl Pool", text: $poolName)
                        .textFieldStyle(.roundedBorder)
                }

                Button {
                    HapticService.impactLight()
                    onContinue()
                } label: {
                    Text("Continue")
                        .font(DesignSystem.Typography.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.fieldGreen)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Button {
                    onChooseDifferentImage()
                } label: {
                    Text("Use a different photo")
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .onAppear {
            if ownerNameFields == [""], !appState.myName.isEmpty {
                ownerNameFields[0] = appState.myName
            }
        }
    }
}

// MARK: - Processing View (tech-style loading)
struct ProcessingScanView: View {
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(DesignSystem.Colors.cardBorder, lineWidth: 4)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: 0.35)
                    .stroke(
                        LinearGradient(
                            colors: [AppColors.techCyan, AppColors.fieldGreen],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(rotationAngle))

                Image(systemName: "text.viewfinder")
                    .font(.system(size: 40))
                    .foregroundStyle(DesignSystem.Colors.accentBlue)
                    .scaleEffect(appeared ? pulseScale : 0.8)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    rotationAngle = 360
                }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulseScale = 1.08
                }
                withAnimation(.appEntrance) {
                    appeared = true
                }
            }

            VStack(spacing: 8) {
                Text("Analyzing Image...")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Detecting grid and reading names")
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Spacer()
        }
    }
}

// MARK: - Review View
struct ReviewScanView: View {
    @Binding var pool: BoxGrid
    let image: UIImage?
    /// Called with the pool to save (including name + ownerLabels). Use this so the saved pool always has the latest fields.
    let onConfirm: (BoxGrid) -> Void
    let onRetry: () -> Void
    @EnvironmentObject var appState: AppState

    @State private var poolName: String = ""
    @State private var showingImagePreview = false
    /// Names as they appear on this sheet (so we can find your boxes). First = primary; add more if you have multiple boxes.
    @State private var ownerNameFields: [String] = [""]
    /// Editable detected numbers (e.g. "9 6 4 1 5 7 8 2 3 0"). Applied on confirm if valid.
    @State private var columnNumbersText: String = ""
    @State private var rowNumbersText: String = ""
    /// Free-text payout rules (e.g. "$25 per quarter, halftime pays double").
    @State private var payoutRulesText: String = ""
    @State private var payoutParseInProgress: Bool = false
    @State private var payoutParsedSummary: String? = nil
    @State private var payoutParseError: String? = nil
    @State private var showingGridEditor: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Success indicator
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    Text("Scan Complete!")
                        .font(DesignSystem.Typography.headline)
                    Spacer()
                    if image != nil {
                        Button("View Image") {
                            showingImagePreview = true
                        }
                        .font(.caption)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.1))
                )

                // Pool name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pool Name")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    TextField("Enter pool name", text: $poolName)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: poolName) { _, newValue in
                            pool.name = newValue
                        }
                }

                // Your name(s) on the sheet — we find every box that matches (supports multiple boxes)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your name(s) on this sheet")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Enter exactly how your name is written. We’ll find every box that matches. Add a row for each different name if you have multiple boxes.")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    ForEach(ownerNameFields.indices, id: \.self) { index in
                        HStack {
                            TextField("Name as on sheet", text: $ownerNameFields[index])
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                            if ownerNameFields.count > 1 {
                                Button {
                                    ownerNameFields.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    Button {
                        ownerNameFields.append("")
                    } label: {
                        Label("I have more than one box", systemImage: "plus.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(AppColors.fieldGreen)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(DesignSystem.Colors.surfaceElevated)
                )

                // Stats
                let effectiveLabels = ownerNameFields.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                let mySquaresCount = effectiveLabels.isEmpty ? 0 : pool.squaresForOwner(ownerLabels: effectiveLabels).count

                HStack(spacing: 12) {
                    StatBox(title: "Names on Sheet", value: "\(pool.filledCount)", icon: "person.fill")
                    StatBox(title: "Your Boxes", value: "\(mySquaresCount)", icon: "star.fill")
                    StatBox(title: "Empty", value: "\(100 - pool.filledCount)", icon: "square.dashed")
                }
                .frame(maxWidth: .infinity)
                if !effectiveLabels.isEmpty && mySquaresCount == 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No boxes matched \"\(effectiveLabels.joined(separator: "\", \""))\". Check spelling above or tap Edit full grid to fix any misread names.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal)
                }

                // Grid preview + backup edit
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Grid preview")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Spacer()
                        Button {
                            showingGridEditor = true
                        } label: {
                            Label("Edit full grid", systemImage: "square.grid.3x3.fill")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.fieldGreen)
                        }
                    }
                    Text("If the scan got a name wrong, tap Edit full grid to fix any cell.")
                        .font(.caption2)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    MiniGridPreview(pool: pool, score: nil)
                        .frame(height: 150)
                }

                // Detected numbers — editable if wrong
                VStack(alignment: .leading, spacing: 8) {
                    Text("Detected Numbers")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text("10 digits 0–9, space-separated. Edit if the scan read them wrong.")
                        .font(.caption2)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top) {
                            Text(pool.homeTeam.id == Team.unknown.id ? "Columns" : "Columns (\(pool.homeTeam.abbreviation))")
                                .font(.caption2)
                                .frame(width: 80, alignment: .leading)
                            TextField("e.g. 9 6 4 1 5 7 8 2 3 0", text: $columnNumbersText)
                                .font(.system(.caption, design: .monospaced))
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numbersAndPunctuation)
                        }
                        HStack(alignment: .top) {
                            Text(pool.awayTeam.id == Team.unknown.id ? "Rows" : "Rows (\(pool.awayTeam.abbreviation))")
                                .font(.caption2)
                                .frame(width: 80, alignment: .leading)
                            TextField("e.g. 2 6 3 0 5 4 7 1 8 9", text: $rowNumbersText)
                                .font(.system(.caption, design: .monospaced))
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numbersAndPunctuation)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(DesignSystem.Colors.surfaceElevated)
                    )
                }

                Button {
                    swapColumnsAndRows()
                } label: {
                    Label("Swap columns & rows", systemImage: "arrow.left.arrow.right")
                        .font(.subheadline)
                        .foregroundColor(AppColors.fieldGreen)
                }

                // Payout rules (optional)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Payout rules (optional)")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Spacer()
                        if PayoutParseConfig.usePayoutParse && !payoutRulesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button {
                                parsePayoutRulesWithAI()
                            } label: {
                                if payoutParseInProgress {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Parse with AI")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(AppColors.fieldGreen)
                                }
                            }
                            .disabled(payoutParseInProgress)
                        }
                    }
                    TextEditor(text: $payoutRulesText)
                        .frame(minHeight: 60)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(DesignSystem.Colors.surfaceElevated)
                        )
                        .overlay(
                            Group {
                                if payoutRulesText.isEmpty {
                                    Text("e.g. $25 per quarter, halftime pays double")
                                        .font(.body)
                                        .foregroundColor(DesignSystem.Colors.textSecondary.opacity(0.6))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 16)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                        .allowsHitTesting(false)
                                }
                            }
                        )
                    if let parsedSummary = payoutParsedSummary {
                        Text(parsedSummary)
                            .font(.caption)
                            .foregroundColor(AppColors.fieldGreen)
                    }
                    if let parseError = payoutParseError {
                        Text(parseError)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        pool.name = poolName.isEmpty ? "Scanned Pool" : poolName
                        applyOwnerLabels()
                        applyEditedNumbersIfValid()
                        var ps = pool.poolStructure ?? PoolStructure.standardQuarterly
                        ps.customPayoutDescription = payoutRulesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : payoutRulesText.trimmingCharacters(in: .whitespacesAndNewlines)
                        pool.poolStructure = ps
                        onConfirm(pool)
                    } label: {
                        Text("Confirm & Save")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColors.fieldGreen)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    Button {
                        onRetry()
                    } label: {
                        Text("Retry Scan")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(DesignSystem.Colors.surfaceElevated)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            poolName = pool.name.isEmpty ? "Scanned Pool" : pool.name
            if ownerNameFields == [""], !appState.myName.isEmpty {
                ownerNameFields[0] = appState.myName
            }
            if let existing = pool.ownerLabels, !existing.isEmpty {
                ownerNameFields = existing
            }
            if columnNumbersText.isEmpty {
                columnNumbersText = pool.homeNumbers.map { String($0) }.joined(separator: " ")
            }
            if rowNumbersText.isEmpty {
                rowNumbersText = pool.awayNumbers.map { String($0) }.joined(separator: " ")
            }
            if payoutRulesText.isEmpty, let desc = pool.poolStructure?.customPayoutDescription {
                payoutRulesText = desc
            }
        }
        .onDisappear {
            applyOwnerLabels()
        }
        .sheet(isPresented: $showingImagePreview) {
            if let image = image {
                ImagePreviewView(image: image)
            }
        }
        .sheet(isPresented: $showingGridEditor) {
            EditableGridSheet(pool: $pool)
        }
    }

    private func applyOwnerLabels() {
        let labels = ownerNameFields
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        pool.ownerLabels = labels.isEmpty ? nil : labels
    }

    /// Call payout-parse backend to interpret payout rules and set pool structure (so current leader, winners, in the hunt, current winnings are correct).
    private func parsePayoutRulesWithAI() {
        let text = payoutRulesText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        payoutParseError = nil
        payoutParsedSummary = nil
        payoutParseInProgress = true
        Task {
            do {
                let parsed = try await PayoutParseService.parse(payoutDescription: text)
                await MainActor.run {
                    var merged = parsed
                    merged.customPayoutDescription = text
                    pool.poolStructure = merged
                    payoutParsedSummary = "Parsed: \(merged.periodLabels.joined(separator: ", "))" + (merged.payoutDescriptions.isEmpty ? "" : " · \(merged.payoutDescriptions.joined(separator: ", "))")
                    payoutParseInProgress = false
                }
            } catch {
                await MainActor.run {
                    payoutParseError = error.localizedDescription
                    payoutParsedSummary = nil
                    payoutParseInProgress = false
                }
            }
        }
    }

    /// Swap columns and rows (teams, number sequences, and transpose grid) so user can fix wrong orientation.
    private func swapColumnsAndRows() {
        swap(&columnNumbersText, &rowNumbersText)
        let hTeam = pool.homeTeam
        let aTeam = pool.awayTeam
        pool.homeTeam = aTeam
        pool.awayTeam = hTeam
        let hNum = pool.homeNumbers
        let aNum = pool.awayNumbers
        pool.homeNumbers = aNum
        pool.awayNumbers = hNum
        var transposed: [[BoxSquare]] = []
        for r in 0..<10 {
            var newRow: [BoxSquare] = []
            for c in 0..<10 {
                let old = pool.squares[c][r]
                newRow.append(BoxSquare(
                    playerName: old.playerName,
                    row: r,
                    column: c,
                    isWinner: old.isWinner,
                    quarterWins: old.quarterWins,
                    winningPeriodIds: old.winningPeriodIds
                ))
            }
            transposed.append(newRow)
        }
        pool.squares = transposed
        HapticService.selection()
    }

    /// Parse edited column/row strings (10 space-separated digits 0–9) and assign to pool if valid.
    private func applyEditedNumbersIfValid() {
        func parseTenDigits(_ s: String) -> [Int]? {
            let parts = s.split(whereSeparator: { $0.isWhitespace }).map { String($0) }
            guard parts.count == 10 else { return nil }
            var out: [Int] = []
            for p in parts {
                guard let n = Int(p), (0...9).contains(n) else { return nil }
                out.append(n)
            }
            return out
        }
        if let cols = parseTenDigits(columnNumbersText) {
            pool.homeNumbers = cols
        }
        if let rows = parseTenDigits(rowNumbersText) {
            pool.awayNumbers = rows
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(AppColors.fieldGreen)
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignSystem.Colors.surfaceElevated)
        )
    }
}

// MARK: - Editable full grid (backup when scan gets a name wrong)
private struct GridCellID: Identifiable, Equatable {
    let row: Int
    let col: Int
    var id: String { "\(row)-\(col)" }
}

struct EditableGridSheet: View {
    @Binding var pool: BoxGrid
    @Environment(\.dismiss) var dismiss
    @State private var editingCell: GridCellID? = nil
    @State private var editingName: String = ""
    @State private var showListView: Bool = false

    private let cellSize: CGFloat = 30
    private let labelWidth: CGFloat = 22

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $showListView) {
                    Text("Grid").tag(false)
                    Text("List").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                if showListView {
                    listView
                } else {
                    gridView
                }
            }
            .navigationTitle("Edit full grid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $editingCell) { cell in
                EditGridCellSheet(
                    name: $editingName,
                    row: cell.row,
                    col: cell.col,
                    pool: pool,
                    onSave: {
                        pool.updateSquare(row: cell.row, column: cell.col, playerName: editingName.trimmingCharacters(in: .whitespacesAndNewlines))
                        editingCell = nil
                    },
                    onDismiss: {
                        editingCell = nil
                    }
                )
            }
        }
    }

    private var gridView: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 2) {
                    Color.clear.frame(width: labelWidth, height: cellSize)
                    ForEach(0..<10, id: \.self) { col in
                        Text("\(pool.homeNumbers[col])")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .frame(width: cellSize, height: cellSize)
                            .background(DesignSystem.Colors.surfaceElevated)
                    }
                }
                ForEach(0..<10, id: \.self) { row in
                    HStack(spacing: 2) {
                        Text("\(pool.awayNumbers[row])")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .frame(width: labelWidth, height: cellSize)
                            .background(DesignSystem.Colors.surfaceElevated)
                        ForEach(0..<10, id: \.self) { col in
                            let name = pool.squares[row][col].playerName
                            let cellId = GridCellID(row: row, col: col)
                            let isEditing = editingCell == cellId
                            Button {
                                editingCell = cellId
                                editingName = name
                            } label: {
                                Text(name.isEmpty ? "—" : name)
                                    .font(.system(size: 9, weight: .regular))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(width: cellSize, height: cellSize)
                                    .padding(2)
                                    .background(isEditing ? AppColors.fieldGreen.opacity(0.3) : DesignSystem.Colors.surfaceElevated)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(8)
        }
    }

    private var listView: some View {
        List {
            ForEach(0..<10, id: \.self) { row in
                Section(header: Text("Row \(pool.awayNumbers[row])")) {
                    ForEach(0..<10, id: \.self) { col in
                        let name = pool.squares[row][col].playerName
                        let cellId = GridCellID(row: row, col: col)
                        Button {
                            editingCell = cellId
                            editingName = name
                        } label: {
                            HStack {
                                Text("Col \(pool.homeNumbers[col])")
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .frame(width: 44, alignment: .leading)
                                Text(name.isEmpty ? "—" : name)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                Spacer()
                                Image(systemName: "pencil")
                                    .font(.caption)
                                    .foregroundColor(AppColors.fieldGreen)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct EditGridCellSheet: View {
    @Binding var name: String
    let row: Int
    let col: Int
    let pool: BoxGrid
    let onSave: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name in this square", text: $name)
                        .autocorrectionDisabled()
                } header: {
                    Text("Row \(pool.awayNumbers[row]), Col \(pool.homeNumbers[col])")
                }
            }
            .navigationTitle("Edit cell")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave() }
                }
            }
        }
    }
}

struct ImagePreviewView: View {
    let image: UIImage
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .navigationTitle("Scanned Image")
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

// MARK: - Error View
struct ErrorScanView: View {
    let message: String
    let onRetry: () -> Void
    let onManualEntry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            VStack(spacing: 8) {
                Text("Scan Failed")
                    .font(DesignSystem.Typography.title)
                    .fontWeight(.bold)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                Button {
                    onRetry()
                } label: {
                    Text("Try Again")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.fieldGreen)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Button {
                    onManualEntry()
                } label: {
                    Text("Enter Manually Instead")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(DesignSystem.Colors.surfaceElevated)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}

// MARK: - Optional Binding Extension
extension Binding {
    func unwrap<T>(default defaultValue: T) -> Binding<T> where Value == T? {
        Binding<T>(
            get: { self.wrappedValue ?? defaultValue },
            set: { self.wrappedValue = $0 }
        )
    }
}

#Preview {
    ScannerView { _ in }
        .environmentObject(AppState())
}

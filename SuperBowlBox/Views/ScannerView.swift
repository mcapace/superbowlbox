import SwiftUI
import PhotosUI

struct ScannerView: View {
    let onPoolScanned: (BoxGrid) -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @StateObject private var visionService = VisionService()

    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var selectedImage: UIImage?
    @State private var scannedPool: BoxGrid?
    @State private var showingManualEntry = false
    @State private var scanProgress: ScanProgress = .idle
    @State private var selectedItem: PhotosPickerItem?
    /// Name(s) and pool name entered before OCR, so we match and pre-fill the review step.
    @State private var ownerNameFieldsBeforeScan: [String] = [""]
    @State private var poolNameBeforeScan: String = ""

    enum ScanProgress {
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
                                onPoolScanned(poolToSave)
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
                            scanProgress = .idle
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
                Text("We’ll use your name to find and highlight your squares on the sheet.")
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
    /// Names as they appear on this sheet (so we can find your squares). First = primary; add more if you have multiple boxes.
    @State private var ownerNameFields: [String] = [""]

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

                // How does your name appear on this sheet?
                VStack(alignment: .leading, spacing: 12) {
                    Text("How does your name appear on this sheet?")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("We use this to find and highlight your squares. Add another row if you have more than one box.")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    ForEach(ownerNameFields.indices, id: \.self) { index in
                        HStack {
                            TextField("Name as written on sheet", text: $ownerNameFields[index])
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

                HStack(spacing: 20) {
                    StatBox(
                        title: "Names on Sheet",
                        value: "\(pool.filledCount)",
                        icon: "person.fill"
                    )
                    StatBox(
                        title: "Your Squares",
                        value: "\(mySquaresCount)",
                        icon: "star.fill"
                    )
                    StatBox(
                        title: "Empty",
                        value: "\(100 - pool.filledCount)",
                        icon: "square.dashed"
                    )
                }
                if !effectiveLabels.isEmpty && mySquaresCount == 0 {
                    Text("No squares matched \"\(effectiveLabels.joined(separator: "\", \""))\". Try the exact spelling as on the sheet (we ignore extra spaces and case).")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal)
                }

                // Grid preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("Grid Preview")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    MiniGridPreview(pool: pool, score: nil)
                        .frame(height: 150)
                }

                // Detected numbers
                VStack(alignment: .leading, spacing: 8) {
                    Text("Detected Numbers")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    HStack {
                        VStack(alignment: .leading) {
                            Text("Columns (\(pool.homeTeam.abbreviation))")
                                .font(.caption2)
                            Text(pool.homeNumbers.map { String($0) }.joined(separator: " "))
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.bold)
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("Rows (\(pool.awayTeam.abbreviation))")
                                .font(.caption2)
                            Text(pool.awayNumbers.map { String($0) }.joined(separator: " "))
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.bold)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(DesignSystem.Colors.surfaceElevated)
                    )
                }

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        pool.name = poolName.isEmpty ? "Scanned Pool" : poolName
                        applyOwnerLabels()
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
        }
        .onDisappear {
            applyOwnerLabels()
        }
        .sheet(isPresented: $showingImagePreview) {
            if let image = image {
                ImagePreviewView(image: image)
            }
        }
    }

    private func applyOwnerLabels() {
        let labels = ownerNameFields
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        pool.ownerLabels = labels.isEmpty ? nil : labels
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
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignSystem.Colors.surfaceElevated)
        )
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

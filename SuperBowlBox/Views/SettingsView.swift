import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingJoinPool = false
    @State private var showingAbout = false
    @State private var showingInstructions = false
    @State private var showingSignIn = false
    @State private var showingEraseConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                SportsbookBackgroundView()
            List {
                // Profile Section
                Section {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(DesignSystem.Colors.accentBlue)
                                .frame(width: 60, height: 60)

                            Text(initials)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            if appState.myName.isEmpty {
                                Text("Set Your Name")
                                    .font(.headline)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            } else {
                                Text(appState.myName)
                                    .font(.headline)
                            }
                            Text("Tap to edit")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .padding(.leading, 8)
                    }
                    .padding(.vertical, 8)

                    TextField("Your Name", text: $appState.myName)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: appState.myName) { _, _ in
                            appState.savePools()
                        }
                } header: {
                    Text("Profile")
                } footer: {
                    Text("Your name is used to highlight your boxes. When you scan or create a pool, you can set how your name appears on that sheet (and add multiple names if you have more than one box).")
                }

                // Account — sign in is in onboarding; here: status, Sign out, or single Sign in link
                Section {
                    if let user = appState.authService.currentUser {
                        HStack(spacing: 12) {
                            Image(systemName: user.provider == .apple ? "apple.logo" : (user.provider == .google ? "g.circle.fill" : "envelope.fill"))
                                .font(.title2)
                                .foregroundColor(DesignSystem.Colors.accentBlue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName ?? user.email ?? "Signed in")
                                    .font(AppTypography.headline)
                                if let email = user.email {
                                    Text(email)
                                        .font(AppTypography.caption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)

                        Button(role: .destructive) {
                            appState.authService.signOut()
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                            }
                        }
                    } else {
                        Button {
                            showingSignIn = true
                        } label: {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .foregroundColor(DesignSystem.Colors.accentBlue)
                                Text("Sign in to sync")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        }
                    }

                    if let error = appState.authService.errorMessage {
                        Text(error)
                            .font(AppTypography.caption2)
                            .foregroundColor(.red)
                    }
                } header: {
                    Text("Account")
                } footer: {
                    if appState.authService.currentUser == nil {
                        Text("Sign in during onboarding or here to sync across devices (optional)")
                    }
                }

                // Join Pool Section
                Section {
                    Button {
                        showingJoinPool = true
                    } label: {
                        HStack {
                            Image(systemName: "link.badge.plus")
                                .foregroundColor(DesignSystem.Colors.accentBlue)
                            Text("Join Pool with Code")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                } header: {
                    Text("Join Pool")
                } footer: {
                    Text("Enter an invite code from a pool host to join their pool")
                }

                // Share Section
                Section {
                    ForEach(appState.pools) { pool in
                        SharePoolRow(pool: pool)
                    }
                } header: {
                    Text("Share My Pools")
                } footer: {
                    Text("Generate invite codes to share your pools with others")
                }

                // Data Section
                Section {
                    Button {
                        appState.savePools()
                    } label: {
                        HStack {
                            Image(systemName: "externaldrive.fill.badge.icloud")
                            Text("Backup data")
                        }
                    }

                    Button(role: .destructive) {
                        showingEraseConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Erase all data")
                        }
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Erase removes all pools and your name from this device. You can sign in again and create or join pools.")
                }

                // About Section (icons same width so labels line up)
                Section {
                    Button {
                        showingInstructions = true
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundColor(DesignSystem.Colors.accentBlue)
                                .frame(width: 28, height: 28, alignment: .center)
                            Text("How it works")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    }

                    Button {
                        showingAbout = true
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: "apps.iphone")
                                .foregroundColor(DesignSystem.Colors.accentBlue)
                                .frame(width: 28, height: 28, alignment: .center)
                            Text("About Square Up")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    }

                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(DesignSystem.Colors.liveGreen)
                            .frame(width: 28, height: 28, alignment: .center)
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                } header: {
                    Text("About")
                }
            }
            }
            .scrollContentBackground(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: DesignSystem.Layout.screenInset, bottom: 4, trailing: DesignSystem.Layout.screenInset))
            .listRowBackground(
                SettingsListRowGlassBackground()
            )
            .toolbarBackground(DesignSystem.Colors.backgroundSecondary, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    AppNavBrandView()
                }
            }
            .sheet(isPresented: $showingJoinPool) {
                JoinPoolSheet()
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .sheet(isPresented: $showingInstructions) {
                InstructionsView(isOnboarding: false) { }
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showingSignIn) {
                OnboardingSignInView(authService: appState.authService, onSkip: { showingSignIn = false })
                    .onChange(of: appState.authService.currentUser) { _, new in
                        if new != nil { showingSignIn = false }
                    }
            }
            .alert("Erase all data?", isPresented: $showingEraseConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Erase", role: .destructive) {
                    appState.eraseAllData()
                    showingEraseConfirmation = false
                }
            } message: {
                Text("This will remove all pools and your name from this device. You can sign in again later.")
            }
        }
    }

    var initials: String {
        let words = appState.myName.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else if let first = words.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }

    private func topViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else { return nil }
        var vc = window.rootViewController
        while let presented = vc?.presentedViewController { vc = presented }
        return vc
    }
}

// MARK: - Settings list row glass background (depth + border + bevel)
private struct SettingsListRowGlassBackground: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall)
                .fill(DesignSystem.Colors.backgroundTertiary.opacity(0.5))
            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall)
                .strokeBorder(DesignSystem.Colors.glassBorder, lineWidth: 0.8)
        }
        .glassBevelHighlight(cornerRadius: DesignSystem.Layout.cornerRadiusSmall)
        .glassDepthShadowsEnhanced()
    }
}

// MARK: - Share Pool Row
struct SharePoolRow: View {
    let pool: BoxGrid
    @EnvironmentObject var appState: AppState
    @State private var showingShareSheet = false

    var displayCode: String {
        pool.sharedCode ?? "—"
    }

    var body: some View {
        Button {
            showingShareSheet = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pool.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Code: \(displayCode)")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Spacer()

                Image(systemName: "paperplane.fill")
                    .foregroundColor(DesignSystem.Colors.accentBlue)
            }
            .foregroundColor(DesignSystem.Colors.textPrimary)
        }
        .sheet(isPresented: $showingShareSheet) {
            SharePoolSheet(
                pool: pool,
                onCodeGenerated: { code in
                    var p = pool
                    p.sharedCode = code
                    appState.updatePool(p)
                }
            )
        }
    }
}

// MARK: - Share Pool Sheet
struct SharePoolSheet: View {
    let pool: BoxGrid
    let onCodeGenerated: (String) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var displayedCode: String? = nil
    @State private var isUploading = false
    @State private var uploadError: String? = nil
    @State private var copied = false
    @State private var showingSystemShare = false

    private var inviteCode: String {
        displayedCode ?? pool.sharedCode ?? ""
    }

    private var shareMessage: String {
        "Join my pool '\(pool.name)' on Square Up!\n\nInvite Code: \(inviteCode)"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Layout.sectionSpacing * 2) {
                // Pool info
                VStack(spacing: DesignSystem.Layout.sectionSpacing) {
                    Image(systemName: "rectangle.split.3x3")
                        .font(.system(size: 44))
                        .foregroundColor(DesignSystem.Colors.accentBlue)

                    Text(pool.name)
                        .font(DesignSystem.Typography.title)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text("\(pool.awayTeam.abbreviation) vs \(pool.homeTeam.abbreviation)")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                // Invite code
                VStack(spacing: DesignSystem.Layout.sectionSpacing) {
                    Text("Invite Code")
                        .font(DesignSystem.Typography.labelUppercase)
                        .tracking(0.6)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    if isUploading {
                        ProgressView()
                            .scaleEffect(1.2)
                            .padding()
                        Text("Generating code…")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    } else if let err = uploadError {
                        Text(err)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.dangerRed)
                            .multilineTextAlignment(.center)
                    } else if !inviteCode.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(Array(inviteCode), id: \.self) { char in
                                Text(String(char))
                                    .font(DesignSystem.Typography.mono)
                                    .fontWeight(.bold)
                                    .font(.system(size: 26))
                                    .frame(width: 36, height: 48)
                                    .background(DesignSystem.Colors.surfaceElevated)
                                    .cornerRadius(DesignSystem.Layout.cornerRadiusSmall)
                            }
                        }

                        Button {
                            UIPasteboard.general.string = inviteCode
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                copied = false
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                Text(copied ? "Copied!" : "Copy Code")
                            }
                            .font(DesignSystem.Typography.callout)
                            .padding(.horizontal, DesignSystem.Layout.cardPadding + 6)
                            .padding(.vertical, DesignSystem.Layout.sectionSpacing)
                            .background(
                                Capsule()
                                    .fill(copied ? DesignSystem.Colors.liveGreen : DesignSystem.Colors.accentBlue)
                            )
                            .foregroundColor(.white)
                        }
                    } else if !SharedPoolsConfig.isConfigured {
                        Text("Configure SharedPoolsURL or LoginDatabaseURL in Secrets.plist to generate codes.")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }

                Divider()
                    .background(DesignSystem.Colors.cardBorder)

                // Share options
                VStack(spacing: DesignSystem.Layout.sectionSpacing) {
                    Text("Share via")
                        .font(DesignSystem.Typography.labelUppercase)
                        .tracking(0.6)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    HStack(spacing: 24) {
                        ShareOptionButton(icon: "message.fill", label: "Message", color: DesignSystem.Colors.liveGreen, disabled: inviteCode.isEmpty) {
                            showingSystemShare = true
                        }
                        ShareOptionButton(icon: "envelope.fill", label: "Email", color: DesignSystem.Colors.accentBlue, disabled: inviteCode.isEmpty) {
                            showingSystemShare = true
                        }
                        ShareOptionButton(icon: "square.and.arrow.up", label: "More", color: DesignSystem.Colors.textTertiary, disabled: inviteCode.isEmpty) {
                            showingSystemShare = true
                        }
                    }
                }

                Spacer(minLength: 0)

                // Instructions
                VStack(alignment: .leading, spacing: DesignSystem.Layout.sectionSpacing) {
                    Text("How to join:")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text("1. Download Square Up from the App Store")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text("2. Go to Settings → Join Pool with Code")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text("3. Enter the code above")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(DesignSystem.Layout.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: DesignSystem.Layout.glassCornerRadius)
                            .fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: DesignSystem.Layout.glassCornerRadius)
                            .fill(DesignSystem.Colors.surfaceElevated.opacity(0.5))
                        RoundedRectangle(cornerRadius: DesignSystem.Layout.glassCornerRadius)
                            .strokeBorder(DesignSystem.Colors.glassBorder, lineWidth: 0.8)
                    }
                )
            }
            .padding(DesignSystem.Layout.screenInset)
            .background(DesignSystem.Colors.backgroundPrimary)
            .navigationTitle("Share Pool")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DesignSystem.Colors.backgroundSecondary, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    AppNavBrandView()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
            }
            .sheet(isPresented: $showingSystemShare) {
                ShareSheet(items: [shareMessage])
            }
            .onAppear {
                if displayedCode == nil, pool.sharedCode == nil, SharedPoolsConfig.isConfigured {
                    isUploading = true
                    uploadError = nil
                    Task {
                        do {
                            let code = try await SharedPoolsService.uploadPool(pool)
                            await MainActor.run {
                                displayedCode = code
                                isUploading = false
                                onCodeGenerated(code)
                            }
                        } catch {
                            await MainActor.run {
                                uploadError = error.localizedDescription
                                isUploading = false
                            }
                        }
                    }
                } else if displayedCode == nil, let existing = pool.sharedCode {
                    displayedCode = existing
                }
            }
        }
    }

}

struct ShareOptionButton: View {
    let icon: String
    let label: String
    let color: Color
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Layout.sectionSpacing) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .frame(width: 52, height: 52)
                    .background(disabled ? DesignSystem.Colors.surfaceElevated : color)
                    .foregroundColor(.white)
                    .cornerRadius(DesignSystem.Layout.cornerRadius)

                Text(label)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(disabled ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.textPrimary)
            }
        }
        .disabled(disabled)
        .buttonStyle(.plain)
    }
}

// MARK: - Join Pool Sheet
struct JoinPoolSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @State private var code: String = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var joinedPool: BoxGrid?

    var body: some View {
        NavigationStack {
            Group {
                if let pool = joinedPool {
                    ClaimYourSquaresView(
                        pool: pool,
                        onConfirm: { updatedPool in
                            var p = updatedPool
                            p.joinedViaCode = code.trimmingCharacters(in: .whitespaces).uppercased()
                            appState.addPool(p, isOwner: false)
                            HapticService.success()
                            dismiss()
                        },
                        onCancel: { joinedPool = nil }
                    )
                } else {
                    joinCodeContent
                }
            }
            .navigationTitle(joinedPool != nil ? "Claim your boxes" : "Join Pool")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if joinedPool != nil { joinedPool = nil } else { dismiss() }
                    }
                }
            }
        }
    }

    private var joinCodeContent: some View {
        VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 50))
                        .foregroundColor(AppColors.fieldGreen)

                    Text("Join a Pool")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Enter the invite code shared by the pool host")
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // Code input
                VStack(spacing: 12) {
                    TextField("Enter code", text: $code)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(DesignSystem.Colors.surfaceElevated)
                        )
                        .onChange(of: code) { _, newValue in
                            // Limit to 8 characters
                            if newValue.count > 8 {
                                code = String(newValue.prefix(8))
                            }
                            code = code.uppercased()
                        }

                    if let error = error {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Button {
                    joinPool()
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Join Pool")
                    }
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(code.count == 8 ? AppColors.fieldGreen : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(code.count != 8 || isLoading)

                Spacer()

                if !SharedPoolsConfig.isConfigured {
                    Text("Configure SharedPoolsURL or LoginDatabaseURL in Secrets.plist to join with a code.")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
    }

    private func joinPool() {
        guard SharedPoolsConfig.isConfigured else {
            error = "Share/join is not configured. Add SharedPoolsURL or LoginDatabaseURL in Secrets.plist."
            return
        }
        isLoading = true
        error = nil
        Task {
            do {
                let pool = try await SharedPoolsService.fetchPool(code: code.trimmingCharacters(in: .whitespaces).uppercased())
                await MainActor.run {
                    joinedPool = pool
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Claim your boxes (after join: enter name or manual box numbers; rules already in pool)
struct ClaimYourSquaresView: View {
    let pool: BoxGrid
    let onConfirm: (BoxGrid) -> Void
    let onCancel: () -> Void

    @EnvironmentObject var appState: AppState
    @State private var ownerName: String = ""
    @State private var useManualEntry = false
    @State private var manualBoxes: [(homeDigit: Int, awayDigit: Int)] = [(0, 0)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Rules and payout were set by the host. Confirm your name so we can find your boxes on the grid.")
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                if !useManualEntry {
                    if !pool.allPlayers.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Select your name from the sheet")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                                ForEach(pool.allPlayers.sorted(), id: \.self) { name in
                                    Button {
                                        HapticService.selection()
                                        ownerName = name
                                    } label: {
                                        Text(name)
                                            .font(.caption)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(ownerName == name ? AppColors.fieldGreen.opacity(0.3) : DesignSystem.Colors.surfaceElevated)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Or type your name as it appears on the sheet")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("e.g. Mike Capace", text: $ownerName)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.name)
                            .autocorrectionDisabled()
                    }

                    Button {
                        claimWithName()
                    } label: {
                        Text("Find my boxes")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColors.fieldGreen)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(ownerName.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button {
                        useManualEntry = true
                    } label: {
                        Text("My name isn't listed / Enter my numbers manually")
                            .font(.subheadline)
                            .foregroundColor(AppColors.fieldGreen)
                    }
                } else {
                    manualEntrySection
                }
            }
            .padding()
        }
        .onAppear {
            if ownerName.isEmpty, !appState.myName.isEmpty {
                ownerName = appState.myName
            }
        }
    }

    private var manualEntrySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Enter the column and row number for each of your boxes.")
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            TextField("Your name", text: $ownerName)
                .textFieldStyle(.roundedBorder)

            ForEach(Array(manualBoxes.enumerated()), id: \.offset) { index, _ in
                HStack {
                    Text("Box \(index + 1)")
                        .font(.subheadline)
                        .frame(width: 44, alignment: .leading)
                    Picker("", selection: Binding(
                        get: { manualBoxes[index].homeDigit },
                        set: { newVal in
                            var b = manualBoxes
                            b[index].homeDigit = newVal
                            manualBoxes = b
                        }
                    )) {
                        ForEach(0...9, id: \.self) { n in Text("\(n)").tag(n) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    Text("\(pool.homeTeam.abbreviation)")
                        .font(.caption2)
                    Picker("", selection: Binding(
                        get: { manualBoxes[index].awayDigit },
                        set: { newVal in
                            var b = manualBoxes
                            b[index].awayDigit = newVal
                            manualBoxes = b
                        }
                    )) {
                        ForEach(0...9, id: \.self) { n in Text("\(n)").tag(n) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    Text("\(pool.awayTeam.abbreviation)")
                        .font(.caption2)
                    if manualBoxes.count > 1 {
                        Button {
                            manualBoxes.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(DesignSystem.Colors.dangerRed)
                        }
                    }
                }
            }

            Button {
                manualBoxes.append((0, 0))
            } label: {
                Label("Add another box", systemImage: "plus.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(AppColors.fieldGreen)
            }

            Button {
                claimWithManualBoxes()
            } label: {
                Text("Done – add pool")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.fieldGreen)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
    }

    private func claimWithName() {
        let name = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        var p = pool
        p.ownerLabels = [name]
        onConfirm(p)
    }

    private func claimWithManualBoxes() {
        let name = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = name.isEmpty ? "You" : name
        var p = pool
        for box in manualBoxes {
            if let pos = p.winningPosition(homeDigit: box.homeDigit, awayDigit: box.awayDigit) {
                p.updateSquare(row: pos.row, column: pos.column, playerName: label)
            }
        }
        p.ownerLabels = [label]
        onConfirm(p)
    }
}

// MARK: - About View
struct AboutView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // App logo and wordmark
                    VStack(spacing: 16) {
                        SquareUpLogoView(showIcon: true, wordmarkSize: 40)
                            .padding(.top, 8)

                        Text("Pools, boxes & brackets. Any event.")
                            .font(AppTypography.callout)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.top, 32)

                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(
                            icon: "text.viewfinder",
                            title: "Smart Scanning",
                            description: "Scan your pool sheet with your camera"
                        )

                        FeatureRow(
                            icon: "dot.radiowaves.left.and.right",
                            title: "Live Scores",
                            description: "Real-time score updates during the game"
                        )

                        FeatureRow(
                            icon: "rectangle.split.3x3",
                            title: "Multiple Pools",
                            description: "Manage all your pools in one place"
                        )

                        FeatureRow(
                            icon: "paperplane.fill",
                            title: "Easy Sharing",
                            description: "Share pools with friends via invite codes"
                        )
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(DesignSystem.Colors.surfaceElevated)
                    )

                    // Footer
                    VStack(spacing: 8) {
                        Text("Made with love for football fans")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption2)
                            Text("Version 1.0.0")
                                .font(.caption2)
                        }
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                .padding()
            }
            .navigationTitle("About")
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

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(DesignSystem.Colors.accentBlue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}

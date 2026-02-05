import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingJoinPool = false
    @State private var showingAbout = false
    @State private var showingInstructions = false
    @State private var showingOnboardingAgain = false

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
                    Text("Your name is used to highlight your squares. When you scan or create a pool, you can set how your name appears on that sheet (and add multiple names if you have more than one box).")
                }

                // Account (Sign in with Apple / Google)
                Section {
                    if let user = appState.authService.currentUser {
                        HStack(spacing: 12) {
                            Image(systemName: user.provider == .apple ? "apple.logo" : "g.circle.fill")
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
                        SignInWithAppleButton {
                            appState.authService.signInWithApple()
                        }

                        GoogleSignInButton(
                            action: {
                                Task { @MainActor in
                                    guard let vc = topViewController() else { return }
                                    await appState.authService.signInWithGoogle(presenting: vc)
                                }
                            },
                            isDisabled: appState.authService.isSigningIn
                        )
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
                        Text("Sign in to sync your account across devices (optional)")
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

                // Live Scores Section
                Section {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(DesignSystem.Colors.accentBlue)
                            .frame(width: 28, alignment: .center)
                        Text("Auto-refresh Scores")
                        Spacer()
                        Toggle("", isOn: .constant(true))
                            .tint(DesignSystem.Colors.accentBlue)
                    }

                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                            .frame(width: 28, alignment: .center)
                        Text("Refresh Interval")
                        Spacer()
                        Text("30 seconds")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    if let lastUpdated = appState.scoreService.lastUpdated {
                        HStack {
                            Image(systemName: "clock.badge.checkmark.fill")
                                .foregroundColor(DesignSystem.Colors.accentBlue)
                                .frame(width: 28, alignment: .center)
                            Text("Last Updated")
                            Spacer()
                            Text(lastUpdated, style: .relative)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                } header: {
                    Text("Live Scores")
                }

                // Data Section
                Section {
                    Button {
                        appState.savePools()
                    } label: {
                        HStack {
                            Image(systemName: "externaldrive.fill.badge.icloud")
                            Text("Backup Data")
                        }
                    }

                    Button(role: .destructive) {
                        // Clear all data
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear All Data")
                        }
                    }
                } header: {
                    Text("Data")
                }

                // About Section
                Section {
                    Button {
                        showingOnboardingAgain = true
                    } label: {
                        HStack {
                            Image(systemName: "hand.wave.fill")
                                .foregroundColor(DesignSystem.Colors.accentBlue)
                            Text("Show onboarding again")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    }

                    Button {
                        showingInstructions = true
                    } label: {
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundColor(DesignSystem.Colors.accentBlue)
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
                        HStack {
                            Image(systemName: "apps.iphone")
                                .foregroundColor(DesignSystem.Colors.accentBlue)
                                .frame(width: 28, alignment: .center)
                            Text("About SquareUp")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    }

                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(DesignSystem.Colors.liveGreen)
                            .frame(width: 28, alignment: .center)
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
            .toolbarBackground(DesignSystem.Colors.backgroundSecondary, for: .navigationBar)
            .navigationTitle("Settings")
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
            .fullScreenCover(isPresented: $showingOnboardingAgain) {
                InstructionsView(isOnboarding: true) {
                    showingOnboardingAgain = false
                    appState.completeOnboarding()
                }
                .environmentObject(appState)
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

    private var inviteCode: String {
        displayedCode ?? pool.sharedCode ?? ""
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Pool info
                VStack(spacing: 8) {
                    Image(systemName: "rectangle.split.3x3")
                        .font(.system(size: 50))
                        .foregroundColor(DesignSystem.Colors.accentBlue)

                    Text(pool.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("\(pool.awayTeam.abbreviation) vs \(pool.homeTeam.abbreviation)")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                // Invite code
                VStack(spacing: 12) {
                    Text("Invite Code")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    if isUploading {
                        ProgressView()
                            .scaleEffect(1.2)
                            .padding()
                        Text("Generating code…")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    } else if let err = uploadError {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    } else if !inviteCode.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(Array(inviteCode), id: \.self) { char in
                                Text(String(char))
                                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                                    .frame(width: 36, height: 48)
                                    .background(DesignSystem.Colors.surfaceElevated)
                                    .cornerRadius(8)
                            }
                        }

                        Button {
                            UIPasteboard.general.string = inviteCode
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                copied = false
                            }
                        } label: {
                            HStack {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                Text(copied ? "Copied!" : "Copy Code")
                            }
                            .font(.subheadline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(copied ? DesignSystem.Colors.liveGreen : DesignSystem.Colors.accentBlue)
                            )
                            .foregroundColor(.white)
                        }
                    } else if !SharedPoolsConfig.isConfigured {
                        Text("Configure SharedPoolsURL or LoginDatabaseURL in Secrets.plist to generate codes.")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }

                Divider()

                // Share options
                VStack(spacing: 16) {
                    Text("Share via")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    HStack(spacing: 24) {
                        ShareOptionButton(icon: "message.fill", label: "Message", color: .green) {
                            shareViaMessages()
                        }

                        ShareOptionButton(icon: "envelope.fill", label: "Email", color: .blue) {
                            shareViaEmail()
                        }

                        ShareOptionButton(icon: "square.and.arrow.up", label: "More", color: .gray) {
                            shareGeneric()
                        }
                    }
                }

                Spacer()

                // Instructions
                VStack(alignment: .leading, spacing: 8) {
                    Text("How to join:")
                        .font(.caption)
                        .fontWeight(.semibold)

                    Text("1. Download SquareUp from the App Store")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Text("2. Go to Settings > Join Pool with Code")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Text("3. Enter the code above")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(DesignSystem.Colors.surfaceElevated)
                )
            }
            .padding()
            .navigationTitle("Share Pool")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
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

    private func shareViaMessages() {
        let message = "Join my pool '\(pool.name)' on SquareUp!\n\nInvite Code: \(inviteCode)"
        // In a real app, this would open the Messages app
        UIPasteboard.general.string = message
    }

    private func shareViaEmail() {
        let message = "Join my pool '\(pool.name)' on SquareUp!\n\nInvite Code: \(inviteCode)"
        UIPasteboard.general.string = message
    }

    private func shareGeneric() {
        let message = "Join my pool '\(pool.name)' on SquareUp!\n\nInvite Code: \(inviteCode)"
        UIPasteboard.general.string = message
    }
}

struct ShareOptionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 50, height: 50)
                    .background(color)
                    .foregroundColor(.white)
                    .cornerRadius(12)

                Text(label)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
        }
    }
}

// MARK: - Join Pool Sheet
struct JoinPoolSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @State private var code: String = ""
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
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
            .navigationTitle("Join Pool")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
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
                    appState.addPool(pool)
                    HapticService.success()
                    dismiss()
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
                            description: "Scan your pool sheet with OCR technology"
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

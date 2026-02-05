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
                                    .foregroundColor(.secondary)
                            } else {
                                Text(appState.myName)
                                    .font(.headline)
                            }
                            Text("Tap to edit")
                                .font(.caption)
                                .foregroundColor(.secondary)
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
                                        .foregroundColor(.secondary)
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
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
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
                        Text("Auto-refresh Scores")
                        Spacer()
                        Toggle("", isOn: .constant(true))
                            .tint(AppColors.fieldGreen)
                    }

                    HStack {
                        Text("Refresh Interval")
                        Spacer()
                        Text("30 seconds")
                            .foregroundColor(.secondary)
                    }

                    if let lastUpdated = appState.scoreService.lastUpdated {
                        HStack {
                            Text("Last Updated")
                            Spacer()
                            Text(lastUpdated, style: .relative)
                                .foregroundColor(.secondary)
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
                            Image(systemName: "icloud.and.arrow.up")
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
                                .foregroundColor(.secondary)
                        }
                        .foregroundColor(.primary)
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
                                .foregroundColor(.secondary)
                        }
                        .foregroundColor(.primary)
                    }

                    Button {
                        showingAbout = true
                    } label: {
                        HStack {
                            Text("About SquareUp")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .foregroundColor(.primary)
                    }

                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .scrollContentBackground(.hidden)
            .toolbarBackground(DesignSystem.Colors.backgroundSecondary, for: .navigationBar)
            .background(DesignSystem.Colors.backgroundPrimary)
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
    @State private var showingShareSheet = false

    var inviteCode: String {
        // Generate a simple invite code from the pool ID
        String(pool.id.uuidString.prefix(8)).uppercased()
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
                    Text("Code: \(inviteCode)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(AppColors.fieldGreen)
            }
            .foregroundColor(.primary)
        }
        .sheet(isPresented: $showingShareSheet) {
            SharePoolSheet(pool: pool, inviteCode: inviteCode)
        }
    }
}

// MARK: - Share Pool Sheet
struct SharePoolSheet: View {
    let pool: BoxGrid
    let inviteCode: String
    @Environment(\.dismiss) var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Pool info
                VStack(spacing: 8) {
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.system(size: 50))
                        .foregroundColor(AppColors.fieldGreen)

                    Text(pool.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("\(pool.awayTeam.abbreviation) vs \(pool.homeTeam.abbreviation)")
                        .foregroundColor(.secondary)
                }

                // Invite code
                VStack(spacing: 12) {
                    Text("Invite Code")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        ForEach(Array(inviteCode), id: \.self) { char in
                            Text(String(char))
                                .font(.system(size: 28, weight: .bold, design: .monospaced))
                                .frame(width: 36, height: 48)
                                .background(Color(.systemGray6))
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
                                .fill(copied ? Color.green : AppColors.fieldGreen)
                        )
                        .foregroundColor(.white)
                    }
                }

                Divider()

                // Share options
                VStack(spacing: 16) {
                    Text("Share via")
                        .font(.caption)
                        .foregroundColor(.secondary)

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
                        .foregroundColor(.secondary)

                    Text("2. Go to Settings > Join Pool with Code")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("3. Enter the code above")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
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
                    .foregroundColor(.primary)
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
                        .foregroundColor(.secondary)
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
                                .fill(Color(.systemGray6))
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

                // Note
                Text("Note: In this demo version, invite codes create a local copy of the pool. Full cloud sync coming soon!")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
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
        isLoading = true
        error = nil

        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // In a real app, this would fetch the pool from a server
            // For demo, create a sample pool
            let pool = BoxGrid(name: "Joined Pool - \(code)")
            appState.addPool(pool)
            isLoading = false
            dismiss()
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
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 32)

                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(
                            icon: "camera.viewfinder",
                            title: "Smart Scanning",
                            description: "Scan your pool sheet with OCR technology"
                        )

                        FeatureRow(
                            icon: "play.circle",
                            title: "Live Scores",
                            description: "Real-time score updates during the game"
                        )

                        FeatureRow(
                            icon: "person.2",
                            title: "Multiple Pools",
                            description: "Manage all your pools in one place"
                        )

                        FeatureRow(
                            icon: "square.and.arrow.up",
                            title: "Easy Sharing",
                            description: "Share pools with friends via invite codes"
                        )
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray6))
                    )

                    // Footer
                    VStack(spacing: 8) {
                        Text("Made with love for football fans")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("Version 1.0.0")
                            .font(.caption2)
                            .foregroundColor(.secondary)
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
                .foregroundColor(AppColors.fieldGreen)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}

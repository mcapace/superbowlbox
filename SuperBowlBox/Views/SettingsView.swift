import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingJoinPool = false
    @State private var showingAbout = false
    @State private var notificationsEnabled = true
    @State private var autoRefresh = true

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Profile Section
                        ProfileSection(myName: $appState.myName) {
                            appState.savePools()
                        }

                        // Quick Actions
                        QuickActionsSection(
                            onJoinPool: { showingJoinPool = true }
                        )

                        // Share Pools
                        if !appState.pools.isEmpty {
                            SharePoolsSection(pools: appState.pools)
                        }

                        // Notifications
                        NotificationsSection(
                            notificationsEnabled: $notificationsEnabled
                        )

                        // Live Scores
                        LiveScoresSection(
                            autoRefresh: $autoRefresh,
                            lastUpdated: appState.scoreService.lastUpdated
                        )

                        // Data Management
                        DataSection(
                            onBackup: { appState.savePools() }
                        )

                        // About
                        AboutSection(
                            onShowAbout: { showingAbout = true }
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
            }
            .toolbarBackground(DesignSystem.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showingJoinPool) {
                JoinPoolSheet()
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Profile Section
struct ProfileSection: View {
    @Binding var myName: String
    let onSave: () -> Void
    @FocusState private var isEditing: Bool

    var initials: String {
        let words = myName.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else if let first = words.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [DesignSystem.Colors.accent, DesignSystem.Colors.accent.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)

                    Text(initials)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
                .shadow(color: DesignSystem.Colors.accentGlow, radius: 12, y: 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text("YOUR PROFILE")
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundColor(DesignSystem.Colors.textMuted)
                        .tracking(1)

                    if myName.isEmpty {
                        Text("Set Your Name")
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    } else {
                        Text(myName)
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                }

                Spacer()
            }

            // Name input
            HStack(spacing: 12) {
                Image(systemName: "person.fill")
                    .foregroundColor(DesignSystem.Colors.textMuted)
                    .frame(width: 20)

                TextField("Enter your name", text: $myName)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .focused($isEditing)
                    .onChange(of: myName) { _, _ in
                        onSave()
                    }

                if !myName.isEmpty {
                    Button {
                        Haptics.selection()
                        myName = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DesignSystem.Colors.textMuted)
                    }
                }
            }
            .padding(14)
            .background(DesignSystem.Colors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isEditing ? DesignSystem.Colors.accent.opacity(0.5) : DesignSystem.Colors.glassBorder,
                        lineWidth: 1
                    )
            )

            Text("Your name is used to highlight your squares across all pools")
                .font(DesignSystem.Typography.captionSmall)
                .foregroundColor(DesignSystem.Colors.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .glassCard()
    }
}

// MARK: - Quick Actions Section
struct QuickActionsSection: View {
    let onJoinPool: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("QUICK ACTIONS")
                .font(DesignSystem.Typography.captionSmall)
                .foregroundColor(DesignSystem.Colors.textMuted)
                .tracking(1)

            Button {
                Haptics.impact(.light)
                onJoinPool()
            } label: {
                HStack {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.accent.opacity(0.15))
                            .frame(width: 40, height: 40)

                        Image(systemName: "link.badge.plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.accent)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Join Pool with Code")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        Text("Enter an invite code from a pool host")
                            .font(DesignSystem.Typography.captionSmall)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textMuted)
                }
                .padding(16)
                .glassCard()
            }
        }
    }
}

// MARK: - Share Pools Section
struct SharePoolsSection: View {
    let pools: [BoxGrid]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SHARE MY POOLS")
                .font(DesignSystem.Typography.captionSmall)
                .foregroundColor(DesignSystem.Colors.textMuted)
                .tracking(1)

            VStack(spacing: 8) {
                ForEach(pools) { pool in
                    SharePoolRow(pool: pool)
                }
            }
        }
    }
}

// MARK: - Notifications Section
struct NotificationsSection: View {
    @Binding var notificationsEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NOTIFICATIONS")
                .font(DesignSystem.Typography.captionSmall)
                .foregroundColor(DesignSystem.Colors.textMuted)
                .tracking(1)

            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: "bell.badge.fill",
                    iconColor: DesignSystem.Colors.danger,
                    title: "Push Notifications",
                    subtitle: "Get notified when you win",
                    isOn: $notificationsEnabled
                )

                Divider()
                    .background(DesignSystem.Colors.glassBorder)
                    .padding(.leading, 56)

                SettingsToggleRow(
                    icon: "scope",
                    iconColor: DesignSystem.Colors.gold,
                    title: "On the Hunt Alerts",
                    subtitle: "When your squares are close to winning",
                    isOn: $notificationsEnabled
                )
            }
            .glassCard()
        }
    }
}

// MARK: - Live Scores Section
struct LiveScoresSection: View {
    @Binding var autoRefresh: Bool
    let lastUpdated: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LIVE SCORES")
                .font(DesignSystem.Typography.captionSmall)
                .foregroundColor(DesignSystem.Colors.textMuted)
                .tracking(1)

            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: "arrow.clockwise",
                    iconColor: DesignSystem.Colors.live,
                    title: "Auto-refresh Scores",
                    subtitle: "Updates every 30 seconds during games",
                    isOn: $autoRefresh
                )

                if let lastUpdated = lastUpdated {
                    Divider()
                        .background(DesignSystem.Colors.glassBorder)
                        .padding(.leading, 56)

                    HStack {
                        ZStack {
                            Circle()
                                .fill(DesignSystem.Colors.surfaceElevated)
                                .frame(width: 40, height: 40)

                            Image(systemName: "clock.fill")
                                .font(.system(size: 16))
                                .foregroundColor(DesignSystem.Colors.textMuted)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Last Updated")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)

                            Text(lastUpdated, style: .relative)
                                .font(DesignSystem.Typography.captionSmall)
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                        }

                        Spacer()
                    }
                    .padding(16)
                }
            }
            .glassCard()
        }
    }
}

// MARK: - Data Section
struct DataSection: View {
    let onBackup: () -> Void
    @State private var showingClearConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DATA")
                .font(DesignSystem.Typography.captionSmall)
                .foregroundColor(DesignSystem.Colors.textMuted)
                .tracking(1)

            VStack(spacing: 0) {
                Button {
                    Haptics.impact(.light)
                    onBackup()
                } label: {
                    SettingsRowContent(
                        icon: "icloud.and.arrow.up.fill",
                        iconColor: DesignSystem.Colors.accent,
                        title: "Backup Data",
                        showChevron: false
                    )
                }

                Divider()
                    .background(DesignSystem.Colors.glassBorder)
                    .padding(.leading, 56)

                Button {
                    Haptics.impact(.medium)
                    showingClearConfirm = true
                } label: {
                    SettingsRowContent(
                        icon: "trash.fill",
                        iconColor: DesignSystem.Colors.danger,
                        title: "Clear All Data",
                        titleColor: DesignSystem.Colors.danger,
                        showChevron: false
                    )
                }
            }
            .glassCard()
        }
        .alert("Clear All Data?", isPresented: $showingClearConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                // Clear data action
            }
        } message: {
            Text("This will delete all your pools and settings. This cannot be undone.")
        }
    }
}

// MARK: - About Section
struct AboutSection: View {
    let onShowAbout: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ABOUT")
                .font(DesignSystem.Typography.captionSmall)
                .foregroundColor(DesignSystem.Colors.textMuted)
                .tracking(1)

            VStack(spacing: 0) {
                Button {
                    Haptics.selection()
                    onShowAbout()
                } label: {
                    SettingsRowContent(
                        icon: "info.circle.fill",
                        iconColor: DesignSystem.Colors.accent,
                        title: "About SquareUp",
                        showChevron: true
                    )
                }

                Divider()
                    .background(DesignSystem.Colors.glassBorder)
                    .padding(.leading, 56)

                HStack {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.surfaceElevated)
                            .frame(width: 40, height: 40)

                        Image(systemName: "sparkles")
                            .font(.system(size: 16))
                            .foregroundColor(DesignSystem.Colors.gold)
                    }

                    Text("Version")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()

                    Text("1.0.0")
                        .font(DesignSystem.Typography.mono)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                .padding(16)
            }
            .glassCard()
        }
    }
}

// MARK: - Settings Row Components
struct SettingsToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text(subtitle)
                    .font(DesignSystem.Typography.captionSmall)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .tint(DesignSystem.Colors.accent)
                .labelsHidden()
        }
        .padding(16)
    }
}

struct SettingsRowContent: View {
    let icon: String
    let iconColor: Color
    let title: String
    var titleColor: Color = DesignSystem.Colors.textPrimary
    let showChevron: Bool

    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            Text(title)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(titleColor)

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textMuted)
            }
        }
        .padding(16)
    }
}

// MARK: - Share Pool Row
struct SharePoolRow: View {
    let pool: BoxGrid
    @State private var showingShareSheet = false

    var inviteCode: String {
        String(pool.id.uuidString.prefix(8)).uppercased()
    }

    var body: some View {
        Button {
            Haptics.selection()
            showingShareSheet = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pool.name)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    HStack(spacing: 4) {
                        Text("Code:")
                            .foregroundColor(DesignSystem.Colors.textMuted)
                        Text(inviteCode)
                            .foregroundColor(DesignSystem.Colors.accent)
                    }
                    .font(DesignSystem.Typography.mono)
                }

                Spacer()

                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.accent)
            }
            .padding(16)
            .glassCard()
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
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: 32) {
                    // Pool info
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(DesignSystem.Colors.accent.opacity(0.15))
                                .frame(width: 80, height: 80)

                            Image(systemName: "square.grid.3x3.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [DesignSystem.Colors.accent, DesignSystem.Colors.accent.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }

                        Text(pool.name)
                            .font(DesignSystem.Typography.title)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        HStack(spacing: 8) {
                            TeamBadge(team: pool.awayTeam, size: 28)
                            Text("vs")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textMuted)
                            TeamBadge(team: pool.homeTeam, size: 28)
                        }
                    }
                    .padding(.top, 20)

                    // Invite code
                    VStack(spacing: 16) {
                        Text("INVITE CODE")
                            .font(DesignSystem.Typography.captionSmall)
                            .foregroundColor(DesignSystem.Colors.textMuted)
                            .tracking(2)

                        HStack(spacing: 6) {
                            ForEach(Array(inviteCode), id: \.self) { char in
                                Text(String(char))
                                    .font(DesignSystem.Typography.monoLarge)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                    .frame(width: 38, height: 50)
                                    .background(DesignSystem.Colors.surfaceElevated)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(DesignSystem.Colors.glassBorder, lineWidth: 1)
                                    )
                            }
                        }

                        Button {
                            Haptics.impact(.light)
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
                            .font(DesignSystem.Typography.bodyMedium)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(copied ? DesignSystem.Colors.live : DesignSystem.Colors.accent)
                            )
                            .foregroundColor(.white)
                        }
                    }
                    .padding(24)
                    .glassCard()
                    .padding(.horizontal, 20)

                    // Share options
                    VStack(spacing: 16) {
                        Text("SHARE VIA")
                            .font(DesignSystem.Typography.captionSmall)
                            .foregroundColor(DesignSystem.Colors.textMuted)
                            .tracking(2)

                        HStack(spacing: 32) {
                            ShareOptionButton(icon: "message.fill", label: "Message", color: DesignSystem.Colors.live) {
                                shareViaMessages()
                            }

                            ShareOptionButton(icon: "envelope.fill", label: "Email", color: DesignSystem.Colors.accent) {
                                shareViaEmail()
                            }

                            ShareOptionButton(icon: "square.and.arrow.up", label: "More", color: DesignSystem.Colors.textSecondary) {
                                shareGeneric()
                            }
                        }
                    }

                    Spacer()

                    // Instructions
                    VStack(alignment: .leading, spacing: 10) {
                        Text("HOW TO JOIN")
                            .font(DesignSystem.Typography.captionSmall)
                            .foregroundColor(DesignSystem.Colors.textMuted)
                            .tracking(1)

                        InstructionRow(number: "1", text: "Download SquareUp from the App Store")
                        InstructionRow(number: "2", text: "Go to Settings > Join Pool with Code")
                        InstructionRow(number: "3", text: "Enter the code above")
                    }
                    .padding(20)
                    .glassCard()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Share Pool")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DesignSystem.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func shareViaMessages() {
        let message = "Join my Super Bowl pool '\(pool.name)' on SquareUp!\n\nInvite Code: \(inviteCode)"
        UIPasteboard.general.string = message
    }

    private func shareViaEmail() {
        let message = "Join my Super Bowl pool '\(pool.name)' on SquareUp!\n\nInvite Code: \(inviteCode)"
        UIPasteboard.general.string = message
    }

    private func shareGeneric() {
        let message = "Join my Super Bowl pool '\(pool.name)' on SquareUp!\n\nInvite Code: \(inviteCode)"
        UIPasteboard.general.string = message
    }
}

struct InstructionRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(DesignSystem.Typography.mono)
                .foregroundColor(DesignSystem.Colors.accent)
                .frame(width: 24, height: 24)
                .background(DesignSystem.Colors.accent.opacity(0.15))
                .clipShape(Circle())

            Text(text)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }
}

struct ShareOptionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.selection()
            action()
        }) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(color.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(color)
                }

                Text(label)
                    .font(DesignSystem.Typography.captionSmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
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
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(DesignSystem.Colors.accent.opacity(0.15))
                                .frame(width: 80, height: 80)

                            Image(systemName: "link.badge.plus")
                                .font(.system(size: 36))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [DesignSystem.Colors.accent, DesignSystem.Colors.accent.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }

                        Text("Join a Pool")
                            .font(DesignSystem.Typography.title)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        Text("Enter the invite code shared by the pool host")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    // Code input
                    VStack(spacing: 16) {
                        TextField("ENTER CODE", text: $code)
                            .font(DesignSystem.Typography.monoLarge)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .focused($isCodeFocused)
                            .padding()
                            .background(DesignSystem.Colors.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        isCodeFocused ? DesignSystem.Colors.accent.opacity(0.5) : DesignSystem.Colors.glassBorder,
                                        lineWidth: 1
                                    )
                            )
                            .onChange(of: code) { _, newValue in
                                if newValue.count > 8 {
                                    code = String(newValue.prefix(8))
                                }
                                code = code.uppercased()
                            }
                            .padding(.horizontal, 20)

                        if let error = error {
                            Text(error)
                                .font(DesignSystem.Typography.captionSmall)
                                .foregroundColor(DesignSystem.Colors.danger)
                        }
                    }

                    Button {
                        Haptics.impact(.medium)
                        joinPool()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Join Pool")
                                    .font(DesignSystem.Typography.bodyMedium)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: code.count == 8 ?
                                    [DesignSystem.Colors.accent, DesignSystem.Colors.accent.opacity(0.8)] :
                                    [DesignSystem.Colors.textMuted, DesignSystem.Colors.textMuted.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(
                            color: code.count == 8 ? DesignSystem.Colors.accentGlow : .clear,
                            radius: 12, y: 4
                        )
                    }
                    .disabled(code.count != 8 || isLoading)
                    .padding(.horizontal, 20)

                    Spacer()

                    // Note
                    Text("Note: In this demo version, invite codes create a local copy of the pool. Full cloud sync coming soon!")
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundColor(DesignSystem.Colors.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 20)
                }
            }
            .navigationTitle("Join Pool")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DesignSystem.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .onAppear {
                isCodeFocused = true
            }
        }
        .preferredColorScheme(.dark)
    }

    private func joinPool() {
        isLoading = true
        error = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
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
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        // App icon and name
                        VStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [DesignSystem.Colors.accent.opacity(0.3), DesignSystem.Colors.accent.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 120, height: 120)

                                Image(systemName: "square.grid.3x3.fill")
                                    .font(.system(size: 56))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [DesignSystem.Colors.accent, DesignSystem.Colors.accent.opacity(0.6)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            .shadow(color: DesignSystem.Colors.accentGlow, radius: 20, y: 8)

                            Text("SquareUp")
                                .font(DesignSystem.Typography.scoreHero)
                                .foregroundColor(DesignSystem.Colors.textPrimary)

                            Text("Super Bowl Squares Made Easy")
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                        }
                        .padding(.top, 40)

                        // Features
                        VStack(spacing: 16) {
                            FeatureRow(
                                icon: "camera.viewfinder",
                                iconColor: DesignSystem.Colors.accent,
                                title: "Smart Scanning",
                                description: "Scan your pool sheet with OCR technology"
                            )

                            FeatureRow(
                                icon: "play.circle.fill",
                                iconColor: DesignSystem.Colors.live,
                                title: "Live Scores",
                                description: "Real-time score updates during the game"
                            )

                            FeatureRow(
                                icon: "scope",
                                iconColor: DesignSystem.Colors.danger,
                                title: "On the Hunt",
                                description: "Know when your squares are close to winning"
                            )

                            FeatureRow(
                                icon: "bell.badge.fill",
                                iconColor: DesignSystem.Colors.gold,
                                title: "Notifications",
                                description: "Get alerts when you win a quarter"
                            )

                            FeatureRow(
                                icon: "square.and.arrow.up",
                                iconColor: DesignSystem.Colors.textSecondary,
                                title: "Easy Sharing",
                                description: "Share pools with friends via invite codes"
                            )
                        }
                        .padding(20)
                        .glassCard()
                        .padding(.horizontal, 20)

                        // Footer
                        VStack(spacing: 8) {
                            Text("Made with ♠️ for football fans")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textTertiary)

                            Text("Version 1.0.0")
                                .font(DesignSystem.Typography.captionSmall)
                                .foregroundColor(DesignSystem.Colors.textMuted)
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DesignSystem.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text(description)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }

            Spacer()
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}

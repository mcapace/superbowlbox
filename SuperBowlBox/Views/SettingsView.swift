import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingJoinPool = false
    @State private var showingAbout = false
    @State private var notificationsEnabled = true
    @State private var autoRefresh = true

    var body: some View {
        ZStack {
            // Animated Background
            AnimatedMeshBackground()
            TechGridBackground()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SETTINGS")
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                            .foregroundStyle(DesignSystem.Colors.cyberGradient)

                        Text("SYSTEM CONFIGURATION")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.textMuted)
                            .tracking(2)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 20)

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
                    .padding(.bottom, 140)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingJoinPool) {
            JoinPoolSheet()
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
    }
}

// MARK: - Profile Section
struct ProfileSection: View {
    @Binding var myName: String
    let onSave: () -> Void
    @FocusState private var isEditing: Bool
    @State private var orbitalRotation: Double = 0

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
        VStack(spacing: 20) {
            // Section header
            HStack {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.accent)

                Text("IDENTITY MODULE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.textMuted)
                    .tracking(2)

                Spacer()

                // Status indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(myName.isEmpty ? DesignSystem.Colors.danger : DesignSystem.Colors.live)
                        .frame(width: 6, height: 6)

                    Text(myName.isEmpty ? "UNSET" : "ACTIVE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(myName.isEmpty ? DesignSystem.Colors.danger : DesignSystem.Colors.live)
                }
            }

            HStack(spacing: 16) {
                // Avatar with orbital ring
                ZStack {
                    OrbitalRing(
                        progress: myName.isEmpty ? 0.2 : 1.0,
                        color: DesignSystem.Colors.accent,
                        size: 80,
                        lineWidth: 3
                    )

                    Circle()
                        .fill(DesignSystem.Colors.cyberGradient)
                        .frame(width: 60, height: 60)

                    Text(initials)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }
                .glow(DesignSystem.Colors.accent, radius: 15)

                VStack(alignment: .leading, spacing: 6) {
                    Text("TRACKING AS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.textMuted)
                        .tracking(2)

                    if myName.isEmpty {
                        Text("Not Configured")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    } else {
                        Text(myName.uppercased())
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .tracking(1)
                    }
                }

                Spacer()
            }

            // Name input with futuristic styling
            HStack(spacing: 12) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isEditing ? DesignSystem.Colors.accent : DesignSystem.Colors.textMuted)

                TextField("Enter identity...", text: $myName)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .autocorrectionDisabled()
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
                            .font(.system(size: 18))
                            .foregroundColor(DesignSystem.Colors.textMuted)
                    }
                }
            }
            .padding(14)
            .background(DesignSystem.Colors.surface.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isEditing ? DesignSystem.Colors.accent.opacity(0.5) : DesignSystem.Colors.glassBorder,
                        lineWidth: 1
                    )
            )

            Text("Identity is used to locate your squares across all connected pools")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(DesignSystem.Colors.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .neonCard(DesignSystem.Colors.accent, intensity: 0.2)
    }
}

// MARK: - Quick Actions Section
struct QuickActionsSection: View {
    let onJoinPool: () -> Void
    @State private var scanRotation: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.horizontal.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.gold)

                Text("QUICK ACTIONS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.textMuted)
                    .tracking(2)

                Spacer()
            }

            Button {
                Haptics.impact(.light)
                onJoinPool()
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        // Scanning animation
                        Circle()
                            .stroke(DesignSystem.Colors.accent.opacity(0.2), lineWidth: 2)
                            .frame(width: 48, height: 48)

                        Circle()
                            .trim(from: 0, to: 0.25)
                            .stroke(DesignSystem.Colors.accent, lineWidth: 2)
                            .frame(width: 48, height: 48)
                            .rotationEffect(.degrees(scanRotation))

                        Image(systemName: "link.badge.plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.accent)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("JOIN POOL WITH CODE")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .tracking(1)

                        Text("Enter an invite code from host")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(DesignSystem.Colors.accent.opacity(0.6))
                }
                .padding(16)
                .neonCard(DesignSystem.Colors.accent, intensity: 0.15)
            }
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    scanRotation = 360
                }
            }
        }
    }
}

// MARK: - Share Pools Section
struct SharePoolsSection: View {
    let pools: [BoxGrid]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.live)

                Text("SHARE POOLS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.textMuted)
                    .tracking(2)

                Spacer()

                Text("\(pools.count)")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.live)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DesignSystem.Colors.live.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

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
            HStack {
                Image(systemName: "bell.and.waves.left.and.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.danger)

                Text("ALERTS MODULE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.textMuted)
                    .tracking(2)

                Spacer()

                // Status
                HStack(spacing: 4) {
                    Circle()
                        .fill(notificationsEnabled ? DesignSystem.Colors.live : DesignSystem.Colors.textMuted)
                        .frame(width: 6, height: 6)

                    Text(notificationsEnabled ? "ENABLED" : "DISABLED")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(notificationsEnabled ? DesignSystem.Colors.live : DesignSystem.Colors.textMuted)
                }
            }

            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: "bell.badge.waveform.fill",
                    iconColor: DesignSystem.Colors.danger,
                    title: "PUSH NOTIFICATIONS",
                    subtitle: "Get notified when you win",
                    isOn: $notificationsEnabled
                )

                Rectangle()
                    .fill(DesignSystem.Colors.glassBorder)
                    .frame(height: 1)
                    .padding(.leading, 56)

                SettingsToggleRow(
                    icon: "viewfinder.trianglebadge.exclamationmark",
                    iconColor: DesignSystem.Colors.gold,
                    title: "ON THE HUNT ALERTS",
                    subtitle: "When squares are close to winning",
                    isOn: $notificationsEnabled
                )
            }
            .neonCard(DesignSystem.Colors.danger, intensity: 0.1)
        }
    }
}

// MARK: - Live Scores Section
struct LiveScoresSection: View {
    @Binding var autoRefresh: Bool
    let lastUpdated: Date?
    @State private var wavePhase: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.live)

                Text("LIVE DATA FEED")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.textMuted)
                    .tracking(2)

                Spacer()

                if autoRefresh {
                    // Animated signal indicator
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(DesignSystem.Colors.live)
                                .frame(width: 3, height: 6 + CGFloat(i) * 4)
                                .opacity(0.4 + Double(i) * 0.3)
                        }
                    }
                }
            }

            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: "arrow.triangle.2.circlepath",
                    iconColor: DesignSystem.Colors.live,
                    title: "AUTO-REFRESH SCORES",
                    subtitle: "Updates every 30s during games",
                    isOn: $autoRefresh
                )

                if let lastUpdated = lastUpdated {
                    Rectangle()
                        .fill(DesignSystem.Colors.glassBorder)
                        .frame(height: 1)
                        .padding(.leading, 56)

                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .stroke(DesignSystem.Colors.textMuted.opacity(0.3), lineWidth: 2)
                                .frame(width: 40, height: 40)

                            Circle()
                                .trim(from: 0, to: 0.75)
                                .stroke(DesignSystem.Colors.textMuted, lineWidth: 2)
                                .frame(width: 40, height: 40)
                                .rotationEffect(.degrees(-90))

                            Image(systemName: "clock.badge.checkmark.fill")
                                .font(.system(size: 14))
                                .foregroundColor(DesignSystem.Colors.textMuted)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("LAST SYNC")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(DesignSystem.Colors.textMuted)
                                .tracking(1)

                            Text(lastUpdated, style: .relative)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                        }

                        Spacer()
                    }
                    .padding(16)
                }
            }
            .neonCard(DesignSystem.Colors.live, intensity: 0.1)
        }
    }
}

// MARK: - Data Section
struct DataSection: View {
    let onBackup: () -> Void
    @State private var showingClearConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "externaldrive.fill.badge.icloud")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.accent)

                Text("DATA MANAGEMENT")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.textMuted)
                    .tracking(2)

                Spacer()
            }

            VStack(spacing: 0) {
                Button {
                    Haptics.impact(.light)
                    onBackup()
                } label: {
                    SettingsRowContent(
                        icon: "arrow.up.doc.fill",
                        iconColor: DesignSystem.Colors.accent,
                        title: "BACKUP DATA",
                        showChevron: false
                    )
                }

                Rectangle()
                    .fill(DesignSystem.Colors.glassBorder)
                    .frame(height: 1)
                    .padding(.leading, 56)

                Button {
                    Haptics.impact(.medium)
                    showingClearConfirm = true
                } label: {
                    SettingsRowContent(
                        icon: "trash.fill",
                        iconColor: DesignSystem.Colors.danger,
                        title: "CLEAR ALL DATA",
                        titleColor: DesignSystem.Colors.danger,
                        showChevron: false
                    )
                }
            }
            .neonCard(DesignSystem.Colors.accent, intensity: 0.1)
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
            HStack {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Text("SYSTEM INFO")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.textMuted)
                    .tracking(2)

                Spacer()
            }

            VStack(spacing: 0) {
                Button {
                    Haptics.selection()
                    onShowAbout()
                } label: {
                    SettingsRowContent(
                        icon: "apps.iphone",
                        iconColor: DesignSystem.Colors.accent,
                        title: "ABOUT SQUAREUP",
                        showChevron: true
                    )
                }

                Rectangle()
                    .fill(DesignSystem.Colors.glassBorder)
                    .frame(height: 1)
                    .padding(.leading, 56)

                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.gold.opacity(0.15))
                            .frame(width: 40, height: 40)

                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.gold)
                    }

                    Text("VERSION")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .tracking(1)

                    Spacer()

                    Text("1.0.0")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(DesignSystem.Colors.accent.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(16)
            }
            .neonCard(DesignSystem.Colors.textSecondary, intensity: 0.05)
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
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .tracking(1)

                Text(subtitle)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
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
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            Text(title)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(titleColor)
                .tracking(1)

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(DesignSystem.Colors.textMuted.opacity(0.6))
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
            HStack(spacing: 14) {
                // Mini grid preview
                VStack(spacing: 1) {
                    ForEach(0..<3, id: \.self) { row in
                        HStack(spacing: 1) {
                            ForEach(0..<3, id: \.self) { col in
                                Rectangle()
                                    .fill(DesignSystem.Colors.accent.opacity(0.3 + Double.random(in: 0...0.4)))
                                    .frame(width: 10, height: 10)
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))

                VStack(alignment: .leading, spacing: 4) {
                    Text(pool.name.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .tracking(1)

                    HStack(spacing: 6) {
                        Text("CODE:")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.textMuted)
                        Text(inviteCode)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.accent)
                    }
                }

                Spacer()

                Image(systemName: "square.and.arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(DesignSystem.Colors.accent.opacity(0.6))
            }
            .padding(14)
            .neonCard(DesignSystem.Colors.accent, intensity: 0.1)
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
    @State private var codeGlow = false

    var body: some View {
        ZStack {
            AnimatedMeshBackground()
            TechGridBackground()

            VStack(spacing: 32) {
                // Header
                HStack {
                    Text("SHARE POOL")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(DesignSystem.Colors.cyberGradient)

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(DesignSystem.Colors.textMuted)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Pool info
                VStack(spacing: 20) {
                    ZStack {
                        // Orbital rings
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .stroke(DesignSystem.Colors.accent.opacity(0.1), lineWidth: 1)
                                .frame(width: 80 + CGFloat(i) * 30)
                        }

                        Circle()
                            .fill(DesignSystem.Colors.cyberGradient)
                            .frame(width: 70, height: 70)

                        Image(systemName: "square.grid.3x3.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                    .glow(DesignSystem.Colors.accent, radius: 20)

                    Text(pool.name.uppercased())
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .tracking(2)

                    HStack(spacing: 8) {
                        TeamBadge(team: pool.awayTeam, size: 28)
                        Text("VS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.textMuted)
                        TeamBadge(team: pool.homeTeam, size: 28)
                    }
                }

                // Invite code
                VStack(spacing: 20) {
                    Text("INVITE CODE")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.textMuted)
                        .tracking(3)

                    HStack(spacing: 6) {
                        ForEach(Array(inviteCode), id: \.self) { char in
                            Text(String(char))
                                .font(.system(size: 24, weight: .black, design: .monospaced))
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .frame(width: 38, height: 50)
                                .background(DesignSystem.Colors.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(DesignSystem.Colors.accent.opacity(codeGlow ? 0.8 : 0.3), lineWidth: 1)
                                )
                        }
                    }
                    .shadow(color: codeGlow ? DesignSystem.Colors.accentGlow : .clear, radius: 15)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                            codeGlow = true
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
                            Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                            Text(copied ? "COPIED!" : "COPY CODE")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .tracking(1)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(copied ? DesignSystem.Colors.live : DesignSystem.Colors.accent)
                        )
                        .shadow(color: (copied ? DesignSystem.Colors.liveGlow : DesignSystem.Colors.accentGlow), radius: 12)
                    }
                }
                .padding(24)
                .neonCard(DesignSystem.Colors.accent, intensity: 0.2)
                .padding(.horizontal, 20)

                // Share options
                VStack(spacing: 16) {
                    Text("SHARE VIA")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.textMuted)
                        .tracking(3)

                    HStack(spacing: 32) {
                        ShareOptionButton(icon: "message.fill", label: "MESSAGE", color: DesignSystem.Colors.live) {
                            shareViaMessages()
                        }

                        ShareOptionButton(icon: "envelope.fill", label: "EMAIL", color: DesignSystem.Colors.accent) {
                            shareViaEmail()
                        }

                        ShareOptionButton(icon: "square.and.arrow.up.fill", label: "MORE", color: DesignSystem.Colors.textSecondary) {
                            shareGeneric()
                        }
                    }
                }

                Spacer()

                // Instructions
                VStack(alignment: .leading, spacing: 12) {
                    Text("HOW TO JOIN")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.textMuted)
                        .tracking(2)

                    InstructionRow(number: "1", text: "Download SquareUp from the App Store")
                    InstructionRow(number: "2", text: "Go to Settings > Join Pool with Code")
                    InstructionRow(number: "3", text: "Enter the code above")
                }
                .padding(20)
                .neonCard(DesignSystem.Colors.textSecondary, intensity: 0.05)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
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
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(DesignSystem.Colors.accent)
                .frame(width: 24, height: 24)
                .background(DesignSystem.Colors.accent.opacity(0.15))
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
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
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(color)
                }

                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .tracking(1)
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
    @State private var scanRotation: Double = 0

    var body: some View {
        ZStack {
            AnimatedMeshBackground()
            TechGridBackground()

            VStack(spacing: 32) {
                // Header
                HStack {
                    Text("JOIN POOL")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(DesignSystem.Colors.cyberGradient)

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(DesignSystem.Colors.textMuted)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Icon with scanning animation
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(DesignSystem.Colors.accent.opacity(0.1), lineWidth: 1)
                            .frame(width: 80 + CGFloat(i) * 30)
                    }

                    Circle()
                        .trim(from: 0, to: 0.25)
                        .stroke(DesignSystem.Colors.accent, lineWidth: 2)
                        .frame(width: 130)
                        .rotationEffect(.degrees(scanRotation))

                    Circle()
                        .fill(DesignSystem.Colors.cyberGradient)
                        .frame(width: 70, height: 70)

                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                }
                .glow(DesignSystem.Colors.accent, radius: 20)
                .onAppear {
                    withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                        scanRotation = 360
                    }
                }

                VStack(spacing: 8) {
                    Text("ENTER INVITE CODE")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .tracking(2)

                    Text("Enter the code shared by the pool host")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }

                // Code input
                VStack(spacing: 16) {
                    TextField("XXXXXXXX", text: $code)
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($isCodeFocused)
                        .padding()
                        .background(DesignSystem.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    isCodeFocused ? DesignSystem.Colors.accent.opacity(0.6) : DesignSystem.Colors.glassBorder,
                                    lineWidth: isCodeFocused ? 2 : 1
                                )
                        )
                        .shadow(color: isCodeFocused ? DesignSystem.Colors.accentGlow : .clear, radius: 12)
                        .onChange(of: code) { _, newValue in
                            if newValue.count > 8 {
                                code = String(newValue.prefix(8))
                            }
                            code = code.uppercased()
                        }
                        .padding(.horizontal, 20)

                    if let error = error {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                            Text(error)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                        }
                        .foregroundColor(DesignSystem.Colors.danger)
                    }
                }

                Button {
                    Haptics.impact(.medium)
                    joinPool()
                } label: {
                    HStack(spacing: 10) {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                            Text("JOIN POOL")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .tracking(1)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        code.count == 8 ?
                            DesignSystem.Colors.cyberGradient :
                            LinearGradient(colors: [DesignSystem.Colors.textMuted], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(
                        color: code.count == 8 ? DesignSystem.Colors.accentGlow : .clear,
                        radius: 15
                    )
                }
                .disabled(code.count != 8 || isLoading)
                .padding(.horizontal, 20)

                Spacer()

                // Note
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 14))
                    Text("Demo: Codes create local pool copies. Cloud sync coming soon!")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
                .foregroundColor(DesignSystem.Colors.textMuted)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            isCodeFocused = true
        }
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
    @State private var logoRotation: Double = 0

    var body: some View {
        ZStack {
            AnimatedMeshBackground()
            TechGridBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Header
                    HStack {
                        Text("ABOUT")
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .foregroundStyle(DesignSystem.Colors.cyberGradient)

                        Spacer()

                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(DesignSystem.Colors.textMuted)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // App logo with orbital animation
                    VStack(spacing: 24) {
                        ZStack {
                            // Orbital rings
                            ForEach(0..<4, id: \.self) { i in
                                Circle()
                                    .stroke(DesignSystem.Colors.accent.opacity(0.08), lineWidth: 1)
                                    .frame(width: 100 + CGFloat(i) * 30)
                            }

                            Circle()
                                .trim(from: 0, to: 0.15)
                                .stroke(DesignSystem.Colors.accent, lineWidth: 2)
                                .frame(width: 180)
                                .rotationEffect(.degrees(logoRotation))

                            Circle()
                                .trim(from: 0.5, to: 0.65)
                                .stroke(DesignSystem.Colors.gold, lineWidth: 2)
                                .frame(width: 150)
                                .rotationEffect(.degrees(-logoRotation * 0.7))

                            Circle()
                                .fill(DesignSystem.Colors.cyberGradient)
                                .frame(width: 90, height: 90)

                            Image(systemName: "square.grid.3x3.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.white)
                        }
                        .glow(DesignSystem.Colors.accent, radius: 25)
                        .onAppear {
                            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                                logoRotation = 360
                            }
                        }

                        VStack(spacing: 8) {
                            Text("SQUAREUP")
                                .font(.system(size: 32, weight: .black, design: .monospaced))
                                .foregroundStyle(DesignSystem.Colors.cyberGradient)
                                .tracking(4)

                            Text("SUPER BOWL SQUARES REIMAGINED")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(DesignSystem.Colors.textMuted)
                                .tracking(2)
                        }
                    }

                    // Features
                    VStack(spacing: 16) {
                        FeatureRow(
                            icon: "text.viewfinder",
                            iconColor: DesignSystem.Colors.accent,
                            title: "SMART SCANNING",
                            description: "Scan pool sheets with OCR technology"
                        )

                        FeatureRow(
                            icon: "dot.radiowaves.left.and.right",
                            iconColor: DesignSystem.Colors.live,
                            title: "LIVE SCORES",
                            description: "Real-time score updates during game"
                        )

                        FeatureRow(
                            icon: "viewfinder.trianglebadge.exclamationmark",
                            iconColor: DesignSystem.Colors.danger,
                            title: "ON THE HUNT",
                            description: "Know when squares are close to winning"
                        )

                        FeatureRow(
                            icon: "bell.badge.waveform.fill",
                            iconColor: DesignSystem.Colors.gold,
                            title: "SMART ALERTS",
                            description: "Get notified when you win a quarter"
                        )

                        FeatureRow(
                            icon: "paperplane.circle.fill",
                            iconColor: DesignSystem.Colors.textSecondary,
                            title: "EASY SHARING",
                            description: "Share pools via invite codes"
                        )
                    }
                    .padding(20)
                    .neonCard(DesignSystem.Colors.accent, intensity: 0.15)
                    .padding(.horizontal, 20)

                    // Footer
                    VStack(spacing: 12) {
                        Text("MADE WITH ♠️ FOR FOOTBALL FANS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                            .tracking(2)

                        HStack(spacing: 6) {
                            Text("VERSION")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(DesignSystem.Colors.textMuted)
                            Text("1.0.0")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(DesignSystem.Colors.accent)
                        }
                    }
                    .padding(.bottom, 40)
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
        HStack(alignment: .center, spacing: 14) {
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
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .tracking(1)

                Text(description)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
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

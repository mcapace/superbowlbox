import SwiftUI

// MARK: - Animated instruction screens (onboarding + "How it works")

struct InstructionStep: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let accent: Color
}

private let steps: [InstructionStep] = [
    InstructionStep(
        icon: "person.crop.circle.badge.plus",
        title: "Sign in to sync",
        subtitle: "Optional—sign in with Apple or Google to sync your pools and preferences across devices.",
        accent: AppColors.fieldGreen
    ),
    InstructionStep(
        icon: "square.grid.3x3.topleft.filled",
        title: "Create or scan a pool",
        subtitle: "Start a new box pool or scan an existing sheet with your camera. SquareUp reads the grid and names for you.",
        accent: AppColors.fieldGreen
    ),
    InstructionStep(
        icon: "person.crop.circle.badge.checkmark",
        title: "Set your name",
        subtitle: "Add your name in Settings. Your squares will be highlighted across every pool so you can spot them at a glance.",
        accent: AppColors.fieldGreenLight
    ),
    InstructionStep(
        icon: "play.circle.fill",
        title: "Watch live scores",
        subtitle: "Scores update automatically during the game. The winning numbers (last digit of each team’s score) drive who’s ahead.",
        accent: AppColors.gold
    ),
    InstructionStep(
        icon: "trophy.fill",
        title: "See who wins",
        subtitle: "The app highlights the current winning square and tracks winners by quarter, halftime, or final—depending on your pool’s rules.",
        accent: AppColors.goldMuted
    )
]

struct InstructionsView: View {
    var isOnboarding: Bool = true
    var onComplete: () -> Void = {}
    @EnvironmentObject var appState: AppState

    @State private var currentPage = 0
    @State private var iconScale: CGFloat = 0.6
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var iconFloat: CGFloat = 0
    @Environment(\.dismiss) var dismiss

    private var pageCount: Int { isOnboarding ? steps.count : steps.count - 1 }
    private var lastPageIndex: Int { pageCount - 1 }

    var body: some View {
        ZStack {
            DesignSystem.Colors.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip (sheet mode or onboarding)
                if !isOnboarding {
                    HStack {
                        Spacer()
                        Button("Skip") {
                            dismiss()
                        }
                        .font(AppTypography.callout)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                    }
                }

                TabView(selection: $currentPage) {
                    ForEach(0..<pageCount, id: \.self) { index in
                        let stepIndex = isOnboarding ? index : index + 1
                        if isOnboarding && index == 0 {
                            OnboardingSignInView(
                                authService: appState.authService,
                                onSkip: {
                                    HapticService.selection()
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        currentPage = 1
                                    }
                                }
                            )
                            .tag(0)
                        } else {
                            InstructionStepView(
                                step: steps[stepIndex],
                                pageIndex: index,
                                currentPage: currentPage,
                                iconScale: $iconScale,
                                iconOpacity: $iconOpacity,
                                textOpacity: $textOpacity,
                                iconFloat: $iconFloat
                            )
                            .tag(index)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.35), value: currentPage)

                // Page indicator (tech-style)
                HStack(spacing: 8) {
                    ForEach(0..<pageCount, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? AppColors.techCyan : Color(.systemGray4))
                            .frame(width: index == currentPage ? 10 : 8, height: index == currentPage ? 10 : 8)
                            .scaleEffect(index == currentPage ? 1.0 : 0.9)
                            .overlay(
                                Circle()
                                    .strokeBorder(index == currentPage ? AppColors.techCyan.opacity(0.6) : Color.clear, lineWidth: 1.5)
                            )
                            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentPage)
                    }
                }
                .padding(.bottom, 24)

                // Button
                Button {
                    if currentPage < lastPageIndex {
                        HapticService.selection()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            currentPage += 1
                        }
                    } else {
                        HapticService.success()
                        onComplete()
                        if isOnboarding { } else { dismiss() }
                    }
                } label: {
                    Text(currentPage < lastPageIndex ? "Next" : (isOnboarding ? "Get Started" : "Done"))
                        .font(AppTypography.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: AppCardStyle.cornerRadiusSmall)
                                .fill(AppColors.fieldGreen)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCardStyle.cornerRadiusSmall)
                                .strokeBorder(AppColors.techCyan.opacity(0.4), lineWidth: 1)
                        )
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .onChange(of: currentPage) { _, _ in
            triggerStepAnimation()
        }
        .onAppear {
            triggerStepAnimation()
        }
    }

    private func triggerStepAnimation() {
        iconScale = 0.6
        iconOpacity = 0
        textOpacity = 0
        iconFloat = 0
        withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
            textOpacity = 1.0
        }
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(0.6)) {
            iconFloat = 6
        }
    }
}

// MARK: - Onboarding sign-in step (Apple + Google)
private struct OnboardingSignInView: View {
    @ObservedObject var authService: AuthService
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
                .frame(height: 20)

            SquareUpLogoView(showIcon: true, wordmarkSize: 38)
                .padding(.bottom, 8)

            VStack(spacing: 12) {
                Text("Sign in to sync")
                    .font(AppTypography.title2)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                Text("Optional—sign in with Apple or Google to sync your pools and preferences across devices.")
                    .font(AppTypography.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 12) {
                SignInWithAppleButton {
                    HapticService.impactLight()
                    authService.signInWithApple()
                }
                .frame(height: 52)
                .cornerRadius(12)

                GoogleSignInButton(
                    action: {
                        Task { @MainActor in
                            HapticService.impactLight()
                            guard let vc = topViewController() else { return }
                            await authService.signInWithGoogle(presenting: vc)
                        }
                    },
                    isDisabled: authService.isSigningIn
                )

                if let error = authService.errorMessage {
                    Text(error)
                        .font(AppTypography.caption2)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            Button("Skip for now") {
                onSkip()
            }
            .font(AppTypography.callout)
            .foregroundColor(.secondary)
            .padding(.top, 16)

            Spacer(minLength: 80)
        }
    }

    private func topViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else { return nil }
        var vc = window.rootViewController
        while let presented = vc?.presentedViewController { vc = presented }
        return vc
    }
}

private struct InstructionStepView: View {
    let step: InstructionStep
    let pageIndex: Int
    let currentPage: Int
    @Binding var iconScale: CGFloat
    @Binding var iconOpacity: Double
    @Binding var textOpacity: Double
    @Binding var iconFloat: CGFloat

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
                .frame(height: 20)

            // Animated icon
            ZStack {
                Circle()
                    .fill(step.accent.opacity(0.15))
                    .frame(width: 160, height: 160)
                    .scaleEffect(iconScale * 1.1)
                    .opacity(iconOpacity * 0.8)

                Image(systemName: step.icon)
                    .font(.system(size: 72, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [step.accent, step.accent.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)
                    .offset(y: iconFloat)
            }
            .frame(height: 200)

            VStack(spacing: 16) {
                Text(step.title)
                    .font(AppTypography.title)
                    .multilineTextAlignment(.center)
                    .opacity(textOpacity)

                Text(step.subtitle)
                    .font(AppTypography.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 8)
                    .opacity(textOpacity)
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 80)
        }
        .opacity(pageIndex == currentPage ? 1 : 0.5)
        .scaleEffect(pageIndex == currentPage ? 1 : 0.98)
    }
}

#Preview("Onboarding") {
    InstructionsView(isOnboarding: true, onComplete: {})
        .environmentObject(AppState())
}

#Preview("Sheet") {
    InstructionsView(isOnboarding: false, onComplete: {})
        .environmentObject(AppState())
}

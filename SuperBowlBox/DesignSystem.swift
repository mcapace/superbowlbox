import SwiftUI

// MARK: - Premium dark glassmorphic design system

enum DesignSystem {
    // MARK: Colors
    enum Colors {
        static let backgroundPrimary = Color(hex: "09090B") ?? Color.black
        static let backgroundSecondary = Color(hex: "18181B") ?? Color(white: 0.09)
        static let backgroundTertiary = Color(hex: "27272A") ?? Color(white: 0.15)
        static let glassFill = Color.white.opacity(0.05)
        static let glassBorder = Color.white.opacity(0.10)
        static let accentBlue = Color(hex: "3B82F6") ?? Color.blue
        static let accentBlueGlow = (Color(hex: "3B82F6") ?? Color.blue).opacity(0.5)
        static let liveGreen = Color(hex: "22C55E") ?? Color.green
        static let winnerGold = Color(hex: "F59E0B") ?? Color.orange
        static let dangerRed = Color(hex: "EF4444") ?? Color.red
        static let textPrimary = Color.white
        static let textSecondary = Color(hex: "A1A1AA") ?? Color.gray
        static let textTertiary = Color(hex: "71717A") ?? Color.gray
        static let textMuted = Color(hex: "52525B") ?? Color.gray
    }

    // MARK: Typography
    enum Typography {
        static let scoreHero = Font.system(size: 72, weight: .bold, design: .rounded)
        static let scoreLarge = Font.system(size: 56, weight: .bold, design: .rounded)
        static let scoreMedium = Font.system(size: 40, weight: .bold, design: .rounded)
        static let title = Font.system(size: 22, weight: .bold, design: .rounded)
        static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 17, weight: .regular, design: .rounded)
        static let callout = Font.system(size: 16, weight: .medium, design: .rounded)
        static let caption = Font.system(size: 13, weight: .medium, design: .rounded)
        static let caption2 = Font.system(size: 11, weight: .medium, design: .rounded)
        static let mono = Font.system(size: 17, weight: .medium, design: .monospaced)
    }

    // MARK: Layout
    enum Layout {
        static let cornerRadius: CGFloat = 20
        static let cornerRadiusSmall: CGFloat = 12
        static let cardPadding: CGFloat = 20
        static let sectionSpacing: CGFloat = 24
        static let screenInset: CGFloat = 20
    }
}

// MARK: - Glass card modifier (use .dsGlassCard() to avoid conflict with App card())
extension View {
    func dsGlassCard(cornerRadius: CGFloat = DesignSystem.Layout.cornerRadius) -> some View {
        self
            .padding(DesignSystem.Layout.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(DesignSystem.Colors.glassFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(DesignSystem.Colors.glassBorder, lineWidth: 1)
            )
    }
}

// MARK: - Glow modifier
extension View {
    func glow(color: Color = DesignSystem.Colors.accentBlueGlow, radius: CGFloat = 12) -> some View {
        self.shadow(color: color, radius: radius)
    }
}

// MARK: - Pulse animation (for live/target icons)
struct PulseModifier: ViewModifier {
    @State private var isPulsing = false
    var isActive: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive && isPulsing ? 1.15 : 1.0)
            .opacity(isActive && isPulsing ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}
extension View {
    func pulse(isActive: Bool = true) -> some View {
        modifier(PulseModifier(isActive: isActive))
    }
}

// MARK: - Shimmer (loading)
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.15),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.5)
                    .offset(x: phase * geo.size.width - geo.size.width * 0.5)
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) { phase = 1 }
            }
    }
}
extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// Uses Color(hex:) from ContentView extension when available; fallbacks use Color(white:) / Color.blue etc.

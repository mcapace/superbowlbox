import SwiftUI

// MARK: - Futuristic design system (mesh, orbitals, neon, cyber palette)

enum DesignSystem {
    // MARK: Colors (cyber palette + existing)
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
        // Cyber / futuristic
        static let cyberCyan = Color(hex: "06B6D4") ?? Color.cyan
        static let matrixGreen = Color(hex: "10B981") ?? Color.green
        static let neonPink = Color(hex: "EC4899") ?? Color.pink
        static let neonCyanGlow = (Color(hex: "06B6D4") ?? Color.cyan).opacity(0.6)
        static let matrixGreenGlow = (Color(hex: "10B981") ?? Color.green).opacity(0.5)
    }

    // MARK: Typography (monospaced for tech aesthetic)
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
        static let monoSmall = Font.system(size: 13, weight: .medium, design: .monospaced)
    }
    static let letterTracking: CGFloat = 0.8

    // MARK: Layout
    enum Layout {
        static let cornerRadius: CGFloat = 20
        static let cornerRadiusSmall: CGFloat = 12
        static let cardPadding: CGFloat = 20
        static let sectionSpacing: CGFloat = 24
        static let screenInset: CGFloat = 20
    }
}

// MARK: - Animated mesh background (floating orbs + gradient)
struct MeshBackgroundView: View {
    @State private var phase: CGFloat = 0
    var body: some View {
        ZStack {
            DesignSystem.Colors.backgroundPrimary
                .ignoresSafeArea()
            GeometryReader { geo in
                ZStack {
                    RadialGradient(
                        colors: [
                            DesignSystem.Colors.cyberCyan.opacity(0.15),
                            Color.clear
                        ],
                        center: .init(x: 0.2 + phase * 0.1, y: 0.3),
                        startRadius: 0,
                        endRadius: max(geo.size.width, geo.size.height) * 0.8
                    )
                    RadialGradient(
                        colors: [
                            DesignSystem.Colors.matrixGreen.opacity(0.12),
                            Color.clear
                        ],
                        center: .init(x: 0.8 - phase * 0.05, y: 0.7),
                        startRadius: 0,
                        endRadius: max(geo.size.width, geo.size.height) * 0.7
                    )
                    RadialGradient(
                        colors: [
                            DesignSystem.Colors.neonPink.opacity(0.08),
                            Color.clear
                        ],
                        center: .init(x: 0.5, y: 0.5 + phase * 0.03),
                        startRadius: 0,
                        endRadius: max(geo.size.width, geo.size.height) * 0.5
                    )
                }
            }
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) { phase = 1 }
            }
        }
    }
}

// MARK: - Tech grid overlay (subtle lines)
struct TechGridOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let step: CGFloat = 40
            Path { p in
                var x: CGFloat = 0
                while x <= geo.size.width + step {
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: geo.size.height))
                    x += step
                }
                var y: CGFloat = 0
                while y <= geo.size.height + step {
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: geo.size.width, y: y))
                    y += step
                }
            }
            .stroke(DesignSystem.Colors.glassBorder.opacity(0.3), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Orbital ring (circular progress / decoration)
struct OrbitalRingView: View {
    var progress: CGFloat = 1.0
    var lineWidth: CGFloat = 2
    var size: CGFloat = 60
    var color: Color = DesignSystem.Colors.cyberCyan
    @State private var rotation: Double = 0
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
                .frame(width: size, height: size)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [color, color.opacity(0.6), color]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(rotation))
        }
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) { rotation = 360 }
        }
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

    /// Neon card: dark fill + glowing border (futuristic)
    func neonCard(
        cornerRadius: CGFloat = DesignSystem.Layout.cornerRadius,
        glowColor: Color = DesignSystem.Colors.neonCyanGlow
    ) -> some View {
        self
            .padding(DesignSystem.Layout.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(DesignSystem.Colors.backgroundTertiary.opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(glowColor.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: glowColor.opacity(0.25), radius: 12, x: 0, y: 4)
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

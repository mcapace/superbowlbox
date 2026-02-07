import SwiftUI

// MARK: - Premium sportsbook / analytics design (DraftKings-style)

enum DesignSystem {
    // MARK: Colors (lighter, modern dark theme for readability)
    enum Colors {
        static let backgroundPrimary = Color(hex: "16181A") ?? Color(white: 0.09)
        static let backgroundSecondary = Color(hex: "1C1E21") ?? Color(white: 0.11)
        static let headerGreen = Color(hex: "1E2D21") ?? Color(red: 0.12, green: 0.18, blue: 0.13)
        static let backgroundTertiary = Color(hex: "222426") ?? Color(white: 0.13)
        static let cardSurface = Color(hex: "1E2124") ?? Color(white: 0.12)
        static let cardBorder = Color.white.opacity(0.12)
        static let cardShadow = Color.black.opacity(0.3)
        static let glassFill = Color.white.opacity(0.06)
        static let glassBorder = Color.white.opacity(0.1)
        static let accentBlue = Color(hex: "0A84FF") ?? Color.blue
        static let accentBlueGlow = (Color(hex: "0A84FF") ?? Color.blue).opacity(0.4)
        static let liveGreen = Color(hex: "30D158") ?? Color.green
        static let winnerGold = Color(hex: "FF9F0A") ?? Color.orange
        static let dangerRed = Color(hex: "FF453A") ?? Color.red
        static let textPrimary = Color.white
        static let textSecondary = Color(hex: "C8C8CE") ?? Color(white: 0.82)
        static let textTertiary = Color(hex: "A8A8B0") ?? Color(white: 0.72)
        static let textMuted = Color(hex: "8E8E96") ?? Color(white: 0.6)
        static let surfaceElevated = Color(hex: "2A2D30") ?? Color(white: 0.2)
        static let cyberCyan = Color(hex: "64D2FF") ?? Color.cyan
        static let matrixGreen = liveGreen
        static let neonPink = Color(hex: "FF375F") ?? Color.pink
        static let neonCyanGlow = accentBlueGlow
        static let matrixGreenGlow = liveGreen.opacity(0.4)
    }

    enum Dashboard {
        static let header = Color(hex: "1A2520") ?? Color(red: 0.1, green: 0.14, blue: 0.13)
        static let headerBright = Color(hex: "34D96C") ?? Color.green
        static let background = Color(hex: "14181E") ?? Color(red: 0.08, green: 0.09, blue: 0.12)
        static let card = Color(hex: "1C2228") ?? Color(red: 0.11, green: 0.13, blue: 0.16)
        static let cardBorder = Color.white.opacity(0.12)
    }

    // MARK: Typography (SF Pro Rounded for UI; tabular numbers for scores)
    enum Typography {
        static let scoreHero = Font.system(size: 56, weight: .bold).monospacedDigit()
        static let scoreLarge = Font.system(size: 44, weight: .bold).monospacedDigit()
        static let scoreMedium = Font.system(size: 34, weight: .bold).monospacedDigit()
        static let title = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 17, weight: .regular, design: .rounded)
        static let callout = Font.system(size: 15, weight: .medium, design: .rounded)
        static let caption = Font.system(size: 13, weight: .regular, design: .rounded)
        static let caption2 = Font.system(size: 11, weight: .medium, design: .rounded)
        static let mono = Font.system(size: 15, weight: .medium, design: .monospaced)
        static let monoSmall = Font.system(size: 12, weight: .medium, design: .monospaced)
        static let labelUppercase = Font.system(size: 11, weight: .semibold, design: .rounded)
    }
    static let letterTracking: CGFloat = 0.3

    // MARK: Layout (tighter, less clunky)
    enum Layout {
        static let cornerRadius: CGFloat = 10
        static let cornerRadiusSmall: CGFloat = 6
        static let cardPadding: CGFloat = 14
        static let sectionSpacing: CGFloat = 14
        static let screenInset: CGFloat = 14
        static let sectionHeaderBottom: CGFloat = 6
        /// Control Center / liquid glass: larger radius for frosted segments
        static let glassCornerRadius: CGFloat = 18
        static let glassCornerRadiusLarge: CGFloat = 22
    }
}

// MARK: - Section header (sleek: label + thin divider)
struct SectionHeaderView: View {
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(DesignSystem.Typography.labelUppercase)
                .tracking(0.6)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            Rectangle()
                .fill(DesignSystem.Colors.cardBorder)
                .frame(height: 0.5)
        }
        .padding(.horizontal, DesignSystem.Layout.screenInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
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

    /// Neon card: dark fill + glowing border (legacy / optional)
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

    /// Sportsbook card: solid surface, subtle border, no glow (DraftKings-style)
    func sportsbookCard(
        cornerRadius: CGFloat = DesignSystem.Layout.cornerRadius,
        accentBorder: Color? = nil
    ) -> some View {
        self
            .padding(DesignSystem.Layout.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(DesignSystem.Colors.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(accentBorder ?? DesignSystem.Colors.cardBorder, lineWidth: 1)
            )
            .shadow(color: DesignSystem.Colors.cardShadow, radius: 6, x: 0, y: 2)
    }

    /// Two-layer shadow for visible depth (use on any glass card or widget)
    func glassDepthShadows() -> some View {
        self
            .shadow(color: DesignSystem.Colors.cardShadow.opacity(0.5), radius: 3, x: 0, y: 1.5)
            .shadow(color: DesignSystem.Colors.cardShadow.opacity(0.35), radius: 14, x: 0, y: 5)
    }

    /// Extra dimension: third softer shadow for more lift
    func glassDepthShadowsEnhanced() -> some View {
        self
            .glassDepthShadows()
            .shadow(color: DesignSystem.Colors.cardShadow.opacity(0.22), radius: 20, x: 0, y: 8)
    }

    /// 3D bevel: top-edge highlight so cards look raised (call after background + border)
    func glassBevelHighlight(cornerRadius: CGFloat = DesignSystem.Layout.glassCornerRadius) -> some View {
        self
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.08),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
    }

    /// Liquid glass / Control Center style: frosted material, depth shadows, bevel, thin border
    func liquidGlassCard(
        cornerRadius: CGFloat = DesignSystem.Layout.glassCornerRadius,
        useThinMaterial: Bool = true
    ) -> some View {
        let material: Material = useThinMaterial ? .ultraThinMaterial : .thinMaterial
        return self
            .padding(DesignSystem.Layout.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(material)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(DesignSystem.Colors.glassBorder, lineWidth: 0.8)
            )
            .glassBevelHighlight(cornerRadius: cornerRadius)
            .glassDepthShadowsEnhanced()
    }
}

// MARK: - Solid screen background (sportsbook default)
struct SportsbookBackgroundView: View {
    var body: some View {
        ZStack {
            DesignSystem.Colors.backgroundPrimary
                .ignoresSafeArea()
            // Subtle depth: very faint gradient
            LinearGradient(
                colors: [
                    DesignSystem.Colors.liveGreen.opacity(0.03),
                    Color.clear,
                    DesignSystem.Colors.accentBlue.opacity(0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
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

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
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(DesignSystem.Colors.glassFill)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.04),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(DesignSystem.Colors.glassBorder, lineWidth: 1)
            )
            .glassBevelHighlight(cornerRadius: cornerRadius)
            .glassDepthShadows()
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

    /// Sportsbook card: solid surface, gradient border, multi-layer depth (sophisticated, tech-forward)
    func sportsbookCard(
        cornerRadius: CGFloat = DesignSystem.Layout.cornerRadius,
        accentBorder: Color? = nil
    ) -> some View {
        self
            .padding(DesignSystem.Layout.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(DesignSystem.Colors.cardSurface)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.04),
                                    Color.clear,
                                    Color.black.opacity(0.05)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        accentBorder ?? DesignSystem.Colors.cardBorder,
                        lineWidth: 1
                    )
            )
            .glassBevelHighlight(cornerRadius: cornerRadius)
            .glassDepthShadows()
    }

    /// Two-layer shadow for visible depth (use on any glass card or widget)
    func glassDepthShadows() -> some View {
        self
            .shadow(color: DesignSystem.Colors.cardShadow.opacity(0.55), radius: 2, x: 0, y: 1)
            .shadow(color: DesignSystem.Colors.cardShadow.opacity(0.4), radius: 8, x: 0, y: 3)
            .shadow(color: DesignSystem.Colors.cardShadow.opacity(0.28), radius: 16, x: 0, y: 6)
    }

    /// Extra dimension: multi-layer shadow for premium lift and depth (tech-forward, sophisticated)
    func glassDepthShadowsEnhanced() -> some View {
        self
            .shadow(color: DesignSystem.Colors.cardShadow.opacity(0.5), radius: 3, x: 0, y: 1.5)
            .shadow(color: DesignSystem.Colors.cardShadow.opacity(0.38), radius: 10, x: 0, y: 4)
            .shadow(color: DesignSystem.Colors.cardShadow.opacity(0.25), radius: 22, x: 0, y: 8)
            .shadow(color: Color.black.opacity(0.18), radius: 32, x: 0, y: 12)
    }

    /// 3D bevel: top-edge highlight so cards look raised and lit from above (call after background + border)
    func glassBevelHighlight(cornerRadius: CGFloat = DesignSystem.Layout.glassCornerRadius) -> some View {
        self
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.04),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.2
                    )
            )
    }

    /// Subtle inner depth: gradient overlay (lighter top, darker bottom) for a lit-from-above card feel
    func glassInnerDepth(cornerRadius: CGFloat = DesignSystem.Layout.glassCornerRadius) -> some View {
        self
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.06),
                                Color.clear,
                                Color.black.opacity(0.06)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .allowsHitTesting(false)
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
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(material)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.05),
                                    Color.clear,
                                    Color.black.opacity(0.04)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.glassBorder,
                                DesignSystem.Colors.glassBorder,
                                DesignSystem.Colors.glassBorder.opacity(0.6)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
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

// MARK: - Score flip digit (airport-board style)
struct FlipDigit: View {
    let digit: Int
    let color: Color
    let size: CGFloat
    @State private var displayDigit: Int = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.15)
                .fill(DesignSystem.Colors.surfaceElevated)
                .frame(width: size, height: size * 1.4)
            Text("\(displayDigit)")
                .font(.system(size: size * 0.8, weight: .black, design: .rounded))
                .foregroundColor(color)
                .contentTransition(.numericText(value: Double(displayDigit)))
            Rectangle()
                .fill(DesignSystem.Colors.backgroundPrimary)
                .frame(height: 2)
            RoundedRectangle(cornerRadius: size * 0.15)
                .stroke(color.opacity(0.3), lineWidth: 1)
                .frame(width: size, height: size * 1.4)
        }
        .shadow(color: color.opacity(0.3), radius: 8, y: 2)
        .onChange(of: digit) { _, newValue in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { displayDigit = newValue }
        }
        .onAppear { displayDigit = digit }
    }
}

// MARK: - Live pulse indicator
struct LivePulseIndicator: View {
    let isLive: Bool
    var size: CGFloat = 12
    @State private var pulse = false
    @State private var ringScale: CGFloat = 1
    @State private var ringOpacity: Double = 0.8

    var body: some View {
        ZStack {
            if isLive {
                Circle()
                    .stroke(DesignSystem.Colors.liveGreen, lineWidth: 2)
                    .frame(width: size * 2.5, height: size * 2.5)
                    .scaleEffect(ringScale)
                    .opacity(ringOpacity)
                Circle()
                    .stroke(DesignSystem.Colors.liveGreen, lineWidth: 1)
                    .frame(width: size * 2, height: size * 2)
                    .scaleEffect(ringScale * 0.8)
                    .opacity(ringOpacity * 0.6)
            }
            Circle()
                .fill(isLive ? DesignSystem.Colors.liveGreen : DesignSystem.Colors.textMuted)
                .frame(width: size, height: size)
                .scaleEffect(pulse ? 1.2 : 1.0)
                .shadow(color: isLive ? DesignSystem.Colors.liveGreen.opacity(0.6) : .clear, radius: 6)
        }
        .onAppear {
            guard isLive else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true }
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) { ringScale = 2; ringOpacity = 0 }
        }
    }
}

// MARK: - Quarter progress dots
struct QuarterProgressDots: View {
    let currentQuarter: Int
    let totalQuarters: Int = 4

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...totalQuarters, id: \.self) { quarter in
                Circle()
                    .fill(quarter <= currentQuarter ? DesignSystem.Colors.liveGreen : DesignSystem.Colors.surfaceElevated)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(quarter <= currentQuarter ? DesignSystem.Colors.liveGreen : DesignSystem.Colors.glassBorder, lineWidth: 1))
                    .shadow(color: quarter <= currentQuarter ? DesignSystem.Colors.liveGreen.opacity(0.5) : .clear, radius: 4)
            }
        }
    }
}

// MARK: - Winning cell glow
struct WinningGlow: ViewModifier {
    let isWinning: Bool
    let color: Color
    @State private var glowIntensity: Double = 0.3
    @State private var borderGlow: Double = 0.5

    func body(content: Content) -> some View {
        content
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color, lineWidth: isWinning ? 2 : 0).opacity(borderGlow))
            .shadow(color: color.opacity(isWinning ? glowIntensity : 0), radius: 12)
            .shadow(color: color.opacity(isWinning ? glowIntensity * 0.5 : 0), radius: 24)
            .onAppear {
                guard isWinning else { return }
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { glowIntensity = 0.8; borderGlow = 1.0 }
            }
    }
}

extension View {
    func winningGlow(isWinning: Bool, color: Color = DesignSystem.Colors.liveGreen) -> some View {
        modifier(WinningGlow(isWinning: isWinning, color: color))
    }
}

// MARK: - Skeleton loading
struct SkeletonView: View {
    let width: CGFloat?
    let height: CGFloat
    var cornerRadius: CGFloat = 8
    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(DesignSystem.Colors.surfaceElevated)
            .frame(width: width, height: height)
            .overlay(
                GeometryReader { geo in
                    LinearGradient(colors: [.clear, Color.white.opacity(0.1), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width * 0.5)
                        .offset(x: shimmerOffset * geo.size.width)
                }
                .mask(RoundedRectangle(cornerRadius: cornerRadius))
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) { shimmerOffset = 1.5 }
            }
    }
}

// MARK: - Points away indicator (e.g. "KC +3 PTS")
struct PointsAwayIndicator: View {
    let pointsAway: Int
    let teamAbbr: String

    var urgencyColor: Color {
        switch pointsAway {
        case 1...3: return DesignSystem.Colors.dangerRed
        case 4...6: return DesignSystem.Colors.winnerGold
        default: return DesignSystem.Colors.accentBlue
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(teamAbbr)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(DesignSystem.Colors.textSecondary)
            Image(systemName: "arrow.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(DesignSystem.Colors.textMuted)
            HStack(spacing: 2) {
                Text("+\(pointsAway)")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(urgencyColor)
                Text("PTS")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(urgencyColor.opacity(0.7))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(urgencyColor.opacity(0.15))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(urgencyColor.opacity(0.3), lineWidth: 1))
    }
}

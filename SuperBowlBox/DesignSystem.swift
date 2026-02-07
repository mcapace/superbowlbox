import SwiftUI

// MARK: - Futuristic Design System
// Inspired by: Robinhood, Linear, Arc, Apple Weather, Flighty

struct DesignSystem {

    // MARK: - Color Palette
    struct Colors {
        // Backgrounds - Deep space blacks
        static let background = Color(hex: "050507")!
        static let backgroundSecondary = Color(hex: "0A0A0F")!
        static let backgroundTertiary = Color(hex: "12121A")!
        static let surface = Color(hex: "0F0F14")!
        static let surfaceElevated = Color(hex: "1A1A24")!

        // Glass effect colors - More visible
        static let glassFill = Color.white.opacity(0.03)
        static let glassBorder = Color.white.opacity(0.08)
        static let glassHighlight = Color.white.opacity(0.12)

        // Primary accent - Cyber blue
        static let accent = Color(hex: "00D4FF")!
        static let accentLight = Color(hex: "5CEBFF")!
        static let accentGlow = Color(hex: "00D4FF")!.opacity(0.6)

        // Live/Active - Matrix green
        static let live = Color(hex: "00FF88")!
        static let liveGlow = Color(hex: "00FF88")!.opacity(0.6)
        static let livePulse = Color(hex: "4ADE80")!

        // Winner - Electric gold
        static let gold = Color(hex: "FFD700")!
        static let goldLight = Color(hex: "FFE55C")!
        static let goldGlow = Color(hex: "FFD700")!.opacity(0.5)

        // Danger/Hot - Neon pink/red
        static let danger = Color(hex: "FF3366")!
        static let dangerGlow = Color(hex: "FF3366")!.opacity(0.5)

        // Holographic accents
        static let holoPurple = Color(hex: "A855F7")!
        static let holoBlue = Color(hex: "3B82F6")!
        static let holoCyan = Color(hex: "22D3EE")!

        // Text hierarchy
        static let textPrimary = Color.white
        static let textSecondary = Color(hex: "B4B4C0")!
        static let textTertiary = Color(hex: "6B6B7B")!
        static let textMuted = Color(hex: "404050")!

        // Gradients
        static let cyberGradient = LinearGradient(
            colors: [Color(hex: "00D4FF")!, Color(hex: "A855F7")!],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let holoGradient = LinearGradient(
            colors: [
                Color(hex: "FF3366")!,
                Color(hex: "A855F7")!,
                Color(hex: "00D4FF")!,
                Color(hex: "00FF88")!
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let goldGradient = LinearGradient(
            colors: [Color(hex: "FFD700")!, Color(hex: "FFA500")!],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let liveGradient = LinearGradient(
            colors: [Color(hex: "00FF88")!, Color(hex: "00D4FF")!],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let dangerGradient = LinearGradient(
            colors: [Color(hex: "FF3366")!, Color(hex: "FF6B35")!],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Typography
    struct Typography {
        // Display - For scores and big numbers
        static let scoreHero = Font.system(size: 80, weight: .black, design: .rounded)
        static let scoreLarge = Font.system(size: 64, weight: .bold, design: .rounded)
        static let scoreMedium = Font.system(size: 44, weight: .bold, design: .rounded)

        // Headings
        static let title = Font.system(size: 32, weight: .bold, design: .default)
        static let headline = Font.system(size: 20, weight: .semibold, design: .default)
        static let subheadline = Font.system(size: 16, weight: .semibold, design: .default)

        // Body
        static let body = Font.system(size: 16, weight: .regular, design: .default)
        static let bodyMedium = Font.system(size: 14, weight: .medium, design: .default)
        static let caption = Font.system(size: 12, weight: .medium, design: .default)
        static let captionSmall = Font.system(size: 10, weight: .semibold, design: .default)

        // Monospace for numbers
        static let mono = Font.system(size: 14, weight: .medium, design: .monospaced)
        static let monoLarge = Font.system(size: 18, weight: .bold, design: .monospaced)
        static let monoHero = Font.system(size: 28, weight: .bold, design: .monospaced)
    }

    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    // MARK: - Radius
    struct Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let full: CGFloat = 9999
    }

    // MARK: - Animation
    struct Animation {
        static let springSnappy = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
        static let springSmooth = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.8)
        static let springBouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)
        static let easeOut = SwiftUI.Animation.easeOut(duration: 0.2)
    }
}

// MARK: - Animated Mesh Background
struct AnimatedMeshBackground: View {
    @State private var animate = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/30)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate

                // Draw gradient orbs
                let orb1Center = CGPoint(
                    x: size.width * 0.3 + sin(time * 0.5) * 50,
                    y: size.height * 0.2 + cos(time * 0.3) * 30
                )
                let orb2Center = CGPoint(
                    x: size.width * 0.7 + cos(time * 0.4) * 40,
                    y: size.height * 0.6 + sin(time * 0.6) * 50
                )
                let orb3Center = CGPoint(
                    x: size.width * 0.5 + sin(time * 0.7) * 60,
                    y: size.height * 0.8 + cos(time * 0.5) * 40
                )

                // Purple orb
                context.fill(
                    Circle().path(in: CGRect(x: orb1Center.x - 150, y: orb1Center.y - 150, width: 300, height: 300)),
                    with: .color(Color(hex: "A855F7")!.opacity(0.15))
                )

                // Cyan orb
                context.fill(
                    Circle().path(in: CGRect(x: orb2Center.x - 200, y: orb2Center.y - 200, width: 400, height: 400)),
                    with: .color(Color(hex: "00D4FF")!.opacity(0.1))
                )

                // Green orb
                context.fill(
                    Circle().path(in: CGRect(x: orb3Center.x - 120, y: orb3Center.y - 120, width: 240, height: 240)),
                    with: .color(Color(hex: "00FF88")!.opacity(0.08))
                )
            }
        }
        .blur(radius: 80)
        .background(DesignSystem.Colors.background)
        .ignoresSafeArea()
    }
}

// MARK: - Tech Grid Background
struct TechGridBackground: View {
    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let gridSize: CGFloat = 40
                let lineWidth: CGFloat = 0.5

                // Horizontal lines
                for y in stride(from: 0, to: size.height, by: gridSize) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(Color.white.opacity(0.03)), lineWidth: lineWidth)
                }

                // Vertical lines
                for x in stride(from: 0, to: size.width, by: gridSize) {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(Color.white.opacity(0.03)), lineWidth: lineWidth)
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Orbital Ring View
struct OrbitalRing: View {
    let progress: Double
    let color: Color
    let size: CGFloat
    let lineWidth: CGFloat

    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(color.opacity(0.1), lineWidth: lineWidth)
                .frame(width: size, height: size)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [color.opacity(0.3), color, color],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.5), radius: 8)

            // Orbiting dot
            Circle()
                .fill(color)
                .frame(width: lineWidth * 2, height: lineWidth * 2)
                .offset(y: -size / 2)
                .rotationEffect(.degrees(rotation))
                .shadow(color: color, radius: 6)
        }
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Neon Card Modifier
struct NeonCard: ViewModifier {
    let glowColor: Color
    var intensity: Double = 0.3

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                    .fill(DesignSystem.Colors.surface.opacity(0.8))
            )
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                    .fill(.ultraThinMaterial.opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                    .stroke(glowColor.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: glowColor.opacity(intensity), radius: 20, y: 5)
            .shadow(color: glowColor.opacity(intensity * 0.5), radius: 40, y: 10)
    }
}

// MARK: - Holographic Shimmer
struct HolographicShimmer: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.1),
                            Color(hex: "A855F7")!.opacity(0.1),
                            Color(hex: "00D4FF")!.opacity(0.1),
                            Color.white.opacity(0.1),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: phase * geo.size.width)
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - Glowing Border
struct GlowingBorder: ViewModifier {
    let colors: [Color]
    @State private var rotation: Double = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                    .stroke(
                        AngularGradient(
                            colors: colors + colors,
                            center: .center,
                            angle: .degrees(rotation)
                        ),
                        lineWidth: 2
                    )
                    .blur(radius: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                    .stroke(
                        AngularGradient(
                            colors: colors + colors,
                            center: .center,
                            angle: .degrees(rotation)
                        ),
                        lineWidth: 1
                    )
            )
            .onAppear {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

// MARK: - Pulse Ring Effect
struct PulseRings: View {
    let color: Color
    @State private var scale1: CGFloat = 1
    @State private var scale2: CGFloat = 1
    @State private var scale3: CGFloat = 1
    @State private var opacity1: Double = 0.6
    @State private var opacity2: Double = 0.4
    @State private var opacity3: Double = 0.2

    var body: some View {
        ZStack {
            Circle()
                .stroke(color, lineWidth: 2)
                .scaleEffect(scale1)
                .opacity(opacity1)

            Circle()
                .stroke(color, lineWidth: 1.5)
                .scaleEffect(scale2)
                .opacity(opacity2)

            Circle()
                .stroke(color, lineWidth: 1)
                .scaleEffect(scale3)
                .opacity(opacity3)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false)) {
                scale1 = 2.5
                opacity1 = 0
            }
            withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false).delay(0.5)) {
                scale2 = 2.5
                opacity2 = 0
            }
            withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false).delay(1)) {
                scale3 = 2.5
                opacity3 = 0
            }
        }
    }
}

// MARK: - Animated Counter
struct AnimatedCounter: View {
    let value: Int
    let font: Font
    let color: Color

    @State private var displayValue: Int = 0

    var body: some View {
        Text("\(displayValue)")
            .font(font)
            .foregroundColor(color)
            .contentTransition(.numericText(value: displayValue))
            .onChange(of: value) { _, newValue in
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    displayValue = newValue
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                    displayValue = value
                }
            }
    }
}

// MARK: - Data Waveform
struct DataWaveform: View {
    let color: Color
    @State private var phase: CGFloat = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/30)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                var path = Path()

                let amplitude: CGFloat = size.height * 0.3
                let frequency: CGFloat = 0.02
                let speed: CGFloat = 3

                path.move(to: CGPoint(x: 0, y: size.height / 2))

                for x in stride(from: 0, to: size.width, by: 2) {
                    let y = size.height / 2 +
                        sin(x * frequency + CGFloat(time) * speed) * amplitude * 0.5 +
                        sin(x * frequency * 2 + CGFloat(time) * speed * 1.5) * amplitude * 0.3 +
                        sin(x * frequency * 0.5 + CGFloat(time) * speed * 0.5) * amplitude * 0.2
                    path.addLine(to: CGPoint(x: x, y: y))
                }

                context.stroke(path, with: .linearGradient(
                    Gradient(colors: [color.opacity(0.3), color, color.opacity(0.3)]),
                    startPoint: CGPoint(x: 0, y: size.height / 2),
                    endPoint: CGPoint(x: size.width, y: size.height / 2)
                ), lineWidth: 2)
            }
        }
    }
}

// MARK: - Glass Card Modifier (Updated)
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = DesignSystem.Radius.xl
    var borderOpacity: Double = 0.1
    var backgroundOpacity: Double = 0.05

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(DesignSystem.Colors.surface.opacity(0.6))
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - Glow Effect Modifier
struct GlowEffect: ViewModifier {
    let color: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color, radius: radius / 2)
            .shadow(color: color.opacity(0.5), radius: radius)
    }
}

// MARK: - View Extensions
extension View {
    func glassCard(cornerRadius: CGFloat = DesignSystem.Radius.xl) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }

    func neonCard(_ color: Color, intensity: Double = 0.3) -> some View {
        modifier(NeonCard(glowColor: color, intensity: intensity))
    }

    func glow(_ color: Color, radius: CGFloat = 20) -> some View {
        modifier(GlowEffect(color: color, radius: radius))
    }

    func holoShimmer() -> some View {
        modifier(HolographicShimmer())
    }

    func glowingBorder(_ colors: [Color]) -> some View {
        modifier(GlowingBorder(colors: colors))
    }
}

// MARK: - Color Extension
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}

// MARK: - Haptic Feedback
struct Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func winner() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            generator.impactOccurred(intensity: 0.7)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            generator.impactOccurred(intensity: 0.5)
        }
    }
}

// MARK: - Score Flip Digit (Airport Board Style)
struct FlipDigit: View {
    let digit: Int
    let color: Color
    let size: CGFloat

    @State private var animateTop = false
    @State private var animateBottom = false
    @State private var displayDigit: Int = 0

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: size * 0.15)
                .fill(DesignSystem.Colors.surface)
                .frame(width: size, height: size * 1.4)

            // Digit
            Text("\(displayDigit)")
                .font(.system(size: size * 0.8, weight: .black, design: .rounded))
                .foregroundColor(color)
                .contentTransition(.numericText(value: displayDigit))

            // Center line
            Rectangle()
                .fill(DesignSystem.Colors.background)
                .frame(height: 2)

            // Border
            RoundedRectangle(cornerRadius: size * 0.15)
                .stroke(color.opacity(0.3), lineWidth: 1)
                .frame(width: size, height: size * 1.4)
        }
        .shadow(color: color.opacity(0.3), radius: 8, y: 2)
        .onChange(of: digit) { _, newValue in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                displayDigit = newValue
            }
        }
        .onAppear {
            displayDigit = digit
        }
    }
}

// MARK: - Live Pulse Indicator
struct LivePulseIndicator: View {
    let isLive: Bool
    var size: CGFloat = 12

    @State private var pulse = false
    @State private var ringScale: CGFloat = 1
    @State private var ringOpacity: Double = 0.8

    var body: some View {
        ZStack {
            if isLive {
                // Outer pulse rings
                Circle()
                    .stroke(DesignSystem.Colors.live, lineWidth: 2)
                    .frame(width: size * 2.5, height: size * 2.5)
                    .scaleEffect(ringScale)
                    .opacity(ringOpacity)

                Circle()
                    .stroke(DesignSystem.Colors.live, lineWidth: 1)
                    .frame(width: size * 2, height: size * 2)
                    .scaleEffect(ringScale * 0.8)
                    .opacity(ringOpacity * 0.6)
            }

            // Core dot
            Circle()
                .fill(isLive ? DesignSystem.Colors.live : DesignSystem.Colors.textMuted)
                .frame(width: size, height: size)
                .scaleEffect(pulse ? 1.2 : 1.0)
                .shadow(color: isLive ? DesignSystem.Colors.liveGlow : .clear, radius: 6)
        }
        .onAppear {
            guard isLive else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                ringScale = 2
                ringOpacity = 0
            }
        }
    }
}

// MARK: - Quarter Progress Dots
struct QuarterProgressDots: View {
    let currentQuarter: Int
    let totalQuarters: Int = 4

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...totalQuarters, id: \.self) { quarter in
                Circle()
                    .fill(quarter <= currentQuarter ? DesignSystem.Colors.live : DesignSystem.Colors.surface)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(
                                quarter <= currentQuarter ? DesignSystem.Colors.live : DesignSystem.Colors.glassBorder,
                                lineWidth: 1
                            )
                    )
                    .shadow(color: quarter <= currentQuarter ? DesignSystem.Colors.liveGlow : .clear, radius: 4)
            }
        }
    }
}

// MARK: - Winning Cell Glow Animation
struct WinningGlow: ViewModifier {
    let isWinning: Bool
    let color: Color

    @State private var glowIntensity: Double = 0.3
    @State private var borderGlow: Double = 0.5

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        color,
                        lineWidth: isWinning ? 2 : 0
                    )
                    .opacity(borderGlow)
            )
            .shadow(color: color.opacity(isWinning ? glowIntensity : 0), radius: 12)
            .shadow(color: color.opacity(isWinning ? glowIntensity * 0.5 : 0), radius: 24)
            .onAppear {
                guard isWinning else { return }
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    glowIntensity = 0.8
                    borderGlow = 1.0
                }
            }
    }
}

// MARK: - Probability Gauge
struct ProbabilityGauge: View {
    let probability: Double // 0-1
    let label: String
    let size: CGFloat

    @State private var animatedProgress: Double = 0

    var gaugeColor: Color {
        if probability > 0.6 { return DesignSystem.Colors.live }
        if probability > 0.3 { return DesignSystem.Colors.gold }
        return DesignSystem.Colors.danger
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background track
                Circle()
                    .trim(from: 0.15, to: 0.85)
                    .stroke(DesignSystem.Colors.surface, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(90))

                // Progress
                Circle()
                    .trim(from: 0.15, to: 0.15 + (animatedProgress * 0.7))
                    .stroke(
                        gaugeColor,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(90))
                    .shadow(color: gaugeColor.opacity(0.5), radius: 6)

                // Percentage text
                VStack(spacing: 2) {
                    Text("\(Int(animatedProgress * 100))")
                        .font(.system(size: size * 0.25, weight: .black, design: .monospaced))
                        .foregroundColor(gaugeColor)
                    Text("%")
                        .font(.system(size: size * 0.12, weight: .bold, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.textMuted)
                }
            }

            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(DesignSystem.Colors.textTertiary)
                .tracking(1)
        }
        .onAppear {
            withAnimation(.spring(response: 1, dampingFraction: 0.8)) {
                animatedProgress = probability
            }
        }
        .onChange(of: probability) { _, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Skeleton Loading View
struct SkeletonView: View {
    let width: CGFloat?
    let height: CGFloat
    var cornerRadius: CGFloat = 8

    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(DesignSystem.Colors.surface)
            .frame(width: width, height: height)
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.1),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.5)
                    .offset(x: shimmerOffset * geo.size.width)
                }
                .mask(RoundedRectangle(cornerRadius: cornerRadius))
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    shimmerOffset = 1.5
                }
            }
    }
}

// MARK: - Celebration Confetti
struct ConfettiView: View {
    let isActive: Bool
    let colors: [Color]

    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(particle.position)
                        .opacity(particle.opacity)
                }
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                spawnConfetti()
            }
        }
        .allowsHitTesting(false)
    }

    func spawnConfetti() {
        let centerX = UIScreen.main.bounds.width / 2
        let startY = UIScreen.main.bounds.height / 3

        for i in 0..<30 {
            let particle = ConfettiParticle(
                color: colors.randomElement() ?? DesignSystem.Colors.gold,
                size: CGFloat.random(in: 6...12),
                position: CGPoint(x: centerX, y: startY),
                opacity: 1.0
            )
            particles.append(particle)

            // Animate particle
            let delay = Double(i) * 0.02
            let endX = centerX + CGFloat.random(in: -150...150)
            let endY = startY + CGFloat.random(in: 100...400)

            withAnimation(.easeOut(duration: 2).delay(delay)) {
                if let index = particles.firstIndex(where: { $0.id == particle.id }) {
                    particles[index].position = CGPoint(x: endX, y: endY)
                    particles[index].opacity = 0
                }
            }
        }

        // Clean up particles
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            particles.removeAll()
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    var position: CGPoint
    var opacity: Double
}

// MARK: - Points Away Indicator
struct PointsAwayIndicator: View {
    let pointsAway: Int
    let teamAbbr: String

    var urgencyColor: Color {
        switch pointsAway {
        case 1...3: return DesignSystem.Colors.danger
        case 4...6: return DesignSystem.Colors.gold
        default: return DesignSystem.Colors.accent
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            // Team needing to score
            Text(teamAbbr)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(DesignSystem.Colors.textSecondary)

            // Arrow
            Image(systemName: "arrow.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(DesignSystem.Colors.textMuted)

            // Points needed
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
        .overlay(
            Capsule()
                .stroke(urgencyColor.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Score Change Animation
struct ScoreChangeIndicator: View {
    let change: Int
    @State private var show = false
    @State private var offset: CGFloat = 0

    var body: some View {
        if change != 0 {
            Text(change > 0 ? "+\(change)" : "\(change)")
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundColor(change > 0 ? DesignSystem.Colors.live : DesignSystem.Colors.danger)
                .opacity(show ? 0 : 1)
                .offset(y: offset)
                .onAppear {
                    withAnimation(.easeOut(duration: 1.5)) {
                        show = true
                        offset = -30
                    }
                }
        }
    }
}

// MARK: - View Extension for Winning Glow
extension View {
    func winningGlow(isWinning: Bool, color: Color = DesignSystem.Colors.live) -> some View {
        modifier(WinningGlow(isWinning: isWinning, color: color))
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        AnimatedMeshBackground()
        TechGridBackground()

        ScrollView {
            VStack(spacing: 30) {
                Text("PREMIUM ANIMATIONS")
                    .font(DesignSystem.Typography.title)
                    .foregroundStyle(DesignSystem.Colors.cyberGradient)

                // Flip Digits
                HStack(spacing: 8) {
                    FlipDigit(digit: 2, color: DesignSystem.Colors.danger, size: 50)
                    FlipDigit(digit: 1, color: DesignSystem.Colors.accent, size: 50)
                }

                // Live Indicator
                HStack(spacing: 20) {
                    LivePulseIndicator(isLive: true)
                    Text("LIVE")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.live)
                }

                // Quarter Progress
                QuarterProgressDots(currentQuarter: 2)

                // Probability Gauge
                ProbabilityGauge(probability: 0.72, label: "WIN CHANCE", size: 100)

                // Skeleton Loading
                VStack(spacing: 8) {
                    SkeletonView(width: 200, height: 20)
                    SkeletonView(width: 150, height: 16)
                }

                // Points Away
                PointsAwayIndicator(pointsAway: 3, teamAbbr: "KC")
            }
            .padding(30)
        }
    }
}

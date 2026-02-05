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

// MARK: - Preview
#Preview {
    ZStack {
        AnimatedMeshBackground()
        TechGridBackground()

        VStack(spacing: 30) {
            Text("FUTURISTIC")
                .font(DesignSystem.Typography.title)
                .foregroundStyle(DesignSystem.Colors.cyberGradient)

            HStack(spacing: 20) {
                OrbitalRing(progress: 0.75, color: DesignSystem.Colors.accent, size: 100, lineWidth: 4)
                OrbitalRing(progress: 0.5, color: DesignSystem.Colors.live, size: 80, lineWidth: 3)
            }

            DataWaveform(color: DesignSystem.Colors.accent)
                .frame(height: 60)
                .padding(.horizontal, 40)

            VStack {
                Text("LIVE SCORE")
                    .font(DesignSystem.Typography.captionSmall)
                    .foregroundColor(DesignSystem.Colors.textMuted)

                AnimatedCounter(value: 42, font: DesignSystem.Typography.scoreLarge, color: DesignSystem.Colors.live)
            }
            .padding(30)
            .neonCard(DesignSystem.Colors.live, intensity: 0.4)
        }
    }
}

import SwiftUI

// MARK: - Premium Design System
// Inspired by Linear, Arc Browser, Flighty

struct DesignSystem {

    // MARK: - Color Palette
    struct Colors {
        // Backgrounds - Rich blacks, not pure black
        static let background = Color(hex: "09090B")!
        static let backgroundSecondary = Color(hex: "18181B")!
        static let backgroundTertiary = Color(hex: "27272A")!
        static let surface = Color(hex: "1C1C1E")!
        static let surfaceElevated = Color(hex: "2C2C2E")!

        // Glass effect colors
        static let glassFill = Color.white.opacity(0.05)
        static let glassBorder = Color.white.opacity(0.1)
        static let glassHighlight = Color.white.opacity(0.15)

        // Primary accent - Electric blue
        static let accent = Color(hex: "3B82F6")!
        static let accentLight = Color(hex: "60A5FA")!
        static let accentGlow = Color(hex: "3B82F6")!.opacity(0.4)

        // Live/Active - Neon green
        static let live = Color(hex: "22C55E")!
        static let liveGlow = Color(hex: "22C55E")!.opacity(0.5)
        static let livePulse = Color(hex: "4ADE80")!

        // Winner - Rich gold
        static let gold = Color(hex: "F59E0B")!
        static let goldLight = Color(hex: "FBBF24")!
        static let goldGlow = Color(hex: "F59E0B")!.opacity(0.4)

        // Danger/Away team
        static let danger = Color(hex: "EF4444")!
        static let dangerGlow = Color(hex: "EF4444")!.opacity(0.4)

        // Text hierarchy
        static let textPrimary = Color.white
        static let textSecondary = Color(hex: "A1A1AA")!
        static let textTertiary = Color(hex: "71717A")!
        static let textMuted = Color(hex: "52525B")!

        // Gradients
        static let scoreGradient = LinearGradient(
            colors: [Color(hex: "3B82F6")!, Color(hex: "8B5CF6")!],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let goldGradient = LinearGradient(
            colors: [Color(hex: "F59E0B")!, Color(hex: "EAB308")!],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let liveGradient = LinearGradient(
            colors: [Color(hex: "22C55E")!, Color(hex: "10B981")!],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let meshGradient = MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
            ],
            colors: [
                Color(hex: "09090B")!, Color(hex: "0F172A")!, Color(hex: "09090B")!,
                Color(hex: "0F172A")!, Color(hex: "1E1B4B")!, Color(hex: "0F172A")!,
                Color(hex: "09090B")!, Color(hex: "0F172A")!, Color(hex: "09090B")!
            ]
        )
    }

    // MARK: - Typography
    struct Typography {
        // Display - For scores and big numbers
        static let scoreHero = Font.system(size: 72, weight: .bold, design: .rounded)
        static let scoreLarge = Font.system(size: 56, weight: .bold, design: .rounded)
        static let scoreMedium = Font.system(size: 40, weight: .bold, design: .rounded)

        // Headings
        static let title = Font.system(size: 34, weight: .bold, design: .default)
        static let headline = Font.system(size: 22, weight: .semibold, design: .default)
        static let subheadline = Font.system(size: 17, weight: .semibold, design: .default)

        // Body
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let bodyMedium = Font.system(size: 15, weight: .medium, design: .default)
        static let caption = Font.system(size: 13, weight: .medium, design: .default)
        static let captionSmall = Font.system(size: 11, weight: .semibold, design: .default)

        // Monospace for numbers
        static let mono = Font.system(size: 15, weight: .medium, design: .monospaced)
        static let monoLarge = Font.system(size: 20, weight: .bold, design: .monospaced)
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
        static let full: CGFloat = 9999
    }

    // MARK: - Shadows
    struct Shadows {
        static func glow(_ color: Color, radius: CGFloat = 20) -> some View {
            EmptyView()
        }
    }

    // MARK: - Animation
    struct Animation {
        static let springSnappy = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
        static let springSmooth = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.8)
        static let springBouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)
        static let easeOut = SwiftUI.Animation.easeOut(duration: 0.2)
    }
}

// MARK: - Glass Card Modifier
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = DesignSystem.Radius.xl
    var borderOpacity: Double = 0.1
    var backgroundOpacity: Double = 0.05

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .opacity(0.8)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(backgroundOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(borderOpacity), lineWidth: 1)
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

// MARK: - Pulse Animation Modifier
struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false
    let color: Color

    func body(content: Content) -> some View {
        content
            .overlay(
                Circle()
                    .stroke(color, lineWidth: 2)
                    .scaleEffect(isPulsing ? 1.5 : 1)
                    .opacity(isPulsing ? 0 : 0.8)
                    .animation(
                        .easeOut(duration: 1.5)
                        .repeatForever(autoreverses: false),
                        value: isPulsing
                    )
            )
            .onAppear { isPulsing = true }
    }
}

// MARK: - Shimmer Effect
struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.1),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    phase = 400
                }
            }
    }
}

// MARK: - View Extensions
extension View {
    func glassCard(cornerRadius: CGFloat = DesignSystem.Radius.xl) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }

    func glow(_ color: Color, radius: CGFloat = 20) -> some View {
        modifier(GlowEffect(color: color, radius: radius))
    }

    func pulse(_ color: Color) -> some View {
        modifier(PulseAnimation(color: color))
    }

    func shimmer() -> some View {
        modifier(ShimmerEffect())
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
        // Celebratory haptic pattern
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
        DesignSystem.Colors.background
            .ignoresSafeArea()

        VStack(spacing: 20) {
            Text("Premium Design")
                .font(DesignSystem.Typography.title)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text("72")
                .font(DesignSystem.Typography.scoreHero)
                .foregroundStyle(DesignSystem.Colors.scoreGradient)

            HStack {
                Circle()
                    .fill(DesignSystem.Colors.live)
                    .frame(width: 12, height: 12)
                    .glow(DesignSystem.Colors.live, radius: 10)

                Text("LIVE")
                    .font(DesignSystem.Typography.captionSmall)
                    .foregroundColor(DesignSystem.Colors.live)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .glassCard(cornerRadius: DesignSystem.Radius.full)

            VStack {
                Text("Glass Card")
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Text("With blur effect")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .padding(24)
            .glassCard()
        }
    }
}
